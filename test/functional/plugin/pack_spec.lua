local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local skip_integ = os.getenv('NVIM_TEST_INTEG') ~= '1'

local api = n.api
local fn = n.fn

local eq = t.eq
local matches = t.matches
local pcall_err = t.pcall_err
local exec_lua = n.exec_lua

-- Helpers ====================================================================
-- Installed plugins ----------------------------------------------------------

local function pack_get_dir()
  return vim.fs.joinpath(fn.stdpath('data'), 'site', 'pack', 'core', 'opt')
end

local function pack_get_plug_path(plug_name)
  return vim.fs.joinpath(pack_get_dir(), plug_name)
end

local function pack_exists(plug_name)
  local path = vim.fs.joinpath(pack_get_dir(), plug_name)
  return vim.uv.fs_stat(path) ~= nil
end

-- Test repos (to be installed) -----------------------------------------------

local repos_dir = vim.fs.abspath('test/functional/lua/pack-test-repos')

--- Map from repo name to its proper `src` used in plugin spec
--- @type table<string,string>
local repos_src = {}

local function repo_get_path(repo_name)
  vim.validate('repo_name', repo_name, 'string')
  return vim.fs.joinpath(repos_dir, repo_name)
end

local function repo_write_file(repo_name, rel_path, text, no_dedent, append)
  local path = vim.fs.joinpath(repo_get_path(repo_name), rel_path)
  fn.mkdir(vim.fs.dirname(path), 'p')
  t.write_file(path, text, no_dedent, append)
end

--- @return vim.SystemCompleted
local function system_sync(cmd, opts)
  return exec_lua(function()
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

local function git_get_hash(rev, repo_name)
  return git_cmd({ 'rev-list', '-1', rev }, repo_name)
end

local function git_get_short_hash(rev, repo_name)
  return git_cmd({ 'rev-list', '-1', '--abbrev-commit', rev }, repo_name)
end

-- Common test repos ----------------------------------------------------------
--- @type table<string,function>
local repos_setup = {}

function repos_setup.basic()
  init_test_repo('basic')

  repo_write_file('basic', 'lua/basic.lua', 'return "basic init"')
  git_add_commit('Initial commit for "basic"', 'basic')
  repo_write_file('basic', 'lua/basic.lua', 'return "basic main"')
  git_add_commit('Commit in `main` but not in `feat-branch`', 'basic')

  git_cmd({ 'checkout', 'main~' }, 'basic')
  git_cmd({ 'checkout', '-b', 'feat-branch' }, 'basic')

  repo_write_file('basic', 'lua/basic.lua', 'return "basic some-tag"')
  git_add_commit('Add commit for some tag', 'basic')
  git_cmd({ 'tag', 'some-tag' }, 'basic')

  repo_write_file('basic', 'lua/basic.lua', 'return "basic feat-branch"')
  git_add_commit('Add important feature', 'basic')

  -- Make sure that `main` is the default remote branch
  git_cmd({ 'checkout', 'main' }, 'basic')
end

function repos_setup.plugindirs()
  init_test_repo('plugindirs')

  -- Add semver tag
  repo_write_file('plugindirs', 'lua/plugindirs.lua', 'return "plugindirs v0.0.1"')
  git_add_commit('Add version v0.0.1', 'plugindirs')
  git_cmd({ 'tag', 'v0.0.1' }, 'plugindirs')

  -- Add various 'plugin/' files
  repo_write_file('plugindirs', 'lua/plugindirs.lua', 'return "plugindirs main"')
  repo_write_file('plugindirs', 'plugin/dirs.lua', 'vim.g._plugin = true')
  repo_write_file('plugindirs', 'plugin/dirs_log.lua', '_G.DL = _G.DL or {}; DL[#DL+1] = "p"')
  repo_write_file('plugindirs', 'plugin/dirs.vim', 'let g:_plugin_vim=v:true')
  repo_write_file('plugindirs', 'plugin/sub/dirs.lua', 'vim.g._plugin_sub = true')
  repo_write_file('plugindirs', 'plugin/bad % name.lua', 'vim.g._plugin_bad = true')
  repo_write_file('plugindirs', 'after/plugin/dirs.lua', 'vim.g._after_plugin = true')
  repo_write_file('plugindirs', 'after/plugin/dirs_log.lua', '_G.DL = _G.DL or {}; DL[#DL+1] = "a"')
  repo_write_file('plugindirs', 'after/plugin/dirs.vim', 'let g:_after_plugin_vim=v:true')
  repo_write_file('plugindirs', 'after/plugin/sub/dirs.lua', 'vim.g._after_plugin_sub = true')
  repo_write_file('plugindirs', 'after/plugin/bad % name.lua', 'vim.g._after_plugin_bad = true')
  git_add_commit('Initial commit for "plugindirs"', 'plugindirs')
end

function repos_setup.helptags()
  init_test_repo('helptags')
  repo_write_file('helptags', 'lua/helptags.lua', 'return "helptags main"')
  repo_write_file('helptags', 'doc/my-test-help.txt', '*my-test-help*')
  repo_write_file('helptags', 'doc/bad % name.txt', '*my-test-help-bad*')
  repo_write_file('helptags', 'doc/bad % dir/file.txt', '*my-test-help-sub-bad*')
  git_add_commit('Initial commit for "helptags"', 'helptags')
end

function repos_setup.pluginerr()
  init_test_repo('pluginerr')

  repo_write_file('pluginerr', 'lua/pluginerr.lua', 'return "pluginerr main"')
  repo_write_file('pluginerr', 'plugin/err.lua', 'error("Wow, an error")')
  git_add_commit('Initial commit for "pluginerr"', 'pluginerr')
end

function repos_setup.defbranch()
  init_test_repo('defbranch')

  repo_write_file('defbranch', 'lua/defbranch.lua', 'return "defbranch main"')
  git_add_commit('Initial commit for "defbranch"', 'defbranch')

  -- Make `dev` the default remote branch
  git_cmd({ 'checkout', '-b', 'dev' }, 'defbranch')

  repo_write_file('defbranch', 'lua/defbranch.lua', 'return "defbranch dev"')
  git_add_commit('Add to new default branch', 'defbranch')
end

function repos_setup.gitsuffix()
  init_test_repo('gitsuffix.git')

  repo_write_file('gitsuffix.git', 'lua/gitsuffix.lua', 'return "gitsuffix main"')
  git_add_commit('Initial commit for "gitsuffix"', 'gitsuffix.git')
end

function repos_setup.semver()
  init_test_repo('semver')

  local function add_tag(name)
    repo_write_file('semver', 'lua/semver.lua', 'return "semver ' .. name .. '"')
    git_add_commit('Add version ' .. name, 'semver')
    git_cmd({ 'tag', name }, 'semver')
  end

  add_tag('v0.0.1')
  add_tag('v0.0.2')
  add_tag('v0.1.0')
  add_tag('v0.1.1')
  add_tag('v0.2.0-dev')
  add_tag('v0.2.0')
  add_tag('v0.3.0')
  repo_write_file('semver', 'lua/semver.lua', 'return "semver middle-commit')
  git_add_commit('Add middle commit', 'semver')
  add_tag('0.3.1')
  add_tag('v0.4')
  add_tag('non-semver')
  add_tag('v0.2.1') -- Intentionally add version not in order
  add_tag('v1.0.0')
end

-- Utility --------------------------------------------------------------------

local function watch_events(event)
  exec_lua(function()
    _G.event_log = _G.event_log or {} --- @type table[]
    vim.api.nvim_create_autocmd(event, {
      callback = function(ev)
        table.insert(_G.event_log, { event = ev.event, match = ev.match, data = ev.data })
      end,
    })
  end)
end

--- @param log table[]
local function make_find_packchanged(log)
  --- @param suffix string
  return function(suffix, kind, repo_name, version, active)
    local path = pack_get_plug_path(repo_name)
    local spec = { name = repo_name, src = repos_src[repo_name], version = version }
    local data = { active = active, kind = kind, path = path, spec = spec }
    local entry = { event = 'PackChanged' .. suffix, match = vim.fs.abspath(path), data = data }

    local res = 0
    for i, tbl in ipairs(log) do
      if vim.deep_equal(tbl, entry) then
        res = i
        break
      end
    end
    eq(true, res > 0)

    return res
  end
end

local function track_nvim_echo()
  exec_lua(function()
    _G.echo_log = {}
    local nvim_echo_orig = vim.api.nvim_echo
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.api.nvim_echo = function(...)
      table.insert(_G.echo_log, vim.deepcopy({ ... }))
      return nvim_echo_orig(...)
    end
  end)
end

local function assert_progress_report(action, step_names)
  -- NOTE: Assume that `nvim_echo` mocked log has only progress report messages
  local echo_log = exec_lua('return _G.echo_log') ---@type table[]
  local n_steps = #step_names
  eq(n_steps + 2, #echo_log)

  local progress = { kind = 'progress', title = 'vim.pack', status = 'running', percent = 0 }
  local init_step = { { { ('%s (0/%d)'):format(action, n_steps) } }, true, progress }
  eq(init_step, echo_log[1])

  local steps_seen = {} --- @type table<string,boolean>
  for i = 1, n_steps do
    local echo_args = echo_log[i + 1]

    -- NOTE: There is no guaranteed order (as it is async), so check that some
    -- expected step name is used in the message
    local msg = ('%s (%d/%d)'):format(action, i, n_steps)
    local pattern = '^' .. vim.pesc(msg) .. ' %- (%S+)$'
    local step = echo_args[1][1][1]:match(pattern) ---@type string
    eq(true, vim.tbl_contains(step_names, step))
    steps_seen[step] = true

    -- Should not add intermediate progress report to history
    eq(echo_args[2], false)

    -- Should update a single message by its id (computed after first call)
    progress.id = progress.id or echo_args[3].id ---@type integer
    progress.percent = math.floor(100 * i / n_steps)
    eq(echo_args[3], progress)
  end

  -- Should report all steps
  eq(n_steps, vim.tbl_count(steps_seen))

  progress.percent, progress.status = 100, 'success'
  local final_step = { { { ('%s (%d/%d)'):format(action, n_steps, n_steps) } }, true, progress }
  eq(final_step, echo_log[n_steps + 2])
end

local function mock_confirm(output_value)
  exec_lua(function()
    _G.confirm_log = _G.confirm_log or {}

    ---@diagnostic disable-next-line: duplicate-set-field
    vim.fn.confirm = function(...)
      table.insert(_G.confirm_log, { ... })
      return output_value
    end
  end)
end

local function is_jit()
  return exec_lua('return package.loaded.jit ~= nil')
end

local function get_lock_path()
  return vim.fs.joinpath(fn.stdpath('config'), 'nvim-pack-lock.json')
end

--- @return {plugins:table<string, {rev:string, src:string, version?:string}>}
local function get_lock_tbl()
  return vim.json.decode(fn.readblob(get_lock_path()))
end

-- Tests ======================================================================

describe('vim.pack', function()
  setup(function()
    n.clear()
    for _, r_setup in pairs(repos_setup) do
      r_setup()
    end
  end)

  before_each(function()
    n.clear()
  end)

  after_each(function()
    vim.fs.rm(pack_get_dir(), { force = true, recursive = true })
    vim.fs.rm(get_lock_path(), { force = true })
    local log_path = vim.fs.joinpath(fn.stdpath('log'), 'nvim-pack.log')
    pcall(vim.fs.rm, log_path, { force = true })
  end)

  teardown(function()
    vim.fs.rm(repos_dir, { force = true, recursive = true })
  end)

  describe('add()', function()
    it('installs only once', function()
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)
      n.clear()

      watch_events({ 'PackChanged' })
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)
      eq(exec_lua('return #_G.event_log'), 0)
    end)

    it('passes `data` field through to `opts.load`', function()
      local out = exec_lua(function()
        local map = {} ---@type table<string,boolean>
        local function load(p)
          local name = p.spec.name ---@type string
          map[name] = name == 'basic' and (p.spec.data.test == 'value') or (p.spec.data == 'value')
        end
        vim.pack.add({
          { src = repos_src.basic, data = { test = 'value' } },
          { src = repos_src.defbranch, data = 'value' },
        }, { load = load })
        return map
      end)
      eq({ basic = true, defbranch = true }, out)
    end)

    it('asks for installation confirmation', function()
      -- Do not confirm installation to see what happens (should not error)
      mock_confirm(2)

      exec_lua(function()
        vim.pack.add({ repos_src.basic, { src = repos_src.defbranch, name = 'other-name' } })
      end)
      eq(false, pack_exists('basic'))
      eq(false, pack_exists('defbranch'))
      eq({ plugins = {} }, get_lock_tbl())

      local confirm_msg_lines = ([[
        These plugins will be installed:

        basic      from %s
        other-name from %s]]):format(repos_src.basic, repos_src.defbranch)
      local confirm_msg = vim.trim(vim.text.indent(0, confirm_msg_lines))
      local ref_log = { { confirm_msg .. '\n', 'Proceed? &Yes\n&No\n&Always', 1, 'Question' } }
      eq(ref_log, exec_lua('return _G.confirm_log'))

      -- Should remove lock data if not confirmed during lockfile sync
      n.clear()
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)
      eq(true, pack_exists('basic'))
      eq('table', type(get_lock_tbl().plugins.basic))

      vim.fs.rm(pack_get_dir(), { force = true, recursive = true })
      n.clear()
      mock_confirm(2)

      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)
      eq(false, pack_exists('basic'))
      eq({ plugins = {} }, get_lock_tbl())

      -- Should ask for confirm twice: during lockfile sync and inside
      -- `vim.pack.add()` (i.e. not confirming during lockfile sync has
      -- an immediate effect on whether a plugin is installed or not)
      eq(2, exec_lua('return #_G.confirm_log'))
    end)

    it('respects `opts.confirm`', function()
      mock_confirm(1)
      exec_lua(function()
        vim.pack.add({ repos_src.basic }, { confirm = false })
      end)

      eq(0, exec_lua('return #_G.confirm_log'))
      eq(true, pack_exists('basic'))

      -- Should also respect `confirm` when installing during lockfile sync
      vim.fs.rm(pack_get_dir(), { force = true, recursive = true })
      eq('table', type(get_lock_tbl().plugins.basic))

      n.clear()
      mock_confirm(1)

      exec_lua(function()
        vim.pack.add({}, { confirm = false })
      end)
      eq(0, exec_lua('return #_G.confirm_log'))
      eq(true, pack_exists('basic'))
    end)

    it('can always confirm in current session', function()
      mock_confirm(3)

      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)
      eq(1, exec_lua('return #_G.confirm_log'))
      eq('basic main', exec_lua('return require("basic")'))

      exec_lua(function()
        vim.pack.add({ repos_src.defbranch })
      end)
      eq(1, exec_lua('return #_G.confirm_log'))
      eq('defbranch dev', exec_lua('return require("defbranch")'))

      -- Should still ask in next session
      n.clear()
      mock_confirm(3)
      exec_lua(function()
        vim.pack.add({ repos_src.plugindirs })
      end)
      eq(1, exec_lua('return #_G.confirm_log'))
      eq('plugindirs main', exec_lua('return require("plugindirs")'))
    end)

    it('creates lockfile', function()
      local helptags_rev = git_get_hash('HEAD', 'helptags')
      exec_lua(function()
        vim.pack.add({
          { src = repos_src.basic, version = 'some-tag' },
          { src = repos_src.defbranch, version = 'main' },
          { src = repos_src.helptags, version = helptags_rev },
          { src = repos_src.plugindirs },
          { src = repos_src.semver, version = vim.version.range('*') },
        })
      end)

      local basic_rev = git_get_hash('some-tag', 'basic')
      local defbranch_rev = git_get_hash('main', 'defbranch')
      local plugindirs_rev = git_get_hash('HEAD', 'plugindirs')
      local semver_rev = git_get_hash('v1.0.0', 'semver')

      -- Should properly format as indented JSON. Notes:
      -- - Branch, tag, and commit should be serialized like `'value'` to be
      --   distinguishable from version ranges.
      -- - Absent `version` should be missing and not autoresolved.
      local ref_lockfile_lines = ([[
        {
          "plugins": {
            "basic": {
              "rev": "%s",
              "src": "%s",
              "version": "'some-tag'"
            },
            "defbranch": {
              "rev": "%s",
              "src": "%s",
              "version": "'main'"
            },
            "helptags": {
              "rev": "%s",
              "src": "%s",
              "version": "'%s'"
            },
            "plugindirs": {
              "rev": "%s",
              "src": "%s"
            },
            "semver": {
              "rev": "%s",
              "src": "%s",
              "version": ">=0.0.0"
            }
          }
        }]]):format(
        basic_rev,
        repos_src.basic,
        defbranch_rev,
        repos_src.defbranch,
        helptags_rev,
        repos_src.helptags,
        helptags_rev,
        plugindirs_rev,
        repos_src.plugindirs,
        semver_rev,
        repos_src.semver
      )
      eq(vim.text.indent(0, ref_lockfile_lines), fn.readblob(get_lock_path()))
    end)

    it('updates lockfile', function()
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)
      local ref_lockfile = {
        plugins = {
          basic = { rev = git_get_hash('main', 'basic'), src = repos_src.basic },
        },
      }
      eq(ref_lockfile, get_lock_tbl())

      n.clear()
      exec_lua(function()
        vim.pack.add({ { src = repos_src.basic, version = 'main' } })
      end)

      ref_lockfile.plugins.basic.version = "'main'"
      eq(ref_lockfile, get_lock_tbl())
    end)

    it('uses lockfile during install', function()
      exec_lua(function()
        vim.pack.add({
          { src = repos_src.basic, version = 'feat-branch' },
          repos_src.defbranch,
        })
      end)

      -- Mock clean initial install, but with lockfile present
      vim.fs.rm(pack_get_dir(), { force = true, recursive = true })
      n.clear()

      local basic_rev = git_get_hash('feat-branch', 'basic')
      local defbranch_rev = git_get_hash('HEAD', 'defbranch')
      local ref_lockfile = {
        plugins = {
          basic = { rev = basic_rev, src = repos_src.basic, version = "'feat-branch'" },
          defbranch = { rev = defbranch_rev, src = repos_src.defbranch },
        },
      }
      eq(ref_lockfile, get_lock_tbl())

      mock_confirm(1)
      exec_lua(function()
        -- Should use revision from lockfile (pointing at latest 'feat-branch'
        -- commit) and not use latest `main` commit
        vim.pack.add({ { src = repos_src.basic, version = 'main' } })
      end)
      local basic_lua_file = vim.fs.joinpath(pack_get_plug_path('basic'), 'lua', 'basic.lua')
      eq('return "basic feat-branch"', fn.readblob(basic_lua_file))

      local confirm_log = exec_lua('return _G.confirm_log')
      eq(1, #confirm_log)
      matches('basic.*defbranch', confirm_log[1][1])

      -- Should install `defbranch` (as it is in lockfile), but not load it
      eq(true, pack_exists('defbranch'))
      eq(false, exec_lua('return pcall(require, "defbranch")'))

      -- Running `update()` should still update to use `main`
      exec_lua(function()
        vim.pack.update({ 'basic' }, { force = true })
      end)
      eq('return "basic main"', fn.readblob(basic_lua_file))

      ref_lockfile.plugins.basic.rev = git_get_hash('main', 'basic')
      ref_lockfile.plugins.basic.version = "'main'"
      eq(ref_lockfile, get_lock_tbl())
    end)

    it('handles lockfile during install errors', function()
      local repo_not_exist = 'file://' .. repo_get_path('does-not-exist')
      pcall_err(exec_lua, function()
        vim.pack.add({
          repo_not_exist,
          { src = repos_src.basic, version = 'not-exist' },
          { src = repos_src.pluginerr, version = 'main' },
        })
      end)

      local pluginerr_hash = git_get_hash('main', 'pluginerr')
      local ref_lockfile = {
        -- Should be no entry for `repo_not_exist` and `basic` as they did not
        -- fully install
        plugins = {
          -- Error during sourcing 'plugin/' should not affect lockfile
          pluginerr = { rev = pluginerr_hash, src = repos_src.pluginerr, version = "'main'" },
        },
      }
      eq(ref_lockfile, get_lock_tbl())
    end)

    it('regenerates manually deleted lockfile', function()
      exec_lua(function()
        vim.pack.add({
          { src = repos_src.basic, name = 'other', version = 'feat-branch' },
          repos_src.defbranch,
        })
      end)
      local lock_path = get_lock_path()
      eq(true, vim.uv.fs_stat(lock_path) ~= nil)

      local basic_rev = git_get_hash('feat-branch', 'basic')
      local plugindirs_rev = git_get_hash('dev', 'defbranch')

      -- Should try its best to regenerate lockfile based on installed plugins
      fn.delete(get_lock_path())
      n.clear()
      exec_lua(function()
        vim.pack.add({})
      end)
      local ref_lockfile = {
        plugins = {
          -- No `version = 'feat-branch'` as there is no way to get that info
          -- (lockfile was the only source of that on disk)
          other = { rev = basic_rev, src = repos_src.basic },
          defbranch = { rev = plugindirs_rev, src = repos_src.defbranch },
        },
      }
      eq(ref_lockfile, get_lock_tbl())

      local ref_messages = 'vim.pack: Repaired corrupted lock data for plugins: defbranch, other'
      eq(ref_messages, n.exec_capture('messages'))

      -- Calling `add()` with `version` should still add it to lockfile
      exec_lua(function()
        vim.pack.add({ { src = repos_src.basic, name = 'other', version = 'feat-branch' } })
      end)
      eq("'feat-branch'", get_lock_tbl().plugins.other.version)
    end)

    it('repairs corrupted lock data for installed plugins', function()
      exec_lua(function()
        vim.pack.add({
          -- Should preserve present `version`
          { src = repos_src.basic, version = 'feat-branch' },
          repos_src.defbranch,
          repos_src.semver,
          repos_src.helptags,
        })
      end)

      local lock_tbl = get_lock_tbl()
      local ref_lock_tbl = vim.deepcopy(lock_tbl)
      local assert = function()
        exec_lua('vim.pack.add({})')
        eq(ref_lock_tbl, get_lock_tbl())
        eq(true, pack_exists('basic'))
        eq(true, pack_exists('defbranch'))
        eq(true, pack_exists('semver'))
        eq(true, pack_exists('helptags'))
      end

      -- Missing lock data required field
      lock_tbl.plugins.basic.rev = nil
      -- Wrong lock data field type
      lock_tbl.plugins.defbranch.src = 1 ---@diagnostic disable-line: assign-type-mismatch
      -- Wrong lock data type
      lock_tbl.plugins.semver = 1 ---@diagnostic disable-line: assign-type-mismatch

      local lockfile_text = vim.json.encode(lock_tbl, { indent = '  ', sort_keys = true })
      fn.writefile(vim.split(lockfile_text, '\n'), get_lock_path())

      n.clear()
      assert()

      local ref_messages =
        'vim.pack: Repaired corrupted lock data for plugins: basic, defbranch, semver'
      eq(ref_messages, n.exec_capture('messages'))

      -- Should work even for badly corrupted lockfile
      lockfile_text = vim.json.encode({ plugins = 1 }, { indent = '  ', sort_keys = true })
      fn.writefile(vim.split(lockfile_text, '\n'), get_lock_path())

      n.clear()
      -- Can not preserve `version` if it was deleted from the lockfile
      ref_lock_tbl.plugins.basic.version = nil
      assert()
    end)

    it('removes unrepairable corrupted data and plugins', function()
      exec_lua(function()
        vim.pack.add({ repos_src.basic, repos_src.defbranch, repos_src.semver, repos_src.helptags })
      end)

      local lock_tbl = get_lock_tbl()
      local ref_lock_tbl = vim.deepcopy(lock_tbl)

      -- Corrupted data for missing plugin
      vim.fs.rm(pack_get_plug_path('basic'), { recursive = true, force = true })
      lock_tbl.plugins.basic.rev = nil

      -- Good data for corrupted plugin
      local defbranch_path = pack_get_plug_path('defbranch')
      vim.fs.rm(defbranch_path, { recursive = true, force = true })
      fn.writefile({ 'File and not directory' }, defbranch_path)

      -- Corrupted data for corrupted plugin
      local semver_path = pack_get_plug_path('semver')
      vim.fs.rm(semver_path, { recursive = true, force = true })
      fn.writefile({ 'File and not directory' }, semver_path)
      lock_tbl.plugins.semver.rev = 1 ---@diagnostic disable-line: assign-type-mismatch

      local lockfile_text = vim.json.encode(lock_tbl, { indent = '  ', sort_keys = true })
      fn.writefile(vim.split(lockfile_text, '\n'), get_lock_path())

      n.clear()
      exec_lua('vim.pack.add({})')
      ref_lock_tbl.plugins.basic = nil
      ref_lock_tbl.plugins.defbranch = nil
      ref_lock_tbl.plugins.semver = nil
      eq(ref_lock_tbl, get_lock_tbl())

      eq(false, pack_exists('basic'))
      eq(false, pack_exists('defbranch'))
      eq(false, pack_exists('semver'))
      eq(true, pack_exists('helptags'))
    end)

    it('installs at proper version', function()
      local out = exec_lua(function()
        vim.pack.add({
          { src = repos_src.basic, version = 'feat-branch' },
        })
        -- Should have plugin available immediately after
        return require('basic')
      end)

      eq('basic feat-branch', out)

      local rtp = vim.tbl_map(t.fix_slashes, api.nvim_list_runtime_paths())
      local plug_path = pack_get_plug_path('basic')
      local after_dir = vim.fs.joinpath(plug_path, 'after')
      eq(true, vim.tbl_contains(rtp, plug_path))
      -- No 'after/' directory in runtimepath because it is not present in plugin
      eq(false, vim.tbl_contains(rtp, after_dir))
    end)

    it('does not install on bad `version`', function()
      local err = pcall_err(exec_lua, function()
        vim.pack.add({ { src = repos_src.basic, version = 'not-exist' } })
      end)
      matches('`not%-exist` is not a branch/tag/commit', err)
      eq(false, pack_exists('basic'))
    end)

    it('can install from the Internet', function()
      t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')
      exec_lua(function()
        vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig' })
      end)
      eq(true, exec_lua('return pcall(require, "lspconfig")'))
    end)

    describe('startup', function()
      local config_dir, pack_add_cmd = '', ''

      before_each(function()
        config_dir = fn.stdpath('config')
        fn.mkdir(vim.fs.joinpath(config_dir, 'plugin'), 'p')

        pack_add_cmd = ('vim.pack.add({ %s })'):format(vim.inspect(repos_src.plugindirs))
      end)

      after_each(function()
        vim.fs.rm(config_dir, { recursive = true, force = true })
      end)

      local function assert_loaded()
        eq('plugindirs main', exec_lua('return require("plugindirs")'))

        -- Should source 'plugin/' and 'after/plugin/' exactly once
        eq({ true, true }, n.exec_lua('return { vim.g._plugin, vim.g._after_plugin }'))
        eq({ 'p', 'a' }, n.exec_lua('return _G.DL'))
      end

      local function assert_works()
        -- Should auto-install but wait before executing code after it
        n.clear({ args_rm = { '-u' } })
        n.exec_lua('vim.wait(500, function() return _G.done end, 50)')
        assert_loaded()

        -- Should only `:packadd!`/`:packadd` already installed plugin
        n.clear({ args_rm = { '-u' } })
        assert_loaded()
      end

      it('works in init.lua', function()
        local init_lua = vim.fs.joinpath(config_dir, 'init.lua')
        fn.writefile({ pack_add_cmd, '_G.done = true' }, init_lua)
        assert_works()

        -- Should not load plugins if `--noplugin`, only adjust 'runtimepath'
        n.clear({ args = { '--noplugin' }, args_rm = { '-u' } })
        eq('plugindirs main', exec_lua('return require("plugindirs")'))
        eq({}, n.exec_lua('return { vim.g._plugin, vim.g._after_plugin }'))
        eq(vim.NIL, n.exec_lua('return _G.DL'))
      end)

      it('works in plugin/', function()
        local plugin_file = vim.fs.joinpath(config_dir, 'plugin', 'mine.lua')
        fn.writefile({ pack_add_cmd, '_G.done = true' }, plugin_file)
        -- Should source plugin's 'plugin/' files without explicit `load=true`
        assert_works()
      end)
    end)

    it('shows progress report during installation', function()
      track_nvim_echo()
      exec_lua(function()
        vim.pack.add({ repos_src.basic, repos_src.defbranch })
      end)
      assert_progress_report('Installing plugins', { 'basic', 'defbranch' })
    end)

    it('triggers relevant events', function()
      watch_events({ 'PackChangedPre', 'PackChanged' })

      exec_lua(function()
        -- Should provide event-data respecting manual `version` without inferring default
        vim.pack.add({ { src = repos_src.basic, version = 'feat-branch' }, repos_src.defbranch })
      end)

      local log = exec_lua('return _G.event_log')
      local find_event = make_find_packchanged(log)
      local installpre_basic = find_event('Pre', 'install', 'basic', 'feat-branch', false)
      local installpre_defbranch = find_event('Pre', 'install', 'defbranch', nil, false)
      local install_basic = find_event('', 'install', 'basic', 'feat-branch', false)
      local install_defbranch = find_event('', 'install', 'defbranch', nil, false)
      eq(4, #log)

      -- NOTE: There is no guaranteed installation order among separate plugins (as it is async)
      eq(true, installpre_basic < install_basic)
      eq(true, installpre_defbranch < install_defbranch)
    end)

    it('recognizes several `version` types', function()
      local prev_commit = git_get_hash('HEAD~', 'defbranch')
      exec_lua(function()
        vim.pack.add({
          { src = repos_src.basic, version = 'some-tag' }, -- Tag
          { src = repos_src.defbranch, version = prev_commit }, -- Commit hash
          { src = repos_src.semver, version = vim.version.range('<1') }, -- Semver constraint
        })
      end)

      eq('basic some-tag', exec_lua('return require("basic")'))
      eq('defbranch main', exec_lua('return require("defbranch")'))
      eq('semver v0.4', exec_lua('return require("semver")'))
    end)

    it('respects plugin/ and after/plugin/ scripts', function()
      local function assert(load, ref)
        local opts = { load = load }
        local out = exec_lua(function()
          -- Should handle bad plugin directory name
          vim.pack.add({ { src = repos_src.plugindirs, name = 'plugin % dirs' } }, opts)
          return {
            vim.g._plugin,
            vim.g._plugin_vim,
            vim.g._plugin_sub,
            vim.g._plugin_bad,
            vim.g._after_plugin,
            vim.g._after_plugin_vim,
            vim.g._after_plugin_sub,
            vim.g._after_plugin_bad,
          }
        end)

        eq(ref, out)

        -- Should add necessary directories to runtimepath regardless of `opts.load`
        local rtp = vim.tbl_map(t.fix_slashes, api.nvim_list_runtime_paths())
        local plug_path = pack_get_plug_path('plugin % dirs')
        local after_dir = vim.fs.joinpath(plug_path, 'after')
        eq(true, vim.tbl_contains(rtp, plug_path))
        eq(true, vim.tbl_contains(rtp, after_dir))
      end

      assert(nil, { true, true, true, true, true, true, true, true })

      n.clear()
      assert(false, {})
    end)

    it('can use function `opts.load`', function()
      local function assert()
        n.exec_lua(function()
          _G.load_log = {}
          local function load(...)
            table.insert(_G.load_log, { ... })
          end
          vim.pack.add({ repos_src.plugindirs, repos_src.basic }, { load = load })
        end)

        -- Order of execution should be the same as supplied in `add()`
        local plugindirs_data = {
          spec = { src = repos_src.plugindirs, name = 'plugindirs' },
          path = pack_get_plug_path('plugindirs'),
        }
        local basic_data = {
          spec = { src = repos_src.basic, name = 'basic' },
          path = pack_get_plug_path('basic'),
        }
        -- - Only single table argument should be supplied to `load`
        local ref_log = { { plugindirs_data }, { basic_data } }
        eq(ref_log, n.exec_lua('return _G.load_log'))

        -- Should not add plugin to the session in any way
        eq(false, exec_lua('return pcall(require, "plugindirs")'))
        eq(false, exec_lua('return pcall(require, "basic")'))

        -- Should not source 'plugin/'
        eq({}, n.exec_lua('return { vim.g._plugin, vim.g._after_plugin }'))

        -- Plugins should still be marked as "active", since they were added
        eq(true, exec_lua('return vim.pack.get({ "plugindirs" })[1].active'))
        eq(true, exec_lua('return vim.pack.get({ "basic" })[1].active'))
      end

      -- Works on initial install
      assert()

      -- Works when loading already installed plugin
      n.clear()
      assert()
    end)

    it('generates help tags', function()
      exec_lua(function()
        vim.pack.add({ { src = repos_src.helptags, name = 'help tags' } })
      end)
      local target_tags = fn.getcompletion('my-test', 'help')
      table.sort(target_tags)
      eq({ 'my-test-help', 'my-test-help-bad', 'my-test-help-sub-bad' }, target_tags)
    end)

    it('reports install/load errors after loading all input', function()
      t.skip(not is_jit(), "Non LuaJIT reports errors differently due to 'coxpcall'")
      local function assert(err_pat)
        local err = pcall_err(exec_lua, function()
          vim.pack.add({
            { src = repos_src.basic, version = 'wrong-version' }, -- Error during initial checkout
            { src = repos_src.semver, version = vim.version.range('>=2.0.0') }, -- Missing version
            { src = repos_src.plugindirs, version = 'main' },
            { src = repos_src.pluginerr, version = 'main' }, -- Error during 'plugin/' source
          })
        end)

        matches(err_pat, err)

        -- Should have processed non-errored 'plugin/' and add to 'rtp'
        eq('plugindirs main', exec_lua('return require("plugindirs")'))
        eq(true, exec_lua('return vim.g._plugin'))

        -- Should add plugin to 'rtp' even if 'plugin/' has error
        eq('pluginerr main', exec_lua('return require("pluginerr")'))
      end

      -- During initial install
      local err_pat_parts = {
        'vim%.pack',
        '`basic`:\n',
        -- Should report available branches and tags if revision is absent
        '`wrong%-version`',
        -- Should list default branch first
        'Available:\nTags: some%-tag\nBranches: main, feat%-branch',
        -- Should report available branches and versions if no constraint match
        '`semver`',
        'Available:\nVersions: v1%.0%.0, v0%.4, 0%.3%.1, v0%.3%.0.*\nBranches: main\n',
        '`pluginerr`:\n',
        'Wow, an error',
      }
      assert(table.concat(err_pat_parts, '.*'))

      -- During loading already installed plugin.
      n.clear()
      -- NOTE: There is no error for wrong `version`, because there is no check
      -- for already installed plugins. Might change in the future.
      assert('vim%.pack.*`pluginerr`:\n.*Wow, an error')
    end)

    it('normalizes each spec', function()
      exec_lua(function()
        vim.pack.add({
          repos_src.basic, -- String should be inferred as `{ src = ... }`
          { src = repos_src.defbranch }, -- Default `version` is remote's default branch
          { src = repos_src['gitsuffix.git'] }, -- Default `name` comes from `src` repo name
          { src = repos_src.plugindirs, name = 'plugin/dirs' }, -- Ensure proper directory name
        })
      end)

      eq('basic main', exec_lua('return require("basic")'))
      eq('defbranch dev', exec_lua('return require("defbranch")'))
      eq('gitsuffix main', exec_lua('return require("gitsuffix")'))
      eq(true, exec_lua('return vim.g._plugin'))

      eq(true, pack_exists('gitsuffix'))
      eq(true, pack_exists('dirs'))
    end)

    it('handles problematic names', function()
      exec_lua(function()
        vim.pack.add({ { src = repos_src.basic, name = 'bad % name' } })
      end)
      eq('basic main', exec_lua('return require("basic")'))
    end)

    it('is not affected by special environment variables', function()
      fn.setenv('GIT_WORK_TREE', fn.getcwd())
      fn.setenv('GIT_DIR', vim.fs.joinpath(fn.getcwd(), '.git'))
      local ref_environ = fn.environ()

      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)
      eq('basic main', exec_lua('return require("basic")'))

      eq(ref_environ, fn.environ())
    end)

    it('validates input', function()
      local function assert(err_pat, input)
        local function add_input()
          vim.pack.add(input)
        end
        matches(err_pat, pcall_err(exec_lua, add_input))
      end

      -- Separate spec entries
      assert('list', repos_src.basic)
      assert('spec:.*table', { 1 })
      assert('spec%.src:.*string', { { src = 1 } })
      assert('spec%.src:.*non%-empty string', { { src = '' } })
      assert('spec%.name:.*string', { { src = repos_src.basic, name = 1 } })
      assert('spec%.name:.*non%-empty string', { { src = repos_src.basic, name = '' } })
      assert(
        'spec%.version:.*string or vim%.VersionRange',
        { { src = repos_src.basic, version = 1 } }
      )

      -- Conflicts in input array
      local version_conflict = {
        { src = repos_src.basic, version = 'feat-branch' },
        { src = repos_src.basic, version = 'main' },
      }
      assert('Conflicting `version` for `basic`.*feat%-branch.*main', version_conflict)

      local src_conflict = {
        { src = repos_src.basic, name = 'my-plugin' },
        { src = repos_src.semver, name = 'my-plugin' },
      }
      assert('Conflicting `src` for `my%-plugin`.*basic.*semver', src_conflict)
    end)
  end)

  describe('update()', function()
    -- Lua source code for the tested plugin named "fetch"
    local fetch_lua_file
    -- Tables with hashes used to test confirmation buffer and log content
    local hashes --- @type table<string,string>
    local short_hashes --- @type table<string,string>

    before_each(function()
      -- Create a dedicated clean repo for which "push changes" will be mocked
      init_test_repo('fetch')

      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch init"')
      git_add_commit('Initial commit for "fetch"', 'fetch')

      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch main"')
      git_add_commit('Commit from `main` to be removed', 'fetch')

      fetch_lua_file = vim.fs.joinpath(pack_get_plug_path('fetch'), 'lua', 'fetch.lua')
      hashes = { fetch_head = git_get_hash('HEAD', 'fetch') }
      short_hashes = { fetch_head = git_get_short_hash('HEAD', 'fetch') }

      -- Install initial versions of tested plugins
      exec_lua(function()
        vim.pack.add({
          { src = repos_src.fetch, version = 'main' },
          { src = repos_src.semver, version = 'v0.3.0' },
          repos_src.defbranch,
        })
      end)
      n.clear()

      -- Mock remote repo update
      -- - Force push
      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch new"')
      git_cmd({ 'add', '*' }, 'fetch')
      git_cmd({ 'commit', '--amend', '-m', 'Commit to be added 1' }, 'fetch')

      -- - Presence of a tag (should be shown in changelog)
      git_cmd({ 'tag', 'dev-tag' }, 'fetch')

      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch new 2"')
      git_add_commit('Commit to be added 2', 'fetch')

      -- Make `dev` default remote branch to check that `version` is respected
      git_cmd({ 'checkout', '-b', 'dev' }, 'fetch')
      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch dev"')
      git_add_commit('Commit from default `dev` branch', 'fetch')
    end)

    after_each(function()
      pcall(vim.fs.rm, repo_get_path('fetch'), { force = true, recursive = true })
      local log_path = vim.fs.joinpath(fn.stdpath('log'), 'nvim-pack.log')
      pcall(vim.fs.rm, log_path, { force = true })
    end)

    describe('confirmation buffer', function()
      it('works', function()
        exec_lua(function()
          vim.pack.add({
            repos_src.fetch,
            { src = repos_src.semver, version = 'v0.3.0' },
            { src = repos_src.defbranch, version = 'does-not-exist' },
          })
        end)
        eq('return "fetch main"', fn.readblob(fetch_lua_file))

        exec_lua(function()
          -- Enable highlighting of special filetype
          vim.cmd('filetype plugin on')
          vim.pack.update()
        end)

        -- Buffer should be special and shown in a separate tabpage
        eq(2, #api.nvim_list_tabpages())
        eq(2, fn.tabpagenr())
        eq(api.nvim_get_option_value('filetype', {}), 'nvim-pack')
        eq(api.nvim_get_option_value('modifiable', {}), false)
        eq(api.nvim_get_option_value('buftype', {}), 'acwrite')
        local confirm_bufnr = api.nvim_get_current_buf()
        local confirm_winnr = api.nvim_get_current_win()
        local confirm_tabpage = api.nvim_get_current_tabpage()
        eq(api.nvim_buf_get_name(0), 'nvim-pack://confirm#' .. confirm_bufnr)

        -- Adjust lines for a more robust screenshot testing
        local fetch_src = repos_src.fetch
        local fetch_path = pack_get_plug_path('fetch')
        local semver_src = repos_src.semver
        local semver_path = pack_get_plug_path('semver')
        local pack_runtime = '/lua/vim/pack.lua'

        exec_lua(function()
          -- Replace matches in line to preserve extmark highlighting
          local function replace_in_line(i, pattern, repl)
            local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
            local from, to = line:find(pattern)
            while from and to do
              vim.api.nvim_buf_set_text(0, i - 1, from - 1, i - 1, to, { repl })
              line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
              from, to = line:find(pattern)
            end
          end

          vim.bo.modifiable = true
          local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          -- NOTE: replace path to `vim.pack` in error traceback accounting for
          -- pcall source truncation and possibly different slashes on Windows
          local pack_runtime_pattern = ('%%S.+%s:%%d+'):format(
            vim.pesc(pack_runtime):gsub('/', '[\\/]')
          )
          for i = 1, #lines do
            replace_in_line(i, pack_runtime_pattern, 'VIM_PACK_RUNTIME')
            replace_in_line(i, vim.pesc(fetch_path), 'FETCH_PATH')
            replace_in_line(i, vim.pesc(fetch_src), 'FETCH_SRC')
            replace_in_line(i, vim.pesc(semver_path), 'SEMVER_PATH')
            replace_in_line(i, vim.pesc(semver_src), 'SEMVER_SRC')
          end
          vim.bo.modified = false
          vim.bo.modifiable = false
        end)

        -- Use screenshot to test highlighting, otherwise prefer text matching.
        -- This requires computing target hashes on each test run because they
        -- change due to source repos being cleanly created on each file test.
        local screen
        screen = Screen.new(85, 35)

        hashes.fetch_new = git_get_hash('main', 'fetch')
        short_hashes.fetch_new = git_get_short_hash('main', 'fetch')
        short_hashes.fetch_new_prev = git_get_short_hash('main~', 'fetch')
        hashes.semver_head = git_get_hash('v0.3.0', 'semver')

        local tab_name = 'n' .. (t.is_os('win') and ':' or '') .. '//confirm#2'

        local screen_lines = {
          ('{24: [No Name] }{5: %s }{2:%s                                                          }{24:X}|'):format(
            tab_name,
            t.is_os('win') and '' or ' '
          ),
          '{19:^# Error ────────────────────────────────────────────────────────────────────────}     |',
          '                                                                                     |',
          '{19:## defbranch}                                                                         |',
          '                                                                                     |',
          ' VIM_PACK_RUNTIME: `does-not-exist` is not a branch/tag/commit. Available:           |',
          '  Tags:                                                                              |',
          '  Branches: dev, main                                                                |',
          '                                                                                     |',
          '{101:# Update ───────────────────────────────────────────────────────────────────────}     |',
          '                                                                                     |',
          '{101:## fetch}                                                                             |',
          'Path:            {103:FETCH_PATH}                                                          |',
          'Source:          {103:FETCH_SRC}                                                           |',
          ('Revision before: {103:%s}                            |'):format(hashes.fetch_head),
          ('Revision after:  {103:%s} {102:(main)}                     |'):format(hashes.fetch_new),
          '                                                                                     |',
          'Pending updates:                                                                     |',
          ('{19:< %s │ Commit from `main` to be removed}                                         |'):format(
            short_hashes.fetch_head
          ),
          ('{104:> %s │ Commit to be added 2}                                                     |'):format(
            short_hashes.fetch_new
          ),
          ('{104:> %s │ Commit to be added 1 (tag: dev-tag)}                                      |'):format(
            short_hashes.fetch_new_prev
          ),
          '                                                                                     |',
          '{102:# Same ─────────────────────────────────────────────────────────────────────────}     |',
          '                                                                                     |',
          '{102:## semver}                                                                            |',
          'Path:     {103:SEMVER_PATH}                                                                |',
          'Source:   {103:SEMVER_SRC}                                                                 |',
          ('Revision: {103:%s} {102:(v0.3.0)}                          |'):format(
            hashes.semver_head
          ),
          '                                                                                     |',
          'Available newer versions:                                                            |',
          '• {102:v1.0.0}                                                                             |',
          '• {102:v0.4}                                                                               |',
          '• {102:0.3.1}                                                                              |',
          '{1:~                                                                                    }|',
          '                                                                                     |',
        }

        screen:add_extra_attr_ids({
          [101] = { foreground = Screen.colors.Orange },
          [102] = { foreground = Screen.colors.LightGray },
          [103] = { foreground = Screen.colors.LightBlue },
          [104] = { foreground = Screen.colors.SeaGreen },
        })
        -- NOTE: Non LuaJIT reports errors differently due to 'coxpcall'
        if is_jit() then
          screen:expect(table.concat(screen_lines, '\n'))
        end

        -- `:write` should confirm
        n.exec('write')

        -- - Apply changes immediately
        eq('return "fetch new 2"', fn.readblob(fetch_lua_file))

        -- - Clean up buffer+window+tabpage
        eq(false, api.nvim_buf_is_valid(confirm_bufnr))
        eq(false, api.nvim_win_is_valid(confirm_winnr))
        eq(false, api.nvim_tabpage_is_valid(confirm_tabpage))

        -- - Write to log file
        local log_path = vim.fs.joinpath(fn.stdpath('log'), 'nvim-pack.log')
        local log_text = fn.readblob(log_path)
        local log_1, log_rest = log_text:match('^(.-)\n(.*)$') --- @type string, string
        matches('========== Update %d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d ==========', log_1)
        local ref_log_lines = ([[
          # Update ───────────────────────────────────────────────────────────────────────

          ## fetch
          Path:            %s
          Source:          %s
          Revision before: %s
          Revision after:  %s (main)

          Pending updates:
          < %s │ Commit from `main` to be removed
          > %s │ Commit to be added 2
          > %s │ Commit to be added 1 (tag: dev-tag)]]):format(
          fetch_path,
          fetch_src,
          hashes.fetch_head,
          hashes.fetch_new,
          short_hashes.fetch_head,
          short_hashes.fetch_new,
          short_hashes.fetch_new_prev
        )
        eq(vim.text.indent(0, ref_log_lines), vim.trim(log_rest))
      end)

      it('can be dismissed with `:quit`', function()
        exec_lua(function()
          vim.pack.add({ repos_src.fetch })
          vim.pack.update({ 'fetch' })
        end)
        eq('nvim-pack', api.nvim_get_option_value('filetype', {}))

        -- Should not apply updates
        n.exec('quit')
        eq('return "fetch main"', fn.readblob(fetch_lua_file))
      end)

      it('closes full tabpage', function()
        exec_lua(function()
          vim.pack.add({ repos_src.fetch })
          vim.pack.update()
        end)

        -- Confirm with `:write`
        local confirm_tabpage = api.nvim_get_current_tabpage()
        n.exec('-tab split other-tab')
        local other_tabpage = api.nvim_get_current_tabpage()
        n.exec('tabnext')
        n.exec('write')
        eq(true, api.nvim_tabpage_is_valid(other_tabpage))
        eq(false, api.nvim_tabpage_is_valid(confirm_tabpage))

        -- Not confirm with `:quit`
        n.exec('tab split other-tab-2')
        local other_tabpage_2 = api.nvim_get_current_tabpage()
        exec_lua(function()
          vim.pack.update()
        end)
        confirm_tabpage = api.nvim_get_current_tabpage()

        -- - Temporary split window in tabpage should not matter
        n.exec('vsplit other-buf')
        n.exec('wincmd w')

        n.exec('tabclose ' .. api.nvim_tabpage_get_number(other_tabpage_2))
        eq(confirm_tabpage, api.nvim_get_current_tabpage())
        n.exec('quit')
        eq(false, api.nvim_tabpage_is_valid(confirm_tabpage))
      end)

      it('has in-process LSP features', function()
        t.skip(not is_jit(), "Non LuaJIT reports errors differently due to 'coxpcall'")
        track_nvim_echo()
        exec_lua(function()
          vim.pack.add({
            repos_src.fetch,
            { src = repos_src.semver, version = 'v0.3.0' },
            { src = repos_src.defbranch, version = 'does-not-exist' },
          })
          vim.pack.update()
        end)

        eq(1, exec_lua('return #vim.lsp.get_clients({ bufnr = 0 })'))

        -- textDocument/documentSymbol
        exec_lua('vim.lsp.buf.document_symbol()')
        local loclist = vim.tbl_map(function(x) --- @param x table
          return {
            lnum = x.lnum, --- @type integer
            col = x.col, --- @type integer
            end_lnum = x.end_lnum, --- @type integer
            end_col = x.end_col, --- @type integer
            text = x.text, --- @type string
          }
        end, fn.getloclist(0))
        local ref_loclist = {
          { lnum = 1, col = 1, end_lnum = 9, end_col = 1, text = '[Namespace] Error' },
          { lnum = 3, col = 1, end_lnum = 9, end_col = 1, text = '[Module] defbranch' },
          { lnum = 9, col = 1, end_lnum = 22, end_col = 1, text = '[Namespace] Update' },
          { lnum = 11, col = 1, end_lnum = 22, end_col = 1, text = '[Module] fetch' },
          { lnum = 22, col = 1, end_lnum = 32, end_col = 1, text = '[Namespace] Same' },
          { lnum = 24, col = 1, end_lnum = 32, end_col = 1, text = '[Module] semver' },
        }
        eq(ref_loclist, loclist)

        n.exec('lclose')

        -- textDocument/hover
        local confirm_winnr = api.nvim_get_current_win()
        local function assert_hover(pos, commit_msg)
          api.nvim_win_set_cursor(0, pos)
          exec_lua(function()
            vim.lsp.buf.hover()
            -- Default hover is async shown in floating window
            vim.wait(1000, function()
              return #vim.api.nvim_tabpage_list_wins(0) > 1
            end)
          end)

          local all_wins = api.nvim_tabpage_list_wins(0)
          eq(2, #all_wins)
          local float_winnr = all_wins[1] == confirm_winnr and all_wins[2] or all_wins[1]
          eq(true, api.nvim_win_get_config(float_winnr).relative ~= '')

          local float_buf = api.nvim_win_get_buf(float_winnr)
          local text = table.concat(api.nvim_buf_get_lines(float_buf, 0, -1, false), '\n')

          local ref_pattern = 'Marvim <marvim@neovim%.io>\nDate:.*' .. vim.pesc(commit_msg)
          matches(ref_pattern, text)
        end

        assert_hover({ 14, 0 }, 'Commit from `main` to be removed')
        assert_hover({ 15, 0 }, 'Commit to be added 2')
        assert_hover({ 18, 0 }, 'Commit from `main` to be removed')
        assert_hover({ 19, 0 }, 'Commit to be added 2')
        assert_hover({ 20, 0 }, 'Commit to be added 1')
        assert_hover({ 27, 0 }, 'Add version v0.3.0')
        assert_hover({ 30, 0 }, 'Add version v1.0.0')
        assert_hover({ 31, 0 }, 'Add version v0.4')
        assert_hover({ 32, 0 }, 'Add version 0.3.1')

        -- textDocument/codeAction
        n.exec_lua(function()
          -- Mock `vim.ui.select()` which is a default code action selection
          _G.select_idx = 0

          ---@diagnostic disable-next-line: duplicate-set-field
          vim.ui.select = function(items, _, on_choice)
            _G.select_items = items
            local idx = _G.select_idx
            if idx > 0 then
              on_choice(items[idx], idx)
              -- Minor delay before continue because LSP cmd execution is async
              vim.wait(10)
            end
          end
        end)

        local ref_lockfile = get_lock_tbl() --- @type vim.pack.Lock

        local function assert_action(pos, action_titles, select_idx)
          api.nvim_win_set_cursor(0, pos)

          local lines = api.nvim_buf_get_lines(0, 0, -1, false)
          n.exec_lua(function()
            _G.select_items = nil
            _G.select_idx = select_idx
            vim.lsp.buf.code_action()
          end)
          local titles = vim.tbl_map(function(x) --- @param x table
            return x.action.title
          end, n.exec_lua('return _G.select_items or {}'))
          eq(titles, action_titles)

          -- If no action is asked (like via cancel), should not delete lines
          if select_idx <= 0 then
            eq(lines, api.nvim_buf_get_lines(0, 0, -1, false))
          end
        end

        -- - Should not include "namespace" header as "plugin at cursor"
        assert_action({ 1, 1 }, {}, 0)
        assert_action({ 2, 0 }, {}, 0)
        -- - Only deletion should be available on errored plugin
        assert_action({ 3, 1 }, { 'Delete `defbranch`' }, 0)
        assert_action({ 7, 0 }, { 'Delete `defbranch`' }, 0)
        -- - Should not include separator blank line as "plugin at cursor"
        assert_action({ 8, 0 }, {}, 0)
        assert_action({ 9, 0 }, {}, 0)
        assert_action({ 10, 0 }, {}, 0)
        -- - Should also suggest updating related actions if updates available
        local fetch_actions = { 'Update `fetch`', 'Skip updating `fetch`', 'Delete `fetch`' }
        assert_action({ 11, 0 }, fetch_actions, 0)
        assert_action({ 14, 0 }, fetch_actions, 0)
        assert_action({ 20, 0 }, fetch_actions, 0)
        assert_action({ 21, 0 }, {}, 0)
        assert_action({ 22, 0 }, {}, 0)
        assert_action({ 23, 0 }, {}, 0)
        -- - Only deletion should be available on plugins without update
        assert_action({ 24, 0 }, { 'Delete `semver`' }, 0)
        assert_action({ 28, 0 }, { 'Delete `semver`' }, 0)
        assert_action({ 32, 0 }, { 'Delete `semver`' }, 0)

        -- - Should correctly perform action and remove plugin's lines
        local function line_match(lnum, pattern)
          matches(pattern, api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1])
        end

        -- - Delete. Should remove from disk and update lockfile.
        assert_action({ 3, 0 }, { 'Delete `defbranch`' }, 1)
        eq(false, pack_exists('defbranch'))
        line_match(1, '^# Error')
        line_match(2, '^$')
        line_match(3, '^# Update')

        ref_lockfile.plugins.defbranch = nil
        eq(ref_lockfile, get_lock_tbl())

        -- - Skip udating
        assert_action({ 5, 0 }, fetch_actions, 2)
        eq('return "fetch main"', fn.readblob(fetch_lua_file))
        line_match(3, '^# Update')
        line_match(4, '^$')
        line_match(5, '^# Same')

        -- - Update plugin. Should not re-fetch new data and update lockfile.
        n.exec('quit')
        n.exec_lua(function()
          vim.pack.update({ 'fetch', 'semver' })
        end)
        exec_lua('_G.echo_log = {}')

        ref_lockfile.plugins.fetch.rev = git_get_hash('main', 'fetch')
        repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch new 3"')
        git_add_commit('Commit to be added 3', 'fetch')

        assert_action({ 3, 0 }, fetch_actions, 1)

        eq('return "fetch new 2"', fn.readblob(fetch_lua_file))
        assert_progress_report('Applying updates', { 'fetch' })
        line_match(1, '^# Update')
        line_match(2, '^$')
        line_match(3, '^# Same')

        eq(ref_lockfile, get_lock_tbl())

        -- - Can still respect `:write` after action
        n.exec('write')
        eq('vim.pack: Nothing to update', n.exec_capture('1messages'))
        eq(api.nvim_get_option_value('filetype', {}), '')
      end)

      it('has buffer-local mappings', function()
        t.skip(not is_jit(), "Non LuaJIT reports update errors differently due to 'coxpcall'")
        exec_lua(function()
          vim.pack.add({
            repos_src.fetch,
            { src = repos_src.semver, version = 'v0.3.0' },
            { src = repos_src.defbranch, version = 'does-not-exist' },
          })
          -- Enable sourcing filetype script (that creates mappings)
          vim.cmd('filetype plugin on')
          vim.pack.update()
        end)

        -- Plugin sections navigation
        local function assert(keys, ref_cursor)
          n.feed(keys)
          eq(ref_cursor, api.nvim_win_get_cursor(0))
        end

        api.nvim_win_set_cursor(0, { 1, 1 })
        assert(']]', { 3, 0 })
        assert(']]', { 11, 0 })
        assert(']]', { 24, 0 })
        -- - Should not wrap around the edge
        assert(']]', { 24, 0 })

        api.nvim_win_set_cursor(0, { 32, 1 })
        assert('[[', { 24, 0 })
        assert('[[', { 11, 0 })
        assert('[[', { 3, 0 })
        -- - Should not wrap around the edge
        assert('[[', { 3, 0 })
      end)

      it('suggests newer versions when on non-tagged commit', function()
        local commit = git_get_hash('0.3.1~', 'semver')
        exec_lua(function()
          -- Make fresh install for cleaner test
          vim.pack.del({ 'semver' })
          vim.pack.add({ { src = repos_src.semver, version = commit } })
          vim.pack.update({ 'semver' })
        end)

        -- Should correctly infer that 0.3.0 is the latest version and suggest
        -- versions greater than that
        local confirm_text = table.concat(api.nvim_buf_get_lines(0, 0, -1, false), '\n')
        matches('Available newer versions:\n• v1%.0%.0\n• v0%.4\n• 0%.3%.1$', confirm_text)
      end)

      it('updates lockfile', function()
        exec_lua(function()
          vim.pack.add({ repos_src.fetch })
        end)
        local ref_fetch_lock = { rev = hashes.fetch_head, src = repos_src.fetch }
        eq(ref_fetch_lock, get_lock_tbl().plugins.fetch)

        exec_lua('vim.pack.update()')
        n.exec('write')

        ref_fetch_lock.rev = git_get_hash('main', 'fetch')
        eq(ref_fetch_lock, get_lock_tbl().plugins.fetch)
      end)
    end)

    it('works with not active plugins', function()
      -- No plugins are added, but they are installed in `before_each()`
      exec_lua(function()
        -- By default should also include not active plugins
        vim.pack.update()
      end)
      eq('return "fetch main"', fn.readblob(fetch_lua_file))
      n.exec('write')
      eq('return "fetch new 2"', fn.readblob(fetch_lua_file))
    end)

    it('can force update', function()
      exec_lua(function()
        vim.pack.add({ repos_src.fetch })
        vim.pack.update({ 'fetch' }, { force = true })
      end)

      -- Apply changes immediately
      local fetch_src = repos_src.fetch
      local fetch_path = pack_get_plug_path('fetch')
      eq('return "fetch new 2"', fn.readblob(fetch_lua_file))

      -- No special buffer/window/tabpage
      eq(1, #api.nvim_list_tabpages())
      eq(1, #api.nvim_list_wins())
      eq('', api.nvim_get_option_value('filetype', {}))

      -- Write to log file
      hashes.fetch_new = git_get_hash('main', 'fetch')
      short_hashes.fetch_new = git_get_short_hash('main', 'fetch')
      short_hashes.fetch_new_prev = git_get_short_hash('main~', 'fetch')

      local log_path = vim.fs.joinpath(fn.stdpath('log'), 'nvim-pack.log')
      local log_text = fn.readblob(log_path)
      local log_1, log_rest = log_text:match('^(.-)\n(.*)$') --- @type string, string
      matches('========== Update %d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d ==========', log_1)
      local ref_log_lines = ([[
        # Update ───────────────────────────────────────────────────────────────────────

        ## fetch
        Path:            %s
        Source:          %s
        Revision before: %s
        Revision after:  %s (main)

        Pending updates:
        < %s │ Commit from `main` to be removed
        > %s │ Commit to be added 2
        > %s │ Commit to be added 1 (tag: dev-tag)]]):format(
        fetch_path,
        fetch_src,
        hashes.fetch_head,
        hashes.fetch_new,
        short_hashes.fetch_head,
        short_hashes.fetch_new,
        short_hashes.fetch_new_prev
      )
      eq(vim.text.indent(0, ref_log_lines), vim.trim(log_rest))

      -- Should update lockfile
      eq(hashes.fetch_new, get_lock_tbl().plugins.fetch.rev)
    end)

    it('can use lockfile revision as a target', function()
      exec_lua(function()
        vim.pack.add({ repos_src.fetch })
      end)
      eq('return "fetch main"', fn.readblob(fetch_lua_file))

      -- Mock "update -> revert lockfile -> revert plugin"
      local lock_path = get_lock_path()
      local lockfile_before = fn.readblob(lock_path)
      hashes.fetch_new = git_get_hash('main', 'fetch')

      -- - Update
      exec_lua('vim.pack.update({ "fetch" }, { force = true })')
      eq('return "fetch new 2"', fn.readblob(fetch_lua_file))

      -- - Revert lockfile
      fn.writefile(vim.split(lockfile_before, '\n'), lock_path)
      n.clear()

      -- - Revert plugin
      eq('return "fetch new 2"', fn.readblob(fetch_lua_file))
      exec_lua('vim.pack.update({ "fetch" }, { target = "lockfile" })')
      local confirm_lines = api.nvim_buf_get_lines(0, 0, -1, false)
      n.exec('write')
      eq('return "fetch main"', fn.readblob(fetch_lua_file))
      eq(hashes.fetch_head, get_lock_tbl().plugins.fetch.rev)

      -- - Should mention that new revision comes from *lockfile*
      eq(confirm_lines[6], ('Revision before: %s'):format(hashes.fetch_new))
      eq(confirm_lines[7], ('Revision after:  %s (*lockfile*)'):format(hashes.fetch_head))
    end)

    it('can change `src` of installed plugin', function()
      local basic_src = repos_src.basic
      local defbranch_src = repos_src.defbranch
      exec_lua(function()
        vim.pack.add({ basic_src })
      end)

      local function assert_origin(ref)
        -- Should be in sync both on disk and in lockfile
        local opts = { cwd = pack_get_plug_path('basic') }
        local real_origin = system_sync({ 'git', 'remote', 'get-url', 'origin' }, opts)
        eq(ref, vim.trim(real_origin.stdout))

        eq(ref, get_lock_tbl().plugins.basic.src)
      end

      n.clear()
      watch_events({ 'PackChangedPre', 'PackChanged' })

      assert_origin(basic_src)
      exec_lua(function()
        vim.pack.add({ { src = defbranch_src, name = 'basic' } })
      end)
      -- Should not yet (after `add()`) affect plugin source
      assert_origin(basic_src)

      -- Should update source immediately (to work if updates are discarded)
      exec_lua(function()
        vim.pack.update({ 'basic' })
      end)
      assert_origin(defbranch_src)

      -- Should not revert source change even if update is discarded
      n.exec('quit')
      assert_origin(defbranch_src)
      eq({}, exec_lua('return _G.event_log'))

      -- Should work with forced update
      n.clear()
      exec_lua(function()
        vim.pack.add({ basic_src })
        vim.pack.update({ 'basic' }, { force = true })
      end)
      assert_origin(basic_src)
    end)

    it('shows progress report', function()
      track_nvim_echo()
      exec_lua(function()
        vim.pack.add({ repos_src.fetch, repos_src.defbranch })
        -- Should also include updates from not active plugins
        vim.pack.update()
      end)

      -- During initial download
      assert_progress_report('Downloading updates', { 'fetch', 'defbranch', 'semver' })
      exec_lua('_G.echo_log = {}')

      -- During application (only for plugins that have updates)
      n.exec('write')
      assert_progress_report('Applying updates', { 'fetch' })

      -- During force update
      n.clear()
      track_nvim_echo()
      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch new 3"')
      git_add_commit('Commit to be added 3', 'fetch')

      exec_lua(function()
        vim.pack.add({ repos_src.fetch, repos_src.defbranch })
        vim.pack.update(nil, { force = true })
      end)
      assert_progress_report('Updating', { 'fetch', 'defbranch', 'semver' })
    end)

    it('triggers relevant events', function()
      watch_events({ 'PackChangedPre', 'PackChanged' })
      exec_lua(function()
        vim.pack.add({ repos_src.fetch, repos_src.defbranch })
        _G.event_log = {}
        vim.pack.update()
      end)
      eq({}, exec_lua('return _G.event_log'))

      -- Should trigger relevant events only for actually updated plugins
      n.exec('write')
      local log = exec_lua('return _G.event_log')
      local find_event = make_find_packchanged(log)
      eq(1, find_event('Pre', 'update', 'fetch', nil, true))
      eq(2, find_event('', 'update', 'fetch', nil, true))
      eq(2, #log)
    end)

    it('stashes before applying changes', function()
      fn.writefile({ 'A text that will be stashed' }, fetch_lua_file)
      exec_lua(function()
        vim.pack.add({ repos_src.fetch })
        vim.pack.update()
        vim.cmd('write')
      end)

      local fetch_path = pack_get_plug_path('fetch')
      local stash_list = system_sync({ 'git', 'stash', 'list' }, { cwd = fetch_path }).stdout or ''
      matches('vim%.pack: %d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d Stash before checkout', stash_list)

      -- Update should still be applied
      eq('return "fetch new 2"', fn.readblob(fetch_lua_file))
    end)

    it('is not affected by special environment variables', function()
      fn.setenv('GIT_WORK_TREE', fn.getcwd())
      fn.setenv('GIT_DIR', vim.fs.joinpath(fn.getcwd(), '.git'))
      local ref_environ = fn.environ()

      exec_lua(function()
        vim.pack.add({ repos_src.fetch })
        vim.pack.update({ 'fetch' }, { force = true })
      end)
      eq('return "fetch new 2"', fn.readblob(fetch_lua_file))

      eq(ref_environ, fn.environ())
    end)

    it('works with out of sync lockfile', function()
      -- Should first autoinstall missing plugin (with confirmation)
      vim.fs.rm(pack_get_plug_path('fetch'), { force = true, recursive = true })
      n.clear()
      mock_confirm(1)
      exec_lua(function()
        vim.pack.update(nil, { force = true })
      end)
      eq(1, exec_lua('return #_G.confirm_log'))
      -- - Should checkout `version='main'` as it says in the lockfile
      eq('return "fetch new 2"', fn.readblob(fetch_lua_file))

      -- Should regenerate absent lockfile (from present plugins)
      vim.fs.rm(get_lock_path())
      n.clear()
      exec_lua(function()
        vim.pack.update(nil, { force = true })
      end)
      local lock_plugins = get_lock_tbl().plugins
      eq(3, vim.tbl_count(lock_plugins))
      -- - Should checkout default branch since `version='main'` info is lost
      --   after lockfile is deleted.
      eq(nil, lock_plugins.fetch.version)
      eq('return "fetch dev"', fn.readblob(fetch_lua_file))
    end)

    it('validates input', function()
      local function assert(err_pat, input)
        local function update_input()
          vim.pack.update(input)
        end
        matches(err_pat, pcall_err(exec_lua, update_input))
      end

      assert('list', 1)

      -- Should first check if every plugin name represents installed plugin
      -- If not - stop early before any update
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)

      assert('Plugin `ccc` is not installed', { 'ccc', 'basic', 'aaa' })

      -- Empty list is allowed with warning
      n.exec('messages clear')
      exec_lua(function()
        vim.pack.update({})
      end)
      eq('vim.pack: Nothing to update', n.exec_capture('messages'))
    end)
  end)

  describe('get()', function()
    local function make_basic_data(active, info)
      local spec = { name = 'basic', src = repos_src.basic, version = 'feat-branch' }
      local path = pack_get_plug_path('basic')
      local rev = git_get_hash('feat-branch', 'basic')
      local res = { active = active, path = path, spec = spec, rev = rev }
      if info then
        res.branches = { 'main', 'feat-branch' }
        res.tags = { 'some-tag' }
      end
      return res
    end

    local function make_defbranch_data(active, info)
      local spec = { name = 'defbranch', src = repos_src.defbranch }
      local path = pack_get_plug_path('defbranch')
      local rev = git_get_hash('dev', 'defbranch')
      local res = { active = active, path = path, spec = spec, rev = rev }
      if info then
        res.branches = { 'dev', 'main' }
        res.tags = {}
      end
      return res
    end

    local function make_plugindirs_data(active, info)
      local spec =
        { name = 'plugindirs', src = repos_src.plugindirs, version = vim.version.range('*') }
      local path = pack_get_plug_path('plugindirs')
      local rev = git_get_hash('v0.0.1', 'plugindirs')
      local res = { active = active, path = path, spec = spec, rev = rev }
      if info then
        res.branches = { 'main' }
        res.tags = { 'v0.0.1' }
      end
      return res
    end

    it('returns list with necessary data', function()
      local basic_data, defbranch_data, plugindirs_data

      -- Should work just after installation
      exec_lua(function()
        vim.pack.add({
          repos_src.defbranch,
          { src = repos_src.basic, version = 'feat-branch' },
          { src = repos_src.plugindirs, version = vim.version.range('*') },
        })
      end)
      defbranch_data = make_defbranch_data(true, true)
      basic_data = make_basic_data(true, true)
      plugindirs_data = make_plugindirs_data(true, true)
      -- Should preserve order in which plugins were `vim.pack.add()`ed
      eq({ defbranch_data, basic_data, plugindirs_data }, exec_lua('return vim.pack.get()'))

      -- Should also list non-active plugins
      n.clear()

      exec_lua(function()
        vim.pack.add({ repos_src.defbranch })
      end)
      defbranch_data = make_defbranch_data(true, true)
      basic_data = make_basic_data(false, true)
      plugindirs_data = make_plugindirs_data(false, true)
      -- Should first list active, then non-active (including their latest
      -- set `version` which is inferred from lockfile)
      eq({ defbranch_data, basic_data, plugindirs_data }, exec_lua('return vim.pack.get()'))

      -- Should respect `names` for both active and not active plugins
      eq({ basic_data }, exec_lua('return vim.pack.get({ "basic" })'))
      eq({ defbranch_data }, exec_lua('return vim.pack.get({ "defbranch" })'))
      eq({ basic_data, defbranch_data }, exec_lua('return vim.pack.get({ "basic", "defbranch" })'))

      local bad_get_cmd = 'return vim.pack.get({ "ccc", "basic", "aaa" })'
      matches('Plugin `ccc` is not installed', pcall_err(exec_lua, bad_get_cmd))

      -- Should respect `opts.info`
      defbranch_data = make_defbranch_data(true, false)
      basic_data = make_basic_data(false, false)
      plugindirs_data = make_plugindirs_data(false, false)
      eq(
        { defbranch_data, basic_data, plugindirs_data },
        exec_lua('return vim.pack.get(nil, { info = false })')
      )
      eq({ basic_data }, exec_lua('return vim.pack.get({ "basic" }, { info = false })'))
      eq({ defbranch_data }, exec_lua('return vim.pack.get({ "defbranch" }, { info = false })'))
    end)

    it('respects `data` field', function()
      local out = exec_lua(function()
        vim.pack.add({
          { src = repos_src.basic, version = 'feat-branch', data = { test = 'value' } },
          { src = repos_src.defbranch, data = 'value' },
        })
        local plugs = vim.pack.get()
        ---@type table<string,string>
        return { basic = plugs[1].spec.data.test, defbranch = plugs[2].spec.data }
      end)
      eq({ basic = 'value', defbranch = 'value' }, out)
    end)

    it('works with `del()`', function()
      exec_lua(function()
        vim.pack.add({ repos_src.defbranch, { src = repos_src.basic, version = 'feat-branch' } })
      end)

      exec_lua(function()
        _G.get_log = {}
        vim.api.nvim_create_autocmd({ 'PackChangedPre', 'PackChanged' }, {
          callback = function()
            table.insert(_G.get_log, vim.pack.get())
          end,
        })
      end)

      -- Should not include removed plugins immediately after they are removed,
      -- while still returning list without holes
      exec_lua('vim.pack.del({ "defbranch" })')
      local defbranch_data = make_defbranch_data(true, true)
      local basic_data = make_basic_data(true, true)
      eq({ { defbranch_data, basic_data }, { basic_data } }, exec_lua('return _G.get_log'))
    end)

    it('works with out of sync lockfile', function()
      exec_lua(function()
        vim.pack.add({ repos_src.basic, repos_src.defbranch })
      end)
      eq(2, vim.tbl_count(get_lock_tbl().plugins))
      local basic_lua_file = vim.fs.joinpath(pack_get_plug_path('basic'), 'lua', 'basic.lua')

      -- Should first autoinstall missing plugin (with confirmation)
      vim.fs.rm(pack_get_plug_path('basic'), { force = true, recursive = true })
      n.clear()
      mock_confirm(1)
      eq(2, exec_lua('return #vim.pack.get()'))

      eq(1, exec_lua('return #_G.confirm_log'))
      eq('return "basic main"', fn.readblob(basic_lua_file))

      -- Should regenerate absent lockfile (from present plugins)
      vim.fs.rm(get_lock_path())
      n.clear()
      eq(2, exec_lua('return #vim.pack.get()'))
      eq(2, vim.tbl_count(get_lock_tbl().plugins))
    end)
  end)

  describe('del()', function()
    it('works', function()
      exec_lua(function()
        vim.pack.add({ repos_src.plugindirs, { src = repos_src.basic, version = 'feat-branch' } })
      end)
      eq(true, pack_exists('basic'))
      eq(true, pack_exists('plugindirs'))

      local locked_plugins = vim.tbl_keys(get_lock_tbl().plugins)
      table.sort(locked_plugins)
      eq({ 'basic', 'plugindirs' }, locked_plugins)

      watch_events({ 'PackChangedPre', 'PackChanged' })

      n.exec('messages clear')
      exec_lua(function()
        vim.pack.del({ 'basic', 'plugindirs' })
      end)
      eq(false, pack_exists('basic'))
      eq(false, pack_exists('plugindirs'))

      eq(
        "vim.pack: Removed plugin 'basic'\nvim.pack: Removed plugin 'plugindirs'",
        n.exec_capture('messages')
      )

      -- Should trigger relevant events in order as specified in `vim.pack.add()`
      local log = exec_lua('return _G.event_log')
      local find_event = make_find_packchanged(log)
      eq(1, find_event('Pre', 'delete', 'basic', 'feat-branch', true))
      eq(2, find_event('', 'delete', 'basic', 'feat-branch', false))
      eq(3, find_event('Pre', 'delete', 'plugindirs', nil, true))
      eq(4, find_event('', 'delete', 'plugindirs', nil, false))
      eq(4, #log)

      -- Should update lockfile
      eq({ plugins = {} }, get_lock_tbl())
    end)

    it('works without prior `add()`', function()
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)
      n.clear()

      eq(true, pack_exists('basic'))
      exec_lua(function()
        vim.pack.del({ 'basic' })
      end)
      eq(false, pack_exists('basic'))
      eq({ plugins = {} }, get_lock_tbl())
    end)

    it('works with out of sync lockfile', function()
      exec_lua(function()
        vim.pack.add({ repos_src.basic, repos_src.defbranch, repos_src.plugindirs })
      end)
      eq(3, vim.tbl_count(get_lock_tbl().plugins))

      -- Should first autoinstall missing plugin (with confirmation)
      vim.fs.rm(pack_get_plug_path('basic'), { force = true, recursive = true })
      n.clear()
      mock_confirm(1)
      exec_lua('vim.pack.del({ "defbranch" })')

      eq(1, exec_lua('return #_G.confirm_log'))
      eq(true, pack_exists('basic'))
      eq(false, pack_exists('defbranch'))
      eq(true, pack_exists('plugindirs'))

      -- Should regenerate absent lockfile (from present plugins)
      vim.fs.rm(get_lock_path())
      n.clear()
      exec_lua('vim.pack.del({ "basic" })')
      eq(1, exec_lua('return #vim.pack.get()'))
      eq({ 'plugindirs' }, vim.tbl_keys(get_lock_tbl().plugins))
    end)

    it('validates input', function()
      local function assert(err_pat, input)
        local function del_input()
          vim.pack.del(input)
        end
        matches(err_pat, pcall_err(exec_lua, del_input))
      end

      assert('list', nil)

      -- Should first check if every plugin name represents installed plugin
      -- If not - stop early before any delete
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)

      assert('Plugin `ccc` is not installed', { 'ccc', 'basic', 'aaa' })
      eq(true, pack_exists('basic'))

      -- Empty list is allowed with warning
      n.exec('messages clear')
      exec_lua(function()
        vim.pack.del({})
      end)
      eq('vim.pack: Nothing to remove', n.exec_capture('messages'))
    end)
  end)
end)
