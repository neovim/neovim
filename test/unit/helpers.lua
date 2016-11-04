local ffi = require('ffi')
local formatc = require('test.unit.formatc')
local Set = require('test.unit.set')
local Preprocess = require('test.unit.preprocess')
local Paths = require('test.config.paths')
local global_helpers = require('test.helpers')
local assert = require('luassert')
local say = require('say')

local neq = global_helpers.neq
local eq = global_helpers.eq
local ok = global_helpers.ok

-- C constants.
local NULL = ffi.cast('void*', 0)

local OK = 1
local FAIL = 0

-- add some standard header locations
for _, p in ipairs(Paths.include_paths) do
  Preprocess.add_to_include_path(p)
end

-- load neovim shared library
local libnvim = ffi.load(Paths.test_libnvim_path)

local function trim(s)
  return s:match('^%s*(.*%S)') or ''
end

-- a Set that keeps around the lines we've already seen
local cdefs = Set:new()
local imported = Set:new()
local pragma_pack_id = 1

-- some things are just too complex for the LuaJIT C parser to digest. We
-- usually don't need them anyway.
local function filter_complex_blocks(body)
  local result = {}

  for line in body:gmatch("[^\r\n]+") do
    if not (string.find(line, "(^)", 1, true) ~= nil
            or string.find(line, "_ISwupper", 1, true)
            or string.find(line, "msgpack_zone_push_finalizer")
            or string.find(line, "msgpack_unpacker_reserve_buffer")
            or string.find(line, "inline _Bool")) then
      result[#result + 1] = line
    end
  end

  return table.concat(result, "\n")
end

local cdef = ffi.cdef

local cimportstr

-- use this helper to import C files, you can pass multiple paths at once,
-- this helper will return the C namespace of the nvim library.
local function cimport(...)
  local paths = {}
  local args = {...}

  -- filter out paths we've already imported
  for _,path in pairs(args) do
    if path ~= nil and not imported:contains(path) then
      paths[#paths + 1] = path
    end
  end

  for _,path in pairs(paths) do
    imported:add(path)
  end

  if #paths == 0 then
    return libnvim
  end

  local body = nil
  for _ = 1, 10 do
    local stream = Preprocess.preprocess_stream(unpack(paths))
    body = stream:read("*a")
    stream:close()
    if body ~= nil then break end
  end

  if body == nil then
    print("ERROR: helpers.lua: Preprocess.preprocess_stream():read() returned empty")
  end
  return cimportstr(body)
end

cimportstr = function(body)
  -- format it (so that the lines are "unique" statements), also filter out
  -- Objective-C blocks
  body = formatc(body)
  body = filter_complex_blocks(body)

  -- add the formatted lines to a set
  local new_cdefs = Set:new()
  for line in body:gmatch("[^\r\n]+") do
    line = trim(line)
    -- give each #pragma pack an unique id, so that they don't get removed
    -- if they are inserted into the set
    -- (they are needed in the right order with the struct definitions,
    -- otherwise luajit has wrong memory layouts for the sturcts)
    if line:match("#pragma%s+pack") then
      line = line .. " // " .. pragma_pack_id
      pragma_pack_id = pragma_pack_id + 1
    end
    new_cdefs:add(line)
  end

  -- subtract the lines we've already imported from the new lines, then add
  -- the new unique lines to the old lines (so they won't be imported again)
  new_cdefs:diff(cdefs)
  cdefs:union(new_cdefs)

  if new_cdefs:size() == 0 then
    -- if there's no new lines, just return
    return libnvim
  end

  -- request a sorted version of the new lines (same relative order as the
  -- original preprocessed file) and feed that to the LuaJIT ffi
  local new_lines = new_cdefs:to_table()
  if os.getenv('NVIM_TEST_PRINT_CDEF') == '1' then
    for lnum, line in ipairs(new_lines) do
      print(lnum, line)
    end
  end
  cdef(table.concat(new_lines, "\n"))

  return libnvim
end

local function cppimport(path)
  return cimport(Paths.test_include_path .. '/' .. path)
end

local function set_logging_allocator()
  local lib = cimport('./src/nvim/memory.h')
  local log = {log={}}
  local saved = {
    malloc = lib.mem_malloc,
    free = lib.mem_free,
    calloc = lib.mem_calloc,
    realloc = lib.mem_realloc,
  }
  local restore_allocators = function()
    for k, v in pairs(saved) do
      lib['mem_' .. k] = v
    end
  end
  for k, _ in pairs(saved) do
    do
      local kk = k
      lib['mem_' .. k] = function(...)
        local log_entry = {func=kk, args={...}}
        log.log[#log.log + 1] = log_entry
        if kk == 'free' then
          saved[kk](...)
        else
          log_entry.ret = saved[kk](...)
        end
        for i, v in ipairs(log_entry.args) do
          if v == nil then
            -- XXX This thing thinks that {NULL} ~= {NULL}.
            log_entry.args[i] = nil
          end
        end
        if log.hook then log:hook(log_entry) end
        if log_entry.ret then
          return log_entry.ret
        end
      end
    end
  end
  return log, restore_allocators
end

cimport('./src/nvim/types.h')

-- take a pointer to a C-allocated string and return an interned
-- version while also freeing the memory
local function internalize(cdata, len)
  ffi.gc(cdata, ffi.C.free)
  return ffi.string(cdata, len)
end

local cstr = ffi.typeof('char[?]')
local function to_cstr(string)
  return cstr((string.len(string)) + 1, string)
end

-- initialize some global variables, this is still necessary to unit test
-- functions that rely on global state.
do
  local main = cimport('./src/nvim/main.h')
  local time = cimport('./src/nvim/os/time.h')
  time.time_init()
  main.early_init()
  main.event_init()
end

local sc

if posix ~= nil then
  sc = {
    fork = posix.fork,
    pipe = posix.pipe,
    read = posix.read,
    write = posix.write,
    close = posix.close,
    wait = posix.wait,
    exit = posix._exit,
  }
elseif syscall ~= nil then
  sc = {
    fork = syscall.fork,
    pipe = function()
      local ret = {syscall.pipe()}
      return ret[3], ret[4]
    end,
    read = function(rd, len)
      return rd:read(nil, len)
    end,
    write = function(wr, s)
      return wr:write(s)
    end,
    close = function(p)
      return p:close()
    end,
    wait = syscall.wait,
    exit = syscall.exit,
  }
else
  cimport('./test/unit/fixtures/posix.h')
  sc = {
    fork = function()
      return tonumber(ffi.C.fork())
    end,
    pipe = function()
      local ret = ffi.new('int[2]', {-1, -1})
      ffi.errno(0)
      local res = ffi.C.pipe(ret)
      if (res ~= 0) then
        local err = ffi.errno(0)
        assert(res == 0, ("pipe() error: %u: %s"):format(
            err, ffi.string(ffi.C.strerror(err))))
      end
      assert(ret[0] ~= -1 and ret[1] ~= -1)
      return ret[0], ret[1]
    end,
    read = function(rd, len)
      local ret = ffi.new('char[?]', len, {0})
      local total_bytes_read = 0
      ffi.errno(0)
      while total_bytes_read < len do
        local bytes_read = tonumber(ffi.C.read(
            rd,
            ffi.cast('void*', ret + total_bytes_read),
            len - total_bytes_read))
        if bytes_read == -1 then
          local err = ffi.errno(0)
          if err ~= libnvim.kPOSIXErrnoEINTR then
            assert(false, ("read() error: %u: %s"):format(
                err, ffi.string(ffi.C.strerror(err))))
          end
        elseif bytes_read == 0 then
          break
        else
          total_bytes_read = total_bytes_read + bytes_read
        end
      end
      return ffi.string(ret, total_bytes_read)
    end,
    write = function(wr, s)
      local wbuf = to_cstr(s)
      local total_bytes_written = 0
      ffi.errno(0)
      while total_bytes_written < #s do
        local bytes_written = tonumber(ffi.C.write(
            wr,
            ffi.cast('void*', wbuf + total_bytes_written),
            #s - total_bytes_written))
        if bytes_written == -1 then
          local err = ffi.errno(0)
          if err ~= libnvim.kPOSIXErrnoEINTR then
            assert(false, ("write() error: %u: %s"):format(
                err, ffi.string(ffi.C.strerror(err))))
          end
        elseif bytes_written == 0 then
          break
        else
          total_bytes_written = total_bytes_written + bytes_written
        end
      end
      return total_bytes_written
    end,
    close = ffi.C.close,
    wait = function(pid)
      ffi.errno(0)
      while true do
        local r = ffi.C.waitpid(pid, nil, libnvim.kPOSIXWaitWUNTRACED)
        if r == -1 then
          local err = ffi.errno(0)
          if err == libnvim.kPOSIXErrnoECHILD then
            break
          elseif err ~= libnvim.kPOSIXErrnoEINTR then
            assert(false, ("waitpid() error: %u: %s"):format(
                err, ffi.string(ffi.C.strerror(err))))
          end
        else
          assert(r == pid)
        end
      end
    end,
    exit = ffi.C._exit,
  }
end

local function format_list(lst)
  local ret = ''
  for _, v in ipairs(lst) do
    if ret ~= '' then ret = ret .. ', ' end
    ret = ret .. assert:format({v, n=1})[1]
  end
  return ret
end

if os.getenv('NVIM_TEST_PRINT_SYSCALLS') == '1' then
  for k_, v_ in pairs(sc) do
    (function(k, v)
      local f = sc[k]
      sc[k] = function(...)
        local rets = {f(...)}
        io.stderr:write(('%s(%s) = %s\n'):format(k, format_list({...}),
                                                 format_list(rets)))
        return unpack(rets)
      end
    end)(k_, v_)
  end
end

local function gen_itp(it)
  local function just_fail(_)
    return false
  end
  say:set('assertion.just_fail.positive', '%s')
  say:set('assertion.just_fail.negative', '%s')
  assert:register('assertion', 'just_fail', just_fail,
                  'assertion.just_fail.positive',
                  'assertion.just_fail.negative')
  local function itp(name, func, allow_failure)
    it(name, function()
      local rd, wr = sc.pipe()
      local pid = sc.fork()
      if pid == 0 then
        sc.close(rd)
        collectgarbage('stop')
        local err, emsg = pcall(func)
        collectgarbage('restart')
        emsg = tostring(emsg)
        if not err then
          sc.write(wr, ('-\n%05u\n%s'):format(#emsg, emsg))
          sc.close(wr)
          sc.exit(1)
        else
          sc.write(wr, '+\n')
          sc.close(wr)
          sc.exit(0)
        end
      else
        sc.close(wr)
        sc.wait(pid)
        local function check()
          local res = sc.read(rd, 2)
          eq(2, #res)
          if res == '+\n' then
            return
          end
          eq('-\n', res)
          local len_s = sc.read(rd, 5)
          local len = tonumber(len_s)
          neq(0, len)
          local err = sc.read(rd, len + 1)
          assert.just_fail(err)
        end
        if allow_failure then
          local err, emsg = pcall(check)
          if not err then
            io.stderr:write('Errorred out:\n' .. tostring(emsg) .. '\n')
            os.execute([[sh -c "source .ci/common/test.sh ; check_core_dumps --delete \"\$(which luajit)\""]])
          end
        else
          check()
        end
      end
    end)
  end
  return itp
end

return {
  cimport = cimport,
  cppimport = cppimport,
  internalize = internalize,
  ok = ok,
  eq = eq,
  neq = neq,
  ffi = ffi,
  lib = libnvim,
  cstr = cstr,
  to_cstr = to_cstr,
  NULL = NULL,
  OK = OK,
  FAIL = FAIL,
  set_logging_allocator = set_logging_allocator,
  gen_itp = gen_itp,
}
