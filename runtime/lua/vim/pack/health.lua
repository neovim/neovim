local M = {}

local health = vim.health

local function get_lockfile_path()
  return vim.pack._plugin_lock_path or vim.go.packlockfile
end

local function get_plug_dir()
  return vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'core', 'opt')
end

local function git_cmd(cmd, cwd)
  cmd = vim.list_extend({ 'git', '-c', 'gc.auto=0' }, cmd)
  local env = vim.fn.environ() --- @type table<string,string>
  env.GIT_DIR, env.GIT_WORK_TREE = nil, nil
  local sys_opts = { cwd = cwd, text = true, env = env, clear_env = true }
  local out = vim.system(cmd, sys_opts):wait() --- @type vim.SystemCompleted
  if out.code ~= 0 then
    return false, ((out.stderr or ''):gsub('\n+$', ''))
  end
  return true, ((out.stdout or ''):gsub('\n+$', ''))
end

local function check_basics()
  health.start('vim.pack: basics')

  -- Requirements
  if vim.fn.executable('git') == 0 then
    health.warn('`git` executable is required. Install it using your package manager')
    return false, false
  end

  -- Detect if not used
  local lockfile_path = get_lockfile_path()
  local has_lockfile = vim.fn.filereadable(lockfile_path) == 1
  local plug_dir = get_plug_dir()
  local has_plug_dir = vim.fn.isdirectory(plug_dir) == 1
  if not has_lockfile and not has_plug_dir then
    health.ok('`vim.pack` is not used')
    return false, false
  end

  -- General info
  local git = vim.fn.exepath('git')
  local _, version = git_cmd({ 'version' }, vim.uv.cwd())
  health.info(('Git: %s (%s)'):format(version:gsub('^git%s*', ''), git))
  health.info('Lockfile: ' .. lockfile_path)
  health.info('Plugin directory: ' .. plug_dir)

  if has_lockfile and has_plug_dir then
    health.ok('')
  else
    local lockfile_absent = has_lockfile and 'present' or 'absent'
    local plug_dir_absent = has_plug_dir and 'present' or 'absent'
    local msg = ('Lockfile is %s, plugin directory is %s.'):format(lockfile_absent, plug_dir_absent)
      .. ' Restart Nvim and run `vim.pack.add({})` to '
      .. (has_lockfile and 'install plugins from the lockfile' or 'regenerate the lockfile')
    health.warn(msg)
  end

  return has_lockfile, has_plug_dir
end

local function is_version(x)
  return type(x) == 'string' or (type(x) == 'table' and pcall(x.has, x, '1'))
end

local function failed_git_cmd(plug_name, plug_path)
  local msg = ('Failed Git command inside plugin %s.'):format(vim.inspect(plug_name))
    .. ' This is unexpected and should not happen.'
    .. (' Manually delete directory %s and reinstall plugin'):format(plug_path)
  health.error(msg)
  return false
end

--- @return boolean Whether a check is successful
local function check_plugin_lock_data(plug_name, lock_data)
  local name_str = vim.inspect(plug_name)
  local error_with_del_advice = function(reason)
    local msg = ('%s %s.'):format(name_str, reason)
      .. (' Delete %s entry (do not create trailing comma) and '):format(name_str)
      .. 'restart Nvim to regenerate lockfile data'
    health.error(msg)
    return false
  end

  -- Types
  if type(plug_name) ~= 'string' then
    return error_with_del_advice('is not a valid plugin name')
  end
  if type(lock_data) ~= 'table' then
    return error_with_del_advice('entry is not a valid type')
  end
  if type(lock_data.rev) ~= 'string' then
    local reason = '`rev` entry is ' .. (lock_data.rev and 'not a valid type' or 'missing')
    return error_with_del_advice(reason)
  end
  if type(lock_data.src) ~= 'string' then
    local reason = '`src` entry is ' .. (lock_data.src and 'not a valid type' or 'missing')
    return error_with_del_advice(reason)
  end
  if lock_data.version and not is_version(lock_data.version) then
    return error_with_del_advice('`version` entry is not a valid type')
  end

  -- Alignment with what is actually present on disk
  local plug_path = vim.fs.joinpath(get_plug_dir(), plug_name)
  if vim.fn.isdirectory(plug_path) ~= 1 then
    health.warn(
      ('Plugin %s is not installed but present in the lockfile.'):format(name_str)
        .. ' Restart Nvim and run `vim.pack.add({})` to autoinstall.'
        .. (' To fully delete, run `vim.pack.del({ %s }, { force = true })`'):format(name_str)
    )
    return false
  end

  -- NOTE: `vim.pack` currently only supports Git repos as plugins
  if not git_cmd({ 'rev-parse', '--git-dir' }, plug_path) then
    return true
  end

  local has_head, head = git_cmd({ 'rev-list', '-1', 'HEAD' }, plug_path)
  if not has_head then
    return failed_git_cmd(plug_name, plug_path)
  elseif lock_data.rev ~= head then
    health.error(
      ('Plugin %s is not at expected revision\n'):format(name_str)
        .. ('Expected: %s\nActual:   %s\n'):format(lock_data.rev, head)
        .. 'To synchronize, restart Nvim and run '
        .. ('`vim.pack.update({ %s }, { offline = true })`\n'):format(name_str)
        .. 'If there are no updates, delete `rev` lockfile entry (do not create trailing comma) '
        .. 'and restart Nvim to regenerate lockfile data\n'
        .. 'This can happen after updating plugins with read-only `$XDG_CONFIG_HOME`'
    )
    return false
  end

  local has_origin, origin = git_cmd({ 'remote', 'get-url', 'origin' }, plug_path)
  if not has_origin then
    return failed_git_cmd(plug_name, plug_path)
  elseif lock_data.src ~= origin then
    -- Check if lockfile source relies on "insteadOf" Git config
    local ok, src_resolved = git_cmd({ 'ls-remote', '--get-url', lock_data.src }, plug_path)
    if not (ok and src_resolved == origin) then
      health.error(
        ('Plugin %s has not expected source\n'):format(name_str)
          .. ('Expected: %s\nActual:   %s\n'):format(lock_data.src, origin)
          .. 'Delete `src` lockfile entry (do not create trailing comma) and '
          .. 'restart Nvim to regenerate lockfile data'
      )
      return false
    end
  end

  return true
end

local function check_lockfile()
  health.start('vim.pack: lockfile')

  local path = get_lockfile_path()
  local can_read, text = pcall(vim.fn.readblob, path)
  if not can_read then
    health.error('Could not read lockfile. Delete it and restart Nvim.')
    return
  end

  local can_parse, data = pcall(vim.json.decode, text)
  if not can_parse then
    health.error(('Could not parse lockfile: %s\nDelete it and restart Nvim'):format(data))
    return
  end

  if type(data.plugins) ~= 'table' then
    health.error('Field `plugins` is not proper type. Delete lockfile and restart Nvim')
    return
  end

  local is_good = true
  if path ~= vim.go.packlockfile then
    health.warn(
      "Lockfile path is not the same as 'packlockfile' option value. "
        .. "Set 'packlockfile' before the first usage of `vim.pack` function."
    )
    is_good = false
  end
  if path ~= vim.fs.abspath(path) then
    health.warn('Lockfile path is not absolute. Make sure that this is intentional.')
    is_good = false
  end

  --- @cast data { plugins: table<string,table> }
  for plug_name, lock_data in pairs(data.plugins) do
    is_good = check_plugin_lock_data(plug_name, lock_data) and is_good
  end

  if is_good then
    health.ok('')
  end
end

--- @param dep_data vim.pack.ManifestDependency
--- @param src_version_map table<string,any> Map from all installed plugin sources to their version
local function check_manifest_dependency(dep_data, src_version_map)
  local is_proper_shape = type(dep_data) == 'table'
    and type(dep_data.src) == 'string'
    and (dep_data.version == nil or type(dep_data.version) == 'string')
  if not is_proper_shape then
    return false, 'is malformed'
  end

  local src_version = src_version_map[dep_data.src]
  if not src_version then
    return false, dep_data.src .. ' is not installed'
  end

  if dep_data.version then
    local dep_version = dep_data.version:match("^'(.+)'$") or vim.version.range(dep_data.version)
    if not dep_version then
      return false, dep_data.src .. ' has malformed `version`'
    end

    -- Version range match if user specified subset of what is in manifest
    local is_version_exact_match = type(dep_version) == 'string' and dep_version == src_version
    local is_version_range_match, intersect = pcall(vim.version.intersect, dep_version, src_version)
    is_version_range_match = is_version_range_match and intersect == src_version
    if not (is_version_exact_match or is_version_range_match) then
      local msg = ('%s version `%s` does not match installed version `%s`'):format(
        dep_data.src,
        tostring(dep_version),
        src_version == true and 'nil' or tostring(src_version)
      )
      return false, msg
    end
  end

  return true, nil
end

--- @param plug_data vim.pack.PlugData
--- @param all_plug_data vim.pack.PlugData[]
local function check_manifest(plug_data, all_plug_data)
  local name_str = vim.inspect(plug_data.spec.name)
  local manifest = plug_data.manifest --- @type vim.pack.Manifest
  local function warn(msg)
    health.warn(msg .. '\nManifest file: ' .. vim.fs.joinpath(plug_data.path, 'pkg.json'))
  end

  if vim.tbl_count(manifest) == 0 then
    warn(('Plugin %s has empty or malformed manifest file'):format(name_str))
    return false
  end
  local is_good = true

  -- Engine
  local nvim_engine = (manifest.engines or {}).nvim or '*'
  local ok_version, nvim_version_range = pcall(vim.version.range, nvim_engine)
  if not ok_version or nvim_version_range == nil then
    warn(('Plugin %s has malformed `engines.nvim` in manifest file'):format(name_str))
    is_good = false
  elseif not nvim_version_range:has(vim.version()) then
    warn(
      ('Plugin %s Nvim version requirement %s'):format(name_str, tostring(nvim_version_range))
        .. (' does not match current version %s'):format(tostring(vim.version()))
    )
    is_good = false
  end

  -- Scripts
  ---@diagnostic disable-next-line: no-unknown
  for name, script_path in pairs(manifest.scripts or {}) do
    if vim.fn.filereadable(vim.fs.joinpath(plug_data.path, script_path)) == 0 then
      warn(('Plugin %s has no %s script at %s path'):format(name_str, name, script_path))
      is_good = false
    end
  end

  -- Dependencies
  local src_version_map = {} --- @type table<string,any>
  for _, p_data in ipairs(all_plug_data) do
    src_version_map[p_data.spec.src] = p_data.spec.version or p_data.branches[1]
  end
  for _, dep_data in ipairs(manifest.dependencies or {}) do
    local ok_dep, msg = check_manifest_dependency(dep_data, src_version_map)
    if not ok_dep then
      warn(('Plugin %s dependency %s'):format(name_str, msg))
    end
    is_good = is_good and ok_dep
  end

  return is_good
end

--- @param plug_name string
--- @param all_plug_data vim.pack.PlugData[]
--- @return boolean Whether a check is successful
local function check_installed_plugin(plug_name, all_plug_data)
  local name_str = vim.inspect(plug_name)
  local data = {}
  for _, p_data in ipairs(all_plug_data) do
    data = p_data.spec.name == plug_name and p_data or data
  end
  local plug_path = data.path or vim.fs.joinpath(get_plug_dir(), plug_name)

  if vim.fn.isdirectory(plug_path) ~= 1 then
    health.error(('%s is not a directory. Delete it'):format(plug_name))
    return false
  end

  if not git_cmd({ 'rev-parse', '--git-dir' }, plug_path) then
    health.error(
      ('%s is not a Git repository.'):format(name_str)
        .. ' It was not installed by `vim.pack` and should not be present in the plugin directory.'
        .. ' If installed manually, use dedicated `:h packages`'
    )
    return false
  end

  -- Detached HEAD is a sign that plugin is managed by `vim.pack`
  local has_head_ref, head_ref = git_cmd({ 'rev-parse', '--abbrev-ref', 'HEAD' }, plug_path)
  if not has_head_ref then
    return failed_git_cmd(plug_name, plug_path)
  elseif head_ref ~= 'HEAD' then
    health.warn(
      ('Plugin %s is not at state which is a result of `vim.pack` operation.\n'):format(name_str)
        .. 'If it was intentional, make sure you know what you are doing.\n'
        .. 'Otherwise, restart Nvim and run '
        .. ('`vim.pack.update({ %s }, { offline = true })`.\n'):format(name_str)
        .. 'If nothing is updated, plugin is at correct revision and will be managed as expected'
    )
    return false
  end

  -- Usage data
  if data.spec == nil then
    health.error('Could not get `vim.pack` usage information for plugin ' .. name_str)
    return false
  end

  if not data.active then
    health.info(
      ('Plugin %s is not active.'):format(name_str)
        .. ' Is it lazy loaded or did you forget to run `vim.pack.del()`?'
    )
  end

  -- Manifest
  if data.manifest then
    return check_manifest(data, all_plug_data)
  end

  return true
end

local function check_plug_dir()
  health.start('vim.pack: plugin directory')

  local is_good = true
  local plug_dir = get_plug_dir()
  local all_plug_data = vim.pack.get(nil, { info = true })
  for plug_name, _, err in vim.fs.dir(plug_dir, { err = true }) do
    if err then
      health.error(err)
      is_good = false
    else
      is_good = check_installed_plugin(plug_name, all_plug_data) and is_good
    end
  end

  if is_good then
    health.ok('')
  end
end

function M.check()
  local has_lockfile, has_plug_dir = check_basics()
  if has_lockfile then
    check_lockfile()
  end
  if has_plug_dir then
    check_plug_dir()
  end
end

return M
