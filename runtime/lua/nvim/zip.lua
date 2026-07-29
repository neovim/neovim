local api = vim.api
local uv = vim.uv
local notify = require('vim._core.util').notify

local M = {}

---@return string?, string?
local function unzip()
  local command = vim.fn.exepath('unzip')
  if command == '' then
    return nil, 'unzip executable not found'
  end
  return command
end

--- Escape a path so that Info-ZIP matches it literally.
---
--- Info-ZIP matches `*`, `?`, and `[]` in a member selector itself, so this is not shell
--- quoting: passing argv already avoids the shell. For example, unescaped `a[a].txt`
--- silently reads `aa.txt`, and `a?.txt` matches every four-character name. A literal `[`
--- cannot be backslash-escaped, so it is wrapped in a class instead, as is a leading `-`,
--- which would otherwise parse as an option.
--- https://github.com/neovim/neovim/blob/7ba955fe079d4aa2554fea8e7235651fafd40efb/runtime/autoload/zip.vim#L316-L339
---@param value string
---@return string
local function literal_pattern(value)
  return (
    value
      :gsub('\\', '\\\\')
      :gsub('%?', '\\?')
      :gsub('%*', '\\*')
      :gsub('%[', '[[]')
      :gsub('^%-', '[-]')
  )
end

---@param source string
---@return string[]?, string?, boolean?
local function list_archive(source)
  local command, command_err = unzip()
  if not command then
    return nil, command_err, false
  end
  local ok, system = pcall(
    vim.system,
    { command, '-Z1', '--', literal_pattern(source) },
    { text = true }
  )
  if not ok then
    return nil, tostring(system), false
  end
  local result = system:wait()
  if result.code ~= 0 then
    if vim.trim(result.stdout or '') == 'Empty zipfile.' then
      return {}
    end
    return nil, vim.trim(result.stderr or ''), true
  end
  return vim.split(result.stdout or '', '\n', { plain = true, trimempty = true })
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

---@param source string
---@return boolean?, string?
local function has_magic(source)
  local fd, err = uv.fs_open(source, 'r', 438)
  if not fd then
    return nil, err
  end
  local magic, read_err = uv.fs_read(fd, 2, 0)
  uv.fs_close(fd)
  if not magic then
    return nil, read_err
  end
  return magic == 'PK'
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

---@param command string
---@param source string
---@param path string
---@param target string
---@return string?
local function extract_path(command, source, path, target)
  local file, err = io.open(target, 'wb')
  if not file then
    return err
  end
  local write_err ---@type string?
  local ok, system = pcall(
    vim.system,
    { command, '-p', '--', literal_pattern(source), literal_pattern(path) },
    {
      stdout = function(pipe_err, data)
        if pipe_err then
          write_err = pipe_err
        elseif data and not write_err then
          local written, file_err = file:write(data)
          if not written then
            write_err = file_err
          end
        end
      end,
    }
  )
  if not ok then
    file:close()
    return tostring(system)
  end
  local result = system:wait()
  file:close()
  if write_err then
    return write_err
  end
  if result.code ~= 0 then
    return vim.trim(result.stderr or '')
  end
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

--- Parse a `zipfile://` buffer name, as used by quickfix and direct `:edit`.
---@param name string `zipfile://{archive}::{path}`
---@return string?, string? archive and entry path
local function parse_uri(name)
  if not vim.startswith(name, 'zipfile://') then
    return
  end
  local value = name:sub(11)
  local separator ---@type integer?
  local offset = 1
  while true do
    local next_separator = value:find('::', offset, true)
    if not next_separator then
      break
    end
    separator = next_separator
    offset = next_separator + 2
  end
  if not separator then
    return
  end
  return value:sub(1, separator - 1), value:sub(separator + 2)
end

---@class (private) nvim.zip.State
---@field source string Path to the archive.
---@field path? string Archive path shown by a `zipfile://` buffer.
---@field paths? string[] Entry paths carried over from the initial listing.
---@field prefix? string Archive directory currently listed.
---@field pending_prefix? string Prefix to commit once the backend succeeds.

---@param buf integer
---@return nvim.zip.State?
local function get_state(buf)
  return vim.b[buf].nvim_zip
end

---@param buf integer
---@param state nvim.zip.State
local function set_state(buf, state)
  vim.b[buf].nvim_zip = state
end

--- Open a local archive as a read-only `nvim.dir` listing.
---@param buf integer Target archive buffer.
---@param source string Expanded path to the archive.
function M.browse(buf, source)
  buf = vim._resolve_bufnr(buf)
  if vim.b[buf].nvim_dir ~= nil and get_state(buf) ~= nil then
    return
  end
  local magic, magic_err = has_magic(source)
  if magic == nil then
    notify('zip', ('File not readable <%s>: %s'):format(source, magic_err))
    return
  end
  if not magic then
    read_normally(buf, source)
    return
  end
  local paths, err, fallback = list_archive(source)
  if not paths then
    if err then
      notify(
        'zip',
        fallback and ('%s is not a zip file: %s'):format(source, err) or err,
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
---@param name string `zipfile://` buffer name.
function M.read(buf, name)
  buf = vim._resolve_bufnr(buf)
  local state = get_state(buf)
  local source, path = state and state.source, state and state.path
  if not source or not path then
    source, path = parse_uri(name)
  end
  if not source or not path then
    set_readonly(buf)
    notify('zip', ('could not parse buffer name %q'):format(name))
    return
  end
  local command, command_err = unzip()
  if not command then
    set_readonly(buf)
    notify('zip', command_err or 'unzip executable not found')
    return
  end
  local temp = vim.fn.tempname()
  local err = extract_path(command, source, path, temp)
  if err then
    vim.fn.delete(temp)
    set_readonly(buf)
    notify('zip', ('unable to read %s from %s: %s'):format(path, source, err))
    return
  end
  local ok, read_err = pcall(read_tempfile, buf, temp)
  vim.fn.delete(temp)
  if not ok then
    set_readonly(buf)
    notify('zip', tostring(read_err))
  end
end

--- List the requested archive level and commit its prefix only after the backend succeeds.
---@param buf integer
---@param _ string
---@param cb fun(err?: string, entries?: nvim.dir.Entry[])
function M.list(buf, _, cb)
  local state = get_state(buf)
  if not state then
    cb('zip source is not set')
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
  local uri = ('zipfile://%s::%s'):format(state.source, path)
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

--- Extract the entry under the cursor into the current directory.
--- `-j` discards the archive path, so the destination is always a name in the
--- current directory and cannot be redirected by a hostile entry.
function M._extract()
  local buf = api.nvim_get_current_buf()
  local state = get_state(buf)
  if not state then
    return
  end
  local command, command_err = unzip()
  if not command then
    notify('zip', command_err or 'unzip executable not found')
    return
  end
  local line = api.nvim_get_current_line()
  if line == '' then
    return
  end
  if line:sub(-1) == '/' then
    notify('zip', 'please specify a file, not a directory')
    return
  end
  local path = (state.prefix or '') .. line
  local directory = vim.fn.getcwd()
  local target = vim.fs.joinpath(directory, vim.fs.basename(path))
  if uv.fs_stat(target) then
    notify('zip', ('%s already exists, not overwriting'):format(target))
    return
  end
  local ok, system = pcall(vim.system, {
    command,
    '-o',
    '-j',
    '--',
    literal_pattern(state.source),
    literal_pattern(path),
  }, { cwd = directory, text = true })
  if not ok then
    notify('zip', tostring(system))
    return
  end
  local result = system:wait()
  if not uv.fs_stat(target) then
    notify(
      'zip',
      ('unable to extract %s from %s: %s'):format(path, state.source, vim.trim(result.stderr or ''))
    )
    return
  end
  notify('zip', ('extracted %s'):format(target), vim.log.levels.INFO)
end

---@param buf integer
function M.init(buf)
  api.nvim_set_option_value('filetype', 'zip', { buf = buf })
  if vim.fn.hasmapto('<Plug>(nvim-zip-extract)', 'n') == 0 then
    vim.keymap.set('n', 'x', '<Plug>(nvim-zip-extract)', { buffer = buf, silent = true })
  end
  api.nvim_buf_call(buf, function()
    vim.wo.wrap = false
  end)
end

return M
