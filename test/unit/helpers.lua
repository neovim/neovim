local ffi = require('ffi')
local formatc = require('test.unit.formatc')
local Set = require('test.unit.set')
local Preprocess = require('test.unit.preprocess')
local Paths = require('test.config.paths')
local global_helpers = require('test.helpers')
local assert = require('luassert')
local say = require('say')

local posix = nil
local syscall = nil

local check_cores = global_helpers.check_cores
local neq = global_helpers.neq
local map = global_helpers.map
local eq = global_helpers.eq
local ok = global_helpers.ok

-- C constants.
local NULL = ffi.cast('void*', 0)

local OK = 1
local FAIL = 0

local cimport

-- add some standard header locations
for _, p in ipairs(Paths.include_paths) do
  Preprocess.add_to_include_path(p)
end

local child_pid = nil
local function only_separate(func)
  return function(...)
    if child_pid ~= 0 then
      error('This function must be run in a separate process only')
    end
    return func(...)
  end
end
local child_calls_init = {}
local child_calls_mod = nil
local child_calls_mod_once = nil
local function child_call(func, ret)
  return function(...)
    local child_calls = child_calls_mod or child_calls_init
    if child_pid ~= 0 then
      child_calls[#child_calls + 1] = {func=func, args={...}}
      return ret
    else
      return func(...)
    end
  end
end

-- Run some code at the start of the child process, before running the test
-- itself. Is supposed to be run in `before_each`.
local function child_call_once(func, ...)
  if child_pid ~= 0 then
    child_calls_mod_once[#child_calls_mod_once + 1] = {
      func=func, args={...}}
  else
    func(...)
  end
end

local child_cleanups_mod_once = nil

-- Run some code at the end of the child process, before exiting. Is supposed to
-- be run in `before_each` because `after_each` is run after child has exited.
local function child_cleanup_once(func, ...)
  local child_cleanups = child_cleanups_mod_once
  if child_pid ~= 0 then
    child_cleanups[#child_cleanups + 1] = {func=func, args={...}}
  else
    func(...)
  end
end

local libnvim = nil

local lib = setmetatable({}, {
  __index = only_separate(function(_, idx)
    return libnvim[idx]
  end),
  __newindex = child_call(function(_, idx, val)
    libnvim[idx] = val
  end),
})

local init = only_separate(function()
  -- load neovim shared library
  libnvim = ffi.load(Paths.test_libnvim_path)
  for _, c in ipairs(child_calls_init) do
    c.func(unpack(c.args))
  end
  libnvim.time_init()
  libnvim.early_init()
  libnvim.event_init()
  if child_calls_mod then
    for _, c in ipairs(child_calls_mod) do
      c.func(unpack(c.args))
    end
  end
  if child_calls_mod_once then
    for _, c in ipairs(child_calls_mod_once) do
      c.func(unpack(c.args))
    end
    child_calls_mod_once = nil
  end
end)

local deinit = only_separate(function()
  if child_cleanups_mod_once then
    for _, c in ipairs(child_cleanups_mod_once) do
      c.func(unpack(c.args))
    end
    child_cleanups_mod_once = nil
  end
end)

local function trim(s)
  return s:match('^%s*(.*%S)') or ''
end

-- a Set that keeps around the lines we've already seen
local cdefs_init = Set:new()
local cdefs_mod = nil
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
            or string.find(line, "UUID_NULL")  -- static const uuid_t UUID_NULL = {...}
            or string.find(line, "inline _Bool")) then
      result[#result + 1] = line
    end
  end

  return table.concat(result, "\n")
end


local cdef = ffi.cdef

local cimportstr

local previous_defines_init = ''
local preprocess_cache_init = {}
local previous_defines_mod = ''
local preprocess_cache_mod = nil

local function is_child_cdefs()
  return (os.getenv('NVIM_TEST_MAIN_CDEFS') ~= '1')
end

-- use this helper to import C files, you can pass multiple paths at once,
-- this helper will return the C namespace of the nvim library.
cimport = function(...)
  local previous_defines, preprocess_cache, cdefs
  if is_child_cdefs() and preprocess_cache_mod then
    preprocess_cache = preprocess_cache_mod
    previous_defines = previous_defines_mod
    cdefs = cdefs_mod
  else
    preprocess_cache = preprocess_cache_init
    previous_defines = previous_defines_init
    cdefs = cdefs_init
  end
  for _, path in ipairs({...}) do
    if not (path:sub(1, 1) == '/' or path:sub(1, 1) == '.'
            or path:sub(2, 2) == ':') then
      path = './' .. path
    end
    if not preprocess_cache[path] then
      local body
      body, previous_defines = Preprocess.preprocess(previous_defines, path)
      -- format it (so that the lines are "unique" statements), also filter out
      -- Objective-C blocks
      if os.getenv('NVIM_TEST_PRINT_I') == '1' then
        local lnum = 0
        for line in body:gmatch('[^\n]+') do
          lnum = lnum + 1
          print(lnum, line)
        end
      end
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
      -- request a sorted version of the new lines (same relative order as the
      -- original preprocessed file) and feed that to the LuaJIT ffi
      local new_lines = new_cdefs:to_table()
      if os.getenv('NVIM_TEST_PRINT_CDEF') == '1' then
        for lnum, line in ipairs(new_lines) do
          print(lnum, line)
        end
      end
      body = table.concat(new_lines, '\n')

      preprocess_cache[path] = body
    end
    cimportstr(preprocess_cache, path)
  end
  return lib
end

local cimport_immediate = function(...)
  local saved_pid = child_pid
  child_pid = 0
  local err, emsg = pcall(cimport, ...)
  child_pid = saved_pid
  if not err then
    emsg = tostring(emsg)
    io.stderr:write(emsg .. '\n')
    assert(false)
  else
    return lib
  end
end

local function _cimportstr(preprocess_cache, path)
  if imported:contains(path) then
    return lib
  end
  local body = preprocess_cache[path]
  if body == '' then
    return lib
  end
  cdef(body)
  imported:add(path)

  return lib
end

if is_child_cdefs() then
  cimportstr = child_call(_cimportstr, lib)
else
  cimportstr = _cimportstr
end

local function alloc_log_new()
  local log = {
    log={},
    lib=cimport('./src/nvim/memory.h'),
    original_functions={},
    null={['\0:is_null']=true},
  }
  local allocator_functions = {'malloc', 'free', 'calloc', 'realloc'}
  function log:save_original_functions()
    for _, funcname in ipairs(allocator_functions) do
      if not self.original_functions[funcname] then
        self.original_functions[funcname] = self.lib['mem_' .. funcname]
      end
    end
  end
  log.save_original_functions = child_call(log.save_original_functions)
  function log:set_mocks()
    for _, k in ipairs(allocator_functions) do
      do
        local kk = k
        self.lib['mem_' .. k] = function(...)
          local log_entry = {func=kk, args={...}}
          self.log[#self.log + 1] = log_entry
          if kk == 'free' then
            self.original_functions[kk](...)
          else
            log_entry.ret = self.original_functions[kk](...)
          end
          for i, v in ipairs(log_entry.args) do
            if v == nil then
              -- XXX This thing thinks that {NULL} ~= {NULL}.
              log_entry.args[i] = self.null
            end
          end
          if self.hook then self:hook(log_entry) end
          if log_entry.ret then
            return log_entry.ret
          end
        end
      end
    end
  end
  log.set_mocks = child_call(log.set_mocks)
  function log:clear()
    self.log = {}
  end
  function log:check(exp)
    eq(exp, self.log)
    self:clear()
  end
  function log:restore_original_functions()
    -- Do nothing: set mocks live in a separate process
    return
    --[[
       [ for k, v in pairs(self.original_functions) do
       [   self.lib['mem_' .. k] = v
       [ end
       ]]
  end
  function log:setup()
    log:save_original_functions()
    log:set_mocks()
  end
  function log:before_each()
    return
  end
  function log:after_each()
    log:restore_original_functions()
  end
  log:setup()
  return log
end

-- take a pointer to a C-allocated string and return an interned
-- version while also freeing the memory
local function internalize(cdata, len)
  ffi.gc(cdata, ffi.C.free)
  return ffi.string(cdata, len)
end

local cstr = ffi.typeof('char[?]')
local function to_cstr(string)
  return cstr(#string + 1, string)
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
  cimport_immediate('./test/unit/fixtures/posix.h')
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
          if err ~= ffi.C.kPOSIXErrnoEINTR then
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
          if err ~= ffi.C.kPOSIXErrnoEINTR then
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
        local r = ffi.C.waitpid(pid, nil, ffi.C.kPOSIXWaitWUNTRACED)
        if r == -1 then
          local err = ffi.errno(0)
          if err == ffi.C.kPOSIXErrnoECHILD then
            break
          elseif err ~= ffi.C.kPOSIXErrnoEINTR then
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
      sc[k] = function(...)
        local rets = {v(...)}
        io.stderr:write(('%s(%s) = %s\n'):format(k, format_list({...}),
                                                 format_list(rets)))
        return unpack(rets)
      end
    end)(k_, v_)
  end
end

local function gen_itp(it)
  child_calls_mod = {}
  child_calls_mod_once = {}
  child_cleanups_mod_once = {}
  preprocess_cache_mod = map(function(v) return v end, preprocess_cache_init)
  previous_defines_mod = previous_defines_init
  cdefs_mod = cdefs_init:copy()
  local function just_fail(_)
    return false
  end
  say:set('assertion.just_fail.positive', '%s')
  say:set('assertion.just_fail.negative', '%s')
  assert:register('assertion', 'just_fail', just_fail,
                  'assertion.just_fail.positive',
                  'assertion.just_fail.negative')
  local function itp(name, func, allow_failure)
    if allow_failure and os.getenv('NVIM_TEST_RUN_FAILING_TESTS') ~= '1' then
      -- FIXME Fix tests with this true
      return
    end
    it(name, function()
      local rd, wr = sc.pipe()
      child_pid = sc.fork()
      if child_pid == 0 then
        init()
        sc.close(rd)
        collectgarbage('stop')
        local err, emsg = pcall(func)
        collectgarbage('restart')
        emsg = tostring(emsg)
        if not err then
          sc.write(wr, ('-\n%05u\n%s'):format(#emsg, emsg))
          deinit()
          sc.close(wr)
          sc.exit(1)
        else
          sc.write(wr, '+\n')
          deinit()
          sc.close(wr)
          sc.exit(0)
        end
      else
        sc.close(wr)
        sc.wait(child_pid)
        child_pid = nil
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
        local err, emsg = pcall(check)
        sc.close(rd)
        if not err then
          if allow_failure then
            io.stderr:write('Errorred out:\n' .. tostring(emsg) .. '\n')
            os.execute([[sh -c "source .ci/common/test.sh ; check_core_dumps --delete \"]] .. Paths.test_luajit_prg .. [[\""]])
          else
            error(emsg)
          end
        end
      end
    end)
  end
  return itp
end

local function cppimport(path)
  return cimport(Paths.test_include_path .. '/' .. path)
end

cimport('./src/nvim/types.h', './src/nvim/main.h', './src/nvim/os/time.h')

local module = {
  cimport = cimport,
  cppimport = cppimport,
  internalize = internalize,
  ok = ok,
  eq = eq,
  neq = neq,
  ffi = ffi,
  lib = lib,
  cstr = cstr,
  to_cstr = to_cstr,
  NULL = NULL,
  OK = OK,
  FAIL = FAIL,
  alloc_log_new = alloc_log_new,
  gen_itp = gen_itp,
  only_separate = only_separate,
  child_call_once = child_call_once,
  child_cleanup_once = child_cleanup_once,
}
return function(after_each)
  if after_each then
    after_each(function()
      check_cores(Paths.test_luajit_prg)
    end)
  end
  return module
end
