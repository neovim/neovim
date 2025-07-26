local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local fn = n.fn

local eq = t.eq
local exec_lua = n.exec_lua

-- Helpers ====================================================================
-- Installed plugins ----------------------------------------------------------

local function pack_get_dir()
  return vim.fs.joinpath(fn.stdpath('data'), 'site', 'pack', 'core', 'opt')
end

local function pack_get_plug_path(plug_name)
  return vim.fs.joinpath(pack_get_dir(), plug_name)
end

-- Test repos (to be installed) -----------------------------------------------

local repos_dir = vim.fs.abspath('test/functional/lua/pack-test-repos')

--- Map from repo name to its proper `src` used in plugin spec
--- @type table<string,string>
local repos_src = {}

local function repo_get_path(repo_name)
  return vim.fs.joinpath(repos_dir, repo_name)
end

local function repo_write_file(repo_name, rel_path, text, no_dedent, append)
  local path = vim.fs.joinpath(repo_get_path(repo_name), rel_path)
  fn.mkdir(vim.fs.dirname(path), 'p')
  t.write_file(path, text, no_dedent, append)
end

--- @return vim.SystemCompleted
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

local function git_cmd(cmd, repo_name)
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
  local cwd = repo_get_path(repo_name)
  local sys_opts = { cwd = cwd, text = true, clear_env = true }
  local out = system_sync(cmd, sys_opts)
  if out.code ~= 0 then
    error(out.stderr)
  end
  return (out.stdout:gsub('\n+$', ''))
end

local function init_test_repo(repo_name)
  local path = repo_get_path(repo_name)
  fn.mkdir(path, 'p')
  repos_src[repo_name] = 'file://' .. path

  git_cmd({ 'init' }, repo_name)
end

local function git_add_commit(msg, repo_name)
  git_cmd({ 'add', '*' }, repo_name)
  git_cmd({ 'commit', '-m', msg }, repo_name)
end

-- Common test repos ----------------------------------------------------------
local function setup_repo_basic()
  init_test_repo('basic')

  local text = 'return { get = function() return "basic main" end }'
  repo_write_file('basic', 'lua/basic.lua', text)
  git_add_commit('Initial commit for "basic"', 'basic')

  git_cmd({ 'checkout', '-b', 'feat-branch' }, 'basic')

  text = 'return { get = function() return "basic feat-branch" end }'
  repo_write_file('basic', 'lua/basic.lua', text)
  git_add_commit('Add important feature', 'basic')
end

local function setup_repo_plugindirs()
  init_test_repo('plugindirs')

  repo_write_file('plugindirs', 'plugin/dirs.lua', 'vim.g._plugin = true')
  repo_write_file('plugindirs', 'plugin/dirs.vim', 'let g:_plugin_vim=v:true')
  repo_write_file('plugindirs', 'plugin/sub/dirs.lua', 'vim.g._plugin_sub = true')
  repo_write_file('plugindirs', 'after/plugin/dirs.lua', 'vim.g._after_plugin = true')
  repo_write_file('plugindirs', 'after/plugin/dirs.vim', 'let g:_after_plugin_vim=v:true')
  repo_write_file('plugindirs', 'after/plugin/sub/dirs.lua', 'vim.g._after_plugin_sub = true')
  git_add_commit('Initial commit for "plugindirs"', 'plugindirs')
end

-- Tests ======================================================================

describe('vim.pack', function()
  setup(function()
    n.clear()
    setup_repo_basic()
    setup_repo_plugindirs()
  end)

  before_each(function()
    n.clear()
  end)

  after_each(function()
    vim.fs.rm(pack_get_dir(), { force = true, recursive = true })
  end)

  teardown(function()
    vim.fs.rm(repos_dir, { force = true, recursive = true })
  end)

  describe('add()', function()
    it('installs at proper version', function()
      local out = exec_lua(function()
        vim.pack.add({
          { src = repos_src.basic, version = 'feat-branch' },
        })
        -- Should have plugin available immediately after
        return require('basic').get()
      end)

      eq('basic feat-branch', out)

      local rtp = vim.tbl_map(t.fix_slashes, n.api.nvim_list_runtime_paths())
      local plug_path = pack_get_plug_path('basic')
      local after_dir = vim.fs.joinpath(plug_path, 'after')
      eq(true, vim.tbl_contains(rtp, plug_path))
      -- No 'after/' directory in runtimepath because it is not present in plugin
      eq(false, vim.tbl_contains(rtp, after_dir))
    end)

    it('respects plugin/ and after/plugin/ scripts', function()
      local function validate(load, ref)
        local opts = { load = load }
        local out = exec_lua(function()
          vim.pack.add({ repos_src.plugindirs }, opts)
          return {
            vim.g._plugin,
            vim.g._plugin_vim,
            vim.g._plugin_sub,
            vim.g._after_plugin,
            vim.g._after_plugin_vim,
            vim.g._after_plugin_sub,
          }
        end)

        eq(ref, out)

        -- Should add necessary directories to runtimepath regardless of `opts.load`
        local rtp = vim.tbl_map(t.fix_slashes, n.api.nvim_list_runtime_paths())
        local plug_path = pack_get_plug_path('plugindirs')
        local after_dir = vim.fs.joinpath(plug_path, 'after')
        eq(true, vim.tbl_contains(rtp, plug_path))
        eq(true, vim.tbl_contains(rtp, after_dir))
      end

      validate(nil, { true, true, true, true, true, true })

      n.clear()
      validate(false, {})
    end)

    pending('reports errors after loading', function()
      -- TODO
      -- Should handle (not let it terminate the function) and report errors from pack_add()
    end)

    pending('normalizes each spec', function()
      -- TODO

      -- TODO: Should properly infer `name` from `src` (as its basename
      -- minus '.git' suffix) but allow '.git' suffix in explicit `name`
    end)

    pending('normalizes spec array', function()
      -- TODO
      -- Should silently ignore full duplicates (same `src`+`version`)
      -- and error on conflicts.
    end)
  end)

  describe('update()', function()
    pending('works', function()
      -- TODO

      -- TODO: Should work with both added and not added plugins
    end)

    pending('suggests newer tags if there are no updates', function()
      -- TODO

      -- TODO: Should not suggest tags that point to the current state.
      -- Even if there is one/several and located at start/middle/end.
    end)
  end)

  describe('get()', function()
    before_each(function()
      -- Ensure tested plugins were installed in previous session
      exec_lua(function()
        vim.pack.add({ repos_src.plugindirs, repos_src.basic })
      end)
      n.clear()
    end)

    it('returns list of available plugins', function()
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)

      -- Should first return active plugins followed by non-active
      local plug_basic_spec = { name = 'basic', src = repos_src.basic, version = 'feat-branch' }
      local plug_plugindirs_spec =
        { name = 'plugindirs', src = repos_src.plugindirs, version = 'main' }
      local expected = {
        { active = true, path = pack_get_plug_path('basic'), spec = plug_basic_spec },
        { active = false, path = pack_get_plug_path('plugindirs'), spec = plug_plugindirs_spec },
      }
      local actual = exec_lua(function()
        return vim.pack.get()
      end)
      eq(expected, actual)
    end)

    pending('works after `del()`', function()
      -- TODO: Should not include removed plugins and still return list

      -- TODO: Should return corrent list inside `PackChanged` "delete" event
    end)
  end)

  describe('del()', function()
    pending('works', function()
      -- TODO
    end)
  end)
end)
