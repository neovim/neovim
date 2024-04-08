local ffi = require('ffi')
local formatc = require('test.unit.formatc')
local Set = require('test.unit.set')
local Preprocess = require('test.unit.preprocess')
local t_global = require('test.testutil')
local paths = t_global.paths
local assert = require('luassert')
local say = require('say')

local check_cores = t_global.check_cores
local dedent = t_global.dedent
local neq = t_global.neq
local map = vim.tbl_map
local eq = t_global.eq
local trim = vim.trim

-- add some standard header locations
for _, p in ipairs(paths.include_paths) do
  Preprocess.add_to_include_path(p)
end

local child_pid = nil --- @type integer?
--- @generic F: function
--- @param func F
--- @return F
local function only_separate(func)
  return function(...)
    if child_pid ~= 0 then
      error('This function must be run in a separate process only')
    end
    return func(...)
  end
end

--- @class ChildCall
--- @field func function
--- @field args any[]

--- @class ChildCallLog
--- @field func string
--- @field args any[]
--- @field ret any?

local child_calls_init = {} --- @type ChildCall[]
local child_calls_mod = nil --- @type ChildCall[]
local child_calls_mod_once = nil --- @type ChildCall[]?

local function child_call(func, ret)
  return function(...)
    local child_calls = child_calls_mod or child_calls_init
    if child_pid ~= 0 then
      child_calls[#child_calls + 1] = { func = func, args = { ... } }
      return ret
    else
      return func(...)
    end
  end
end

-- Run some code at the start of the child process, before running the test
-- itself. Is supposed to be run in `before_each`.
--- @param func function
local function child_call_once(func, ...)
  if child_pid ~= 0 then
    child_calls_mod_once[#child_calls_mod_once + 1] = { func = func, args = { ... } }
  else
    func(...)
  end
end

local child_cleanups_mod_once = nil --- @type ChildCall[]?

-- Run some code at the end of the child process, before exiting. Is supposed to
-- be run in `before_each` because `after_each` is run after child has exited.
local function child_cleanup_once(func, ...)
  local child_cleanups = child_cleanups_mod_once
  if child_pid ~= 0 then
    child_cleanups[#child_cleanups + 1] = { func = func, args = { ... } }
  else
    func(...)
  end
end

-- Unittests are run from debug nvim binary in lua interpreter mode.
local libnvim = ffi.C

local lib = setmetatable({}, {
  __index = only_separate(function(_, idx)
    return libnvim[idx]
  end),
  __newindex = child_call(function(_, idx, val)
    libnvim[idx] = val
  end),
})

local init = only_separate(function()
  for _, c in ipairs(child_calls_init) do
    c.func(unpack(c.args))
  end
  libnvim.event_init()
  libnvim.early_init(nil)
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

-- a Set that keeps around the lines we've already seen
local cdefs_init = Set:new()
local cdefs_mod = nil
local imported = Set:new()
local pragma_pack_id = 1

-- some things are just too complex for the LuaJIT C parser to digest. We
-- usually don't need them anyway.
--- @param body string
local function filter_complex_blocks(body)
  local result = {} --- @type string[]

  for line in body:gmatch('[^\r\n]+') do
    if
      not (
        string.find(line, '(^)', 1, true) ~= nil
        or string.find(line, '_ISwupper', 1, true)
        or string.find(line, '_Float')
        or string.find(line, '__s128')
        or string.find(line, '__u128')
        or string.find(line, 'msgpack_zone_push_finalizer')
        or string.find(line, 'msgpack_unpacker_reserve_buffer')
        or string.find(line, 'value_init_')
        or string.find(line, 'UUID_NULL') -- static const uuid_t UUID_NULL = {...}
        or string.find(line, 'inline _Bool')
      )
    then
      result[#result + 1] = line
    end
  end

  return table.concat(result, '\n')
end

local cdef = ffi.cdef

local cimportstr

local previous_defines_init = [[
typedef struct { char bytes[16]; } __attribute__((aligned(16))) __uint128_t;
typedef struct { char bytes[16]; } __attribute__((aligned(16))) __float128;
]]

local preprocess_cache_init = {} --- @type table<string,string>
local previous_defines_mod = ''
local preprocess_cache_mod = nil --- @type table<string,string>

local function is_child_cdefs()
  return os.getenv('NVIM_TEST_MAIN_CDEFS') ~= '1'
end

-- use this helper to import C files, you can pass multiple paths at once,
-- this helper will return the C namespace of the nvim library.
local function cimport(...)
  local previous_defines --- @type string
  local preprocess_cache --- @type table<string,string>
  local cdefs
  if is_child_cdefs() and preprocess_cache_mod then
    preprocess_cache = preprocess_cache_mod
    previous_defines = previous_defines_mod
    cdefs = cdefs_mod
  else
    preprocess_cache = preprocess_cache_init
    previous_defines = previous_defines_init
    cdefs = cdefs_init
  end
  for _, path in ipairs({ ... }) do
    if not (path:sub(1, 1) == '/' or path:sub(1, 1) == '.' or path:sub(2, 2) == ':') then
      path = './' .. path
    end
    if not preprocess_cache[path] then
      local body --- @type string
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
      for line in body:gmatch('[^\r\n]+') do
        line = trim(line)
        -- give each #pragma pack a unique id, so that they don't get removed
        -- if they are inserted into the set
        -- (they are needed in the right order with the struct definitions,
        -- otherwise luajit has wrong memory layouts for the structs)
        if line:match('#pragma%s+pack') then
          --- @type string
          line = line .. ' // ' .. pragma_pack_id
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

local function cimport_immediate(...)
  local saved_pid = child_pid
  child_pid = 0
  local err, emsg = pcall(cimport, ...)
  child_pid = saved_pid
  if not err then
    io.stderr:write(tostring(emsg) .. '\n')
    assert(false)
  else
    return lib
  end
end

--- @param preprocess_cache table<string,string[]>
--- @param path string
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
    log = {}, --- @type ChildCallLog[]
    lib = cimport('./src/nvim/memory.h'), --- @type table<string,function>
    original_functions = {}, --- @type table<string,function>
    null = { ['\0:is_null'] = true },
  }

  local allocator_functions = { 'malloc', 'free', 'calloc', 'realloc' }

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
          --- @type ChildCallLog
          local log_entry = { func = kk, args = { ... } }
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
          if self.hook then
            self:hook(log_entry)
          end
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
    local toremove = {} --- @type integer[]
    local allocs = {} --- @type table<string,integer>
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
    for i = #toremove, 1, -1 do
      table.remove(self.log, toremove[i])
    end
  end

  function log:setup()
    log:save_original_functions()
    log:set_mocks()
  end

  function log:before_each() end

  function log:after_each() end

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

cimport_immediate('./test/unit/fixtures/posix.h')

local sc = {}

function sc.fork()
  return tonumber(ffi.C.fork())
end

function sc.pipe()
  local ret = ffi.new('int[2]', { -1, -1 })
  ffi.errno(0)
  local res = ffi.C.pipe(ret)
  if res ~= 0 then
    local err = ffi.errno(0)
    assert(res == 0, ('pipe() error: %u: %s'):format(err, ffi.string(ffi.C.strerror(err))))
  end
  assert(ret[0] ~= -1 and ret[1] ~= -1)
  return ret[0], ret[1]
end

--- @return string
function sc.read(rd, len)
  local ret = ffi.new('char[?]', len, { 0 })
  local total_bytes_read = 0
  ffi.errno(0)
  while total_bytes_read < len do
    local bytes_read =
      tonumber(ffi.C.read(rd, ffi.cast('void*', ret + total_bytes_read), len - total_bytes_read))
    if bytes_read == -1 then
      local err = ffi.errno(0)
      if err ~= ffi.C.kPOSIXErrnoEINTR then
        assert(false, ('read() error: %u: %s'):format(err, ffi.string(ffi.C.strerror(err))))
      end
    elseif bytes_read == 0 then
      break
    else
      total_bytes_read = total_bytes_read + bytes_read
    end
  end
  return ffi.string(ret, total_bytes_read)
end

function sc.write(wr, s)
  local wbuf = to_cstr(s)
  local total_bytes_written = 0
  ffi.errno(0)
  while total_bytes_written < #s do
    local bytes_written = tonumber(
      ffi.C.write(wr, ffi.cast('void*', wbuf + total_bytes_written), #s - total_bytes_written)
    )
    if bytes_written == -1 then
      local err = ffi.errno(0)
      if err ~= ffi.C.kPOSIXErrnoEINTR then
        assert(
          false,
          ("write() error: %u: %s ('%s')"):format(err, ffi.string(ffi.C.strerror(err)), s)
        )
      end
    elseif bytes_written == 0 then
      break
    else
      total_bytes_written = total_bytes_written + bytes_written
    end
  end
  return total_bytes_written
end

sc.close = ffi.C.close

--- @param pid integer
--- @return integer
function sc.wait(pid)
  ffi.errno(0)
  local stat_loc = ffi.new('int[1]', { 0 })
  while true do
    local r = ffi.C.waitpid(pid, stat_loc, ffi.C.kPOSIXWaitWUNTRACED)
    if r == -1 then
      local err = ffi.errno(0)
      if err == ffi.C.kPOSIXErrnoECHILD then
        break
      elseif err ~= ffi.C.kPOSIXErrnoEINTR then
        assert(false, ('waitpid() error: %u: %s'):format(err, ffi.string(ffi.C.strerror(err))))
      end
    else
      assert(r == pid)
    end
  end
  return stat_loc[0]
end

sc.exit = ffi.C._exit

--- @param lst string[]
--- @return string
local function format_list(lst)
  local ret = {} --- @type string[]
  for _, v in ipairs(lst) do
    ret[#ret + 1] = assert:format({ v, n = 1 })[1]
  end
  return table.concat(ret, ', ')
end

if os.getenv('NVIM_TEST_PRINT_SYSCALLS') == '1' then
  for k_, v_ in pairs(sc) do
    (function(k, v)
      sc[k] = function(...)
        local rets = { v(...) }
        io.stderr:write(('%s(%s) = %s\n'):format(k, format_list({ ... }), format_list(rets)))
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
assert:register(
  'assertion',
  'just_fail',
  just_fail,
  'assertion.just_fail.positive',
  'assertion.just_fail.negative'
)

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
  local trace_level_str = os.getenv('NVIM_TEST_TRACE_LEVEL')
  local trace_level = 0
  if trace_level_str and trace_level_str ~= '' then
    --- @type number
    trace_level = assert(tonumber(trace_level_str))
  end

  if trace_level <= 0 then
    return
  end

  local trace_only_c = trace_level <= 1
  --- @type debuginfo?, string?, integer
  local prev_info, prev_reason, prev_lnum

  --- @param reason string
  --- @param lnum integer
  --- @param use_prev boolean
  local function hook(reason, lnum, use_prev)
    local info = nil --- @type debuginfo?
    if use_prev then
      info = prev_info
    elseif reason ~= 'tail return' then -- tail return
      info = debug.getinfo(2, 'nSl')
    end

    if trace_only_c and (not info or info.what ~= 'C') and not use_prev then
      --- @cast info -nil
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
    local lnum_s = lnum == -1 and 'nknwn' or ('%u'):format(lnum)
    --- @type string
    local msg = ( -- lua does not support %*
      ''
      .. msgchar
      .. whatchar
      .. namewhatchar
      .. ' '
      .. source
      .. (' '):rep(hook_sfnamelen - #source)
      .. ':'
      .. funcname
      .. (' '):rep(hook_fnamelen - #funcname)
      .. ':'
      .. ('0'):rep(hook_numlen - #lnum_s)
      .. lnum_s
      .. '\n'
    )
    -- eq(hook_msglen, #msg)
    sc.write(wr, msg)
  end
  debug.sethook(hook, 'crl')
end

local trace_end_msg = ('E%s\n'):format((' '):rep(hook_msglen - 2))

--- @type function
local _debug_log

local debug_log = only_separate(function(...)
  return _debug_log(...)
end)

local function itp_child(wr, func)
  --- @param s string
  _debug_log = function(s)
    s = s:sub(1, hook_msglen - 2)
    sc.write(wr, '>' .. s .. (' '):rep(hook_msglen - 2 - #s) .. '\n')
  end
  local status, result = pcall(init)
  if status then
    collectgarbage('stop')
    child_sethook(wr)
    status, result = pcall(func)
    debug.sethook()
  end
  sc.write(wr, trace_end_msg)
  if not status then
    local emsg = tostring(result)
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
  sc.exit(status and 0 or 1)
end

local function check_child_err(rd)
  local trace = {} --- @type string[]
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
        --- @type string
        err = '\nTest failed, trace:\n' .. tracehelp
        for _, traceline in ipairs(trace) do
          --- @type string
          err = err .. traceline
        end
      end
      --- @type string
      err = err .. sc.read(rd, len + 1)
    end
    local eres = sc.read(rd, 2)
    if eres ~= '$\n' then
      if #trace == 0 then
        err = '\nTest crashed, no trace available (check NVIM_TEST_TRACE_LEVEL)\n'
      else
        err = '\nTest crashed, trace:\n' .. tracehelp
        for i = 1, #trace do
          err = err .. trace[i]
        end
      end
      if not did_traceline then
        --- @type string
        err = err .. '\nNo end of trace occurred'
      end
      local cc_err, cc_emsg = pcall(check_cores, paths.test_luajit_prg, true)
      if not cc_err then
        --- @type string
        err = err .. '\ncheck_cores failed: ' .. cc_emsg
      end
    end
    if err ~= '' then
      assert.just_fail(err)
    end
  end
end

local function itp_parent(rd, pid, allow_failure, location)
  local ok, emsg = pcall(check_child_err, rd)
  local status = sc.wait(pid)
  sc.close(rd)
  if not ok then
    if allow_failure then
      io.stderr:write('Errorred out (' .. status .. '):\n' .. tostring(emsg) .. '\n')
      os.execute([[
        sh -c "source ci/common/test.sh
        check_core_dumps --delete \"]] .. paths.test_luajit_prg .. [[\""]])
    else
      error(tostring(emsg) .. '\nexit code: ' .. status)
    end
  elseif status ~= 0 then
    if not allow_failure then
      error('child process errored out with status ' .. status .. '!\n\n' .. location)
    end
  end
end

local function gen_itp(it)
  child_calls_mod = {}
  child_calls_mod_once = {}
  child_cleanups_mod_once = {}
  preprocess_cache_mod = map(function(v)
    return v
  end, preprocess_cache_init)
  previous_defines_mod = previous_defines_init
  cdefs_mod = cdefs_init:copy()
  local function itp(name, func, allow_failure)
    if allow_failure and os.getenv('NVIM_TEST_RUN_FAILING_TESTS') ~= '1' then
      -- FIXME Fix tests with this true
      return
    end

    -- Pre-emptively calculating error location, wasteful, ugh!
    -- But the way this code messes around with busted implies the real location is strictly
    -- not available in the parent when an actual error occurs. so we have to do this here.
    local location = debug.traceback()
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
        itp_parent(rd, saved_child_pid, allow_failure, location)
      end
    end)
  end
  return itp
end

local function cppimport(path)
  return cimport(paths.test_source_path .. '/test/includes/pre/' .. path)
end

cimport(
  './src/nvim/types_defs.h',
  './src/nvim/main.h',
  './src/nvim/os/time.h',
  './src/nvim/os/fs.h'
)

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

local s = ffi.new('char[64]', { 0 })

local function ptr2key(ptr)
  ffi.C.snprintf(s, ffi.sizeof(s), '%p', ffi.cast('void *', ptr))
  return ffi.string(s)
end

local function is_asan()
  cimport('./src/nvim/version.h')
  local status, res = pcall(function()
    return lib.version_cflags
  end)
  if status then
    return ffi.string(res):match('-fsanitize=[a-z,]*address')
  else
    return false
  end
end

--- @class test.unit.testutil.module
local module = {
  cimport = cimport,
  cppimport = cppimport,
  internalize = internalize,
  ffi = ffi,
  lib = lib,
  cstr = cstr,
  to_cstr = to_cstr,
  NULL = ffi.cast('void*', 0),
  OK = 1,
  FAIL = 0,
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
  is_asan = is_asan,
}
--- @class test.unit.testutil: test.unit.testutil.module, test.testutil
module = vim.tbl_extend('error', module, t_global)

return function()
  return module
end
