local assert = require('luassert')
local luv = require('luv')
local lfs = require('lfs')

local quote_me = '[^.%w%+%-%@%_%/]' -- complement (needn't quote)
local function shell_quote(str)
  if string.find(str, quote_me) or str == '' then
    return '"' .. str:gsub('[$%%"\\]', '\\%0') .. '"'
  else
    return str
  end
end

local function argss_to_cmd(...)
  local cmd = ''
  for i = 1, select('#', ...) do
    local arg = select(i, ...)
    if type(arg) == 'string' then
      cmd = cmd .. ' ' ..shell_quote(arg)
    else
      for _, subarg in ipairs(arg) do
        cmd = cmd .. ' ' .. shell_quote(subarg)
      end
    end
  end
  return cmd
end

local function popen_r(...)
  return io.popen(argss_to_cmd(...), 'r')
end

local function popen_w(...)
  return io.popen(argss_to_cmd(...), 'w')
end

-- sleeps the test runner (_not_ the nvim instance)
local function sleep(ms)
  luv.sleep(ms)
end

local check_logs_useless_lines = {
  ['Warning: noted but unhandled ioctl']=1,
  ['could cause spurious value errors to appear']=2,
  ['See README_MISSING_SYSCALL_OR_IOCTL for guidance']=3,
}

local function eq(expected, actual, ctx)
  return assert.are.same(expected, actual, ctx)
end
local function neq(expected, actual)
  return assert.are_not.same(expected, actual)
end
local function ok(res)
  return assert.is_true(res)
end
local function near(actual, expected, tolerance)
  return assert.is.near(actual, expected, tolerance)
end
local function matches(pat, actual)
  if nil ~= string.match(actual, pat) then
    return true
  end
  error(string.format('Pattern does not match.\nPattern:\n%s\nActual:\n%s', pat, actual))
end
-- Expect an error matching pattern `pat`.
local function expect_err(pat, ...)
  local fn = select(1, ...)
  local fn_args = {...}
  table.remove(fn_args, 1)
  assert.error_matches(function() return fn(unpack(fn_args)) end, pat)
end

-- initial_path:  directory to recurse into
-- re:            include pattern (string)
-- exc_re:        exclude pattern(s) (string or table)
local function glob(initial_path, re, exc_re)
  exc_re = type(exc_re) == 'table' and exc_re or { exc_re }
  local paths_to_check = {initial_path}
  local ret = {}
  local checked_files = {}
  local function is_excluded(path)
    for _, pat in pairs(exc_re) do
      if path:match(pat) then return true end
    end
    return false
  end

  if is_excluded(initial_path) then
    return ret
  end
  while #paths_to_check > 0 do
    local cur_path = paths_to_check[#paths_to_check]
    paths_to_check[#paths_to_check] = nil
    for e in lfs.dir(cur_path) do
      local full_path = cur_path .. '/' .. e
      local checked_path = full_path:sub(#initial_path + 1)
      if (not is_excluded(checked_path)) and e:sub(1, 1) ~= '.' then
        local attrs = lfs.attributes(full_path)
        if attrs then
          local check_key = attrs.dev .. ':' .. tostring(attrs.ino)
          if not checked_files[check_key] then
            checked_files[check_key] = true
            if attrs.mode == 'directory' then
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

local function check_logs()
  local log_dir = os.getenv('LOG_DIR')
  local runtime_errors = 0
  if log_dir and lfs.attributes(log_dir, 'mode') == 'directory' then
    for tail in lfs.dir(log_dir) do
      if tail:sub(1, 30) == 'valgrind-' or tail:find('san%.') then
        local file = log_dir .. '/' .. tail
        local fd = io.open(file)
        local start_msg = ('='):rep(20) .. ' File ' .. file .. ' ' .. ('='):rep(20)
        local lines = {}
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
        os.remove(file)
        if #lines > 0 then
          local out = io.stdout
          out:write(start_msg .. '\n')
          out:write('= ' .. table.concat(lines, '\n= ') .. '\n')
          out:write(select(1, start_msg:gsub('.', '=')) .. '\n')
          runtime_errors = runtime_errors + 1
        end
      end
    end
  end
  assert(0 == runtime_errors)
end

-- Tries to get platform name from $SYSTEM_NAME, uname; fallback is "Windows".
local uname = (function()
  local platform = nil
  return (function()
    if platform then
      return platform
    end

    platform = os.getenv("SYSTEM_NAME")
    if platform then
      return platform
    end

    local status, f = pcall(popen_r, 'uname', '-s')
    if status then
      platform = f:read("*l")
      f:close()
    else
      platform = 'Windows'
    end
    return platform
  end)
end)()

local function tmpdir_get()
  return os.getenv('TMPDIR') and os.getenv('TMPDIR') or os.getenv('TEMP')
end

-- Is temp directory `dir` defined local to the project workspace?
local function tmpdir_is_local(dir)
  return not not (dir and string.find(dir, 'Xtest'))
end

local tmpname = (function()
  local seq = 0
  local tmpdir = tmpdir_get()
  return (function()
    if tmpdir_is_local(tmpdir) then
      -- Cannot control os.tmpname() dir, so hack our own tmpname() impl.
      seq = seq + 1
      local fname = tmpdir..'/nvim-test-lua-'..seq
      io.open(fname, 'w'):close()
      return fname
    else
      local fname = os.tmpname()
      if uname() == 'Windows' and fname:sub(1, 2) == '\\s' then
        -- In Windows tmpname() returns a filename starting with
        -- special sequence \s, prepend $TEMP path
        return tmpdir..fname
      elseif fname:match('^/tmp') and uname() == 'Darwin' then
        -- In OS X /tmp links to /private/tmp
        return '/private'..fname
      else
        return fname
      end
    end
  end)
end)()

local function map(func, tab)
  local rettab = {}
  for k, v in pairs(tab) do
    rettab[k] = func(v)
  end
  return rettab
end

local function filter(filter_func, tab)
  local rettab = {}
  for _, entry in pairs(tab) do
    if filter_func(entry) then
      table.insert(rettab, entry)
    end
  end
  return rettab
end

local function hasenv(name)
  local env = os.getenv(name)
  if env and env ~= '' then
    return env
  end
  return nil
end

local tests_skipped = 0

local function check_cores(app, force)
  app = app or 'build/bin/nvim'
  local initial_path, re, exc_re
  local gdb_db_cmd = 'gdb -n -batch -ex "thread apply all bt full" "$_NVIM_TEST_APP" -c "$_NVIM_TEST_CORE"'
  local lldb_db_cmd = 'lldb -Q -o "bt all" -f "$_NVIM_TEST_APP" -c "$_NVIM_TEST_CORE"'
  local random_skip = false
  -- Workspace-local $TMPDIR, scrubbed and pattern-escaped.
  -- "./Xtest-tmpdir/" => "Xtest%-tmpdir"
  local local_tmpdir = (tmpdir_is_local(tmpdir_get())
    and tmpdir_get():gsub('^[ ./]+',''):gsub('%/+$',''):gsub('([^%w])', '%%%1')
    or nil)
  local db_cmd
  if hasenv('NVIM_TEST_CORE_GLOB_DIRECTORY') then
    initial_path = os.getenv('NVIM_TEST_CORE_GLOB_DIRECTORY')
    re = os.getenv('NVIM_TEST_CORE_GLOB_RE')
    exc_re = { os.getenv('NVIM_TEST_CORE_EXC_RE'), local_tmpdir }
    db_cmd = os.getenv('NVIM_TEST_CORE_DB_CMD') or gdb_db_cmd
    random_skip = os.getenv('NVIM_TEST_CORE_RANDOM_SKIP')
  elseif os.getenv('TRAVIS_OS_NAME') == 'osx' then
    initial_path = '/cores'
    re = nil
    exc_re = { local_tmpdir }
    db_cmd = lldb_db_cmd
  else
    initial_path = '.'
    re = '/core[^/]*$'
    exc_re = { '^/%.deps$', local_tmpdir, '^/%node_modules$' }
    db_cmd = gdb_db_cmd
    random_skip = true
  end
  -- Finding cores takes too much time on linux
  if not force and random_skip and math.random() < 0.9 then
    tests_skipped = tests_skipped + 1
    return
  end
  local cores = glob(initial_path, re, exc_re)
  local found_cores = 0
  local out = io.stdout
  for _, core in ipairs(cores) do
    local len = 80 - #core - #('Core file ') - 2
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
    error("crash detected (see above)")
  end
end

local function which(exe)
  local pipe = popen_r('which', exe)
  local ret = pipe:read('*a')
  pipe:close()
  if ret == '' then
    return nil
  else
    return ret:sub(1, -2)
  end
end

local function repeated_read_cmd(...)
  for _ = 1, 10 do
    local stream = popen_r(...)
    local ret = stream:read('*a')
    stream:close()
    if ret then
      return ret
    end
  end
  print('ERROR: Failed to execute ' .. argss_to_cmd(...) .. ': nil return after 10 attempts')
  return nil
end

local function shallowcopy(orig)
  if type(orig) ~= 'table' then
    return orig
  end
  local copy = {}
  for orig_key, orig_value in pairs(orig) do
    copy[orig_key] = orig_value
  end
  return copy
end

local deepcopy

local function id(v)
  return v
end

local deepcopy_funcs = {
  table = function(orig)
    local copy = {}
    for k, v in pairs(orig) do
      copy[deepcopy(k)] = deepcopy(v)
    end
    return copy
  end,
  number = id,
  string = id,
  ['nil'] = id,
  boolean = id,
}

deepcopy = function(orig)
  return deepcopy_funcs[type(orig)](orig)
end

local REMOVE_THIS = {}

local function mergedicts_copy(d1, d2)
  local ret = shallowcopy(d1)
  for k, v in pairs(d2) do
    if d2[k] == REMOVE_THIS then
      ret[k] = nil
    elseif type(d1[k]) == 'table' and type(v) == 'table' then
      ret[k] = mergedicts_copy(d1[k], v)
    else
      ret[k] = v
    end
  end
  return ret
end

-- dictdiff: find a diff so that mergedicts_copy(d1, diff) is equal to d2
--
-- Note: does not do copies of d2 values used.
local function dictdiff(d1, d2)
  local ret = {}
  local hasdiff = false
  for k, v in pairs(d1) do
    if d2[k] == nil then
      hasdiff = true
      ret[k] = REMOVE_THIS
    elseif type(v) == type(d2[k]) then
      if type(v) == 'table' then
        local subdiff = dictdiff(v, d2[k])
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

local function updated(d, d2)
  for k, v in pairs(d2) do
    d[k] = v
  end
  return d
end

local function concat_tables(...)
  local ret = {}
  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    if tbl then
      for _, v in ipairs(tbl) do
        ret[#ret + 1] = v
      end
    end
  end
  return ret
end

local function dedent(str, leave_indent)
  -- find minimum common indent across lines
  local indent = nil
  for line in str:gmatch('[^\n]+') do
    local line_indent = line:match('^%s+') or ''
    if indent == nil or #line_indent < #indent then
      indent = line_indent
    end
  end
  if indent == nil or #indent == 0 then
    -- no minimum common indent
    return str
  end
  local left_indent = (' '):rep(leave_indent or 0)
  -- create a pattern for the indent
  indent = indent:gsub('%s', '[ \t]')
  -- strip it from the first line
  str = str:gsub('^'..indent, left_indent)
  -- strip it from the remaining lines
  str = str:gsub('[\n]'..indent, '\n' .. left_indent)
  return str
end

local function format_float(v)
  -- On windows exponent appears to have three digits and not two
  local ret = ('%.6e'):format(v)
  local l, f, es, e = ret:match('^(%-?%d)%.(%d+)e([+%-])0*(%d%d+)$')
  return l .. '.' .. f .. 'e' .. es .. e
end

local SUBTBL = {
  '\\000', '\\001', '\\002', '\\003', '\\004',
  '\\005', '\\006', '\\007', '\\008', '\\t',
  '\\n',   '\\011', '\\012', '\\r',   '\\014',
  '\\015', '\\016', '\\017', '\\018', '\\019',
  '\\020', '\\021', '\\022', '\\023', '\\024',
  '\\025', '\\026', '\\027', '\\028', '\\029',
  '\\030', '\\031',
}

local format_luav

format_luav = function(v, indent, opts)
  opts = opts or {}
  local linesep = '\n'
  local next_indent_arg = nil
  local indent_shift = opts.indent_shift or '  '
  local next_indent
  local nl = '\n'
  if indent == nil then
    indent = ''
    linesep = ''
    next_indent = ''
    nl = ' '
  else
    next_indent_arg = indent .. indent_shift
    next_indent = indent .. indent_shift
  end
  local ret = ''
  if type(v) == 'string' then
    if opts.literal_strings then
      ret = v
    else
      local quote = opts.dquote_strings and '"' or '\''
      ret = quote .. tostring(v):gsub(
        opts.dquote_strings and '["\\]' or '[\'\\]',
        '\\%0'):gsub(
          '[%z\1-\31]', function(match)
            return SUBTBL[match:byte() + 1]
          end) .. quote
    end
  elseif type(v) == 'table' then
    if v == REMOVE_THIS then
      ret = 'REMOVE_THIS'
    else
      local processed_keys = {}
      ret = '{' .. linesep
      local non_empty = false
      for i, subv in ipairs(v) do
        ret = ('%s%s%s,%s'):format(ret, next_indent,
                                   format_luav(subv, next_indent_arg, opts), nl)
        processed_keys[i] = true
        non_empty = true
      end
      for k, subv in pairs(v) do
        if not processed_keys[k] then
          if type(k) == 'string' and k:match('^[a-zA-Z_][a-zA-Z0-9_]*$') then
            ret = ret .. next_indent .. k .. ' = '
          else
            ret = ('%s%s[%s] = '):format(ret, next_indent,
                                         format_luav(k, nil, opts))
          end
          ret = ret .. format_luav(subv, next_indent_arg, opts) .. ',' .. nl
          non_empty = true
        end
      end
      if nl == ' ' and non_empty then
        ret = ret:sub(1, -3)
      end
      ret = ret  .. indent .. '}'
    end
  elseif type(v) == 'number' then
    if v % 1 == 0 then
      ret = ('%d'):format(v)
    else
      ret = format_float(v)
    end
  elseif type(v) == 'nil' then
    ret = 'nil'
  elseif type(v) == 'boolean' then
    ret = (v and 'true' or 'false')
  else
    print(type(v))
    -- Not implemented yet
    assert(false)
  end
  return ret
end

local function format_string(fmt, ...)
  local i = 0
  local args = {...}
  local function getarg()
    i = i + 1
    return args[i]
  end
  local ret = fmt:gsub('%%[0-9*]*%.?[0-9*]*[cdEefgGiouXxqsr%%]', function(match)
    local subfmt = match:gsub('%*', function()
      return tostring(getarg())
    end)
    local arg = nil
    if subfmt:sub(-1) ~= '%' then
      arg = getarg()
    end
    if subfmt:sub(-1) == 'r' or subfmt:sub(-1) == 'q' then
      -- %r is like built-in %q, but it is supposed to single-quote strings and
      -- not double-quote them, and also work not only for strings.
      -- Builtin %q is replaced here as it gives invalid and inconsistent with
      -- luajit results for e.g. "\e" on lua: luajit transforms that into `\27`,
      -- lua leaves as-is.
      arg = format_luav(arg, nil, {dquote_strings = (subfmt:sub(-1) == 'q')})
      subfmt = subfmt:sub(1, -2) .. 's'
    end
    if subfmt == '%e' then
      return format_float(arg)
    else
      return subfmt:format(arg)
    end
  end)
  return ret
end

local function intchar2lua(ch)
  ch = tonumber(ch)
  return (20 <= ch and ch < 127) and ('%c'):format(ch) or ch
end

local fixtbl_metatable = {
  __newindex = function()
    assert(false)
  end,
}

local function fixtbl(tbl)
  return setmetatable(tbl, fixtbl_metatable)
end

local function fixtbl_rec(tbl)
  for _, v in pairs(tbl) do
    if type(v) == 'table' then
      fixtbl_rec(v)
    end
  end
  return fixtbl(tbl)
end

-- From https://github.com/premake/premake-core/blob/master/src/base/table.lua
local function table_flatten(arr)
  local result = {}
  local function _table_flatten(_arr)
    local n = #_arr
    for i = 1, n do
      local v = _arr[i]
      if type(v) == "table" then
        _table_flatten(v)
      elseif v then
        table.insert(result, v)
      end
    end
  end
  _table_flatten(arr)
  return result
end

local function hexdump(str)
  local len = string.len(str)
  local dump = ""
  local hex = ""
  local asc = ""

  for i = 1, len do
    if 1 == i % 8 then
      dump = dump .. hex .. asc .. "\n"
      hex = string.format("%04x: ", i - 1)
      asc = ""
    end

    local ord = string.byte(str, i)
    hex = hex .. string.format("%02x ", ord)
    if ord >= 32 and ord <= 126 then
      asc = asc .. string.char(ord)
    else
      asc = asc .. "."
    end
  end

  return dump .. hex .. string.rep("   ", 8 - len % 8) .. asc
end

local function read_file(name)
  local file = io.open(name, 'r')
  if not file then
    return nil
  end
  local ret = file:read('*a')
  file:close()
  return ret
end

-- Dedent the given text and write it to the file name.
local function write_file(name, text, no_dedent, append)
  local file = io.open(name, (append and 'a' or 'w'))
  if type(text) == 'table' then
    -- Byte blob
    local bytes = text
    text = ''
    for _, char in ipairs(bytes) do
      text = ('%s%c'):format(text, char)
    end
  elseif not no_dedent then
    text = dedent(text)
  end
  file:write(text)
  file:flush()
  file:close()
end

local function isCI()
  local is_travis = nil ~= os.getenv('TRAVIS')
  local is_appveyor = nil ~= os.getenv('APPVEYOR')
  local is_quickbuild = nil ~= os.getenv('PR_NUMBER')
  return is_travis or is_appveyor or is_quickbuild
end

-- Gets the contents of $NVIM_LOG_FILE for printing to the build log.
-- Also removes the file, if the current environment looks like CI.
local function read_nvim_log()
  local logfile = os.getenv('NVIM_LOG_FILE') or '.nvimlog'
  local logtext = read_file(logfile)
  local lines = {}
  for l in string.gmatch(logtext or '', "[^\n]+") do  -- Split at newlines.
    table.insert(lines, l)
  end
  local log = (('-'):rep(78)..'\n'
    ..string.format('$NVIM_LOG_FILE: %s\n', logfile)
    ..(logtext and (isCI() and '' or '(last 10 lines)\n') or '(empty)\n'))
  local keep = (isCI() and #lines or math.min(10, #lines))
  local startidx = math.max(1, #lines - keep + 1)
  for i = startidx, (startidx + keep - 1) do
    log = log..lines[i]..'\n'
  end
  log = log..('-'):rep(78)..'\n'
  if isCI() then
    os.remove(logfile)
  end
  return log
end

local module = {
  REMOVE_THIS = REMOVE_THIS,
  argss_to_cmd = argss_to_cmd,
  check_cores = check_cores,
  check_logs = check_logs,
  concat_tables = concat_tables,
  dedent = dedent,
  deepcopy = deepcopy,
  dictdiff = dictdiff,
  eq = eq,
  expect_err = expect_err,
  filter = filter,
  fixtbl = fixtbl,
  fixtbl_rec = fixtbl_rec,
  format_luav = format_luav,
  format_string = format_string,
  glob = glob,
  hasenv = hasenv,
  hexdump = hexdump,
  intchar2lua = intchar2lua,
  map = map,
  matches = matches,
  mergedicts_copy = mergedicts_copy,
  near = near,
  neq = neq,
  ok = ok,
  popen_r = popen_r,
  popen_w = popen_w,
  read_file = read_file,
  read_nvim_log = read_nvim_log,
  repeated_read_cmd = repeated_read_cmd,
  shallowcopy = shallowcopy,
  sleep = sleep,
  table_flatten = table_flatten,
  tmpname = tmpname,
  uname = uname,
  updated = updated,
  which = which,
  write_file = write_file,
}

return module
