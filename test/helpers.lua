local assert = require('luassert')
local lfs = require('lfs')

local check_logs_useless_lines = {
  ['Warning: noted but unhandled ioctl']=1,
  ['could cause spurious value errors to appear']=2,
  ['See README_MISSING_SYSCALL_OR_IOCTL for guidance']=3,
}

local eq = function(exp, act)
  return assert.are.same(exp, act)
end
local neq = function(exp, act)
  return assert.are_not.same(exp, act)
end
local ok = function(res)
  return assert.is_true(res)
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
          -- local out = os.getenv('TRAVIS_CI_BUILD') and io.stdout or io.stderr
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

    local status, f = pcall(io.popen, "uname -s")
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
    exc_re = { '^/%.deps$', local_tmpdir }
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
    local pipe = io.popen(
        db_cmd:gsub('%$_NVIM_TEST_APP', app):gsub('%$_NVIM_TEST_CORE', core)
        .. ' 2>&1', 'r')
    if pipe then
      local bt = pipe:read('*a')
      if bt then
        out:write(bt)
        out:write('\n')
      else
        out:write('Failed to read from the pipe\n')
      end
    else
      out:write('Failed to create pipe\n')
    end
    out:flush()
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
  local pipe = io.popen('which ' .. exe, 'r')
  local ret = pipe:read('*a')
  pipe:close()
  if ret == '' then
    return nil
  else
    return ret:sub(1, -2)
  end
end

local function shallowcopy(orig)
  local copy = {}
  for orig_key, orig_value in pairs(orig) do
    copy[orig_key] = orig_value
  end
  return copy
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

format_luav = function(v, indent)
  local linesep = '\n'
  local next_indent = nil
  if indent == nil then
    indent = ''
    linesep = ''
  else
    next_indent = indent .. '  '
  end
  local ret = ''
  if type(v) == 'string' then
    ret = tostring(v):gsub('[\'\\]', '\\%0'):gsub('[%z\1-\31]', function(match)
      return SUBTBL[match:byte() + 1]
    end)
    ret = '\'' .. ret .. '\''
  elseif type(v) == 'table' then
    local processed_keys = {}
    ret = '{' .. linesep
    for i, subv in ipairs(v) do
      ret = ret .. (next_indent or '') .. format_luav(subv, next_indent) .. ',\n'
      processed_keys[i] = true
    end
    for k, subv in pairs(v) do
      if not processed_keys[k] then
        if type(k) == 'string' and k:match('^[a-zA-Z_][a-zA-Z0-9_]*$') then
          ret = ret .. next_indent .. k .. ' = '
        else
          ret = ret .. next_indent .. '[' .. format_luav(k) .. '] = '
        end
        ret = ret .. format_luav(subv, next_indent) .. ',\n'
      end
    end
    ret = ret  .. indent .. '}'
  elseif type(v) == 'number' then
    if v % 1 == 0 then
      ret = ('%d'):format(v)
    else
      ret = ('%e'):format(v)
    end
  elseif type(v) == 'nil' then
    ret = 'nil'
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
    local subfmt = match:gsub('%*', function(match)
      return getarg()
    end)
    local arg = nil
    if subfmt:sub(-1) ~= '%' then
      arg = getarg()
    end
    if subfmt:sub(-1) == 'r' then
      -- %r is like %q, but it is supposed to single-quote strings and not
      -- double-quote them, and also work not only for strings.
      subfmt = subfmt:sub(1, -2) .. 's'
      arg = format_luav(arg)
    end
    return subfmt:format(arg)
  end)
  return ret
end

return {
  eq = eq,
  neq = neq,
  ok = ok,
  check_logs = check_logs,
  uname = uname,
  tmpname = tmpname,
  map = map,
  filter = filter,
  glob = glob,
  check_cores = check_cores,
  hasenv = hasenv,
  which = which,
  shallowcopy = shallowcopy,
  concat_tables = concat_tables,
  dedent = dedent,
  format_luav = format_luav,
  format_string = format_string,
}
