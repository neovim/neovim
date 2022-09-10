-- Modules loaded here will not be cleared and reloaded by Busted.
-- See #2082, Olivine-Labs/busted#62 and Olivine-Labs/busted#643

local test_type

for _, value in pairs(_G.arg) do
  if value:match('IS_FUNCTIONAL_TEST') then
    test_type = 'functional'
  elseif value:match('IS_UNIT_TEST') then
    test_type = 'unit'
  elseif value:match('IS_BENCHMARK_TEST') then
    test_type = 'benchmark'
  end
end

local luv = require('luv')

local function join_paths(...)
  local path_sep = luv.os_uname().version:match('Windows') and '\\' or '/'
  local result = table.concat({ ... }, path_sep)
  return result
end

local function is_file(path)
  local stat = luv.fs_stat(path)
  return stat and stat.type == 'file' or false
end

local function is_directory(path)
  local stat = luv.fs_stat(path)
  return stat and stat.type == 'directory' or false
end

-- credit: treesitter.actions.remove_dir()
local function remove_dir(path)
  local handle = luv.fs_scandir(path)
  if type(handle) == 'string' then
    error(handle)
  end

  while true do
    local name, t = luv.fs_scandir_next(handle)
    if not name then
      break
    end

    local new_cwd = join_paths(path, name)
    if t == 'directory' then
      local success = remove_dir(new_cwd)
      if not success then
        return false
      end
    else
      local success = luv.fs_unlink(new_cwd)
      if not success then
        return false
      end
    end
  end

  return luv.fs_rmdir(path)
end

--[[
  TODO(kylo252): we should probably override TMPDIR dynamically per test regardless,
  but that seems to cause issues for rpc tests where TMPDIR isn't passed along
  -- luv.os_setenv('TMPDIR', NVIM_TEST_TMPDIR)
--]]

local tmpname = function()
  local fd, tmp_path = luv.fs_mkstemp(join_paths(os.getenv('TMPDIR'), 'nvim_XXXXXXXXXX'))

  -- if not open, open with (0700) permissions
  fd = fd or luv.fs_open(tmp_path, 'w', 384)
  luv.fs_close(fd)

  return tmp_path, function()
    luv.fs_unlink(tmp_path)
  end
end

local global_helpers = require('test.helpers')

global_helpers.is_file = is_file
global_helpers.is_directory = is_directory
global_helpers.join_paths = join_paths
global_helpers.remove_dir = remove_dir

-- override tmpname
global_helpers.tmpname = tmpname

local ffi_ok, ffi = pcall(require, 'ffi')

local iswin = global_helpers.iswin
if iswin() and ffi_ok then
  ffi.cdef([[
  typedef int errno_t;
  errno_t _set_fmode(int mode);
  ]])
  ffi.C._set_fmode(0x8000)
end

if test_type == 'unit' then
  require('test.unit.preprocess')
end

require('test.' .. test_type .. '.helpers')(nil)
package.loaded['test.' .. test_type .. '.helpers'] = nil

local testid = (function()
  local id = 0
  return function()
    id = id + 1
    return id
  end
end)()

local NEOVIM_BUILD_DIR = os.getenv('NEOVIM_BUILD_DIR') or join_paths(luv.cwd(), 'build')
local get_artifcats_dir = function(context)
  return join_paths(NEOVIM_BUILD_DIR, 'Testing', 'artifacts', context.test_pid)
end

local base_dirs = {
  XDG_CONFIG_HOME = join_paths(NEOVIM_BUILD_DIR, 'Xtest_xdg', 'config'),
  XDG_DATA_HOME = join_paths(NEOVIM_BUILD_DIR, 'Xtest_xdg', 'data'),
  XDG_STATE_HOME = join_paths(NEOVIM_BUILD_DIR, 'Xtest_xdg', 'state'),
  XDG_CACHE_HOME = join_paths(NEOVIM_BUILD_DIR, 'Xtest_xdg', 'cache'),
  TMPDIR = join_paths(NEOVIM_BUILD_DIR, 'Xtest_tmpdir'),
  LOG_DIR = join_paths(os.getenv('LOG_DIR') or NEOVIM_BUILD_DIR, 'Xtest_log'),
}

for k, path in pairs(base_dirs) do
  luv.os_setenv(k, path)
end

local cleanupArtifacts = function(context)
  local artifacts_dir = get_artifcats_dir(context)
  if is_directory(artifacts_dir) then
    return remove_dir(artifacts_dir)
  end
end

local testEnd = function(context, _, status, _)
  if status == 'error' then
    return
  end
  cleanupArtifacts(context)
  return nil, true
end

-- Global before_each. https://github.com/Olivine-Labs/busted/issues/613
local before_each = function(context)
  local id = ('T%d'):format(testid())
  context.test_pid = luv.os_getpid()
  context.test_id = id
  _G._nvim_test_id = id

  local NVIM_LOG_FILE = join_paths(os.getenv('LOG_DIR') or base_dirs.TMPDIR, '.nvimlog')
  luv.os_setenv('NVIM_LOG_FILE', NVIM_LOG_FILE)

  luv.os_unsetenv('XDG_DATA_DIRS')
  luv.os_unsetenv('NVIM')

  for k, path in pairs(base_dirs) do
    local dir = require('pl.dir')
    dir.makepath(join_paths(path, id, 'nvim'), tonumber('0700'))
    luv.os_setenv(k, join_paths(path, id))
  end
  return nil, true
end

local busted = require('busted')

busted.subscribe({ 'test', 'start' }, before_each, {
  priority = 1,
  -- Don't generate a test-id for skipped tests. /shrug
  predicate = function(element, _, status)
    return not (element.descriptor == 'pending' or status == 'pending')
  end,
})

busted.subscribe({ 'test', 'end' }, testEnd, {
  priority = 101,
})
