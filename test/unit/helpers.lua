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
local dedent = global_helpers.dedent
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
            or string.find(line, "_Float")
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
  function log:clear_tmp_allocs(clear_null_frees)
    local toremove = {}
    local allocs = {}
    for i, v in ipairs(self.log) do
      if v.func == 'malloc' or v.func == 'calloc' then
        allocs[tostring(v.ret)] = i
      elseif v.func == 'realloc' or v.func == 'free' then
        if allocs[tostring(v.args[1])] then
          toremove[#toremove + 1] = allocs[tostring(v.args[1])]
          if v.func == 'free' then
            toremove[#toremove + 1] = i
          end
        elseif clear_null_frees and v.args[1] == self.null then
          toremove[#toremove + 1] = i
        end
        if v.func == 'realloc' then
          allocs[tostring(v.ret)] = i
        end
      end
    end
    table.sort(toremove)
    for i = #toremove,1,-1 do
      table.remove(self.log, toremove[i])
    end
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

local function just_fail(_)
  return false
end
say:set('assertion.just_fail.positive', '%s')
say:set('assertion.just_fail.negative', '%s')
assert:register('assertion', 'just_fail', just_fail,
                'assertion.just_fail.positive',
                'assertion.just_fail.negative')

local hook_fnamelen = 30
local hook_sfnamelen = 30
local hook_numlen = 5
local hook_msglen = 1 + 1 + 1 + (1 + hook_fnamelen) + (1 + hook_sfnamelen) + (1 + hook_numlen) + 1

local tracehelp = dedent([[
  Trace: either in the format described below or custom debug output starting
  with `>`. Latter lines still have the same width in byte.

  ┌ Trace type: _r_eturn from function , function _c_all, _l_ine executed,
  │             _t_ail return, _C_ount (should not actually appear),
  │             _s_aved from previous run for reference, _>_ for custom debug
  │             output.
  │┏ Function type: _L_ua function, _C_ function, _m_ain part of chunk,
  │┃                function that did _t_ail call.
  │┃┌ Function name type: _g_lobal, _l_ocal, _m_ethod, _f_ield, _u_pvalue,
  │┃│                     space for unknown.
  │┃│ ┏ Source file name             ┌ Function name                ┏ Line
  │┃│ ┃ (trunc to 30 bytes, no .lua) │ (truncated to last 30 bytes) ┃ number
  CWN SSSSSSSSSSSSSSSSSSSSSSSSSSSSSS:FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:LLLLL\n
]])

local function child_sethook(wr)
  local trace_level = os.getenv('NVIM_TEST_TRACE_LEVEL')
  if not trace_level or trace_level == '' then
    trace_level = 1
  else
    trace_level = tonumber(trace_level)
  end
  if trace_level <= 0 then
    return
  end
  local trace_only_c = trace_level <= 1
  local prev_info, prev_reason, prev_lnum
  local function hook(reason, lnum, use_prev)
    local info = nil
    if use_prev then
      info = prev_info
    elseif reason ~= 'tail return' then  -- tail return
      info = debug.getinfo(2, 'nSl')
    end

    if trace_only_c and (not info or info.what ~= 'C') and not use_prev then
      if info.source:sub(-9) == '_spec.lua' then
        prev_info = info
        prev_reason = 'saved'
        prev_lnum = lnum
      end
      return
    end
    if trace_only_c and not use_prev and prev_reason then
      hook(prev_reason, prev_lnum, true)
      prev_reason = nil
    end

    local whatchar = ' '
    local namewhatchar = ' '
    local funcname = ''
    local source = ''
    local msgchar = reason:sub(1, 1)

    if reason == 'count' then
      msgchar = 'C'
    end

    if info then
      funcname = (info.name or ''):sub(1, hook_fnamelen)
      whatchar = info.what:sub(1, 1)
      namewhatchar = info.namewhat:sub(1, 1)
      if namewhatchar == '' then
        namewhatchar = ' '
      end
      source = info.source
      if source:sub(1, 1) == '@' then
        if source:sub(-4, -1) == '.lua' then
          source = source:sub(1, -5)
        end
        source = source:sub(-hook_sfnamelen, -1)
      end
      lnum = lnum or info.currentline
    end

    -- assert(-1 <= lnum and lnum <= 99999)
    local lnum_s
    if lnum == -1 then
      lnum_s = 'nknwn'
    else
      lnum_s = ('%u'):format(lnum)
    end
    local msg = (  -- lua does not support %*
      ''
      .. msgchar
      .. whatchar
      .. namewhatchar
      .. ' '
      .. source .. (' '):rep(hook_sfnamelen - #source)
      .. ':'
      .. funcname .. (' '):rep(hook_fnamelen - #funcname)
      .. ':'
      .. ('0'):rep(hook_numlen - #lnum_s) .. lnum_s
      .. '\n'
    )
    -- eq(hook_msglen, #msg)
    sc.write(wr, msg)
  end
  debug.sethook(hook, 'crl')
end

local trace_end_msg = ('E%s\n'):format((' '):rep(hook_msglen - 2))

local _debug_log

local debug_log = only_separate(function(...)
  return _debug_log(...)
end)

local function itp_child(wr, func)
  _debug_log = function(s)
    s = s:sub(1, hook_msglen - 2)
    sc.write(wr, '>' .. s .. (' '):rep(hook_msglen - 2 - #s) .. '\n')
  end
  local err, emsg = pcall(init)
  if err then
    collectgarbage('stop')
    child_sethook(wr)
    err, emsg = pcall(func)
    debug.sethook()
  end
  emsg = tostring(emsg)
  sc.write(wr, trace_end_msg)
  if not err then
    if #emsg > 99999 then
      emsg = emsg:sub(1, 99999)
    end
    sc.write(wr, ('-\n%05u\n%s'):format(#emsg, emsg))
    deinit()
  else
    sc.write(wr, '+\n')
    deinit()
  end
  collectgarbage('restart')
  collectgarbage()
  sc.write(wr, '$\n')
  sc.close(wr)
  sc.exit(err and 0 or 1)
end

local function check_child_err(rd)
  local trace = {}
  local did_traceline = false
  local maxtrace = tonumber(os.getenv('NVIM_TEST_MAXTRACE')) or 1024
  while true do
    local traceline = sc.read(rd, hook_msglen)
    if #traceline ~= hook_msglen then
      if #traceline == 0 then
        break
      else
        trace[#trace + 1] = 'Partial read: <' .. trace .. '>\n'
      end
    end
    if traceline == trace_end_msg then
      did_traceline = true
      break
    end
    trace[#trace + 1] = traceline
    if #trace > maxtrace then
      table.remove(trace, 1)
    end
  end
  local res = sc.read(rd, 2)
  if #res == 2 then
    local err = ''
    if res ~= '+\n' then
      eq('-\n', res)
      local len_s = sc.read(rd, 5)
      local len = tonumber(len_s)
      neq(0, len)
      if os.getenv('NVIM_TEST_TRACE_ON_ERROR') == '1' and #trace ~= 0 then
        err = '\nTest failed, trace:\n' .. tracehelp
        for _, traceline in ipairs(trace) do
          err = err .. traceline
        end
      end
      err = err .. sc.read(rd, len + 1)
    end
    local eres = sc.read(rd, 2)
    if eres ~= '$\n' then
      if #trace == 0 then
        err = '\nTest crashed, no trace available\n'
      else
        err = '\nTest crashed, trace:\n' .. tracehelp
        for i = 1, #trace do
          err = err .. trace[i]
        end
      end
      if not did_traceline then
        err = err .. '\nNo end of trace occurred'
      end
      local cc_err, cc_emsg = pcall(check_cores, Paths.test_luajit_prg, true)
      if not cc_err then
        err = err .. '\ncheck_cores failed: ' .. cc_emsg
      end
    end
    if err ~= '' then
      assert.just_fail(err)
    end
  end
end

local function itp_parent(rd, pid, allow_failure)
  local err, emsg = pcall(check_child_err, rd)
  sc.wait(pid)
  sc.close(rd)
  if not err then
    if allow_failure then
      io.stderr:write('Errorred out:\n' .. tostring(emsg) .. '\n')
      os.execute([[
        sh -c "source ci/common/test.sh
        check_core_dumps --delete \"]] .. Paths.test_luajit_prg .. [[\""]])
    else
      error(emsg)
    end
  end
end

local function gen_itp(it)
  child_calls_mod = {}
  child_calls_mod_once = {}
  child_cleanups_mod_once = {}
  preprocess_cache_mod = map(function(v) return v end, preprocess_cache_init)
  previous_defines_mod = previous_defines_init
  cdefs_mod = cdefs_init:copy()
  local function itp(name, func, allow_failure)
    if allow_failure and os.getenv('NVIM_TEST_RUN_FAILING_TESTS') ~= '1' then
      -- FIXME Fix tests with this true
      return
    end
    it(name, function()
      local rd, wr = sc.pipe()
      child_pid = sc.fork()
      if child_pid == 0 then
        sc.close(rd)
        itp_child(wr, func)
      else
        sc.close(wr)
        local saved_child_pid = child_pid
        child_pid = nil
        itp_parent(rd, saved_child_pid, allow_failure)
      end
    end)
  end
  return itp
end

local function cppimport(path)
  return cimport(Paths.test_include_path .. '/' .. path)
end

cimport('./src/nvim/types.h', './src/nvim/main.h', './src/nvim/os/time.h')

local function conv_enum(etab, eval)
  local n = tonumber(eval)
  return etab[n] or n
end

local function array_size(arr)
  return ffi.sizeof(arr) / ffi.sizeof(arr[0])
end

local function kvi_size(kvi)
  return array_size(kvi.init_array)
end

local function kvi_init(kvi)
  kvi.capacity = kvi_size(kvi)
  kvi.items = kvi.init_array
  return kvi
end

local function kvi_destroy(kvi)
  if kvi.items ~= kvi.init_array then
    lib.xfree(kvi.items)
  end
end

local function kvi_new(ct)
  return kvi_init(ffi.new(ct))
end

local function make_enum_conv_tab(m, values, skip_pref, set_cb)
  child_call_once(function()
    local ret = {}
    for _, v in ipairs(values) do
      local str_v = v
      if v:sub(1, #skip_pref) == skip_pref then
        str_v = v:sub(#skip_pref + 1)
      end
      ret[tonumber(m[v])] = str_v
    end
    set_cb(ret)
  end)
end

local function ptr2addr(ptr)
  return tonumber(ffi.cast('intptr_t', ffi.cast('void *', ptr)))
end

local s = ffi.new('char[64]', {0})

local function ptr2key(ptr)
  ffi.C.snprintf(s, ffi.sizeof(s), '%p', ffi.cast('void *', ptr))
  return ffi.string(s)
end

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
  sc = sc,
  conv_enum = conv_enum,
  array_size = array_size,
  kvi_destroy = kvi_destroy,
  kvi_size = kvi_size,
  kvi_init = kvi_init,
  kvi_new = kvi_new,
  make_enum_conv_tab = make_enum_conv_tab,
  ptr2addr = ptr2addr,
  ptr2key = ptr2key,
  debug_log = debug_log,
}
return function()
  return module
end
