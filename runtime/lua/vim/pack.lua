--- @brief
---
---WORK IN PROGRESS built-in plugin manager! Early testing of existing features
---is appreciated, but expect breaking changes without notice.
---
---Manages plugins only in a dedicated [vim.pack-directory]() (see |packages|):
---`$XDG_DATA_HOME/nvim/site/pack/core/opt`. `$XDG_DATA_HOME/nvim/site` needs to
---be part of 'packpath'. It usually is, but might not be in cases like |--clean| or
---setting |$XDG_DATA_HOME| during startup.
---Plugin's subdirectory name matches plugin's name in specification.
---It is assumed that all plugins in the directory are managed exclusively by `vim.pack`.
---
---Uses Git to manage plugins and requires present `git` executable of at
---least version 2.36. Target plugins should be Git repositories with versions
---as named tags following semver convention `v<major>.<minor>.<patch>`.
---
---The latest state of all managed plugins is stored inside a [vim.pack-lockfile]()
---located at `$XDG_CONFIG_HOME/nvim/nvim-pack-lock.json`. It is a JSON file that
---is used to persistently track data about plugins.
---For a more robust config treat lockfile like its part: put under version control, etc.
---In this case initial install prefers revision from the lockfile instead of
---inferring from `version`. Should not be edited by hand or deleted.
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
---   { src = 'https://github.com/user/plugin1' },
---
---   -- Specify plugin's name (here the plugin will be called "plugin2"
---   -- instead of "generic-name")
---   { src = 'https://github.com/user/generic-name', name = 'plugin2' },
---
---   -- Specify version to follow during install and update
---   {
---     src = 'https://github.com/user/plugin3',
---     -- Version constraint, see |vim.version.range()|
---     version = vim.version.range('1.0'),
---   },
---   {
---     src = 'https://github.com/user/plugin4',
---     -- Git branch, tag, or commit hash
---     version = 'main',
---   },
---})
---
----- Plugin's code can be used directly after `add()`
---plugin1 = require('plugin1')
---```
---
---- Restart Nvim (for example, with |:restart|). Plugins that were not yet
---installed will be available on disk after `add()` call. Their revision is
---taken from |vim.pack-lockfile| (if present) or inferred from the `version`.
---
---- To update all plugins with new changes:
---    - Execute |vim.pack.update()|. This will download updates from source and
---      show confirmation buffer in a separate tabpage.
---    - Review changes. To confirm all updates execute |:write|.
---      To discard updates execute |:quit|.
---    - (Optionally) |:restart| to start using code from updated plugins.
---
---Switch plugin's version:
---- Update 'init.lua' for plugin to have desired `version`. Let's say, plugin
---named 'plugin1' has changed to `vim.version.range('*')`.
---- |:restart|. The plugin's actual state on disk is not yet changed.
---  Only plugin's `version` in |vim.pack-lockfile| is updated.
---- Execute `vim.pack.update({ 'plugin1' })`.
---- Review changes and either confirm or discard them. If discarded, revert
---any changes in 'init.lua' as well or you will be prompted again next time
---you run |vim.pack.update()|.
---
---Freeze plugin from being updated:
---- Update 'init.lua' for plugin to have `version` set to current revision.
---Get it from |vim.pack-lockfile| (plugin's field `rev`; looks like `abc12345`).
---- |:restart|.
---
---Unfreeze plugin to start receiving updates:
---- Update 'init.lua' for plugin to have `version` set to whichever version
---you want it to be updated.
---- |:restart|.
---
---Remove plugins from disk:
---- Use |vim.pack.del()| with a list of plugin names to remove. Make sure their specs
---are not included in |vim.pack.add()| call in 'init.lua' or they will be reinstalled.
---
---Available events to hook into ~
---
---- [PackChangedPre]() - before trying to change plugin's state.
---- [PackChanged]() - after plugin's state has changed.
---
---Each event populates the following |event-data| fields:
---- `active` - whether plugin was added via |vim.pack.add()| to current session.
---- `kind` - one of "install" (install on disk; before loading),
---  "update" (update already installed plugin; might be not loaded),
---  "delete" (delete from disk).
---- `spec` - plugin's specification with defaults made explicit.
---- `path` - full path to plugin's directory.
---
--- These events can be used to execute plugin hooks. For example:
---```lua
---local hooks = function(ev)
---   -- Use available |event-data|
---   local name, kind = ev.data.spec.name, ev.data.kind
---
---   -- Run build script after plugin's code has changed
---   if name == 'plug-1' and (kind == 'install' or kind == 'update') then
---     vim.system({ 'make' }, { cwd = ev.data.path })
---   end
---
---   -- If action relies on code from the plugin (like user command or
---   -- Lua code), make sure to explicitly load it first
---   if name == 'plug-2' and kind == 'update' then
---     if not ev.data.active then
---       vim.cmd.packadd('plug-2')
---     end
---     vim.cmd('PlugTwoUpdate')
---     require('plug2').after_update()
---   end
---end
---
----- If hooks need to run on install, run this before `vim.pack.add()`
---vim.api.nvim_create_autocmd('PackChanged', { callback = hooks })
---```

local api = vim.api
local uv = vim.uv
local async = require('vim._async')

local M = {}

-- Git ------------------------------------------------------------------------

--- @async
--- @param cmd string[]
--- @param cwd? string
--- @return string
local function git_cmd(cmd, cwd)
  -- Use '-c gc.auto=0' to disable `stderr` "Auto packing..." messages
  cmd = vim.list_extend({ 'git', '-c', 'gc.auto=0' }, cmd)
  local env = vim.fn.environ() --- @type table<string,string>
  env.GIT_DIR, env.GIT_WORK_TREE = nil, nil
  local sys_opts = { cwd = cwd, text = true, env = env, clear_env = true }
  local out = async.await(3, vim.system, cmd, sys_opts) --- @type vim.SystemCompleted
  async.await(1, vim.schedule)
  if out.code ~= 0 then
    error(out.stderr)
  end
  local stdout, stderr = assert(out.stdout), assert(out.stderr)
  if stderr ~= '' then
    vim.schedule(function()
      vim.notify(stderr:gsub('\n+$', ''), vim.log.levels.WARN)
    end)
  end
  return (stdout:gsub('\n+$', ''))
end

local function git_ensure_exec()
  if vim.fn.executable('git') == 0 then
    error('No `git` executable')
  end
end

--- @async
--- @param url string
--- @param path string
local function git_clone(url, path)
  local cmd = { 'clone', '--quiet', '--origin', 'origin', '--no-checkout' }

  if vim.startswith(url, 'file://') then
    cmd[#cmd + 1] = '--no-hardlinks'
  else
    -- NOTE: '--also-filter-submodules' requires Git>=2.36
    local filter_args = { '--filter=blob:none', '--recurse-submodules', '--also-filter-submodules' }
    vim.list_extend(cmd, filter_args)
  end

  vim.list_extend(cmd, { '--origin', 'origin', url, path })
  git_cmd(cmd, uv.cwd())
end

--- @async
--- @param ref string
--- @param cwd string
--- @return string
local function git_get_hash(ref, cwd)
  -- Using `rev-list -1` shows a commit of reference, while `rev-parse` shows
  -- hash of reference. Those are different for annotated tags.
  return git_cmd({ 'rev-list', '-1', ref }, cwd)
end

--- @async
--- @param cwd string
--- @return string
local function git_get_default_branch(cwd)
  local res = git_cmd({ 'rev-parse', '--abbrev-ref', 'origin/HEAD' }, cwd)
  return (res:gsub('^origin/', ''))
end

--- @async
--- @param cwd string
--- @return string[]
local function git_get_branches(cwd)
  local def_branch = git_get_default_branch(cwd)
  local cmd = { 'branch', '--remote', '--list', '--format=%(refname:short)', '--', 'origin/**' }
  local stdout = git_cmd(cmd, cwd)
  local res = {} --- @type string[]
  for l in vim.gsplit(stdout, '\n') do
    local branch = l:match('^origin/(.+)$')
    local pos = branch == def_branch and 1 or (#res + 1)
    table.insert(res, pos, branch)
  end
  return res
end

--- @async
--- @param cwd string
--- @return string[]
local function git_get_tags(cwd)
  local tags = git_cmd({ 'tag', '--list', '--sort=-v:refname' }, cwd)
  return tags == '' and {} or vim.split(tags, '\n')
end

-- Lockfile -------------------------------------------------------------------

--- @return string
local function get_plug_dir()
  return vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'core', 'opt')
end

--- @class (private) vim.pack.LockData
--- @field rev string Latest recorded revision.
--- @field src string Plugin source.
--- @field version? string|vim.VersionRange Plugin `version`, as supplied in `spec`.

--- @class (private) vim.pack.Lock
--- @field plugins table<string, vim.pack.LockData> Map from plugin name to its lock data.

--- @type vim.pack.Lock
local plugin_lock

local function lock_get_path()
  return vim.fs.joinpath(vim.fn.stdpath('config'), 'nvim-pack-lock.json')
end

local function lock_read()
  if plugin_lock then
    return
  end
  local fd = uv.fs_open(lock_get_path(), 'r', 438)
  if not fd then
    plugin_lock = { plugins = {} }
    return
  end
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  assert(uv.fs_close(fd))
  plugin_lock = vim.json.decode(data) --- @type vim.pack.Lock

  -- Deserialize `version`
  for _, l_data in pairs(plugin_lock.plugins) do
    local version = l_data.version
    if type(version) == 'string' then
      l_data.version = version:match("^'(.+)'$") or vim.version.range(version)
    end
  end
end

local function lock_write()
  -- Serialize `version`
  local lock = vim.deepcopy(plugin_lock)
  for _, l_data in pairs(lock.plugins) do
    local version = l_data.version
    if version then
      l_data.version = type(version) == 'string' and ("'%s'"):format(version) or tostring(version)
    end
  end

  local path = lock_get_path()
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local fd = assert(uv.fs_open(path, 'w', 438))

  local data = vim.json.encode(lock, { indent = '  ', sort_keys = true })
  assert(uv.fs_write(fd, data))
  assert(uv.fs_close(fd))
end

-- Plugin operations ----------------------------------------------------------

--- @param msg string|string[]
--- @param level ('DEBUG'|'TRACE'|'INFO'|'WARN'|'ERROR')?
local function notify(msg, level)
  msg = type(msg) == 'table' and table.concat(msg, '\n') or msg
  vim.notify('vim.pack: ' .. msg, vim.log.levels[level or 'INFO'])
  vim.cmd.redraw()
end

--- @param x string|vim.VersionRange
--- @return boolean
local function is_version(x)
  return type(x) == 'string' or (type(x) == 'table' and pcall(x.has, x, '1'))
end

--- @param x string
--- @return boolean
local function is_semver(x)
  return vim.version.parse(x) ~= nil
end

local function is_nonempty_string(x)
  return type(x) == 'string' and x ~= ''
end

--- @return string
local function get_timestamp()
  return vim.fn.strftime('%Y-%m-%d %H:%M:%S')
end

--- @class vim.pack.Spec
---
--- URI from which to install and pull updates. Any format supported by `git clone` is allowed.
--- @field src string
---
--- Name of plugin. Will be used as directory name. Default: `src` repository name.
--- @field name? string
---
--- Version to use for install and updates. Can be:
--- - `nil` (no value, default) to use repository's default branch (usually `main` or `master`).
--- - String to use specific branch, tag, or commit hash.
--- - Output of |vim.version.range()| to install the greatest/last semver tag
---   inside the version constraint.
--- @field version? string|vim.VersionRange
---
--- @field data? any Arbitrary data associated with a plugin.

--- @alias vim.pack.SpecResolved { src: string, name: string, version: nil|string|vim.VersionRange, data: any|nil }

--- @param spec string|vim.pack.Spec
--- @return vim.pack.SpecResolved
local function normalize_spec(spec)
  spec = type(spec) == 'string' and { src = spec } or spec
  vim.validate('spec', spec, 'table')
  vim.validate('spec.src', spec.src, is_nonempty_string, false, 'non-empty string')
  local name = spec.name or spec.src:gsub('%.git$', '')
  name = (type(name) == 'string' and name or ''):match('[^/]+$') or ''
  vim.validate('spec.name', name, is_nonempty_string, true, 'non-empty string')
  vim.validate('spec.version', spec.version, is_version, true, 'string or vim.VersionRange')
  return { src = spec.src, name = name, version = spec.version, data = spec.data }
end

--- @class (private) vim.pack.PlugInfo
--- @field err string The latest error when working on plugin. If non-empty,
---   all further actions should not be done (including triggering events).
--- @field installed? boolean Whether plugin was successfully installed.
--- @field version_str? string `spec.version` with resolved version range.
--- @field version_ref? string Resolved version as Git reference (if different
---   from `version_str`).
--- @field sha_head? string Git hash of HEAD.
--- @field sha_target? string Git hash of `version_ref`.
--- @field update_details? string Details about the update:: changelog if HEAD
---   and target are different, available newer tags otherwise.

--- @class (private) vim.pack.Plug
--- @field spec vim.pack.SpecResolved
--- @field path string
--- @field info vim.pack.PlugInfo Gathered information about plugin.

--- @param spec string|vim.pack.Spec
--- @param plug_dir string?
--- @return vim.pack.Plug
local function new_plug(spec, plug_dir)
  local spec_resolved = normalize_spec(spec)
  local path = vim.fs.joinpath(plug_dir or get_plug_dir(), spec_resolved.name)
  local info = { err = '', installed = uv.fs_stat(path) ~= nil }
  return { spec = spec_resolved, path = path, info = info }
end

--- Normalize plug array: gather non-conflicting data from duplicated entries.
--- @param plugs vim.pack.Plug[]
--- @return vim.pack.Plug[]
local function normalize_plugs(plugs)
  --- @type table<string, { plug: vim.pack.Plug, id: integer }>
  local plug_map = {}
  local n = 0
  for _, p in ipairs(plugs) do
    -- Collect
    if not plug_map[p.path] then
      n = n + 1
      plug_map[p.path] = { plug = p, id = n }
    end
    local p_data = plug_map[p.path]
    -- TODO(echasnovski): if both versions are `vim.VersionRange`, collect as
    -- their intersection. Needs `vim.version.intersect`.
    p_data.plug.spec.version = vim.F.if_nil(p_data.plug.spec.version, p.spec.version)

    -- Ensure no conflicts
    local spec_ref = p_data.plug.spec
    local spec = p.spec
    if spec_ref.src ~= spec.src then
      local src_1 = tostring(spec_ref.src)
      local src_2 = tostring(spec.src)
      error(('Conflicting `src` for `%s`:\n%s\n%s'):format(spec.name, src_1, src_2))
    end
    if spec_ref.version ~= spec.version then
      local ver_1 = tostring(spec_ref.version)
      local ver_2 = tostring(spec.version)
      error(('Conflicting `version` for `%s`:\n%s\n%s'):format(spec.name, ver_1, ver_2))
    end
  end

  --- @type vim.pack.Plug[]
  local res = {}
  for _, p_data in pairs(plug_map) do
    res[p_data.id] = p_data.plug
  end
  assert(#res == n)
  return res
end

--- @param names? string[]
--- @return vim.pack.Plug[]
local function plug_list_from_names(names)
  local p_data_list = M.get(names, { info = false })
  local plug_dir = get_plug_dir()
  local plugs = {} --- @type vim.pack.Plug[]
  for _, p_data in ipairs(p_data_list) do
    plugs[#plugs + 1] = new_plug(p_data.spec, plug_dir)
  end
  return plugs
end

--- Map from plugin path to its data.
--- Use map and not array to avoid linear lookup during startup.
--- @type table<string, { plug: vim.pack.Plug, id: integer }?>
local active_plugins = {}
local n_active_plugins = 0

--- @param p vim.pack.Plug
--- @param event_name 'PackChangedPre'|'PackChanged'
--- @param kind 'install'|'update'|'delete'
local function trigger_event(p, event_name, kind)
  local active = active_plugins[p.path] ~= nil
  local data = { active = active, kind = kind, spec = vim.deepcopy(p.spec), path = p.path }
  api.nvim_exec_autocmds(event_name, { pattern = p.path, data = data })
end

--- @param action string
--- @return fun(kind: 'begin'|'report'|'end', percent: integer, fmt: string, ...:any): nil
local function new_progress_report(action)
  local progress = { kind = 'progress', title = 'vim.pack' }

  return vim.schedule_wrap(function(kind, percent, fmt, ...)
    progress.status = kind == 'end' and 'success' or 'running'
    progress.percent = percent
    local msg = ('%s %s'):format(action, fmt:format(...))
    progress.id = api.nvim_echo({ { msg } }, kind ~= 'report', progress)
    -- Force redraw to show installation progress during startup
    vim.cmd.redraw({ bang = true })
  end)
end

local n_threads = 2 * #(uv.cpu_info() or { {} })
local copcall = package.loaded.jit and pcall or require('coxpcall').pcall

--- Execute function in parallel for each non-errored plugin in the list
--- @param plug_list vim.pack.Plug[]
--- @param f async fun(p: vim.pack.Plug)
--- @param progress_action string
local function run_list(plug_list, f, progress_action)
  local report_progress = new_progress_report(progress_action)

  -- Construct array of functions to execute in parallel
  local n_finished = 0
  local funs = {} --- @type (async fun())[]
  for _, p in ipairs(plug_list) do
    -- Run only for plugins which didn't error before
    if p.info.err == '' then
      --- @async
      funs[#funs + 1] = function()
        local ok, err = copcall(f, p) --[[@as string]]
        if not ok then
          p.info.err = err --- @as string
        end

        -- Show progress
        n_finished = n_finished + 1
        local percent = math.floor(100 * n_finished / #funs)
        report_progress('report', percent, '(%d/%d) - %s', n_finished, #funs, p.spec.name)
      end
    end
  end

  if #funs == 0 then
    return
  end

  -- Run async in parallel but wait for all to finish/timeout
  report_progress('begin', 0, '(0/%d)', #funs)

  --- @async
  local function joined_f()
    async.join(n_threads, funs)
  end
  async.run(joined_f):wait()

  report_progress('end', 100, '(%d/%d)', #funs, #funs)
end

local confirm_all = false

--- @param plug_list vim.pack.Plug[]
--- @return boolean
local function confirm_install(plug_list)
  if confirm_all then
    return true
  end

  local src = {} --- @type string[]
  for _, p in ipairs(plug_list) do
    src[#src + 1] = p.spec.src
  end
  local src_text = table.concat(src, '\n')
  local confirm_msg = ('These plugins will be installed:\n\n%s\n'):format(src_text)
  local res = vim.fn.confirm(confirm_msg, 'Proceed? &Yes\n&No\n&Always', 1, 'Question')
  confirm_all = res == 3
  vim.cmd.redraw()
  return res ~= 2
end

--- @param tags string[]
--- @param version_range vim.VersionRange
local function get_last_semver_tag(tags, version_range)
  local last_tag, last_ver_tag --- @type string, vim.Version
  for _, tag in ipairs(tags) do
    local ver_tag = vim.version.parse(tag)
    if ver_tag then
      if version_range:has(ver_tag) and (not last_ver_tag or ver_tag > last_ver_tag) then
        last_tag, last_ver_tag = tag, ver_tag
      end
    end
  end
  return last_tag
end

--- @async
--- @param p vim.pack.Plug
local function resolve_version(p)
  local function list_in_line(name, list)
    return ('\n%s: %s'):format(name, table.concat(list, ', '))
  end

  -- Resolve only once
  if p.info.version_str then
    return
  end
  local version = p.spec.version

  -- Default branch
  if not version then
    p.info.version_str = git_get_default_branch(p.path)
    p.info.version_ref = 'origin/' .. p.info.version_str
    return
  end

  -- Non-version-range like version: branch, tag, or commit hash
  local branches = git_get_branches(p.path)
  local tags = git_get_tags(p.path)
  if type(version) == 'string' then
    local is_branch = vim.tbl_contains(branches, version)
    local is_tag_or_hash = copcall(git_get_hash, version, p.path)
    if not (is_branch or is_tag_or_hash) then
      local err = ('`%s` is not a branch/tag/commit. Available:'):format(version)
        .. list_in_line('Tags', tags)
        .. list_in_line('Branches', branches)
      error(err)
    end

    p.info.version_str = version
    p.info.version_ref = (is_branch and 'origin/' or '') .. version
    return
  end
  --- @cast version vim.VersionRange

  -- Choose the greatest/last version among all matching semver tags
  p.info.version_str = get_last_semver_tag(tags, version)
  if p.info.version_str == nil then
    local semver_tags = vim.tbl_filter(is_semver, tags)
    table.sort(semver_tags, vim.version.gt)
    local err = 'No versions fit constraint. Relax it or switch to branch. Available:'
      .. list_in_line('Versions', semver_tags)
      .. list_in_line('Branches', branches)
    error(err)
  end
end

--- @async
--- @param p vim.pack.Plug
local function infer_states(p)
  p.info.sha_head = p.info.sha_head or git_get_hash('HEAD', p.path)

  resolve_version(p)
  local target_ref = p.info.version_ref or p.info.version_str --[[@as string]]
  p.info.sha_target = p.info.sha_target or git_get_hash(target_ref, p.path)
end

--- Keep repos in detached HEAD state. Infer commit from resolved version.
--- No local branches are created, branches from "origin" remote are used directly.
--- @async
--- @param p vim.pack.Plug
--- @param timestamp string
local function checkout(p, timestamp)
  infer_states(p)

  local msg = ('vim.pack: %s Stash before checkout'):format(timestamp)
  git_cmd({ 'stash', '--quiet', '--message', msg }, p.path)

  git_cmd({ 'checkout', '--quiet', p.info.sha_target }, p.path)

  plugin_lock.plugins[p.spec.name].rev = p.info.sha_target

  -- (Re)Generate help tags according to the current help files.
  -- Also use `pcall()` because `:helptags` errors if there is no 'doc/'
  -- directory or if it is empty.
  local doc_dir = vim.fs.joinpath(p.path, 'doc')
  vim.fn.delete(vim.fs.joinpath(doc_dir, 'tags'))
  copcall(vim.cmd.helptags, { doc_dir, magic = { file = false } })
end

--- @param plug_list vim.pack.Plug[]
local function install_list(plug_list, confirm)
  -- Get user confirmation to install plugins
  if confirm and not confirm_install(plug_list) then
    for _, p in ipairs(plug_list) do
      p.info.err = 'Installation was not confirmed'
    end
    return
  end

  local timestamp = get_timestamp()
  --- @async
  --- @param p vim.pack.Plug
  local function do_install(p)
    trigger_event(p, 'PackChangedPre', 'install')

    git_clone(p.spec.src, p.path)
    p.info.installed = true

    plugin_lock.plugins[p.spec.name].src = p.spec.src

    -- Prefer revision from the lockfile instead of using `version`
    p.info.sha_target = (plugin_lock.plugins[p.spec.name] or {}).rev

    checkout(p, timestamp)

    trigger_event(p, 'PackChanged', 'install')
  end
  run_list(plug_list, do_install, 'Installing plugins')
end

--- @async
--- @param p vim.pack.Plug
local function infer_update_details(p)
  p.info.update_details = ''
  infer_states(p)
  local sha_head = assert(p.info.sha_head)
  local sha_target = assert(p.info.sha_target)

  -- Try showing log of changes (if any)
  if sha_head ~= sha_target then
    local range = sha_head .. '...' .. sha_target
    local format = '--pretty=format:%m %h │ %s%d'
    -- Show only tags near commits (not `origin/main`, etc.)
    local decorate = '--decorate-refs=refs/tags'
    -- `--topo-order` makes showing divergent branches nicer, but by itself
    -- doesn't ensure that reverted ("left", shown with `<`) and added
    -- ("right", shown with `>`) commits have fixed order.
    local l = git_cmd({ 'log', format, '--topo-order', '--left-only', decorate, range }, p.path)
    local r = git_cmd({ 'log', format, '--topo-order', '--right-only', decorate, range }, p.path)
    p.info.update_details = l == '' and r or (r == '' and l or (l .. '\n' .. r))
    return
  end

  -- Suggest newer semver tags (i.e. greater than greatest past semver tag)
  local all_semver_tags = vim.tbl_filter(is_semver, git_get_tags(p.path))
  if #all_semver_tags == 0 then
    return
  end

  local older_tags = git_cmd({ 'tag', '--list', '--no-contains', sha_head }, p.path)
  local cur_tags = git_cmd({ 'tag', '--list', '--points-at', sha_head }, p.path)
  local past_tags = vim.split(older_tags, '\n')
  vim.list_extend(past_tags, vim.split(cur_tags, '\n'))

  local any_version = vim.version.range('*') --[[@as vim.VersionRange]]
  local last_version = get_last_semver_tag(past_tags, any_version)

  local newer_semver_tags = vim.tbl_filter(function(x) --- @param x string
    return vim.version.gt(x, last_version)
  end, all_semver_tags)

  table.sort(newer_semver_tags, vim.version.gt)
  p.info.update_details = table.concat(newer_semver_tags, '\n')
end

--- @param plug vim.pack.Plug
--- @param load boolean|fun(plug_data: {spec: vim.pack.Spec, path: string})
local function pack_add(plug, load)
  -- Add plugin only once, i.e. no overriding of spec. This allows users to put
  -- plugin first to fully control its spec.
  if active_plugins[plug.path] then
    return
  end

  n_active_plugins = n_active_plugins + 1
  active_plugins[plug.path] = { plug = plug, id = n_active_plugins }

  if vim.is_callable(load) then
    load({ spec = vim.deepcopy(plug.spec), path = plug.path })
    return
  end

  -- NOTE: The `:packadd` specifically seems to not handle spaces in dir name
  vim.cmd.packadd({ vim.fn.escape(plug.spec.name, ' '), bang = not load, magic = { file = false } })

  -- Execute 'after/' scripts if not during startup (when they will be sourced
  -- automatically), as `:packadd` only sources plain 'plugin/' files.
  -- See https://github.com/vim/vim/issues/15584
  -- Deliberately do so after executing all currently known 'plugin/' files.
  if vim.v.vim_did_enter == 1 and load then
    local after_paths = vim.fn.glob(plug.path .. '/after/plugin/**/*.{vim,lua}', false, true)
    --- @param path string
    vim.tbl_map(function(path)
      vim.cmd.source({ path, magic = { file = false } })
    end, after_paths)
  end
end

--- @class vim.pack.keyset.add
--- @inlinedoc
--- Load `plugin/` files and `ftdetect/` scripts. If `false`, works like `:packadd!`.
--- If function, called with plugin data and is fully responsible for loading plugin.
--- Default `false` during startup and `true` afterwards.
--- @field load? boolean|fun(plug_data: {spec: vim.pack.Spec, path: string})
---
--- @field confirm? boolean Whether to ask user to confirm initial install. Default `true`.

--- Add plugin to current session
---
--- - For each specification check that plugin exists on disk in |vim.pack-directory|:
---     - If exists, do nothing in this step.
---     - If doesn't exist, install it by downloading from `src` into `name`
---       subdirectory (via `git clone`) and update state to match `version` (via `git checkout`).
--- - For each plugin execute |:packadd| (or customizable `load` function) making
---   it reachable by Nvim.
---
--- Notes:
--- - Installation is done in parallel, but waits for all to finish before
---   continuing next code execution.
--- - If plugin is already present on disk, there are no checks about its present state.
---   The specified `version` can be not the one actually present on disk.
---   Execute |vim.pack.update()| to synchronize.
--- - Adding plugin second and more times during single session does nothing:
---   only the data from the first adding is registered.
---
--- @param specs (string|vim.pack.Spec)[] List of plugin specifications. String item
--- is treated as `src`.
--- @param opts? vim.pack.keyset.add
function M.add(specs, opts)
  vim.validate('specs', specs, vim.islist, false, 'list')
  opts = vim.tbl_extend('force', { load = vim.v.vim_did_enter == 1, confirm = true }, opts or {})
  vim.validate('opts', opts, 'table')

  local plug_dir = get_plug_dir()
  local plugs = {} --- @type vim.pack.Plug[]
  for i = 1, #specs do
    plugs[i] = new_plug(specs[i], plug_dir)
  end
  plugs = normalize_plugs(plugs)

  -- Pre-process
  lock_read()
  local plugs_to_install = {} --- @type vim.pack.Plug[]
  local needs_lock_write = false
  for _, p in ipairs(plugs) do
    -- TODO(echasnovski): check that lock's `src` is the same as in spec.
    -- If not - cleanly reclone (delete directory and mark as not installed).
    local p_lock = plugin_lock.plugins[p.spec.name] or {}
    needs_lock_write = needs_lock_write or p_lock.version ~= p.spec.version
    p_lock.version = p.spec.version
    plugin_lock.plugins[p.spec.name] = p_lock

    if not p.info.installed then
      plugs_to_install[#plugs_to_install + 1] = p
      needs_lock_write = true
    end
  end

  -- Install
  if #plugs_to_install > 0 then
    git_ensure_exec()
    install_list(plugs_to_install, opts.confirm)
    for _, p in ipairs(plugs_to_install) do
      if not p.info.installed then
        plugin_lock.plugins[p.spec.name] = nil
      end
    end
  end

  if needs_lock_write then
    lock_write()
  end

  -- Register and load those actually on disk while collecting errors
  -- Delay showing all errors to have "good" plugins added first
  local errors = {} --- @type string[]
  for _, p in ipairs(plugs) do
    if p.info.installed then
      local ok, err = pcall(pack_add, p, opts.load) --[[@as string]]
      if not ok then
        p.info.err = err
      end
    end
    if p.info.err ~= '' then
      errors[#errors + 1] = ('`%s`:\n%s'):format(p.spec.name, p.info.err)
    end
  end

  if #errors > 0 then
    local error_str = table.concat(errors, '\n\n')
    error(('vim.pack:\n\n%s'):format(error_str))
  end
end

--- @param p vim.pack.Plug
--- @return string
local function compute_feedback_lines_single(p)
  if p.info.err ~= '' then
    return ('## %s\n\n %s'):format(p.spec.name, p.info.err:gsub('\n', '\n  '))
  end

  local parts = { '## ' .. p.spec.name .. '\n' }
  local version_suffix = p.info.version_str == '' and '' or (' (%s)'):format(p.info.version_str)

  if p.info.sha_head == p.info.sha_target then
    parts[#parts + 1] = table.concat({
      'Path:   ' .. p.path,
      'Source: ' .. p.spec.src,
      'State:  ' .. p.info.sha_target .. version_suffix,
    }, '\n')

    if p.info.update_details ~= '' then
      local details = p.info.update_details:gsub('\n', '\n• ')
      parts[#parts + 1] = '\n\nAvailable newer versions:\n• ' .. details
    end
  else
    parts[#parts + 1] = table.concat({
      'Path:         ' .. p.path,
      'Source:       ' .. p.spec.src,
      'State before: ' .. p.info.sha_head,
      'State after:  ' .. p.info.sha_target .. version_suffix,
      '',
      'Pending updates:',
      p.info.update_details,
    }, '\n')
  end

  return table.concat(parts, '')
end

--- @param plug_list vim.pack.Plug[]
--- @param skip_same_sha boolean
--- @return string[]
local function compute_feedback_lines(plug_list, skip_same_sha)
  -- Construct plugin line groups for better report
  local report_err, report_update, report_same = {}, {}, {}
  for _, p in ipairs(plug_list) do
    --- @type string[]
    local group_arr = p.info.err ~= '' and report_err
      or (p.info.sha_head ~= p.info.sha_target and report_update or report_same)
    group_arr[#group_arr + 1] = compute_feedback_lines_single(p)
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
  if not skip_same_sha then
    append_report('# Same', report_same)
  end

  return vim.split(table.concat(lines, '\n\n'), '\n')
end

--- @param plug_list vim.pack.Plug[]
local function feedback_log(plug_list)
  local lines = { ('========== Update %s =========='):format(get_timestamp()) }
  vim.list_extend(lines, compute_feedback_lines(plug_list, true))
  lines[#lines + 1] = ''

  local log_path = vim.fn.stdpath('log') .. '/nvim-pack.log'
  vim.fn.mkdir(vim.fs.dirname(log_path), 'p')
  vim.fn.writefile(lines, log_path, 'a')
end

--- @param lines string[]
--- @param on_finish fun(bufnr: integer)
local function show_confirm_buf(lines, on_finish)
  -- Show buffer in a separate tabpage
  local bufnr = api.nvim_create_buf(true, true)
  api.nvim_buf_set_name(bufnr, 'nvim-pack://' .. bufnr .. '/confirm-update')
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.cmd.sbuffer({ bufnr, mods = { tab = vim.fn.tabpagenr() } })
  local tab_id = api.nvim_get_current_tabpage()
  local win_id = api.nvim_get_current_win()

  local delete_buffer = vim.schedule_wrap(function()
    pcall(api.nvim_buf_delete, bufnr, { force = true })
    if api.nvim_tabpage_is_valid(tab_id) then
      vim.cmd.tabclose(api.nvim_tabpage_get_number(tab_id))
    end
    vim.cmd.redraw()
  end)

  -- Define action on accepting confirm
  local function finish()
    on_finish(bufnr)
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
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].buftype = 'acwrite'
  vim.bo[bufnr].filetype = 'nvim-pack'

  -- Attach in-process LSP for more capabilities
  vim.lsp.buf_attach_client(bufnr, require('vim.pack._lsp').client_id)
end

--- Get map of plugin names that need update based on confirmation buffer
--- content: all plugin sections present in "# Update" section.
--- @param bufnr integer
--- @return table<string,boolean>
local function get_update_map(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  --- @type table<string,boolean>, boolean
  local res, is_in_update = {}, false
  for _, l in ipairs(lines) do
    local name = l:match('^## (.+)$')
    if name and is_in_update then
      res[name] = true
    end

    local group = l:match('^# (%S+)')
    if group then
      is_in_update = group == 'Update'
    end
  end
  return res
end

--- @class vim.pack.keyset.update
--- @inlinedoc
--- @field force? boolean Whether to skip confirmation and make updates immediately. Default `false`.

--- Update plugins
---
--- - Download new changes from source.
--- - Infer update info (current/target state, changelog, etc.).
--- - Depending on `force`:
---     - If `false`, show confirmation buffer. It lists data about all set to
---       update plugins. Pending changes starting with `>` will be applied while
---       the ones starting with `<` will be reverted.
---       It has dedicated buffer-local mappings:
---       - |]]| and |[[| to navigate through plugin sections.
---
---       Some features are provided  via LSP:
---         - 'textDocument/documentSymbol' (`gO` via |lsp-defaults|
---           or |vim.lsp.buf.document_symbol()|) - show structure of the buffer.
---         - 'textDocument/hover' (`K` via |lsp-defaults| or |vim.lsp.buf.hover()|) -
---           show more information at cursor. Like details of particular pending
---           change or newer tag.
---         - 'textDocument/codeAction' (`gra` via |lsp-defaults| or |vim.lsp.buf.code_action()|) -
---           show code actions available for "plugin at cursor". Like "delete", "update",
---           or "skip updating".
---
---       Execute |:write| to confirm update, execute |:quit| to discard the update.
---     - If `true`, make updates right away.
---
--- Notes:
--- - Every actual update is logged in "nvim-pack.log" file inside "log" |stdpath()|.
---
--- @param names? string[] List of plugin names to update. Must be managed
--- by |vim.pack|, not necessarily already added to current session.
--- Default: names of all plugins managed by |vim.pack|.
--- @param opts? vim.pack.keyset.update
function M.update(names, opts)
  vim.validate('names', names, vim.islist, true, 'list')
  opts = vim.tbl_extend('force', { force = false }, opts or {})

  local plug_list = plug_list_from_names(names)
  if #plug_list == 0 then
    notify('Nothing to update', 'WARN')
    return
  end
  git_ensure_exec()
  lock_read()

  -- Perform update
  local timestamp = get_timestamp()

  --- @async
  --- @param p vim.pack.Plug
  local function do_update(p)
    -- Fetch
    if not opts._offline then
      -- Using '--tags --force' means conflicting tags will be synced with remote
      local args = { 'fetch', '--quiet', '--tags', '--force', '--recurse-submodules=yes', 'origin' }
      git_cmd(args, p.path)
    end

    -- Compute change info: changelog if any, new tags if nothing to update
    infer_update_details(p)

    -- Checkout immediately if no need to confirm
    if opts.force and p.info.sha_head ~= p.info.sha_target then
      trigger_event(p, 'PackChangedPre', 'update')
      checkout(p, timestamp)
      trigger_event(p, 'PackChanged', 'update')
    end
  end
  local progress_title = opts.force and (opts._offline and 'Applying updates' or 'Updating')
    or 'Downloading updates'
  run_list(plug_list, do_update, progress_title)

  if opts.force then
    lock_write()
    feedback_log(plug_list)
    return
  end

  -- Show report in new buffer in separate tabpage
  local lines = compute_feedback_lines(plug_list, false)
  show_confirm_buf(lines, function(bufnr)
    local to_update = get_update_map(bufnr)
    if not next(to_update) then
      notify('Nothing to update', 'WARN')
      return
    end

    --- @param p vim.pack.Plug
    local plugs_to_checkout = vim.tbl_filter(function(p)
      return to_update[p.spec.name]
    end, plug_list)

    local timestamp2 = get_timestamp()
    --- @async
    --- @param p vim.pack.Plug
    local function do_checkout(p)
      trigger_event(p, 'PackChangedPre', 'update')
      checkout(p, timestamp2)
      trigger_event(p, 'PackChanged', 'update')
    end
    run_list(plugs_to_checkout, do_checkout, 'Applying updates')

    lock_write()
    feedback_log(plugs_to_checkout)
  end)
end

--- Remove plugins from disk
---
--- @param names string[] List of plugin names to remove from disk. Must be managed
--- by |vim.pack|, not necessarily already added to current session.
function M.del(names)
  vim.validate('names', names, vim.islist, false, 'list')

  local plug_list = plug_list_from_names(names)
  if #plug_list == 0 then
    notify('Nothing to remove', 'WARN')
    return
  end

  lock_read()

  for _, p in ipairs(plug_list) do
    trigger_event(p, 'PackChangedPre', 'delete')

    vim.fs.rm(p.path, { recursive = true, force = true })
    active_plugins[p.path] = nil
    notify(("Removed plugin '%s'"):format(p.spec.name), 'INFO')

    plugin_lock.plugins[p.spec.name] = nil

    trigger_event(p, 'PackChanged', 'delete')
  end

  lock_write()
end

--- @inlinedoc
--- @class vim.pack.PlugData
--- @field active boolean Whether plugin was added via |vim.pack.add()| to current session.
--- @field branches? string[] Available Git branches (first is default). Missing if `info=false`.
--- @field path string Plugin's path on disk.
--- @field rev string Current Git revision.
--- @field spec vim.pack.SpecResolved A |vim.pack.Spec| with resolved `name`.
--- @field tags? string[] Available Git tags. Missing if `info=false`.

--- @class vim.pack.keyset.get
--- @inlinedoc
--- @field info boolean Whether to include extra plugin info. Default `true`.

--- @param p_data_list vim.pack.PlugData[]
local function add_p_data_info(p_data_list)
  local funs = {} --- @type (async fun())[]
  for i, p_data in ipairs(p_data_list) do
    local path = p_data.path
    --- @async
    funs[i] = function()
      p_data.branches = git_get_branches(path)
      p_data.tags = git_get_tags(path)
    end
  end
  --- @async
  local function joined_f()
    async.join(n_threads, funs)
  end
  async.run(joined_f):wait()
end

--- Gets |vim.pack| plugin info, optionally filtered by `names`.
--- @param names? string[] List of plugin names. Default: all plugins managed by |vim.pack|.
--- @param opts? vim.pack.keyset.get
--- @return vim.pack.PlugData[]
function M.get(names, opts)
  vim.validate('names', names, vim.islist, true, 'list')
  opts = vim.tbl_extend('force', { info = true }, opts or {})

  -- Process active plugins in order they were added. Take into account that
  -- there might be "holes" after `vim.pack.del()`.
  local active = {} --- @type table<integer,vim.pack.Plug?>
  for _, p_active in pairs(active_plugins) do
    active[p_active.id] = p_active.plug
  end

  lock_read()
  local res = {} --- @type vim.pack.PlugData[]
  local used_names = {} --- @type table<string,boolean>
  for i = 1, n_active_plugins do
    if active[i] and (not names or vim.tbl_contains(names, active[i].spec.name)) then
      local name = active[i].spec.name
      local spec = vim.deepcopy(active[i].spec)
      local rev = (plugin_lock.plugins[name] or {}).rev
      res[#res + 1] = { spec = spec, path = active[i].path, rev = rev, active = true }
      used_names[name] = true
    end
  end

  local plug_dir = get_plug_dir()
  for name, l_data in vim.spairs(plugin_lock.plugins) do
    local path = vim.fs.joinpath(plug_dir, name)
    local is_in_names = not names or vim.tbl_contains(names, name)
    if not active_plugins[path] and is_in_names then
      local spec = { name = name, src = l_data.src, version = l_data.version }
      res[#res + 1] = { spec = spec, path = path, rev = l_data.rev, active = false }
      used_names[name] = true
    end
  end

  if names ~= nil then
    -- Align result with input
    local names_order = {} --- @type table<string,integer>
    for i, n in ipairs(names) do
      if not used_names[n] then
        error(('Plugin `%s` is not installed'):format(tostring(n)))
      end
      names_order[n] = i
    end
    table.sort(res, function(a, b)
      return names_order[a.spec.name] < names_order[b.spec.name]
    end)
  end

  if opts.info then
    add_p_data_info(res)
  end

  return res
end

return M
