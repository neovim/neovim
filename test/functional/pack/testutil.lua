local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local fn = n.fn

local M = {}

-- File system ----------------------------------------------------------------

local test_plugins_path = vim.fs.abspath('test/functional/pack/test_plugins')

local function get_plug_abspath(plug_name)
  return vim.fs.joinpath(test_plugins_path, plug_name)
end

function M.write_file(plug_name, rel_path, text, no_dedent, append)
  local path = vim.fs.joinpath(get_plug_abspath(plug_name), rel_path)
  fn.mkdir(vim.fs.dirname(path), 'p')
  t.write_file(path, text, no_dedent, append)
end

function M.get_test_src(plug_name)
  return 'file://' .. get_plug_abspath(plug_name)
end

function M.get_pack_dir(plug_name)
  return vim.fs.joinpath(fn.stdpath('data'), 'site', 'pack', 'core', 'opt', plug_name)
end

function M.clean_repos()
  vim.fs.rm(test_plugins_path, { force = true, recursive = true })
end

-- Git ------------------------------------------------------------------------

local function system_sync(cmd, opts)
  return n.exec_lua(function()
    local obj = vim.system(cmd, opts)

    if opts and opts.timeout then
      -- Minor delay before calling wait() so the timeout uv timer can have a headstart over the
      -- internal call to vim.wait() in wait().
      vim.wait(10)
    end

    local res = obj:wait()

    -- Check the process is no longer running
    assert(not vim.api.nvim_get_proc(obj.pid), 'process still exists')

    return res
  end)
end

local function git_cmd(cmd, plug_name)
  local git_cmd_prefix = {
    'git',
    '-c',
    'gc.auto=0',
    '-c',
    'user.name=Marvim',
    '-c',
    'user.email=marvim@neovim.io',
    '-c',
    'init.defaultBranch=main',
  }

  cmd = vim.list_extend(git_cmd_prefix, cmd)
  local cwd = get_plug_abspath(plug_name)
  local sys_opts = { cwd = cwd, text = true, clear_env = true }
  local out = system_sync(cmd, sys_opts) --- @type vim.SystemCompleted
  if out.code ~= 0 then
    error(out.stderr)
  end
  return (out.stdout:gsub('\n+$', ''))
end

function M.init_test_plugin(plug_name)
  local path = get_plug_abspath(plug_name)
  fn.mkdir(path, 'p')
  git_cmd({ 'init' }, plug_name)
end

function M.git_add(plug_name, args)
  local cmd = { 'add' }
  vim.list_extend(cmd, args)
  git_cmd(cmd, plug_name)
end

function M.git_commit(plug_name, msg)
  git_cmd({ 'commit', '-m', msg }, plug_name)
end

function M.git_get_hash(plug_name, target)
  return git_cmd({ 'rev-list', '-1', '--abbrev-commit', target })
end

-- Common test plugins --------------------------------------------------------
function M.setup_plug_basic()
  M.init_test_plugin('plug_basic')

  local text = 'return { get = function() return "basic main" end }'
  M.write_file('plug_basic', 'lua/plug_basic.lua', text)
  M.git_add('plug_basic', { '*' })
  M.git_commit('plug_basic', 'Initial commit for "basic"')

  git_cmd({ 'checkout', '-b', 'feat-branch' }, 'plug_basic')

  text = 'return { get = function() return "basic feat branch" end }'
  M.write_file('plug_basic', 'lua/plug_basic.lua', text)
  M.git_add('plug_basic', { '*' })
  M.git_commit('plug_basic', 'Add important feature')
end

function M.setup_plug_dummy()
  M.init_test_plugin('plug_dummy')

  M.write_file('plug_dummy', 'README', '# Dummy plugin')
  M.git_add('plug_dummy', { '*' })
  M.git_commit('plug_dummy', 'Initial commit for "dummy"')
end

return M
