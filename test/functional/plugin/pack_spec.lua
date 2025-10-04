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

  local add_tag = function(name)
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
local function find_in_log(log, event, kind, repo_name, version)
  local path = pack_get_plug_path(repo_name)
  local spec = { name = repo_name, src = repos_src[repo_name], version = version }
  local data = { kind = kind, path = path, spec = spec }
  local entry = { event = event, match = vim.fs.abspath(path), data = data }

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

local function validate_progress_report(action, step_names)
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
        local load = function(p)
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
      -- Do not confirm installation to see what happens
      mock_confirm(2)

      local err = pcall_err(exec_lua, function()
        vim.pack.add({ repos_src.basic })
      end)

      matches('`basic`:\nInstallation was not confirmed', err)
      eq(false, exec_lua('return pcall(require, "basic")'))

      local confirm_msg = 'These plugins will be installed:\n\n' .. repos_src.basic .. '\n'
      local ref_log = { { confirm_msg, 'Proceed? &Yes\n&No\n&Always', 1, 'Question' } }
      eq(ref_log, exec_lua('return _G.confirm_log'))
    end)

    it('respects `opts.confirm`', function()
      mock_confirm(1)
      exec_lua(function()
        vim.pack.add({ repos_src.basic }, { confirm = false })
      end)

      eq(0, exec_lua('return #_G.confirm_log'))
      eq('basic main', exec_lua('return require("basic")'))
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

      -- Should properly format as indented JSON
      local ref_lockfile_lines = {
        '{',
        '  "plugins": {',
        '    "basic": {',
        '      "rev": "' .. basic_rev .. '",',
        '      "src": "' .. repos_src.basic .. '",',
        -- Branch, tag, and commit should be serialized like `'value'` to be
        -- distinguishable from version ranges
        '      "version": "\'some-tag\'"',
        '    },',
        '    "defbranch": {',
        '      "rev": "' .. defbranch_rev .. '",',
        '      "src": "' .. repos_src.defbranch .. '",',
        '      "version": "\'main\'"',
        '    },',
        '    "helptags": {',
        '      "rev": "' .. helptags_rev .. '",',
        '      "src": "' .. repos_src.helptags .. '",',
        '      "version": "\'' .. helptags_rev .. '\'"',
        '    },',
        '    "plugindirs": {',
        '      "rev": "' .. plugindirs_rev .. '",',
        '      "src": "' .. repos_src.plugindirs .. '"',
        -- Absent `version` should be missing and not autoresolved
        '    },',
        '    "semver": {',
        '      "rev": "' .. semver_rev .. '",',
        '      "src": "' .. repos_src.semver .. '",',
        '      "version": ">=0.0.0"',
        '    }',
        '  }',
        '}',
      }
      eq(ref_lockfile_lines, fn.readfile(get_lock_path()))
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

    it('can install from the Internet', function()
      t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')
      exec_lua(function()
        vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig' })
      end)
      eq(true, exec_lua('return pcall(require, "lspconfig")'))
    end)

    describe('startup', function()
      local init_lua = ''
      before_each(function()
        init_lua = vim.fs.joinpath(fn.stdpath('config'), 'init.lua')
        fn.mkdir(vim.fs.dirname(init_lua), 'p')
      end)
      after_each(function()
        pcall(vim.fs.rm, init_lua, { force = true })
      end)

      it('works in init.lua', function()
        local pack_add_cmd = ('vim.pack.add({ %s })'):format(vim.inspect(repos_src.plugindirs))
        fn.writefile({ pack_add_cmd, '_G.done = true' }, init_lua)

        local validate_loaded = function()
          eq('plugindirs main', exec_lua('return require("plugindirs")'))

          -- Should source 'plugin/' and 'after/plugin/' exactly once
          eq({ true, true }, n.exec_lua('return { vim.g._plugin, vim.g._after_plugin }'))
          eq({ 'p', 'a' }, n.exec_lua('return _G.DL'))
        end

        -- Should auto-install but wait before executing code after it
        n.clear({ args_rm = { '-u' } })
        n.exec_lua('vim.wait(500, function() return _G.done end, 50)')
        validate_loaded()

        -- Should only `:packadd!` already installed plugin
        n.clear({ args_rm = { '-u' } })
        validate_loaded()

        -- Should not load plugins if `--noplugin`, only adjust 'runtimepath'
        n.clear({ args = { '--noplugin' }, args_rm = { '-u' } })
        eq('plugindirs main', exec_lua('return require("plugindirs")'))
        eq({}, n.exec_lua('return { vim.g._plugin, vim.g._after_plugin }'))
        eq(vim.NIL, n.exec_lua('return _G.DL'))
      end)
    end)

    it('shows progress report during installation', function()
      track_nvim_echo()
      exec_lua(function()
        vim.pack.add({ repos_src.basic, repos_src.defbranch })
      end)
      validate_progress_report('Installing plugins', { 'basic', 'defbranch' })
    end)

    it('triggers relevant events', function()
      watch_events({ 'PackChangedPre', 'PackChanged' })

      exec_lua(function()
        -- Should provide event-data respecting manual `version` without inferring default
        vim.pack.add({ { src = repos_src.basic, version = 'feat-branch' }, repos_src.defbranch })
      end)

      local log = exec_lua('return _G.event_log')
      local installpre_basic = find_in_log(log, 'PackChangedPre', 'install', 'basic', 'feat-branch')
      local installpre_defbranch = find_in_log(log, 'PackChangedPre', 'install', 'defbranch', nil)
      local updatepre_basic = find_in_log(log, 'PackChangedPre', 'update', 'basic', 'feat-branch')
      local updatepre_defbranch = find_in_log(log, 'PackChangedPre', 'update', 'defbranch', nil)
      local update_basic = find_in_log(log, 'PackChanged', 'update', 'basic', 'feat-branch')
      local update_defbranch = find_in_log(log, 'PackChanged', 'update', 'defbranch', nil)
      local install_basic = find_in_log(log, 'PackChanged', 'install', 'basic', 'feat-branch')
      local install_defbranch = find_in_log(log, 'PackChanged', 'install', 'defbranch', nil)
      eq(8, #log)

      -- NOTE: There is no guaranteed installation order among separate plugins (as it is async)
      eq(true, installpre_basic < updatepre_basic)
      eq(true, updatepre_basic < update_basic)
      -- NOTE: "Install" is after "update" to indicate installation at correct version
      eq(true, update_basic < install_basic)

      eq(true, installpre_defbranch < updatepre_defbranch)
      eq(true, updatepre_defbranch < update_defbranch)
      eq(true, update_defbranch < install_defbranch)
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
      local function validate(load, ref)
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

      validate(nil, { true, true, true, true, true, true, true, true })

      n.clear()
      validate(false, {})
    end)

    it('can use function `opts.load`', function()
      local validate = function()
        n.exec_lua(function()
          _G.load_log = {}
          local load = function(...)
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
        plugindirs_data.active = true
        basic_data.active = true
        eq({ plugindirs_data, basic_data }, exec_lua('return vim.pack.get(nil, { info = false })'))
      end

      -- Works on initial install
      validate()

      -- Works when loading already installed plugin
      n.clear()
      validate()
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
      local validate = function(err_pat)
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
      validate(table.concat(err_pat_parts, '.*'))

      -- During loading already installed plugin.
      n.clear()
      -- NOTE: There is no error for wrong `version`, because there is no check
      -- for already installed plugins. Might change in the future.
      validate('vim%.pack.*`pluginerr`:\n.*Wow, an error')
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
      local validate = function(err_pat, input)
        local add_input = function()
          vim.pack.add(input)
        end
        matches(err_pat, pcall_err(exec_lua, add_input))
      end

      -- Separate spec entries
      validate('list', repos_src.basic)
      validate('spec:.*table', { 1 })
      validate('spec%.src:.*string', { { src = 1 } })
      validate('spec%.src:.*non%-empty string', { { src = '' } })
      validate('spec%.name:.*string', { { src = repos_src.basic, name = 1 } })
      validate('spec%.name:.*non%-empty string', { { src = repos_src.basic, name = '' } })
      validate(
        'spec%.version:.*string or vim%.VersionRange',
        { { src = repos_src.basic, version = 1 } }
      )

      -- Conflicts in input array
      local version_conflict = {
        { src = repos_src.basic, version = 'feat-branch' },
        { src = repos_src.basic, version = 'main' },
      }
      validate('Conflicting `version` for `basic`.*feat%-branch.*main', version_conflict)

      local src_conflict = {
        { src = repos_src.basic, name = 'my-plugin' },
        { src = repos_src.semver, name = 'my-plugin' },
      }
      validate('Conflicting `src` for `my%-plugin`.*basic.*semver', src_conflict)
    end)
  end)

  describe('update()', function()
    -- Lua source code for the tested plugin named "fetch"
    local fetch_lua_file = vim.fs.joinpath(pack_get_plug_path('fetch'), 'lua', 'fetch.lua')
    -- Table with hashes used to test confirmation buffer and log content
    local hashes --- @type table<string,string>

    before_each(function()
      -- Create a dedicated clean repo for which "push changes" will be mocked
      init_test_repo('fetch')

      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch init"')
      git_add_commit('Initial commit for "fetch"', 'fetch')

      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch main"')
      git_add_commit('Commit from `main` to be removed', 'fetch')

      hashes = { fetch_head = git_get_hash('HEAD', 'fetch') }

      -- Install initial versions of tested plugins
      exec_lua(function()
        vim.pack.add({
          repos_src.fetch,
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
        eq({ 'return "fetch main"' }, fn.readfile(fetch_lua_file))

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
        eq(api.nvim_buf_get_name(0), 'nvim-pack://' .. confirm_bufnr .. '/confirm-update')

        -- Adjust lines for a more robust screenshot testing
        local fetch_src = repos_src.fetch
        local fetch_path = pack_get_plug_path('fetch')
        local semver_src = repos_src.semver
        local semver_path = pack_get_plug_path('semver')

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
          local pack_runtime = vim.fs.joinpath(vim.env.VIMRUNTIME, 'lua', 'vim', 'pack.lua')
          -- NOTE: replace path to `vim.pack` in error traceback accounting for
          -- possibly different slashes on Windows
          local pack_runtime_pattern = vim.pesc(pack_runtime):gsub('/', '[\\/]') .. ':%d+'
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

        hashes.fetch_new = git_get_hash('HEAD', 'fetch')
        hashes.fetch_new_prev = git_get_hash('HEAD~', 'fetch')
        hashes.semver_head = git_get_hash('v0.3.0', 'semver')

        local tab_name = 'n' .. (t.is_os('win') and ':' or '') .. '//2/confirm-update'

        local screen_lines = {
          ('{24: [No Name] }{5: %s }{2:%s                                                   }{24:X}|'):format(
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
          'Path:         {103:FETCH_PATH}                                                             |',
          'Source:       {103:FETCH_SRC}                                                              |',
          ('State before: {103:%s}                                                                |'):format(
            hashes.fetch_head
          ),
          ('State after:  {103:%s} {102:(main)}                                                         |'):format(
            hashes.fetch_new
          ),
          '                                                                                     |',
          'Pending updates:                                                                     |',
          ('{19:< %s │ Commit from `main` to be removed}                                         |'):format(
            hashes.fetch_head
          ),
          ('{104:> %s │ Commit to be added 2}                                                     |'):format(
            hashes.fetch_new
          ),
          ('{104:> %s │ Commit to be added 1 (tag: dev-tag)}                                      |'):format(
            hashes.fetch_new_prev
          ),
          '                                                                                     |',
          '{102:# Same ─────────────────────────────────────────────────────────────────────────}     |',
          '                                                                                     |',
          '{102:## semver}                                                                            |',
          'Path:   {103:SEMVER_PATH}                                                                  |',
          'Source: {103:SEMVER_SRC}                                                                   |',
          ('State:  {103:%s} {102:(v0.3.0)}                                                             |'):format(
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
        eq({ 'return "fetch new 2"' }, fn.readfile(fetch_lua_file))

        -- - Clean up buffer+window+tabpage
        eq(false, api.nvim_buf_is_valid(confirm_bufnr))
        eq(false, api.nvim_win_is_valid(confirm_winnr))
        eq(false, api.nvim_tabpage_is_valid(confirm_tabpage))

        -- - Write to log file
        local log_path = vim.fs.joinpath(fn.stdpath('log'), 'nvim-pack.log')
        local log_lines = fn.readfile(log_path)
        matches('========== Update %d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d ==========', log_lines[1])
        local ref_log_lines = {
          '# Update ───────────────────────────────────────────────────────────────────────',
          '',
          '## fetch',
          'Path:         ' .. fetch_path,
          'Source:       ' .. fetch_src,
          'State before: ' .. hashes.fetch_head,
          'State after:  ' .. hashes.fetch_new .. ' (main)',
          '',
          'Pending updates:',
          '< ' .. hashes.fetch_head .. ' │ Commit from `main` to be removed',
          '> ' .. hashes.fetch_new .. ' │ Commit to be added 2',
          '> ' .. hashes.fetch_new_prev .. ' │ Commit to be added 1 (tag: dev-tag)',
          '',
        }
        eq(ref_log_lines, vim.list_slice(log_lines, 2))
      end)

      it('can be dismissed with `:quit`', function()
        exec_lua(function()
          vim.pack.add({ repos_src.fetch })
          vim.pack.update({ 'fetch' })
        end)
        eq('nvim-pack', api.nvim_get_option_value('filetype', {}))

        -- Should not apply updates
        n.exec('quit')
        eq({ 'return "fetch main"' }, fn.readfile(fetch_lua_file))
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
        local validate_hover = function(pos, commit_msg)
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

        validate_hover({ 14, 0 }, 'Commit from `main` to be removed')
        validate_hover({ 15, 0 }, 'Commit to be added 2')
        validate_hover({ 18, 0 }, 'Commit from `main` to be removed')
        validate_hover({ 19, 0 }, 'Commit to be added 2')
        validate_hover({ 20, 0 }, 'Commit to be added 1')
        validate_hover({ 27, 0 }, 'Add version v0.3.0')
        validate_hover({ 30, 0 }, 'Add version v1.0.0')
        validate_hover({ 31, 0 }, 'Add version v0.4')
        validate_hover({ 32, 0 }, 'Add version 0.3.1')
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

        ref_fetch_lock.rev = git_get_hash('HEAD', 'fetch')
        eq(ref_fetch_lock, get_lock_tbl().plugins.fetch)
      end)
    end)

    it('works with not active plugins', function()
      exec_lua(function()
        -- No plugins are added, but they are installed in `before_each()`
        vim.pack.update({ 'fetch' })
      end)
      eq({ 'return "fetch main"' }, fn.readfile(fetch_lua_file))
      n.exec('write')
      eq({ 'return "fetch new 2"' }, fn.readfile(fetch_lua_file))
    end)

    it('can force update', function()
      exec_lua(function()
        vim.pack.add({ repos_src.fetch })
        vim.pack.update({ 'fetch' }, { force = true })
      end)

      -- Apply changes immediately
      local fetch_src = repos_src.fetch
      local fetch_path = pack_get_plug_path('fetch')
      eq({ 'return "fetch new 2"' }, fn.readfile(fetch_lua_file))

      -- No special buffer/window/tabpage
      eq(1, #api.nvim_list_tabpages())
      eq(1, #api.nvim_list_wins())
      eq('', api.nvim_get_option_value('filetype', {}))

      -- Write to log file
      hashes.fetch_new = git_get_hash('HEAD', 'fetch')
      hashes.fetch_new_prev = git_get_hash('HEAD~', 'fetch')

      local log_path = vim.fs.joinpath(fn.stdpath('log'), 'nvim-pack.log')
      local log_lines = fn.readfile(log_path)
      matches('========== Update %d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d ==========', log_lines[1])
      local ref_log_lines = {
        '# Update ───────────────────────────────────────────────────────────────────────',
        '',
        '## fetch',
        'Path:         ' .. fetch_path,
        'Source:       ' .. fetch_src,
        'State before: ' .. hashes.fetch_head,
        'State after:  ' .. hashes.fetch_new .. ' (main)',
        '',
        'Pending updates:',
        '< ' .. hashes.fetch_head .. ' │ Commit from `main` to be removed',
        '> ' .. hashes.fetch_new .. ' │ Commit to be added 2',
        '> ' .. hashes.fetch_new_prev .. ' │ Commit to be added 1 (tag: dev-tag)',
        '',
      }
      eq(ref_log_lines, vim.list_slice(log_lines, 2))

      -- Should update lockfile
      eq(git_get_hash('HEAD', 'fetch'), get_lock_tbl().plugins.fetch.rev)
    end)

    it('shows progress report', function()
      track_nvim_echo()
      exec_lua(function()
        vim.pack.add({ repos_src.fetch, repos_src.defbranch })
        vim.pack.update()
      end)

      -- During initial download
      validate_progress_report('Downloading updates', { 'fetch', 'defbranch' })
      exec_lua('_G.echo_log = {}')

      -- During application (only for plugins that have updates)
      n.exec('write')
      validate_progress_report('Applying updates', { 'fetch' })

      -- During force update
      n.clear()
      track_nvim_echo()
      repo_write_file('fetch', 'lua/fetch.lua', 'return "fetch new 3"')
      git_add_commit('Commit to be added 3', 'fetch')

      exec_lua(function()
        vim.pack.add({ repos_src.fetch, repos_src.defbranch })
        vim.pack.update(nil, { force = true })
      end)
      validate_progress_report('Updating', { 'fetch', 'defbranch' })
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
      eq(1, find_in_log(log, 'PackChangedPre', 'update', 'fetch', nil))
      eq(2, find_in_log(log, 'PackChanged', 'update', 'fetch', nil))
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
      eq({ 'return "fetch new 2"' }, fn.readfile(fetch_lua_file))
    end)

    it('is not affected by special environment variables', function()
      fn.setenv('GIT_WORK_TREE', fn.getcwd())
      fn.setenv('GIT_DIR', vim.fs.joinpath(fn.getcwd(), '.git'))
      local ref_environ = fn.environ()

      exec_lua(function()
        vim.pack.add({ repos_src.fetch })
        vim.pack.update({ 'fetch' }, { force = true })
      end)
      eq({ 'return "fetch new 2"' }, fn.readfile(fetch_lua_file))

      eq(ref_environ, fn.environ())
    end)

    it('validates input', function()
      local validate = function(err_pat, input)
        local update_input = function()
          vim.pack.update(input)
        end
        matches(err_pat, pcall_err(exec_lua, update_input))
      end

      validate('list', 1)

      -- Should first check if every plugin name represents installed plugin
      -- If not - stop early before any update
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)

      validate('Plugin `ccc` is not installed', { 'ccc', 'basic', 'aaa' })

      -- Empty list is allowed with warning
      n.exec('messages clear')
      exec_lua(function()
        vim.pack.update({})
      end)
      eq('vim.pack: Nothing to update', n.exec_capture('messages'))
    end)
  end)

  describe('get()', function()
    local make_basic_data = function(active, info)
      local spec = { name = 'basic', src = repos_src.basic, version = 'feat-branch' }
      local path = pack_get_plug_path('basic')
      local res = { active = active, path = path, spec = spec }
      if info then
        res.branches = { 'main', 'feat-branch' }
        res.rev = git_get_hash('feat-branch', 'basic')
        res.tags = { 'some-tag' }
      end
      return res
    end

    local make_defbranch_data = function(active, info)
      local spec = { name = 'defbranch', src = repos_src.defbranch }
      local path = pack_get_plug_path('defbranch')
      local res = { active = active, path = path, spec = spec }
      if info then
        res.branches = { 'dev', 'main' }
        res.rev = git_get_hash('dev', 'defbranch')
        res.tags = {}
      end
      return res
    end

    it('returns list with necessary data', function()
      local basic_data, defbranch_data

      -- Should work just after installation
      exec_lua(function()
        vim.pack.add({ repos_src.defbranch, { src = repos_src.basic, version = 'feat-branch' } })
      end)
      defbranch_data = make_defbranch_data(true, true)
      basic_data = make_basic_data(true, true)
      -- Should preserve order in which plugins were `vim.pack.add()`ed
      eq({ defbranch_data, basic_data }, exec_lua('return vim.pack.get()'))

      -- Should also list non-active plugins
      n.clear()

      exec_lua(function()
        vim.pack.add({ { src = repos_src.basic, version = 'feat-branch' } })
      end)
      defbranch_data = make_defbranch_data(false, true)
      basic_data = make_basic_data(true, true)
      -- Should first list active, then non-active
      eq({ basic_data, defbranch_data }, exec_lua('return vim.pack.get()'))

      -- Should respect `names` for both active and not active plugins
      eq({ basic_data }, exec_lua('return vim.pack.get({ "basic" })'))
      eq({ defbranch_data }, exec_lua('return vim.pack.get({ "defbranch" })'))
      eq({ defbranch_data, basic_data }, exec_lua('return vim.pack.get({ "defbranch", "basic" })'))

      local bad_get_cmd = 'return vim.pack.get({ "ccc", "basic", "aaa" })'
      matches('Plugin `ccc` is not installed', pcall_err(exec_lua, bad_get_cmd))

      -- Should respect `opts.info`
      defbranch_data = make_defbranch_data(false, false)
      basic_data = make_basic_data(true, false)
      eq({ basic_data, defbranch_data }, exec_lua('return vim.pack.get(nil, { info = false })'))
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
      eq(1, find_in_log(log, 'PackChangedPre', 'delete', 'basic', 'feat-branch'))
      eq(2, find_in_log(log, 'PackChanged', 'delete', 'basic', 'feat-branch'))
      eq(3, find_in_log(log, 'PackChangedPre', 'delete', 'plugindirs', nil))
      eq(4, find_in_log(log, 'PackChanged', 'delete', 'plugindirs', nil))
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

    it('validates input', function()
      local validate = function(err_pat, input)
        local del_input = function()
          vim.pack.del(input)
        end
        matches(err_pat, pcall_err(exec_lua, del_input))
      end

      validate('list', nil)

      -- Should first check if every plugin name represents installed plugin
      -- If not - stop early before any delete
      exec_lua(function()
        vim.pack.add({ repos_src.basic })
      end)

      validate('Plugin `ccc` is not installed', { 'ccc', 'basic', 'aaa' })
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
