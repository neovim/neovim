--- @brief
---
---WORK IN PROGRESS built-in plugin manager! Early testing of existing features
---is appreciated, but expect breaking changes without notice.
---
---Manages plugins only in a dedicated [vim.pack-directory]() (see |packages|):
---`$XDG_DATA_HOME/nvim/site/pack/core/opt`.
---Plugin's subdirectory name matches plugin's name in specification.
---It is assumed that all plugins in the directory are managed exclusively by `vim.pack`.
---
---Uses Git to manage plugins and requires present `git` executable of at
---least version 2.36. Target plugins should be Git repositories with versions
---as named tags following semver convention `v<major>.<minor>.<patch>`.
---
---Example workflows ~
---
---Basic install and management:
---
---- Add |vim.pack.add()| call(s) to 'init.lua':
---```lua
---
---vim.pack.add({
---   -- Install "plugin1" and use default branch (usually `main` or `master`)
---   'https://github.com/user/plugin1',
---
---   -- Same as above, but using a table (allows setting other options)
---   { source = 'https://github.com/user/plugin1' },
---
---   -- Specify plugin's name (here the plugin will be called "plugin2"
---   -- instead of "generic-name")
---   { source = 'https://github.com/user/generic-name', name = 'plugin2' },
---
---   -- Specify version to follow during install and update
---   {
---     source = 'https://github.com/user/plugin3',
---     -- Version constraint, see |vim.version.range()|
---     version = vim.version.range('1.0'),
---   },
---   {
---     source = 'https://github.com/user/plugin4',
---     -- Git branch, tag, or commit hash
---     version = 'main',
---   },
---})
---
----- Plugin's code can be used directly after `add()`
---plugin1 = require('plugin1')
---```
---
---- Restart Nvim. Plugins that were not yet installed will be available on disk
---in target state after `add()` call.
---
---- To update all plugins with new changes:
---    - Execute |vim.pack.update()|. This will download updates from source and
---      show confirmation buffer in a separate tabpage.
---    - Review changes. To confirm all updates execute |:write|.
---      To discard updates execute |:quit|.
---
---Switch plugin's version:
---- Update 'init.lua' for plugin to have desired `version`. Let's say, plugin
---named 'plugin1' has changed to `vim.version.range('*')`.
---- Restart Nvim. The plugin's actual state on disk is not yet changed.
---- Execute `vim.pack.update({ 'plugin1' }, { offline = true })`. Using `offline`
---is optional to not download updates from source.
---- Review changes and either confirm or discard them. If discarded, revert
---any changes in 'init.lua' as well or you will be prompted again next time
---you run |vim.pack.update()|.
---
---Freeze plugin from being updated:
---- Update 'init.lua' for plugin to have `version = false`.
---- Restart Nvim.
---
---Unfreeze plugin to start receiving updates:
---- Update 'init.lua' for plugin to have `version` set to whichever version
---you want it to be updated.
---- Restart Nvim.
---
---Remove plugins from disk:
---- Use |vim.pack.del()| with a list of plugin names to remove. Make sure their specs
---are not included in |vim.pack.add()| call in 'init.lua' or they will be reinstalled.
---
--- Available events to hook into ~
---
---- [PackInstallPre]() - before trying to install plugin on disk.
---- [PackInstall]() - after installing plugin on disk in proper state.
---After |PackUpdatePre| and |PackUpdate|.
---- [PackUpdatePre]() - before trying to update plugin's state.
---- [PackUpdate]() - after plugin's state is updated.
---- [PackDeletePre]() - before removing plugin from disk.
---- [PackDelete]() - after removing plugin from disk.

local api = vim.api
local uv = vim.uv

local M = {}

-- Git ------------------------------------------------------------------------
--- @param cmd string[]
--- @param cwd string
local function cli_sync(cmd, cwd)
  local out = vim.system(cmd, { cwd = cwd, text = true, clear_env = true }):wait()
  if out.code ~= 0 then
    error(out.stderr)
  end
  return (out.stdout:gsub('\n+$', ''))
end

local function git_ensure_exec()
  if vim.fn.executable('git') == 0 then
    error('No `git` executable')
  end
end

--- @type table<string,fun(...): string[]>
local git_args = {
  clone = function(source, path)
    -- NOTE: '--also-filter-submodules' requires Git>=2.36
    local opts = { '--filter=blob:none', '--recurse-submodules', '--also-filter-submodules' }
    if vim.startswith(source, 'file://') then
      opts = { '--no-hardlinks' }
    end
    return { 'clone', '--quiet', unpack(opts), '--origin', 'origin', source, path }
  end,
  stash = function(timestamp)
    local msg = '(vim.pack) ' .. timestamp .. ' Stash before checkout' --[[@as string]]
    return { 'stash', '--quiet', '--message', msg }
  end,
  checkout = function(target)
    return { 'checkout', '--quiet', target }
  end,
  -- Using '--tags --force' means conflicting tags will be synced with remote
  fetch = function()
    return { 'fetch', '--quiet', '--tags', '--force', '--recurse-submodules=yes', 'origin' }
  end,
  get_origin = function()
    return { 'remote', 'get-url', 'origin' }
  end,
  get_default_origin_branch = function()
    return { 'rev-parse', '--abbrev-ref', 'origin/HEAD' }
  end,
  -- Using `rev-list -1` shows a commit of revision, while `rev-parse` shows
  -- hash of revision. Those are different for annotated tags.
  get_hash = function(rev)
    return { 'rev-list', '-1', '--abbrev-commit', rev }
  end,
  log = function(from, to)
    local pretty = '--pretty=format:%m %h │ %s%d'
    -- `--topo-order` makes showing divergent branches nicer
    -- `--decorate-refs` shows only tags near commits (not `origin/main`, etc.)
    return { 'log', pretty, '--topo-order', '--decorate-refs=refs/tags', from .. '...' .. to }
  end,
  list_branches = function()
    return { 'branch', '--remote', '--list', '--format=%(refname:short)', '--', 'origin/**' }
  end,
  list_tags = function()
    return { 'tag', '--list', '--sort=-v:refname' }
  end,
  list_new_tags = function(from)
    return { 'tag', '--list', '--sort=-v:refname', '--contains', from }
  end,
  list_cur_tags = function(at)
    return { 'tag', '--list', '--points-at', at }
  end,
}

local function git_cmd(cmd_name, ...)
  local args = git_args[cmd_name](...)
  if args == nil then
    return {}
  end

  -- Use '-c gc.auto=0' to disable `stderr` "Auto packing..." messages
  return { 'git', '-c', 'gc.auto=0', unpack(args) }
end

local function git_get_default_branch(cwd)
  local res = cli_sync(git_cmd('get_default_origin_branch'), cwd)
  return (res:gsub('^origin/', ''))
end

--- @param cwd string
local function git_get_branches(cwd)
  local stdout, res = cli_sync(git_cmd('list_branches'), cwd), {}
  for _, l in ipairs(vim.split(stdout, '\n')) do
    table.insert(res, l:match('^origin/(.+)$'))
  end
  return res
end

--- @param cwd string
local function git_get_tags(cwd)
  local stdout = cli_sync(git_cmd('list_tags'), cwd)
  return vim.split(stdout, '\n')
end

-- Plugin operations ----------------------------------------------------------
local function get_plug_dir()
  return vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'core', 'opt')
end

--- @param msg string|string[]
--- @param level ('DEBUG'|'TRACE'|'INFO'|'WARN'|'ERROR')?
local function notify(msg, level)
  msg = type(msg) == 'table' and table.concat(msg, '\n') or msg
  vim.notify('(vim.pack) ' .. msg, vim.log.levels[level or 'INFO'])
  vim.cmd.redraw()
end

local function is_version_range(x)
  return (pcall(function()
    x:has('1')
  end))
end

local function get_timestamp()
  return vim.fn.strftime('%Y-%m-%d %H:%M:%S')
end

--- @class vim.pack.Spec
---
--- URI from which to install and pull updates. Any format supported by `git clone` is allowed.
--- @field source string
---
--- Name of plugin. Will be used as directory name. Default: basename of `source`.
--- @field name? string
---
--- Version to use for install and updates. Can be:
--- - `nil` (no value, default) to use repository's default branch (usually `main` or `master`).
--- - String to use specific branch, tag, or commit hash.
--- - Output of |vim.version.range()| to install the greatest/last semver tag
---   inside the version constraint.
--- - `false` to freeze current state of already installed plugin from updates.
--- @field version? string|vim.VersionRange|false

--- @alias vim.pack.SpecResolved { source: string, name: string, version: nil|string|vim.VersionRange|false }

--- @param spec string|vim.pack.Spec
--- @return vim.pack.SpecResolved
local function normalize_spec(spec)
  spec = type(spec) == 'string' and { source = spec } or spec
  vim.validate('spec', spec, 'table')
  vim.validate('spec.source', spec.source, 'string')
  local name = (spec.name or spec.source):match('[^/]+$')
  vim.validate('spec.name', name, 'string')
  local version = spec.version
  local function is_version(x)
    return type(x) == 'string' or is_version_range(x) or x == false
  end
  vim.validate('spec.version', version, is_version, true, 'string, vim.VersionRange, or `false`')
  return { source = spec.source, name = name, version = version }
end

--- @class (private) vim.pack.Plug
--- @field spec vim.pack.SpecResolved
--- @field path string

--- @param spec string|vim.pack.Spec
--- @return vim.pack.Plug
local function new_plug(spec)
  local spec_resolved = normalize_spec(spec)
  local path = vim.fs.joinpath(get_plug_dir(), spec_resolved.name)
  return { spec = spec_resolved, path = path }
end

--- @alias vim.pack.Job { cmd: string[], cwd: string, out: string, err: string }

--- @class (private) vim.pack.PlugJobInfo
--- @field warn? string Concatenated job warnings
--- @field version_str? string `spec.version` with resolved version range.
--- @field version_ref? string Resolved version as Git reference (if different
---   from `version_str`).
--- @field sha_head? string Git hash of HEAD.
--- @field sha_target? string Git hash of `version_ref`.
--- @field update_details? string Details about the update:: changelog if HEAD
---   and target are different, available newer tags otherwise.

--- @class (private) vim.pack.PlugJob
--- @field plug vim.pack.Plug
--- @field job { cmd: string[], cwd: string, out: string, err: string }
--- @field info vim.pack.PlugJobInfo

--- @class (private) vim.pack.PlugList List of plugin along with job and info
--- @field list vim.pack.PlugJob[]
local PlugList = {}
PlugList.__index = PlugList

--- @package
--- @param plugs vim.pack.Plug[]
--- @return vim.pack.PlugList
function PlugList.new(plugs)
  --- @type vim.pack.PlugJob[]
  local list = {}
  for i, p in ipairs(plugs) do
    local job = { cmd = {}, cwd = p.path, out = '', err = '' }
    list[i] = { plug = p, job = job, info = { warn = '' } }
  end
  return setmetatable({ list = list }, PlugList)
end

--- @package
--- @param names string[]?
--- @return vim.pack.PlugList
function PlugList.from_names(names)
  local all_plugins, plugs = M.get(), {}
  -- Preserve plugin order; might be important during checkout or event trigger
  for _, p_data in ipairs(all_plugins) do
    -- NOTE: By default include only added plugins (and not all on disk). Using
    -- not added plugins might lead to a confusion as default `version` and
    -- user's desired one might mismatch.
    -- TODO(echasnovski): Consider changing this if/when there is lockfile.
    --- @cast names string[]
    if (names == nil and p_data.was_added) or vim.tbl_contains(names, p_data.spec.name) then
      table.insert(plugs, { spec = p_data.spec, path = p_data.path })
    end
  end

  return PlugList.new(plugs)
end

--- Run jobs from plugin list in parallel
---
--- For each plugin that hasn't errored yet:
--- - Execute `prepare`: do side effects and set `job.cmd`.
--- - If set, execute `job.cmd` asynchronously.
--- - After done, preprocess job's `code`/`stdout`/`stderr`, run `process` to gather
---   useful info, and start next job.
---
--- @package
--- @param prepare? fun(vim.pack.PlugExtra): nil
--- @param process? fun(vim.pack.PlugExtra): nil
--- @param report_progress? fun(kind: 'report'|'end', msg: string, percent: integer): nil
function PlugList:run(prepare, process, report_progress)
  prepare, process = prepare or function(_) end, process or function(_) end
  report_progress = report_progress or function(_, _, _) end

  local n_threads = math.max(math.floor(0.8 * #(uv.cpu_info() or {})), 1)
  local timeout = 30000

  -- Use only plugs which didn't error before
  --- @param p vim.pack.PlugJob
  local list_noerror = vim.tbl_filter(function(p)
    return p.job.err == ''
  end, self.list)
  if #list_noerror == 0 then
    return
  end

  -- Prepare for job execution
  local n_total, n_started, n_finished = #list_noerror, 0, 0
  local function register_finished()
    n_finished = n_finished + 1
    local percent = math.floor(100 * n_finished / n_total)
    report_progress('report', n_finished .. '/' .. n_total, percent)
  end

  local function run_next()
    if n_started >= n_total then
      return
    end
    n_started = n_started + 1

    local p = list_noerror[n_started]

    local function on_exit(sys_res)
      register_finished()

      --- @type string
      local stderr = sys_res.stderr:gsub('\n+$', '')
      -- If error, skip custom processing
      if sys_res.code ~= 0 then
        p.job.err = 'Error code ' .. sys_res.code .. '\n' .. stderr
        return run_next()
      end

      -- Process command results. Treat exit code 0 with `stderr` as warning.
      p.job.out = sys_res.stdout:gsub('\n+$', '')
      p.info.warn = p.info.warn .. (stderr == '' and '' or ('\n\n' .. stderr))
      process(p)
      run_next()
    end

    prepare(p)
    if #p.job.cmd == 0 or p.job.err ~= '' then
      register_finished()
      return run_next()
    end
    local system_opts = { cwd = p.job.cwd, text = true, timeout = timeout, clear_env = true }
    -- NOTE: `schedule_wrap(on_exit)` avoids "is not allowed in fast context"
    vim.system(p.job.cmd, system_opts, vim.schedule_wrap(on_exit))
  end

  -- Run jobs async in parallel but wait for all to finish/timeout
  report_progress('begin', '0/' .. n_total)

  for _ = 1, n_threads do
    run_next()
  end

  local total_wait = timeout * math.ceil(n_total / n_threads)
  vim.wait(total_wait, function()
    return n_finished >= n_total
  end, 1)

  report_progress('end', n_total .. '/' .. n_total)

  -- Clean up. Preserve errors to stop processing plugin after the first one.
  for _, p in ipairs(list_noerror) do
    p.job.cmd, p.job.cwd, p.job.out = {}, p.plug.path, ''
  end
end

--- @package
function PlugList:install()
  -- Get user confirmation to install plugins
  --- @param p vim.pack.PlugJob
  local sources = vim.tbl_map(function(p)
    return p.plug.spec.source
  end, self.list)
  local confirm_msg = 'These plugins will be installed:\n\n' .. table.concat(sources, '\n') .. '\n'
  --- @type integer
  local confirm_res
  if vim.v.vim_did_enter == 1 then
    confirm_res = vim.fn.confirm(confirm_msg, 'Proceed? &Yes\n&No', 1, 'Question')
  else
    -- Work around confirmation message not showing during startup.
    -- This is a semi-regression of #31525: some redraw during startup makes
    -- confirmation message disappear.
    -- TODO: Remove when #34088 is resolved.
    confirm_msg = confirm_msg .. '\nProceed? [Y]es, (N)o'
    vim.defer_fn(function()
      vim.print(confirm_msg)
    end, 100)
    local ok, char = pcall(vim.fn.getcharstr)
    confirm_res = (ok and (char == 'y' or char == 'Y' or char == '\r')) and 1 or 0
    vim.cmd.redraw()
  end

  if confirm_res ~= 1 then
    for _, p in ipairs(self.list) do
      p.job.err = 'Installation was not confirmed'
    end
    return
  end

  -- Trigger relevant event
  self:trigger_event('PackInstallPre')

  -- Clone
  --- @param p vim.pack.PlugJob
  local function prepare(p)
    -- Temporarily change job's cwd because target path doesn't exist yet
    p.job.cwd = uv.cwd() --[[@as string]]
    p.job.cmd = git_cmd('clone', p.plug.spec.source, p.plug.path)
  end
  local report_progress = require('vim.pack.lsp').new_progress_report('Installing plugins')
  self:run(prepare, nil, report_progress)

  -- Checkout to target version. Do not skip checkout even if HEAD and target
  -- have same commit hash to have installed repo in expected detached HEAD
  -- state and generated help files.
  self:checkout({ skip_same_sha = false })

  -- NOTE: 'PackInstall' is triggered after 'PackUpdate' intentionally to have
  -- it indicate "plugin is installed in its correct initial version"
  self:trigger_event('PackInstall')
end

--- Keep repos in detached HEAD state. Infer commit from resolved version.
--- No local branches are created, branches from "origin" remote are used directly.
--- @package
--- @param opts { skip_same_sha: boolean }
function PlugList:checkout(opts)
  opts = vim.tbl_deep_extend('force', { skip_same_sha = true }, opts or {})

  self:infer_head()
  self:infer_target()

  local plug_list = vim.deepcopy(self)
  if opts.skip_same_sha then
    --- @param p vim.pack.PlugJob
    plug_list.list = vim.tbl_filter(function(p)
      return p.info.sha_head ~= p.info.sha_target
    end, plug_list.list)
  end

  -- Stash changes
  local stash_cmd = git_cmd('stash', get_timestamp())
  --- @param p vim.pack.PlugJob
  local function prepare(p)
    p.job.cmd = stash_cmd
  end
  plug_list:run(prepare, nil)

  plug_list:trigger_event('PackUpdatePre')

  -- Checkout
  prepare = function(p)
    p.job.cmd = git_cmd('checkout', p.info.sha_target)
  end
  --- @param p vim.pack.PlugJob
  local function process(p)
    local msg = string.format('Updated state to `%s` in `%s`', p.info.version_str, p.plug.spec.name)
    notify(msg, 'INFO')
  end
  plug_list:run(prepare, process)

  plug_list:trigger_event('PackUpdate')

  -- (Re)Generate help tags according to the current help files
  for _, p in ipairs(plug_list.list) do
    -- Completely redo tags
    local doc_dir = p.plug.path .. '/doc'
    vim.fn.delete(doc_dir .. '/tags')
    -- Use `pcall()` because `:helptags` errors if there is no 'doc/' directory
    -- or if it is empty
    pcall(vim.cmd.helptags, vim.fn.fnameescape(doc_dir))
  end
end

--- @package
function PlugList:download_updates()
  --- @param p vim.pack.PlugJob
  local function prepare(p)
    p.job.cmd = git_cmd('fetch')
  end
  local report_progress = require('vim.pack.lsp').new_progress_report('Downloading updates')
  self:run(prepare, nil, report_progress)
end

--- @package
function PlugList:resolve_version()
  local function list_in_line(name, list)
    return #list == 0 and '' or ('\n' .. name .. ': ' .. table.concat(list, ', '))
  end

  --- @param p vim.pack.PlugJob
  local function prepare(p)
    if p.info.version_str ~= nil then
      return
    end
    local version = p.plug.spec.version

    if version == nil then
      p.info.version_str = git_get_default_branch(p.plug.path)
      p.info.version_ref = 'origin/' .. p.info.version_str
      return
    end

    -- Allow `false` to mean freeze current state from updates
    if version == false then
      p.info.version_str, p.info.version_ref = '', 'HEAD'
      return
    end

    -- Allow specifying non-version-range like version: branch or commit.
    local branches, tags = git_get_branches(p.plug.path), git_get_tags(p.plug.path)
    if type(version) == 'string' then
      local is_branch = vim.tbl_contains(branches, version)
      local is_tag_or_hash = pcall(cli_sync, git_cmd('get_hash', version), p.plug.path)
      if not (is_branch or is_tag_or_hash) then
        p.job.err = string.format('`%s` is not a branch/tag/commit. Available:', version)
          .. list_in_line('Tags', tags)
          .. list_in_line('Branches', branches)
        return
      end

      p.info.version_str, p.info.version_ref = version, (is_branch and 'origin/' or '') .. version
      return
    end
    --- @cast version vim.VersionRange

    -- Choose the greatest/last version among all matching semver tags
    local last_ver_tag, semver_tags = nil, {}
    for _, tag in ipairs(tags) do
      local ver_tag = vim.version.parse(tag)
      table.insert(semver_tags, ver_tag ~= nil and tag or nil)
      local is_in_range = ver_tag ~= nil and version:has(ver_tag)
      if is_in_range and (last_ver_tag == nil or ver_tag > last_ver_tag) then
        p.info.version_str, last_ver_tag = tag, ver_tag
      end
    end

    if p.info.version_str == nil then
      p.job.err = 'No versions fit constraint. Relax it or switch to branch. Available:'
        .. list_in_line('Versions', semver_tags)
        .. list_in_line('Branches', branches)
    end
  end
  self:run(prepare, nil)
end

--- @package
function PlugList:infer_head()
  --- @param p vim.pack.PlugJob
  local function prepare(p)
    p.job.cmd = p.info.sha_head == nil and git_cmd('get_hash', 'HEAD') or {}
  end
  --- @param p vim.pack.PlugJob
  local function process(p)
    p.info.sha_head = p.info.sha_head or p.job.out
  end
  self:run(prepare, process)
end

--- @package
function PlugList:infer_target()
  self:resolve_version()

  --- @param p vim.pack.PlugJob
  local function prepare(p)
    local target_ref = p.info.version_ref or p.info.version_str
    p.job.cmd = p.info.sha_target == nil and git_cmd('get_hash', target_ref) or {}
  end
  --- @param p vim.pack.PlugJob
  local function process(p)
    p.info.sha_target = p.info.sha_target or p.job.out
  end
  self:run(prepare, process)
end

--- @package
function PlugList:infer_update_details()
  self:infer_head()
  self:infer_target()

  --- @param p vim.pack.PlugJob
  local function prepare(p)
    local from, to = p.info.sha_head, p.info.sha_target
    p.job.cmd = from ~= to and git_cmd('log', from, to) or git_cmd('list_new_tags', to)
  end
  --- @param p vim.pack.PlugJob
  local function process(p)
    p.info.update_details = p.job.out
    if p.info.sha_head ~= p.info.sha_target or p.info.update_details == '' then
      return
    end

    -- Remove tags points at target (there might be several)
    local cur_tags = cli_sync(git_cmd('list_cur_tags', p.info.sha_target), p.plug.path)
    for _, tag in ipairs(vim.split(cur_tags, '\n')) do
      p.info.update_details = p.info.update_details:gsub(vim.pesc(tag) .. '\n?', '')
    end
  end
  self:run(prepare, process)
end

--- Trigger event for not yet errored plugin jobs
--- Do so as `PlugList` method to preserve order, which might be important when
--- dealing with dependencies.
--- @package
--- @param event_name 'PackInstallPre'|'PackInstall'|'PackUpdatePre'|'PackUpdate'|'PackDeletePre'|'PackDelete'
function PlugList:trigger_event(event_name)
  --- @param p vim.pack.PlugJob
  local function prepare(p)
    vim.api.nvim_exec_autocmds(event_name, { pattern = p.plug.path, data = vim.deepcopy(p.plug) })
  end
  self:run(prepare, nil)
end

--- @package
--- @param action_name string
function PlugList:show_notifications(action_name)
  for _, p in ipairs(self.list) do
    local name, warn = p.plug.spec.name, p.info.warn
    if warn ~= '' then
      local msg = string.format('Warnings in `%s` during %s:\n%s', name, action_name, warn)
      notify(msg, 'WARN')
    end
    local err = p.job.err
    if err ~= '' then
      local msg = string.format('Error in `%s` during %s:\n%s', name, action_name, err)
      error(msg)
    end
  end
end

--- Map from plugin path to its data.
--- Use map and not array to avoid linear lookup during startup.
--- @type table<string, { plug: vim.pack.Plug, id: integer }>
local added_plugins = {}
local n_added_plugins = 0

--- @param plug vim.pack.Plug
--- @param bang boolean
local function pack_add(plug, bang)
  -- Add plugin only once, i.e. no overriding of spec. This allows users to put
  -- plugin first to fully control its spec.
  if added_plugins[plug.path] ~= nil then
    return
  end

  n_added_plugins = n_added_plugins + 1
  added_plugins[plug.path] = { plug = plug, id = n_added_plugins }

  vim.cmd.packadd({ plug.spec.name, bang = bang })

  -- Execute 'after/' scripts if not during startup (when they will be sourced
  -- automatically), as `:packadd` only sources plain 'plugin/' files.
  -- See https://github.com/vim/vim/issues/15584
  -- Deliberately do so after executing all currently known 'plugin/' files.
  local should_load_after_dir = vim.v.vim_did_enter == 1 and not bang and vim.o.loadplugins
  if should_load_after_dir then
    local after_paths = vim.fn.glob(plug.path .. '/after/plugin/**/*.{vim,lua}', false, true)
    --- @param path string
    vim.tbl_map(function(path)
      pcall(vim.cmd.source, vim.fn.fnameescape(path))
    end, after_paths)
  end
end

--- @class vim.pack.keyset.add
--- @inlinedoc
--- @field bang? boolean Whether to execute `:packadd!` instead of |:packadd|. Default `false`.

--- Add plugin to current session
---
--- - For each specification check that plugin exists on disk in |vim.pack-directory|:
---     - If exists, do nothin in this step.
---     - If doesn't exist, install it by downloading from `source` into `name`
---       subdirectory (via `git clone`) and update state to match `version` (via `git checkout`).
--- - For each plugin execute |:packadd| making them reachable by Nvim.
---
--- Notes:
--- - Installation is done in parallel, but waits for all to finish before
---   continuing next code execution.
--- - If plugin is already present on disk, there are no checks about its present state.
---   The specified `version` can be not the one actually present on disk.
---   Execute |vim.pack.update()| (possibly with `{ offline = true }`) to synchronize.
--- - Adding plugin second and more times during single session does nothing:
---   only the data from the first adding is registered.
---
--- @param specs (string|vim.pack.Spec)[] List of plugin specifications. String item
--- is treated as `source`.
--- @param opts? vim.pack.keyset.add
function M.add(specs, opts)
  vim.validate('specs', specs, vim.islist, false, 'list')
  opts = vim.tbl_extend('force', { bang = false }, opts or {})
  vim.validate('opts', opts, 'table')

  --- @type vim.pack.Plug[]
  local plugs = vim.tbl_map(new_plug, specs)
  -- TODO(echasnovski): Normalize all plugins as a whole, mostly process
  -- duplicates. This has little benefit now, but will be more sore after
  -- packspec processing (as it might introduce conflicting dependencies).

  -- Install
  --- @param p vim.pack.Plug
  local plugs_to_install = vim.tbl_filter(function(p)
    return uv.fs_stat(p.path) == nil
  end, plugs)
  local pluglist_to_install = PlugList.new(plugs_to_install)
  if #plugs_to_install > 0 then
    git_ensure_exec()
    pluglist_to_install:install()
  end

  -- Register and `:packadd` those actually on disk
  for _, p in ipairs(plugs) do
    if uv.fs_stat(p.path) ~= nil then
      pack_add(p, opts.bang)
    end
  end

  -- Delay showing warnings/errors to first have "good" plugins added
  pluglist_to_install:show_notifications('installation')
end

--- @param p vim.pack.PlugJob
--- @return string
local function compute_feedback_lines_single(p)
  if p.job.err ~= '' then
    return '## ' .. p.plug.spec.name .. '\n\n  ' .. p.job.err:gsub('\n', '\n  ')
  end

  local parts = { '## ' .. p.plug.spec.name .. '\n' }
  local version_suffix = p.info.version_str == '' and ''
    or string.format(' (%s)', p.info.version_str)

  if p.info.sha_head == p.info.sha_target then
    table.insert(parts, 'Path:   ' .. p.plug.path .. '\n')
    table.insert(parts, 'Source: ' .. p.plug.spec.source .. '\n')
    table.insert(parts, 'State:  ' .. p.info.sha_target .. version_suffix)

    if p.info.update_details ~= '' then
      local details = p.info.update_details:gsub('\n', '\n• ')
      table.insert(parts, '\n\nAvailable newer tags:\n• ' .. details)
    end
  else
    table.insert(parts, 'Path:         ' .. p.plug.path .. '\n')
    table.insert(parts, 'Source:       ' .. p.plug.spec.source .. '\n')
    table.insert(parts, 'State before: ' .. p.info.sha_head .. '\n')
    table.insert(parts, 'State after:  ' .. p.info.sha_target .. version_suffix)

    table.insert(parts, '\n\nPending updates:\n' .. p.info.update_details)
  end

  return table.concat(parts, '')
end

--- @param plug_list vim.pack.PlugList
--- @param opts { skip_same_sha: boolean }
--- @return string[]
local function compute_feedback_lines(plug_list, opts)
  -- Construct plugin line groups for better report
  local report_err, report_update, report_same = {}, {}, {}
  for _, p in ipairs(plug_list.list) do
    local group_arr = #p.job.err > 0 and report_err
      or (p.info.sha_head ~= p.info.sha_target and report_update or report_same)
    table.insert(group_arr, compute_feedback_lines_single(p))
  end

  local lines = {}
  --- @param header string
  --- @param arr string[]
  local function append_report(header, arr)
    if #arr == 0 then
      return
    end
    header = header .. ' ' .. string.rep('─', 79 - header:len())
    table.insert(lines, header)
    vim.list_extend(lines, arr)
  end
  append_report('# Error', report_err)
  append_report('# Update', report_update)
  if not opts.skip_same_sha then
    append_report('# Same', report_same)
  end

  return vim.split(table.concat(lines, '\n\n'), '\n')
end

--- @param plug_list vim.pack.PlugList
local function feedback_log(plug_list)
  local lines = compute_feedback_lines(plug_list, { skip_same_sha = true })
  local title = string.format('========== Update %s ==========', get_timestamp())
  table.insert(lines, 1, title)
  table.insert(lines, '')

  local log_path = vim.fn.stdpath('log') .. '/nvimpack.log'
  vim.fn.mkdir(vim.fs.dirname(log_path), 'p')
  vim.fn.writefile(lines, log_path, 'a')
end

local function show_confirm_buf(lines, opts)
  -- Show buffer in a separate tabpage
  local bufnr = api.nvim_create_buf(true, true)
  api.nvim_buf_set_name(bufnr, 'nvimpack://' .. bufnr .. '/confirm-update')
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.cmd.sbuffer({ bufnr, mods = { tab = vim.fn.tabpagenr('#') } })
  local tab_num, win_id = api.nvim_tabpage_get_number(0), api.nvim_get_current_win()

  local delete_buffer = vim.schedule_wrap(function()
    pcall(api.nvim_buf_delete, bufnr, { force = true })
    pcall(vim.cmd.tabclose, tab_num)
    vim.cmd.redraw()
  end)

  -- Define action on accepting confirm
  local function finish()
    opts.exec_on_write(bufnr)
    delete_buffer()
  end
  -- - Use `nested` to allow other events (useful for statuslines)
  api.nvim_create_autocmd('BufWriteCmd', { buffer = bufnr, nested = true, callback = finish })

  -- Define action to cancel confirm
  --- @type integer
  local cancel_au_id
  local function on_cancel(data)
    if tonumber(data.match) ~= win_id then
      return
    end
    pcall(api.nvim_del_autocmd, cancel_au_id)
    delete_buffer()
  end
  cancel_au_id = api.nvim_create_autocmd('WinClosed', { nested = true, callback = on_cancel })

  -- Set buffer-local options last (so that user autocmmands could override)
  vim.bo[bufnr].modified, vim.bo[bufnr].modifiable = false, false
  vim.bo[bufnr].buftype, vim.bo[bufnr].filetype = 'acwrite', 'nvimpack'

  -- Attach in-process LSP for more capabilities
  vim.lsp.buf_attach_client(bufnr, require('vim.pack.lsp').client_id)
end

--- @param plug_list vim.pack.PlugList
local function feedback_confirm(plug_list)
  local function finish_update()
    -- TODO(echasnovski): Allow to not update all plugins via LSP code actions
    --- @param p vim.pack.PlugJob
    plug_list.list = vim.tbl_filter(function(p)
      return p.job.err == ''
    end, plug_list.list)
    plug_list:checkout({ skip_same_sha = true })
    feedback_log(plug_list)
  end

  -- Show report in new buffer in separate tabpage
  local lines = compute_feedback_lines(plug_list, { skip_same_sha = false })
  show_confirm_buf(lines, { exec_on_write = finish_update })
end

--- @class vim.pack.keyset.update
--- @inlinedoc
--- @field force? boolean Whether to skip confirmation and make updates immediately. Default `false`.
--- @field offline? boolean Whether to skip downloading new changes from source. Default `false`.

--- Update plugins
---
--- - If not `offline`, download new changes from source.
--- - Infer update info (current/target state, changelog, etc.).
--- - Depending on `force`:
---     - If `false`, show confirmation buffer. It lists data about all set to
---       update plugins. Pending changes starting with `>` will be applied while
---       the ones starting with `<` will be reverted.
---       It has special in-process LSP server attached to provide more interactive
---       features. Currently supported methods:
---         - 'textDocument/documentSymbol' (`gO` via |lsp-defaults|
---           or |vim.lsp.buf.document_symbol()|) - show structure of the buffer.
---         - 'textDocument/hover' (`K` via |lsp-defaults| or |vim.lsp.buf.hover()|) -
---           show more information at cursor. Like details of particular pending
---           change or newer tag.
---
---       Execute |:write| to confirm update, execute |:quit| to discard the update.
---     - If `true`, make updates right away.
---
--- Notes:
--- - Every actual update is logged in "nvimpack.log" file inside "log" |stdpath()|.
---
--- @param names? string[] List of plugin names to update. Must be managed
--- by |vim.pack|, not necessarily already added in current session.
--- Default: names of all plugins added to current session via |vim.pack.add()|.
--- @param opts? vim.pack.keyset.update
function M.update(names, opts)
  vim.validate('names', names, vim.islist, true, 'list')
  opts = vim.tbl_extend('force', { force = false, offline = false }, opts or {})

  local plug_list = PlugList.from_names(names)
  if #plug_list.list == 0 then
    notify('Nothing to update', 'WARN')
    return
  end
  git_ensure_exec()

  -- Download data if asked
  if not opts.offline then
    plug_list:download_updates()
  end

  -- Compute change info: changelog if any, new tags if nothing to update
  plug_list:infer_update_details()

  -- Perform update
  if not opts.force then
    feedback_confirm(plug_list)
    return
  end

  plug_list:checkout({ skip_same_sha = true })
  feedback_log(plug_list)
end

--- Remove plugins from disk
---
--- @param names string[] List of plugin names to remove from disk. Must be managed
--- by |vim.pack|, not necessarily already added in current session.
function M.del(names)
  vim.validate('names', names, vim.islist, false, 'list')

  local plug_list = PlugList.from_names(names)
  if #plug_list.list == 0 then
    notify('Nothing to remove', 'WARN')
    return
  end

  plug_list:trigger_event('PackDeletePre')
  for _, p in ipairs(plug_list.list) do
    vim.fs.rm(p.plug.path, { recursive = true, force = true })
    added_plugins[p.plug.path] = nil
    notify('Removed plugin `' .. p.plug.spec.name .. '`', 'INFO')
  end
  plug_list:trigger_event('PackDelete')
end

--- @inlinedoc
--- @class vim.pack.PlugData
--- @field spec vim.pack.SpecResolved A |vim.pack.Spec| with defaults made explicit.
--- @field path string Plugin's path on disk.
--- @field was_added boolean Whether plugin was added via |vim.pack.add()| in current session.

--- Get data about all plugins managed by |vim.pack|
--- @return vim.pack.PlugData[]
function M.get()
  -- Process added plugins in order they are added. Take into account that
  -- there might be "holes" after `vim.pack.del()`.
  --- @type table<integer,vim.pack.Plug>
  local added = {}
  for _, p in pairs(added_plugins) do
    added[p.id] = p.plug
  end

  --- @type vim.pack.PlugData[]
  local res = {}
  for i = 1, n_added_plugins do
    if added[i] ~= nil then
      res[#res + 1] = { spec = vim.deepcopy(added[i].spec), path = added[i].path, was_added = true }
    end
  end

  -- Process not added plugins
  local plug_dir = get_plug_dir()
  for n, t in vim.fs.dir(plug_dir, { depth = 1 }) do
    local path = vim.fs.joinpath(plug_dir, n)
    if t == 'directory' and not added_plugins[path] then
      local spec = { name = n, source = cli_sync(git_cmd('get_origin'), path) }
      table.insert(res, { spec = spec, path = path, was_added = false })
    end
  end

  -- Make default `version` explicit
  for _, p_data in ipairs(res) do
    if p_data.spec.version == nil then
      p_data.spec.version = git_get_default_branch(p_data.path)
    end
  end

  return res
end

return M
