local api = vim.api
local uv = vim.uv
local notify = require('vim._core.util').notify

local M = {}

---@return string?, string?
local function tar()
  local command = vim.fn.exepath('tar')
  if command == '' then
    return nil, 'tar executable not found'
  end
  -- Windows searches the current directory before $PATH, so an archive could be opened with a
  -- `tar` shipped next to it.
  if vim.fn.has('win32') == 1 then
    local dir = uv.fs_realpath(vim.fs.dirname(vim.fs.normalize(command)))
    local cwd = uv.fs_realpath(vim.fn.getcwd())
    if dir and cwd and dir == cwd then
      return nil, 'refusing to run tar from the current directory'
    end
  end
  return command
end

--- Drop the `./` prefix that tar writes for paths given as `.` on the command line.
---
--- The prefix is an artifact of how the archive was created, not part of the entry path, and
--- leaving it would make every entry look like a dot-segment and flatten the listing.
---@param path string
---@return string
local function strip_leading(path)
  return (path:gsub('^%./', ''))
end

--- List the archive, letting tar detect any compression itself.
---
--- Both GNU tar and bsdtar decompress transparently for `-t` and `-x`, so the compressor does not
--- have to be identified from the extension or run separately.
---@param source string
---@return string[]?, string?, boolean?
local function list_archive(source)
  local command, command_err = tar()
  if not command then
    return nil, command_err, false
  end
  local ok, system = pcall(vim.system, { command, '-t', '-f', source }, { text = true })
  if not ok then
    return nil, tostring(system), false
  end
  local result = system:wait()
  if result.code ~= 0 then
    return nil, vim.trim(result.stderr or ''), true
  end
  local paths = {} ---@type string[]
  local listed = vim.split(result.stdout or '', '\n', { plain = true, trimempty = true })
  for _, path in ipairs(listed) do
    local stripped = strip_leading(path)
    if stripped ~= '' then
      paths[#paths + 1] = stripped
    end
  end
  return paths
end

--- Keep absolute and dot-segment entries visible without treating them as UI navigation.
---@param path string
---@return boolean
local function opaque_path(path)
  if path:sub(1, 1) == '/' or path:match('^%a:[/\\]') then
    return true
  end
  for component in path:gmatch('[^/]+') do
    if component == '.' or component == '..' then
      return true
    end
  end
  return false
end

--- Project the flat archive path list into one navigable directory level.
---@param paths string[] Raw entry paths from the archive.
---@param prefix string Raw archive-directory prefix, including its trailing slash.
---@return nvim.dir.Entry[]
local function entries_at(paths, prefix)
  local entries = {} ---@type nvim.dir.Entry[]
  local seen = {} ---@type table<string,true>
  for _, path in ipairs(paths) do
    if prefix == '' and opaque_path(path) then
      local key = 'opaque:' .. path
      if not seen[key] then
        seen[key] = true
        entries[#entries + 1] = { name = path, dir = false }
      end
    elseif vim.startswith(path, prefix) then
      local rest = path:sub(#prefix + 1)
      local separator = rest:find('/', 1, true)
      local name = separator and rest:sub(1, separator - 1) or rest
      if name ~= '' then
        local dir = separator ~= nil
        local entry_path = ('%s%s%s'):format(prefix, name, dir and '/' or '')
        local key = (dir and 'dir:' or 'file:') .. entry_path
        if not seen[key] then
          seen[key] = true
          entries[#entries + 1] = { name = name, dir = dir }
        end
      end
    end
  end
  return entries
end

---@param buf integer
---@param source string
local function read_normally(buf, source)
  api.nvim_buf_call(buf, function()
    api.nvim_cmd({
      cmd = 'edit',
      args = { source },
      mods = { noautocmd = true, noswapfile = true },
      magic = { file = false, bar = false },
    }, {})
  end)
end

--- Extract one entry into an empty directory and return the file tar wrote.
---
--- bsdtar matches an entry selector as a glob and GNU tar's `--no-wildcards` has no bsdtar
--- equivalent, so an over-match cannot be prevented portably. Extracting into a directory keeps
--- every match in its own file, which makes the requested path recoverable and an ambiguous
--- selector detectable; `-O` would concatenate all of them into a single stream instead. tar
--- also strips leading slashes and `..` components unless told otherwise, so a hostile entry
--- cannot write outside the directory.
---@param command string
---@param source string
---@param path string
---@param dir string
---@return string?, string?
local function extract_path(command, source, path, dir)
  local ok, system = pcall(
    vim.system,
    { command, '-x', '-f', source, '--', path },
    { cwd = dir, text = true }
  )
  if not ok then
    return nil, tostring(system)
  end
  local result = system:wait()
  if result.code ~= 0 then
    local stderr = vim.trim(result.stderr or '')
    return nil, stderr ~= '' and stderr or ('tar exited with %d'):format(result.code)
  end
  local target = vim.fs.joinpath(dir, path)
  if uv.fs_stat(target) then
    return target
  end
  local extracted = {} ---@type string[]
  for name, kind in vim.fs.dir(dir, { depth = math.huge }) do
    if kind == 'file' then
      extracted[#extracted + 1] = name
    end
  end
  if #extracted == 0 then
    return nil, 'no entry was extracted'
  end
  if #extracted > 1 then
    return nil, ('%d entries matched'):format(#extracted)
  end
  return vim.fs.joinpath(dir, extracted[1])
end

---@param buf integer
local function set_readonly(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  api.nvim_set_option_value('swapfile', false, { buf = buf })
  api.nvim_set_option_value('modified', false, { buf = buf })
  api.nvim_set_option_value('buftype', 'nowrite', { buf = buf })
  api.nvim_set_option_value('readonly', true, { buf = buf })
  api.nvim_set_option_value('modifiable', false, { buf = buf })
end

--- Read extracted bytes through Nvim's normal reader to preserve encoding, EOL, and binary behavior.
---@param buf integer Target archive entry buffer.
---@param temp string Temporary file containing the extracted bytes.
local function read_tempfile(buf, temp)
  api.nvim_buf_call(buf, function()
    local name = api.nvim_buf_get_name(buf)
    api.nvim_set_option_value('swapfile', false, { buf = buf })
    api.nvim_cmd({
      cmd = 'file',
      args = { temp },
      mods = { keepalt = true, silent = true },
      magic = { file = false, bar = false },
    }, {})
    api.nvim_cmd({ cmd = 'edit', bang = true, mods = { keepjumps = true, silent = true } }, {})
    api.nvim_cmd({
      cmd = 'file',
      args = { name },
      mods = { keepalt = true, silent = true },
      magic = { file = false, bar = false },
    }, {})
    api.nvim_cmd({ cmd = 'filetype', args = { 'detect' } }, {})
  end)
  set_readonly(buf)
end

--- Resolve a `nvim-tar://` buffer name, as used by quickfix and direct `:edit`.
---
--- The archive path and the entry path are simply joined, so the split is found by walking
--- components: the first one that is a regular file is the archive, because a regular file
--- cannot have children on disk. Entry paths may therefore contain any character.
---@param name string `nvim-tar://{archive}/{path}`
---@return string?, string? archive and entry path
local function resolve_uri(name)
  if not vim.startswith(name, 'nvim-tar://') then
    return
  end
  local value = name:sub(12)
  local offset = 1
  while true do
    local separator = value:find('/', offset + 1, true)
    if not separator then
      return
    end
    local archive = value:sub(1, separator - 1)
    local stat = uv.fs_stat(archive)
    if stat and stat.type == 'file' then
      return archive, value:sub(separator + 1)
    end
    offset = separator
  end
end

---@class (private) nvim.tar.State
---@field source string Path to the archive.
---@field path? string Archive path shown by a `nvim-tar://` buffer.
---@field paths? string[] Entry paths carried over from the initial listing.
---@field prefix? string Archive directory currently listed.
---@field pending_prefix? string Prefix to commit once the backend succeeds.

---@param buf integer
---@return nvim.tar.State?
local function get_state(buf)
  return vim.b[buf].nvim_tar
end

---@param buf integer
---@param state nvim.tar.State
local function set_state(buf, state)
  vim.b[buf].nvim_tar = state
end

--- Open a local archive as a read-only `nvim.dir` listing.
---@param buf integer Target archive buffer.
---@param source string Expanded path to the archive.
function M.browse(buf, source)
  buf = vim._resolve_bufnr(buf)
  if vim.b[buf].nvim_dir ~= nil and get_state(buf) ~= nil then
    return
  end
  local paths, err, fallback = list_archive(source)
  if not paths then
    if err then
      notify(
        'tar',
        fallback and ('%s is not a tar file: %s'):format(source, err) or err,
        fallback and vim.log.levels.WARN or vim.log.levels.ERROR
      )
    end
    if fallback then
      read_normally(buf, source)
    end
    return
  end
  set_state(buf, { source = source, paths = paths, prefix = '' })
  local name = vim.fn.bufname(buf)
  require('nvim.dir').open(buf, name ~= '' and name or source, M)
end

--- Read one archive entry into a read-only buffer.
---@param buf integer Target entry buffer.
---@param name string `nvim-tar://` buffer name.
function M.read(buf, name)
  buf = vim._resolve_bufnr(buf)
  local state = get_state(buf)
  local source, path = state and state.source, state and state.path
  if not source or not path then
    source, path = resolve_uri(name)
  end
  if not source or not path then
    set_readonly(buf)
    notify('tar', ('could not parse buffer name %q'):format(name))
    return
  end
  local command, command_err = tar()
  if not command then
    set_readonly(buf)
    notify('tar', command_err or 'tar executable not found')
    return
  end
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  local temp, err = extract_path(command, source, path, dir)
  if not temp then
    vim.fn.delete(dir, 'rf')
    set_readonly(buf)
    notify('tar', ('unable to read %s from %s: %s'):format(path, source, err))
    return
  end
  local ok, read_err = pcall(read_tempfile, buf, temp)
  vim.fn.delete(dir, 'rf')
  if not ok then
    set_readonly(buf)
    notify('tar', tostring(read_err))
  end
end

--- List the requested archive level and commit its prefix only after the backend succeeds.
---@param buf integer
---@param _ string
---@param cb fun(err?: string, entries?: nvim.dir.Entry[])
function M.list(buf, _, cb)
  local state = get_state(buf)
  if not state then
    cb('tar source is not set')
    return
  end
  local paths = state.paths
  state.paths = nil
  local err ---@type string?
  if not paths then
    paths, err = list_archive(state.source)
  end
  if not paths then
    state.pending_prefix = nil
    set_state(buf, state)
    cb(err)
    return
  end
  state.prefix = state.pending_prefix or state.prefix or ''
  state.pending_prefix = nil
  set_state(buf, state)
  cb(nil, entries_at(paths, state.prefix))
end

---@param buf integer
---@param name string
---@param entry nvim.dir.Entry
function M.open(buf, name, entry)
  local state = get_state(buf)
  if not state then
    return
  end
  local path = (state.prefix or '') .. entry.name .. (entry.dir and '/' or '')
  if entry.dir then
    state.pending_prefix = path
    set_state(buf, state)
    require('nvim.dir').open(buf, name, M)
    return
  end
  local uri = ('nvim-tar://%s/%s'):format(state.source, path)
  local entry_buf = vim.fn.bufadd(uri)
  set_state(entry_buf, { source = state.source, path = path })
  api.nvim_cmd({
    cmd = 'edit',
    args = { uri },
    mods = { noswapfile = true },
    magic = { file = false, bar = false },
  }, {})
end

---@param buf integer
---@param name string
function M.open_parent(buf, name)
  local state = get_state(buf)
  if not state then
    return
  end
  local prefix = state.prefix or ''
  if prefix ~= '' then
    local path = prefix:sub(1, -2)
    local child = assert(path:match('([^/]+)$'))
    state.pending_prefix = path:match('^(.*[/])') or ''
    set_state(buf, state)
    require('nvim.dir').open(buf, name, M, { name = child, dir = true })
    return
  end
  if name:match('^%a[%w+.-]*://') then
    return
  end
  require('nvim.dir.fs').open_parent_path(state.source)
end

---@param buf integer
function M.init(buf)
  api.nvim_set_option_value('filetype', 'tar', { buf = buf })
  api.nvim_buf_call(buf, function()
    vim.wo.wrap = false
  end)
end

return M
