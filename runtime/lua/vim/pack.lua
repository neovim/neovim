local uv = vim.uv

local M = {}

--- @class vim.pack.PackageSpec
--- @field [1] string
--- @field build string?
--- @field branch string?
--- @field pin boolean?
--- @field opt boolean?
--- @field as string?

--- @class vim.pack.Package
--- @field name string
--- @field dir string
--- @field status vim.pack.Status
--- @field hash string
--- @field url string
--- @field pin boolean?
--- @field branch string?
--- @field build string? | function?

--- @nodoc
--- @enum vim.pack.Status
M.status = {
  INSTALLED = 0,
  CLONED = 1,
  UPDATED = 2,
  REMOVED = 3,
  TO_INSTALL = 4,
}

--- List of packages to build
--- @type vim.pack.Package[]
local BuildQueue = {}

--- Table of pgks loaded from the lockfile
--- @type table<string, vim.pack.Package>
local Lock = {}

--- Table of pkgs loaded from the user configuration
--- @type table<string, vim.pack.Package>
local Packages = {}

--- @type table<string, string>
local Path = {
  lock = vim.fs.joinpath(vim.fn.stdpath('state'), 'pack-lock.json'),
  log = vim.fs.joinpath(vim.fn.stdpath('log'), 'pack.log'),
  packs = vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'packs', 'opt'),
}

--- @class vim.pack.Opts
---
--- Format string used to transform the package name into a git url.
--- (default: `https://%s.git`)
--- @field url_format string
---
--- Flags passed to `git clone` during installation of a plugin (see `:Man git-clone(1)` for more)
--- (default: `{ "--depth=1", "--recurse-submodules", "--shallow-submodules", "--no-single-branch" }`)
--- @field clone_args string[]
---
--- Flags passed to `git pull` during update of a plugin (see `:Man git-pull(1)` for more)
--- (default: `{ "--tags", "--force", "--recurse-submodules", "--update-shallow" }`)
--- @field pull_args string[]
---
--- Controls if the packages should be loaded by deafault
--- (default: `false`)
--- @field opt boolean
local Config = {
  -- Using '--tags --force' means conflicting tags will be synced with remote
  clone_args = { '--depth=1', '--recurse-submodules', '--shallow-submodules', '--no-single-branch' },
  pull_args = { '--tags', '--force', '--recurse-submodules', '--update-shallow' },
  url_format = 'https://%s.git',
  opt = false,
}

--- @enum Messages
local Messages = {
  install = { ok = 'Installed', err = 'Failed to install' },
  update = { ok = 'Updated', err = 'Failed to update', nop = '(up-to-date)' },
  remove = { ok = 'Removed', err = 'Failed to remove' },
  build = { ok = 'Built', err = 'Failed to build' },
}

--- @enum Filter
local Filter = {
  installed = function(p)
    return p.status ~= M.status.REMOVED and p.status ~= M.status.TO_INSTALL
  end,
  not_removed = function(p)
    return p.status ~= M.status.REMOVED
  end,
  removed = function(p)
    return p.status == M.status.REMOVED
  end,
  to_install = function(p)
    return p.status == M.status.TO_INSTALL
  end,
  to_update = function(p)
    return p.status ~= M.status.REMOVED and p.status ~= M.status.TO_INSTALL and not p.pin
  end,
}

--- @param path string
--- @param flags string|integer
--- @param data string
local function file_write(path, flags, data)
  local err_msg = "Failed to %s '" .. path .. "'"
  local file = assert(uv.fs_open(path, flags, 0x1A4), err_msg:format('open'))

  if uv.fs_write(file, data) ~= #data then
    assert(uv.fs_close(file), err_msg:format('close'))
    error(err_msg:format('write'))
  end

  assert(uv.fs_close(file), err_msg:format('close'))
end

--- @param path string
--- @return string
local function file_read(path)
  local err_msg = "Failed to %s '" .. path .. "'"
  local file = assert(uv.fs_open(path, 'r', 0x1A4), err_msg:format('open'))

  ---@generic T
  ---@param cond? T
  ---@param message? any
  ---@return T
  ---@return any ...
  local safe_assert = function(cond, message)
    if not cond then
      assert(uv.fs_close(file), err_msg:format('close'))
    end
    return assert(cond, message)
  end

  local stat = safe_assert(uv.fs_stat(path), err_msg:format('get stats for'))
  local data = uv.fs_read(file, stat.size, 0)
  safe_assert(data and #data == stat.size, err_msg:format('read'))
  --- @cast data string

  assert(uv.fs_close(file), err_msg:format('close'))

  return data
end

--- @return vim.pack.Package[]
local function find_unlisted()
  local unlisted = {}
  for name, type in vim.fs.dir(Path.packs) do
    if type == 'directory' then
      local dir = vim.fs.joinpath(Path.packs, name)
      local pkg = Packages[name]
      if not pkg or pkg.dir ~= dir then
        table.insert(unlisted, { name = name, dir = dir })
      end
    end
  end
  return unlisted
end

--- @param dir string
--- @return string
local function get_git_hash(dir)
  local first_line = function(path)
    local data = file_read(path)
    return vim.split(data, '\n')[1]
  end
  local head_ref = first_line(vim.fs.joinpath(dir, '.git', 'HEAD'))
  return head_ref and first_line(vim.fs.joinpath(dir, '.git', head_ref:sub(6, -1)))
end

--- @param pkg vim.pack.Package
--- @param prev_hash string
--- @param cur_hash string
local function log_update_changes(pkg, prev_hash, cur_hash)
  vim.system(
    { 'git', 'log', '--pretty=format:* %s', ('%s..%s'):format(prev_hash, cur_hash) },
    { cwd = pkg.dir, text = true },
    function(obj)
      if obj.code ~= 0 then
        local msg = ('\nFailed to execute git log into %q (code %d):\n%s\n'):format(
          pkg.dir,
          obj.code,
          obj.stderr
        )
        file_write(Path.log, 'a+', msg)
        return
      end
      local output = ('\n%s updated:\n%s\n'):format(pkg.name, obj.stdout)
      file_write(Path.log, 'a+', output)
    end
  )
end

--- @param name string
--- @param msg_op Messages
--- @param result string
--- @param n integer?
--- @param total integer?
local function report(name, msg_op, result, n, total)
  local count = n and (' [%d/%d]'):format(n, total) or ''
  vim.notify(
    ('Pack:%s %s %s'):format(count, msg_op[result], name),
    result == 'err' and vim.log.levels.ERROR or vim.log.levels.INFO
  )
end

--- Object to track result of operations (installs, updates, etc.)
--- @param total integer
--- @param callback function
--- @return function
local function new_counter(total, callback)
  local c = { ok = 0, err = 0, nop = 0 }
  return vim.schedule_wrap(function(name, msg_op, result)
    if c.ok + c.err + c.nop < total then
      c[result] = c[result] + 1
      if result ~= 'nop' then
        report(name, msg_op, result, c.ok + c.nop, total)
      end
    end

    if c.ok + c.err + c.nop == total then
      callback(c.ok, c.err, c.nop)
    end
  end)
end

local function lock_write()
  -- remove run key since can have a function in it, and
  -- json.encode doesn't support functions
  local pkgs = vim.deepcopy(Packages)
  for p, _ in pairs(pkgs) do
    pkgs[p].build = nil
  end
  local ok, result = pcall(vim.json.encode, pkgs)
  if not ok then
    error(result)
  end
  -- Ignore if fail
  pcall(file_write, Path.lock, 'w', result)
  Lock = Packages
end

local function lock_load()
  local exists, data = pcall(file_read, Path.lock)
  if exists then
    local ok, result = pcall(vim.json.decode, data)
    if ok then
      Lock = not vim.tbl_isempty(result) and result or Packages
      -- Repopulate 'build' key so 'vim.deep_equal' works
      for name, pkg in
        pairs(result --[[@as table<string, vim.pack.PackageSpec>]])
      do
        pkg.build = Packages[name] and Packages[name].build or nil
      end
    end
  else
    lock_write()
    Lock = Packages
  end
end

--- @param pkg vim.pack.Package
--- @param counter function
local function clone(pkg, counter)
  local args = vim.list_extend({ 'git', 'clone', pkg.url }, Config.clone_args)
  if pkg.branch then
    vim.list_extend(args, { '-b', pkg.branch })
  end
  table.insert(args, pkg.dir)
  vim.system(args, {}, function(obj)
    local ok = obj.code == 0
    if ok then
      pkg.status = M.status.CLONED
      if pkg.build then
        table.insert(BuildQueue, pkg)
      end
    end
    counter(pkg.name, Messages.install, ok and 'ok' or 'err')
  end)
end

--- @param pkg vim.pack.Package
--- @param counter function
local function pull(pkg, counter)
  local prev_hash = Lock[pkg.name] and Lock[pkg.name].hash or pkg.hash
  vim.system(vim.list_extend({ 'git', 'pull' }, Config.pull_args), { cwd = pkg.dir }, function(obj)
    if obj.code ~= 0 then
      counter(pkg.name, Messages.update, 'err')
      local errmsg = ('\nFailed to update %s:\n%s\n'):format(pkg.name, obj.stderr)
      file_write(Path.log, 'a+', errmsg)
      return
    end
    local cur_hash = get_git_hash(pkg.dir)
    -- It can happen that the user has deleted manually a directory.
    -- Thus the pkg.hash is left blank and we need to update it.
    if cur_hash == prev_hash or prev_hash == '' then
      pkg.hash = cur_hash
      counter(pkg.name, Messages.update, 'nop')
      return
    end
    log_update_changes(pkg, prev_hash or '', cur_hash)
    pkg.status, pkg.hash = M.status.UPDATED, cur_hash
    counter(pkg.name, Messages.update, 'ok')
    if pkg.build then
      table.insert(BuildQueue, pkg)
    end
  end)
end

--- @param pkg vim.pack.Package
--- @param counter function
local function clone_or_pull(pkg, counter)
  if Filter.to_update(pkg) then
    pull(pkg, counter)
  elseif Filter.to_install(pkg) then
    clone(pkg, counter)
  end
end

local function process_build_queue()
  local failed = {}

  local after = function(pkg, ok)
    report(pkg.name, Messages.build, ok)
    if not ok then
      table.insert(failed, pkg)
    end
  end

  for _, pkg in ipairs(BuildQueue) do
    local t = type(pkg.build)
    if t == 'function' then
      ---@diagnostic disable-next-line: param-type-mismatch
      local ok = pcall(pkg.build)
      after(pkg, ok)
    elseif t == 'string' and vim.startswith(pkg.build, ':') then
      ---@diagnostic disable-next-line: param-type-mismatch
      local ok = pcall(vim.cmd, pkg.build)
      after(pkg, ok)
    elseif t == 'string' then
      local args = vim.split(pkg.build, '%s', { trimempty = true })
      vim.system(
        args,
        { cwd = pkg.dir },
        vim.schedule_wrap(function(obj)
          after(pkg, obj.code == 0)
        end)
      )
    end
  end

  BuildQueue = failed
end

--- @param pkg vim.pack.Package
local function reclone(pkg)
  local ok = pcall(vim.fs.rm, pkg.dir, { recursive = true })
  if ok then
    clone(pkg, function() end)
  end
end

--- @param conflict pack.Conflict
local function resolve(conflict)
  reclone(conflict.curr)
end

--- @param pkg string|vim.pack.PackageSpec
--- @return vim.pack.Package
local function register(pkg)
  if type(pkg) == 'string' then
    pkg = { pkg }
  end

  local url = (pkg[1]:match('^https?://') and pkg[1]) -- [1] is a URL
    or string.format(Config.url_format, pkg[1]) -- [1] is a repository name

  local name = pkg.as or url:gsub('%.git$', ''):match('/([%w-_.]+)$') -- Infer name from `url`
  if not name then
    error('Failed to parse ' .. vim.inspect(pkg))
  end

  local dir = vim.fs.joinpath(Path.packs, name)
  local ok, hash = pcall(get_git_hash, dir)
  hash = ok and hash or ''
  local opt = pkg.opt or Config.opt and pkg.opt == nil

  return {
    branch = pkg.branch,
    build = pkg.build,
    dir = dir,
    hash = hash,
    name = name,
    opt = pkg.opt,
    pin = pkg.pin,
    status = uv.fs_stat(dir) and M.status.INSTALLED or M.status.TO_INSTALL,
    url = url,
  }
end

--- @param pkg vim.pack.Package
--- @param counter function
local function remove(pkg, counter)
  local ok = pcall(vim.fs.rm, pkg.dir, { recursive = true })
  counter(pkg.name, Messages.remove, ok and 'ok' or 'err')
  if not ok then
    return
  end
  pkg.status = M.status.REMOVED
  Packages[pkg.name] = pkg
end

--- @nodoc
--- @class pack.Conflict
--- @field prev vim.pack.Package
--- @field curr vim.pack.Package
---
--- @return pack.Conflict[]
local function calculate_conflicts()
  local conflicts = {}
  for name, lock in pairs(Lock) do
    local pkg = Packages[name]
    if pkg and Filter.not_removed(lock) and (lock.branch ~= pkg.branch or lock.url ~= pkg.url) then
      table.insert(conflicts, { prev = lock, curr = pkg })
    end
  end
  return conflicts
end

--- @nodoc
--- @alias Operation
--- | '"install"'
--- | '"update"'
--- | '"remove"'
--- | '"sync"'
---
--- Boilerplate around operations (autocmds, counter initialization, etc.)
--- @param op Operation
--- @param fn function
--- @param pkgs vim.pack.Package[]
local function exe_op(op, fn, pkgs)
  if vim.tbl_isempty(pkgs) then
    vim.notify('Pack: Nothing to ' .. op)

    vim.api.nvim_exec_autocmds('User', {
      pattern = 'PackDone' .. op:gsub('^%l', string.upper),
    })
    return
  end

  local function after(ok, err, nop)
    local summary = 'Pack: %s complete. %d ok; %d errors;' .. (nop > 0 and ' %d no-ops' or '')
    vim.notify(string.format(summary, op, ok, err, nop))
    vim.cmd('silent! helptags ALL')

    if #BuildQueue ~= 0 then
      process_build_queue()
    end

    vim.api.nvim_exec_autocmds('User', { pattern = 'PackDone' .. op:gsub('^%l', string.upper) })

    -- This makes the logfile reload if there were changes while the job was running
    vim.cmd('silent! checktime ' .. vim.fn.fnameescape(Path.log))

    lock_write()
  end

  local counter = new_counter(#pkgs, after)

  for _, pkg in ipairs(pkgs) do
    fn(pkg, counter)
  end
end

---@param opts vim.pack.Opts? When omitted or `nil`, retrieve the current
---       configuration. Otherwise, a configuration table (see |vim.pack.Opts|).
---@return vim.pack.Opts? : Current pack config if {opts} is omitted.
function M.config(opts)
  vim.validate('opts', opts, 'table', true)

  if not opts then
    return vim.deepcopy(Config, true)
  end

  vim.iter(opts):each(function(k, v)
    Config[k] = v
  end)
end

--- Register one or more plugins to be installed (see [pack.PackageSpec]())
---
--- Example:
---
--- ```lua
--- -- pack will update by itself
--- pack.register({
---   "neovim/nvim-lspconfig",
---   { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
---   -- don't load this plugin when registering. The user needs to call `packadd`.
---   { 'tpope/vim-fugitive', opt = true },
--- })
--- ```
---
--- @param pkgs vim.pack.PackageSpec[]
function M.register(pkgs)
  vim.validate('pkgs', pkgs, { 'table' }, true)

  -- Register plugins and load them
  local errors = {}
  Packages = vim
    .iter(pkgs)
    :map(function(spec)
      local ok, pkg = pcall(register, spec)
      if not ok then
        table.insert(errors, pkg)
      else
        return pkg
      end
    end)
    :fold(
      {},
      --- @param acc table<string, vim.pack.Package>
      --- @param pkg vim.pack.Package
      function(acc, pkg)
        acc[pkg.name] = pkg
        if not pkg.opt then
          pcall(vim.cmd.packadd, pkg.name)
          -- Remove opt from the schema
          ---@diagnostic disable-next-line: inject-field, no-unknown
          pkg.opt = nil
        end
        return acc
      end
    )

  -- Resolve conflict between user configuration and lockfile
  vim.iter(calculate_conflicts()):each(resolve)

  vim.iter(errors):each(function(error)
    file_write(Path.log, 'a+', '\n' .. error)
  end)

  if #errors > 0 then
    vim.notify(
      ('Pack: %d packages failed to be parsed. Check :PackLogOpen to learn more'):format(#errors),
      vim.log.levels.ERROR
    )
  end
end

--- Installs not already installed registered plugins
---
--- Can also be invoked with `PackInstall`. [PackInstall]()
function M.install()
  exe_op('install', clone, vim.tbl_filter(Filter.to_install, Packages))
end

--- Updates all registered plugins
---
--- Can also be invoked with `PackUpdate`. [PackUpdate]()
function M.update()
  exe_op('update', pull, vim.tbl_filter(Filter.to_update, Packages))
end

--- Deletes all plugins installed but not registered in the pack directory.
---
--- Can also be invoked with `PackClean`. [PackClean]()
function M.clean()
  exe_op('remove', remove, find_unlisted())
end

--- Does a clean, install and pull at the same time in this order.
---
--- Can also be invoked with `PackSync`. [PackSync]()
function M.sync()
  M.clean()
  exe_op('sync', clone_or_pull, vim.tbl_filter(Filter.not_removed, Packages))
end

--- Queries pack's packages storage with predefined
--- filters by passing one of the following strings:
--- - "installed"
--- - "to_install"
--- - "to_update"
---
--- @param filter string
function M.query(filter)
  vim.validate('filter', filter, { 'function', 'string' }, true)

  if type(filter) == 'string' then
    local f = Filter[filter]
    if not f then
      error(string.format('No filter with name: %q', filter))
    end

    return vim.deepcopy(vim.tbl_filter(f, Packages), true)
  end

  return vim.deepcopy(vim.tbl_filter(filter, Packages), true)
end

for cmd, fn in pairs {
  PackClean = M.clean,
  PackInstall = M.install,
  PackSync = M.sync,
  PackUpdate = M.update,
} do
  vim.api.nvim_create_user_command(cmd, fn, { bar = true })
end

do
  -- Load lockfile only once when module is first required
  lock_load()

  vim.api.nvim_create_user_command('PackList', function()
    local installed = {}
    local removed = {}

    for _, pkg in vim.spairs(Lock) do
      if Filter.installed(pkg) then
        table.insert(installed, pkg)
      elseif Filter.removed(pkg) then
        table.insert(removed, pkg)
      end
    end

    local markers = { '+', '*' }
    local pkg_print = function(pkg)
      print(' ', markers[pkg.status] or ' ', pkg.name)
    end

    if #installed ~= 0 then
      print('Installed packages:')
      vim.iter(installed):each(pkg_print)
    end

    if #removed ~= 0 then
      print('Recently removed:')
      vim.iter(removed):each(pkg_print)
    end
  end, { bar = true })

  vim.api.nvim_create_user_command('PackLogOpen', function()
    vim.cmd.split(vim.fn.fnameescape(Path.log))
    vim.cmd('silent! normal! Gzz')
  end, { bar = true })

  vim.api.nvim_create_user_command('PackLogClean', function()
    if pcall(vim.fs.rm, Path.log) then
      vim.notify('Pack: log file deleted')
    else
      vim.notify('Pack: error while deleting log file', vim.log.levels.ERROR)
    end
  end, { bar = true })
end

return M
