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

local function glob(initial_path, re, exc_re)
  local paths_to_check = {initial_path}
  local ret = {}
  local checked_files = {}
  while #paths_to_check > 0 do
    local cur_path = paths_to_check[#paths_to_check]
    paths_to_check[#paths_to_check] = nil
    for e in lfs.dir(cur_path) do
      local full_path = cur_path .. '/' .. e
      local checked_path = full_path:sub(#initial_path + 1)
      if ((not exc_re or not checked_path:match(exc_re))
          and e:sub(1, 1) ~= '.') then
        local attrs = lfs.attributes(full_path)
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

local function tmpname()
  local fname = os.tmpname()
  if uname() == 'Windows' and fname:sub(1, 2) == '\\s' then
    -- In Windows tmpname() returns a filename starting with
    -- special sequence \s, prepend $TEMP path
    local tmpdir = os.getenv('TEMP')
    return tmpdir..fname
  elseif fname:match('^/tmp') and uname() == 'Darwin' then
    -- In OS X /tmp links to /private/tmp
    return '/private'..fname
  else
    return fname
  end
end

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

local function check_cores(app)
  app = app or 'build/bin/nvim'
  local initial_path, re, exc_re
  local gdb_db_cmd = 'gdb -n -batch -ex "thread apply all bt full" "$_NVIM_TEST_APP" -c "$_NVIM_TEST_CORE"'
  local lldb_db_cmd = 'lldb -Q -o "bt all" -f "$_NVIM_TEST_APP" -c "$_NVIM_TEST_CORE"'
  local random_skip = false
  local db_cmd
  if hasenv('NVIM_TEST_CORE_GLOB_DIRECTORY') then
    initial_path = os.getenv('NVIM_TEST_CORE_GLOB_DIRECTORY')
    re = os.getenv('NVIM_TEST_CORE_GLOB_RE')
    exc_re = os.getenv('NVIM_TEST_CORE_EXC_RE')
    db_cmd = os.getenv('NVIM_TEST_CORE_DB_CMD') or gdb_db_cmd
    random_skip = os.getenv('NVIM_TEST_CORE_RANDOM_SKIP')
  elseif os.getenv('TRAVIS_OS_NAME') == 'osx' then
    initial_path = '/cores'
    re = nil
    exc_re = nil
    db_cmd = lldb_db_cmd
  else
    initial_path = '.'
    re = 'core[^/]*'
    exc_re = '^/%.deps$'
    db_cmd = gdb_db_cmd
    random_skip = true
  end
  -- Finding cores takes too much time on linux
  if random_skip and math.random() < 0.9 then
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
  assert(0 == found_cores)
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
}
