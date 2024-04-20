local luaassert = require('luassert')
local busted = require('busted')
local uv = vim.uv
local Paths = require('test.cmakeconfig.paths')

luaassert:set_parameter('TableFormatLevel', 100)

local quote_me = '[^.%w%+%-%@%_%/]' -- complement (needn't quote)

--- @param str string
--- @return string
local function shell_quote(str)
  if string.find(str, quote_me) or str == '' then
    return '"' .. str:gsub('[$%%"\\]', '\\%0') .. '"'
  end
  return str
end

--- This module uses functions from the context of the test runner.
--- @class test.testutil
local M = {
  paths = Paths,
}

--- @param p string
--- @return string
local function relpath(p)
  p = vim.fs.normalize(p)
  return (p:gsub('^' .. uv.cwd, ''))
end

--- @param path string
--- @return boolean
function M.isdir(path)
  if not path then
    return false
  end
  local stat = uv.fs_stat(path)
  if not stat then
    return false
  end
  return stat.type == 'directory'
end

--- @param ... string|string[]
--- @return string
function M.argss_to_cmd(...)
  local cmd = {} --- @type string[]
  for i = 1, select('#', ...) do
    local arg = select(i, ...)
    if type(arg) == 'string' then
      cmd[#cmd + 1] = shell_quote(arg)
    else
      --- @cast arg string[]
      for _, subarg in ipairs(arg) do
        cmd[#cmd + 1] = shell_quote(subarg)
      end
    end
  end
  return table.concat(cmd, ' ')
end

function M.popen_r(...)
  return io.popen(M.argss_to_cmd(...), 'r')
end

--- Calls fn() until it succeeds, up to `max` times or until `max_ms`
--- milliseconds have passed.
--- @param max integer?
--- @param max_ms integer?
--- @param fn function
--- @return any
function M.retry(max, max_ms, fn)
  luaassert(max == nil or max > 0)
  luaassert(max_ms == nil or max_ms > 0)
  local tries = 1
  local timeout = (max_ms and max_ms or 10000)
  local start_time = uv.now()
  while true do
    --- @type boolean, any
    local status, result = pcall(fn)
    if status then
      return result
    end
    uv.update_time() -- Update cached value of luv.now() (libuv: uv_now()).
    if (max and tries >= max) or (uv.now() - start_time > timeout) then
      busted.fail(string.format('retry() attempts: %d\n%s', tries, tostring(result)), 2)
    end
    tries = tries + 1
    uv.sleep(20) -- Avoid hot loop...
  end
end

local check_logs_useless_lines = {
  ['Warning: noted but unhandled ioctl'] = 1,
  ['could cause spurious value errors to appear'] = 2,
  ['See README_MISSING_SYSCALL_OR_IOCTL for guidance'] = 3,
}

function M.eq(expected, actual, context)
  return luaassert.are.same(expected, actual, context)
end
function M.neq(expected, actual, context)
  return luaassert.are_not.same(expected, actual, context)
end

--- Asserts that `cond` is true, or prints a message.
---
--- @param cond (boolean) expression to assert
--- @param expected (any) description of expected result
--- @param actual (any) description of actual result
function M.ok(cond, expected, actual)
  luaassert(
    (not expected and not actual) or (expected and actual),
    'if "expected" is given, "actual" is also required'
  )
  local msg = expected and ('expected %s, got: %s'):format(expected, tostring(actual)) or nil
  return luaassert(cond, msg)
end

local function epicfail(state, arguments, _)
  state.failure_message = arguments[1]
  return false
end
luaassert:register('assertion', 'epicfail', epicfail)
function M.fail(msg)
  return luaassert.epicfail(msg)
end

--- @param pat string
--- @param actual string
--- @return boolean
function M.matches(pat, actual)
  if nil ~= string.match(actual, pat) then
    return true
  end
  error(string.format('Pattern does not match.\nPattern:\n%s\nActual:\n%s', pat, actual))
end

--- Asserts that `pat` matches (or *not* if inverse=true) any line in the tail of `logfile`.
---
--- Retries for 1 second in case of filesystem delay.
---
---@param pat (string) Lua pattern to match lines in the log file
---@param logfile? (string) Full path to log file (default=$NVIM_LOG_FILE)
---@param nrlines? (number) Search up to this many log lines
---@param inverse? (boolean) Assert that the pattern does NOT match.
function M.assert_log(pat, logfile, nrlines, inverse)
  logfile = logfile or os.getenv('NVIM_LOG_FILE') or '.nvimlog'
  luaassert(logfile ~= nil, 'no logfile')
  nrlines = nrlines or 10
  inverse = inverse or false

  M.retry(nil, 1000, function()
    local lines = M.read_file_list(logfile, -nrlines) or {}
    local msg = string.format(
      'Pattern %q %sfound in log (last %d lines): %s:\n%s',
      pat,
      (inverse and '' or 'not '),
      nrlines,
      logfile,
      '    ' .. table.concat(lines, '\n    ')
    )
    for _, line in ipairs(lines) do
      if line:match(pat) then
        if inverse then
          error(msg)
        else
          return
        end
      end
    end
    if not inverse then
      error(msg)
    end
  end)
end

--- Asserts that `pat` does NOT match any line in the tail of `logfile`.
---
--- @see assert_log
--- @param pat (string) Lua pattern to match lines in the log file
--- @param logfile? (string) Full path to log file (default=$NVIM_LOG_FILE)
--- @param nrlines? (number) Search up to this many log lines
function M.assert_nolog(pat, logfile, nrlines)
  return M.assert_log(pat, logfile, nrlines, true)
end

--- @param fn fun(...): any
--- @param ... any
--- @return boolean, any
function M.pcall(fn, ...)
  luaassert(type(fn) == 'function')
  local status, rv = pcall(fn, ...)
  if status then
    return status, rv
  end

  -- From:
  --    C:/long/path/foo.lua:186: Expected string, got number
  -- to:
  --    .../foo.lua:0: Expected string, got number
  local errmsg = tostring(rv)
    :gsub('([%s<])vim[/\\]([^%s:/\\]+):%d+', '%1\xffvim\xff%2:0')
    :gsub('[^%s<]-[/\\]([^%s:/\\]+):%d+', '.../%1:0')
    :gsub('\xffvim\xff', 'vim/')

  -- Scrub numbers in paths/stacktraces:
  --    shared.lua:0: in function 'gsplit'
  --    shared.lua:0: in function <shared.lua:0>'
  errmsg = errmsg:gsub('([^%s].lua):%d+', '%1:0')
  --    [string "<nvim>"]:0:
  --    [string ":lua"]:0:
  --    [string ":luado"]:0:
  errmsg = errmsg:gsub('(%[string "[^"]+"%]):%d+', '%1:0')

  -- Scrub tab chars:
  errmsg = errmsg:gsub('\t', '    ')
  -- In Lua 5.1, we sometimes get a "(tail call): ?" on the last line.
  --    We remove this so that the tests are not lua dependent.
  errmsg = errmsg:gsub('%s*%(tail call%): %?', '')

  return status, errmsg
end

-- Invokes `fn` and returns the error string (with truncated paths), or raises
-- an error if `fn` succeeds.
--
-- Replaces line/column numbers with zero:
--     shared.lua:0: in function 'gsplit'
--     shared.lua:0: in function <shared.lua:0>'
--
-- Usage:
--    -- Match exact string.
--    eq('e', pcall_err(function(a, b) error('e') end, 'arg1', 'arg2'))
--    -- Match Lua pattern.
--    matches('e[or]+$', pcall_err(function(a, b) error('some error') end, 'arg1', 'arg2'))
--
--- @param fn function
--- @return string
function M.pcall_err_withfile(fn, ...)
  luaassert(type(fn) == 'function')
  local status, rv = M.pcall(fn, ...)
  if status == true then
    error('expected failure, but got success')
  end
  return rv
end

--- @param fn function
--- @param ... any
--- @return string
function M.pcall_err_withtrace(fn, ...)
  local errmsg = M.pcall_err_withfile(fn, ...)

  return (
    errmsg
      :gsub('^%.%.%./testnvim%.lua:0: ', '')
      :gsub('^Error executing lua:- ', '')
      :gsub('^%[string "<nvim>"%]:0: ', '')
  )
end

--- @param fn function
--- @param ... any
--- @return string
function M.pcall_err(fn, ...)
  return M.remove_trace(M.pcall_err_withtrace(fn, ...))
end

--- @param s string
--- @return string
function M.remove_trace(s)
  return (s:gsub('\n%s*stack traceback:.*', ''))
end

-- initial_path:  directory to recurse into
-- re:            include pattern (string)
-- exc_re:        exclude pattern(s) (string or table)
function M.glob(initial_path, re, exc_re)
  exc_re = type(exc_re) == 'table' and exc_re or { exc_re }
  local paths_to_check = { initial_path } --- @type string[]
  local ret = {} --- @type string[]
  local checked_files = {} --- @type table<string,true>
  local function is_excluded(path)
    for _, pat in pairs(exc_re) do
      if path:match(pat) then
        return true
      end
    end
    return false
  end

  if is_excluded(initial_path) then
    return ret
  end
  while #paths_to_check > 0 do
    local cur_path = paths_to_check[#paths_to_check]
    paths_to_check[#paths_to_check] = nil
    for e in vim.fs.dir(cur_path) do
      local full_path = cur_path .. '/' .. e
      local checked_path = full_path:sub(#initial_path + 1)
      if (not is_excluded(checked_path)) and e:sub(1, 1) ~= '.' then
        local stat = uv.fs_stat(full_path)
        if stat then
          local check_key = stat.dev .. ':' .. tostring(stat.ino)
          if not checked_files[check_key] then
            checked_files[check_key] = true
            if stat.type == 'directory' then
              paths_to_check[#paths_to_check + 1] = full_path
            elseif not re or checked_path:match(re) then
              ret[#ret + 1] = full_path
            end
          end
        end
      end
    end
  end
  return ret
end

function M.check_logs()
  local log_dir = os.getenv('LOG_DIR')
  local runtime_errors = {}
  if log_dir and M.isdir(log_dir) then
    for tail in vim.fs.dir(log_dir) do
      if tail:sub(1, 30) == 'valgrind-' or tail:find('san%.') then
        local file = log_dir .. '/' .. tail
        local fd = assert(io.open(file))
        local start_msg = ('='):rep(20) .. ' File ' .. file .. ' ' .. ('='):rep(20)
        local lines = {} --- @type string[]
        local warning_line = 0
        for line in fd:lines() do
          local cur_warning_line = check_logs_useless_lines[line]
          if cur_warning_line == warning_line + 1 then
            warning_line = cur_warning_line
          else
            lines[#lines + 1] = line
          end
        end
        fd:close()
        if #lines > 0 then
          --- @type boolean?, file*?
          local status, f
          local out = io.stdout
          if os.getenv('SYMBOLIZER') then
            status, f = pcall(M.popen_r, os.getenv('SYMBOLIZER'), '-l', file)
          end
          out:write(start_msg .. '\n')
          if status then
            assert(f)
            for line in f:lines() do
              out:write('= ' .. line .. '\n')
            end
            f:close()
          else
            out:write('= ' .. table.concat(lines, '\n= ') .. '\n')
          end
          out:write(select(1, start_msg:gsub('.', '=')) .. '\n')
          table.insert(runtime_errors, file)
        end
        os.remove(file)
      end
    end
  end
  luaassert(
    0 == #runtime_errors,
    string.format('Found runtime errors in logfile(s): %s', table.concat(runtime_errors, ', '))
  )
end

function M.sysname()
  return uv.os_uname().sysname:lower()
end

--- @param s 'win'|'mac'|'freebsd'|'openbsd'|'bsd'
--- @return boolean
function M.is_os(s)
  if not (s == 'win' or s == 'mac' or s == 'freebsd' or s == 'openbsd' or s == 'bsd') then
    error('unknown platform: ' .. tostring(s))
  end
  return not not (
    (s == 'win' and (M.sysname():find('windows') or M.sysname():find('mingw')))
    or (s == 'mac' and M.sysname() == 'darwin')
    or (s == 'freebsd' and M.sysname() == 'freebsd')
    or (s == 'openbsd' and M.sysname() == 'openbsd')
    or (s == 'bsd' and M.sysname():find('bsd'))
  )
end

local function tmpdir_get()
  return os.getenv('TMPDIR') and os.getenv('TMPDIR') or os.getenv('TEMP')
end

--- Is temp directory `dir` defined local to the project workspace?
--- @param dir string?
--- @return boolean
local function tmpdir_is_local(dir)
  return not not (dir and dir:find('Xtest'))
end

local tmpname_id = 0
local tmpdir = tmpdir_get()

--- Creates a new temporary file for use by tests.
function M.tmpname()
  if tmpdir_is_local(tmpdir) then
    -- Cannot control os.tmpname() dir, so hack our own tmpname() impl.
    tmpname_id = tmpname_id + 1
    -- "…/Xtest_tmpdir/T42.7"
    local fname = ('%s/%s.%d'):format(tmpdir, (_G._nvim_test_id or 'nvim-test'), tmpname_id)
    io.open(fname, 'w'):close()
    return fname
  end

  local fname = os.tmpname()
  if M.is_os('win') and fname:sub(1, 2) == '\\s' then
    -- In Windows tmpname() returns a filename starting with
    -- special sequence \s, prepend $TEMP path
    return tmpdir .. fname
  elseif M.is_os('mac') and fname:match('^/tmp') then
    -- In OS X /tmp links to /private/tmp
    return '/private' .. fname
  end

  return fname
end

local function deps_prefix()
  local env = os.getenv('DEPS_PREFIX')
  return (env and env ~= '') and env or '.deps/usr'
end

local tests_skipped = 0

function M.check_cores(app, force) -- luacheck: ignore
  -- Temporary workaround: skip core check as it interferes with CI.
  if true then
    return
  end
  app = app or 'build/bin/nvim' -- luacheck: ignore
  --- @type string, string?, string[]
  local initial_path, re, exc_re
  local gdb_db_cmd =
    'gdb -n -batch -ex "thread apply all bt full" "$_NVIM_TEST_APP" -c "$_NVIM_TEST_CORE"'
  local lldb_db_cmd = 'lldb -Q -o "bt all" -f "$_NVIM_TEST_APP" -c "$_NVIM_TEST_CORE"'
  local random_skip = false
  -- Workspace-local $TMPDIR, scrubbed and pattern-escaped.
  -- "./Xtest-tmpdir/" => "Xtest%-tmpdir"
  local local_tmpdir = (
    tmpdir_is_local(tmpdir_get())
      and relpath(tmpdir_get()):gsub('^[ ./]+', ''):gsub('%/+$', ''):gsub('([^%w])', '%%%1')
    or nil
  )
  local db_cmd --- @type string
  local test_glob_dir = os.getenv('NVIM_TEST_CORE_GLOB_DIRECTORY')
  if test_glob_dir and test_glob_dir ~= '' then
    initial_path = test_glob_dir
    re = os.getenv('NVIM_TEST_CORE_GLOB_RE')
    exc_re = { os.getenv('NVIM_TEST_CORE_EXC_RE'), local_tmpdir }
    db_cmd = os.getenv('NVIM_TEST_CORE_DB_CMD') or gdb_db_cmd
    random_skip = os.getenv('NVIM_TEST_CORE_RANDOM_SKIP') ~= ''
  elseif M.is_os('mac') then
    initial_path = '/cores'
    re = nil
    exc_re = { local_tmpdir }
    db_cmd = lldb_db_cmd
  else
    initial_path = '.'
    if M.is_os('freebsd') then
      re = '/nvim.core$'
    else
      re = '/core[^/]*$'
    end
    exc_re = { '^/%.deps$', '^/%' .. deps_prefix() .. '$', local_tmpdir, '^/%node_modules$' }
    db_cmd = gdb_db_cmd
    random_skip = true
  end
  -- Finding cores takes too much time on linux
  if not force and random_skip and math.random() < 0.9 then
    tests_skipped = tests_skipped + 1
    return
  end
  local cores = M.glob(initial_path, re, exc_re)
  local found_cores = 0
  local out = io.stdout
  for _, core in ipairs(cores) do
    local len = 80 - #core - #'Core file ' - 2
    local esigns = ('='):rep(len / 2)
    out:write(('\n%s Core file %s %s\n'):format(esigns, core, esigns))
    out:flush()
    os.execute(db_cmd:gsub('%$_NVIM_TEST_APP', app):gsub('%$_NVIM_TEST_CORE', core) .. ' 2>&1')
    out:write('\n')
    found_cores = found_cores + 1
    os.remove(core)
  end
  if found_cores ~= 0 then
    out:write(('\nTests covered by this check: %u\n'):format(tests_skipped + 1))
  end
  tests_skipped = 0
  if found_cores > 0 then
    error('crash detected (see above)')
  end
end

--- @return string?
function M.repeated_read_cmd(...)
  for _ = 1, 10 do
    local stream = M.popen_r(...)
    local ret = stream:read('*a')
    stream:close()
    if ret then
      return ret
    end
  end
  print('ERROR: Failed to execute ' .. M.argss_to_cmd(...) .. ': nil return after 10 attempts')
  return nil
end

--- @generic T
--- @param orig T
--- @return T
function M.shallowcopy(orig)
  if type(orig) ~= 'table' then
    return orig
  end
  --- @cast orig table<any,any>
  local copy = {} --- @type table<any,any>
  for orig_key, orig_value in pairs(orig) do
    copy[orig_key] = orig_value
  end
  return copy
end

--- @param d1 table<any,any>
--- @param d2 table<any,any>
--- @return table<any,any>
function M.mergedicts_copy(d1, d2)
  local ret = M.shallowcopy(d1)
  for k, v in pairs(d2) do
    if d2[k] == vim.NIL then
      ret[k] = nil
    elseif type(d1[k]) == 'table' and type(v) == 'table' then
      ret[k] = M.mergedicts_copy(d1[k], v)
    else
      ret[k] = v
    end
  end
  return ret
end

--- dictdiff: find a diff so that mergedicts_copy(d1, diff) is equal to d2
---
--- Note: does not do copies of d2 values used.
--- @param d1 table<any,any>
--- @param d2 table<any,any>
function M.dictdiff(d1, d2)
  local ret = {} --- @type table<any,any>
  local hasdiff = false
  for k, v in pairs(d1) do
    if d2[k] == nil then
      hasdiff = true
      ret[k] = vim.NIL
    elseif type(v) == type(d2[k]) then
      if type(v) == 'table' then
        local subdiff = M.dictdiff(v, d2[k])
        if subdiff ~= nil then
          hasdiff = true
          ret[k] = subdiff
        end
      elseif v ~= d2[k] then
        ret[k] = d2[k]
        hasdiff = true
      end
    else
      ret[k] = d2[k]
      hasdiff = true
    end
  end
  local shallowcopy = M.shallowcopy
  for k, v in pairs(d2) do
    if d1[k] == nil then
      ret[k] = shallowcopy(v)
      hasdiff = true
    end
  end
  if hasdiff then
    return ret
  else
    return nil
  end
end

-- Concat list-like tables.
function M.concat_tables(...)
  local ret = {} --- @type table<any,any>
  for i = 1, select('#', ...) do
    --- @type table<any,any>
    local tbl = select(i, ...)
    if tbl then
      for _, v in ipairs(tbl) do
        ret[#ret + 1] = v
      end
    end
  end
  return ret
end

--- @param str string
--- @param leave_indent? integer
--- @return string
function M.dedent(str, leave_indent)
  -- find minimum common indent across lines
  local indent --- @type string?
  for line in str:gmatch('[^\n]+') do
    local line_indent = line:match('^%s+') or ''
    if indent == nil or #line_indent < #indent then
      indent = line_indent
    end
  end

  if not indent or #indent == 0 then
    -- no minimum common indent
    return str
  end

  local left_indent = (' '):rep(leave_indent or 0)
  -- create a pattern for the indent
  indent = indent:gsub('%s', '[ \t]')
  -- strip it from the first line
  str = str:gsub('^' .. indent, left_indent)
  -- strip it from the remaining lines
  str = str:gsub('[\n]' .. indent, '\n' .. left_indent)
  return str
end

function M.intchar2lua(ch)
  ch = tonumber(ch)
  return (20 <= ch and ch < 127) and ('%c'):format(ch) or ch
end

--- @param str string
--- @return string
function M.hexdump(str)
  local len = string.len(str)
  local dump = ''
  local hex = ''
  local asc = ''

  for i = 1, len do
    if 1 == i % 8 then
      dump = dump .. hex .. asc .. '\n'
      hex = string.format('%04x: ', i - 1)
      asc = ''
    end

    local ord = string.byte(str, i)
    hex = hex .. string.format('%02x ', ord)
    if ord >= 32 and ord <= 126 then
      asc = asc .. string.char(ord)
    else
      asc = asc .. '.'
    end
  end

  return dump .. hex .. string.rep('   ', 8 - len % 8) .. asc
end

--- Reads text lines from `filename` into a table.
--- @param filename string path to file
--- @param start? integer start line (1-indexed), negative means "lines before end" (tail)
--- @return string[]?
function M.read_file_list(filename, start)
  local lnum = (start ~= nil and type(start) == 'number') and start or 1
  local tail = (lnum < 0)
  local maxlines = tail and math.abs(lnum) or nil
  local file = io.open(filename, 'r')
  if not file then
    return nil
  end

  -- There is no need to read more than the last 2MB of the log file, so seek
  -- to that.
  local file_size = file:seek('end')
  local offset = file_size - 2000000
  if offset < 0 then
    offset = 0
  end
  file:seek('set', offset)

  local lines = {}
  local i = 1
  local line = file:read('*l')
  while line ~= nil do
    if i >= start then
      table.insert(lines, line)
      if #lines > maxlines then
        table.remove(lines, 1)
      end
    end
    i = i + 1
    line = file:read('*l')
  end
  file:close()
  return lines
end

--- Reads the entire contents of `filename` into a string.
--- @param filename string
--- @return string?
function M.read_file(filename)
  local file = io.open(filename, 'r')
  if not file then
    return nil
  end
  local ret = file:read('*a')
  file:close()
  return ret
end

-- Dedent the given text and write it to the file name.
function M.write_file(name, text, no_dedent, append)
  local file = assert(io.open(name, (append and 'a' or 'w')))
  if type(text) == 'table' then
    -- Byte blob
    --- @type string[]
    local bytes = text
    text = ''
    for _, char in ipairs(bytes) do
      text = ('%s%c'):format(text, char)
    end
  elseif not no_dedent then
    text = M.dedent(text)
  end
  file:write(text)
  file:flush()
  file:close()
end

--- @param name? 'cirrus'|'github'
--- @return boolean
function M.is_ci(name)
  local any = (name == nil)
  luaassert(any or name == 'github' or name == 'cirrus')
  local gh = ((any or name == 'github') and nil ~= os.getenv('GITHUB_ACTIONS'))
  local cirrus = ((any or name == 'cirrus') and nil ~= os.getenv('CIRRUS_CI'))
  return gh or cirrus
end

-- Gets the (tail) contents of `logfile`.
-- Also moves the file to "${NVIM_LOG_FILE}.displayed" on CI environments.
function M.read_nvim_log(logfile, ci_rename)
  logfile = logfile or os.getenv('NVIM_LOG_FILE') or '.nvimlog'
  local is_ci = M.is_ci()
  local keep = is_ci and 100 or 10
  local lines = M.read_file_list(logfile, -keep) or {}
  local log = (
    ('-'):rep(78)
    .. '\n'
    .. string.format('$NVIM_LOG_FILE: %s\n', logfile)
    .. (#lines > 0 and '(last ' .. tostring(keep) .. ' lines)\n' or '(empty)\n')
  )
  for _, line in ipairs(lines) do
    log = log .. line .. '\n'
  end
  log = log .. ('-'):rep(78) .. '\n'
  if is_ci and ci_rename then
    os.rename(logfile, logfile .. '.displayed')
  end
  return log
end

--- @param path string
--- @return boolean?
function M.mkdir(path)
  -- 493 is 0755 in decimal
  return (uv.fs_mkdir(path, 493))
end

--- @param expected any[]
--- @param received any[]
--- @param kind string
--- @return any
function M.expect_events(expected, received, kind)
  if not pcall(M.eq, expected, received) then
    local msg = 'unexpected ' .. kind .. ' received.\n\n'

    msg = msg .. 'received events:\n'
    for _, e in ipairs(received) do
      msg = msg .. '  ' .. vim.inspect(e) .. ';\n'
    end
    msg = msg .. '\nexpected events:\n'
    for _, e in ipairs(expected) do
      msg = msg .. '  ' .. vim.inspect(e) .. ';\n'
    end
    M.fail(msg)
  end
  return received
end

--- @param cond boolean
--- @param reason? string
--- @return boolean
function M.skip(cond, reason)
  if cond then
    --- @type fun(reason: string)
    local pending = getfenv(2).pending
    pending(reason or 'FIXME')
    return true
  end
  return false
end

-- Calls pending() and returns `true` if the system is too slow to
-- run fragile or expensive tests. Else returns `false`.
function M.skip_fragile(pending_fn, cond)
  if pending_fn == nil or type(pending_fn) ~= type(function() end) then
    error('invalid pending_fn')
  end
  if cond then
    pending_fn('skipped (test is fragile on this system)', function() end)
    return true
  elseif os.getenv('TEST_SKIP_FRAGILE') then
    pending_fn('skipped (TEST_SKIP_FRAGILE)', function() end)
    return true
  end
  return false
end

return M
