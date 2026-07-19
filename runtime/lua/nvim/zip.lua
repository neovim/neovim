local api = vim.api
local uv = vim.uv

local M = {}

---@class (private) nvim.zip.Entry : nvim.dir.Entry
---@field member string

---@class (private) nvim.zip.Session
---@field source string
---@field members string[]
---@field prefix string
---@field pending_prefix? string

-- Seed `provider_state` on the first `nvim.dir` list request.
---@type table<integer,nvim.zip.Session>
local pending_sessions = {}

-- Preserve generated member identity separately from the legacy, delimiter-based buffer name.
---@type table<string,{ source: string, member: string }>
local pending_reads = {}

---@param msg string
---@param level? integer
local function notify(msg, level)
  vim.schedule(function()
    vim.notify(('zip: %s'):format(msg), level or vim.log.levels.ERROR)
  end)
end

---@return string?, string?
local function unzip()
  local command = vim.fn.exepath('unzip')
  if command == '' then
    return nil, 'unzip executable not found'
  end
  return command
end

--- Escape a path passed to Info-ZIP, which expands glob patterns even without a shell.
--- https://github.com/neovim/neovim/blob/7ba955fe079d4aa2554fea8e7235651fafd40efb/runtime/autoload/zip.vim#L316-L339
---@param value string
---@return string
local function literal_pattern(value)
  return (value:gsub('\\', '\\\\'):gsub('%?', '\\?'):gsub('%*', '\\*'):gsub('%[', '[[]'))
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
    return nil, vim.trim(result.stderr or ''), true
  end
  return vim.split(result.stdout or '', '\n', { plain = true, trimempty = true })
end

--- Keep absolute and dot-segment members visible without treating them as UI navigation.
---@param member string
---@return boolean
local function opaque_member(member)
  if member:sub(1, 1) == '/' or member:match('^%a:[/\\]') then
    return true
  end
  for component in member:gmatch('[^/]+') do
    if component == '.' or component == '..' then
      return true
    end
  end
  return false
end

--- Project the flat archive-member list into one navigable directory level.
---@param members string[] Raw member names from the archive.
---@param prefix string Raw archive-directory prefix, including its trailing slash.
---@return nvim.zip.Entry[]
local function entries_at(members, prefix)
  local entries = {} ---@type nvim.zip.Entry[]
  local seen = {} ---@type table<string,true>
  for _, member in ipairs(members) do
    if prefix == '' and opaque_member(member) then
      local key = 'opaque:' .. member
      if not seen[key] then
        seen[key] = true
        entries[#entries + 1] = { name = member, dir = false, member = member }
      end
    elseif vim.startswith(member, prefix) then
      local rest = member:sub(#prefix + 1)
      local separator = rest:find('/', 1, true)
      local name = separator and rest:sub(1, separator - 1) or rest
      if name ~= '' then
        local dir = separator ~= nil
        local path = ('%s%s%s'):format(prefix, name, dir and '/' or '')
        local key = (dir and 'dir:' or 'file:') .. path
        if not seen[key] then
          seen[key] = true
          entries[#entries + 1] = { name = name, dir = dir, member = path }
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
---@param member string
---@param target string
---@return string?
local function extract_member(command, source, member, target)
  local file, err = io.open(target, 'wb')
  if not file then
    return err
  end
  local write_err ---@type string?
  local ok, system = pcall(
    vim.system,
    { command, '-p', '--', literal_pattern(source), literal_pattern(member) },
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
local function lock_member(buf)
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
---@param buf integer Target archive-member buffer.
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
  lock_member(buf)
end

--- Parse the legacy member-buffer name used by quickfix and direct `:edit` callers.
---@param name string `zipfile://{archive}::{member}`
---@return string?, string? archive path and member name
local function parse_member_name(name)
  if not vim.startswith(name, 'zipfile://') then
    return
  end
  local value = name:sub(11)
  local separator = value:find('::', 1, true)
  if not separator then
    return
  end
  return value:sub(1, separator - 1), value:sub(separator + 2)
end

--- Open a local archive as a read-only `nvim.dir` listing.
---@param buf integer Target archive buffer.
---@param source string Expanded path to the archive.
function M.browse(buf, source)
  buf = vim._resolve_bufnr(buf)
  if vim.b[buf].nvim_dir ~= nil and vim.b[buf].nvim_zip ~= nil then
    return
  end
  local magic, magic_err = has_magic(source)
  if magic == nil then
    notify(('File not readable <%s>: %s'):format(source, magic_err))
    return
  end
  if not magic then
    read_normally(buf, source)
    return
  end
  local members, err, fallback = list_archive(source)
  if not members then
    if err then
      notify(
        fallback and ('%s is not a zip file: %s'):format(source, err) or err,
        fallback and vim.log.levels.WARN or vim.log.levels.ERROR
      )
    end
    if fallback then
      read_normally(buf, source)
    end
    return
  end
  pending_sessions[buf] = { source = source, members = members, prefix = '' }
  local name = vim.fn.bufname(buf)
  require('nvim.dir').open(buf, name ~= '' and name or source, M)
end

--- Read one archive member into a locked, read-only buffer.
---@param buf integer Target member buffer.
---@param name string `zipfile://` buffer name.
function M.read(buf, name)
  buf = vim._resolve_bufnr(buf)
  local pending = pending_reads[name]
  pending_reads[name] = nil
  local source ---@type string?
  local member ---@type string?
  if pending then
    source, member = pending.source, pending.member
  else
    source, member = parse_member_name(name)
  end
  if not source or not member then
    lock_member(buf)
    notify(('could not parse buffer name %q'):format(name))
    return
  end
  local command, command_err = unzip()
  if not command then
    lock_member(buf)
    notify(command_err or 'unzip executable not found')
    return
  end
  local temp = vim.fn.tempname()
  local err = extract_member(command, source, member, temp)
  if err then
    vim.fn.delete(temp)
    lock_member(buf)
    notify(('unable to read %s from %s: %s'):format(member, source, err))
    return
  end
  local ok, read_err = pcall(read_tempfile, buf, temp)
  vim.fn.delete(temp)
  if not ok then
    lock_member(buf)
    notify(tostring(read_err))
  end
end

--- List the requested archive level and commit its prefix only after the backend succeeds.
---@param ctx nvim.dir.Ctx
---@param cb fun(err?: string, entries?: nvim.zip.Entry[])
function M.list_entries(ctx, cb)
  local state = ctx.provider_state ---@cast state nvim.zip.Session
  local initial = pending_sessions[ctx.buf]
  if initial then
    pending_sessions[ctx.buf] = nil
    state.source = initial.source
    state.members = initial.members
    state.prefix = ''
    cb(nil, entries_at(state.members, state.prefix))
    return
  end
  local members, err = list_archive(state.source)
  if not members then
    state.pending_prefix = nil
    cb(err)
    return
  end
  local prefix = state.pending_prefix or state.prefix
  state.members = members
  state.prefix = prefix
  state.pending_prefix = nil
  cb(nil, entries_at(members, prefix))
end

---@param ctx nvim.dir.Ctx
---@param entry nvim.zip.Entry
function M.open_entry(ctx, entry)
  local state = ctx.provider_state ---@cast state nvim.zip.Session
  if entry.dir then
    state.pending_prefix = entry.member
    require('nvim.dir').open(ctx.buf, ctx.name, M)
    return
  end
  local uri = ('zipfile://%s::%s'):format(state.source, entry.member)
  pending_reads[uri] = { source = state.source, member = entry.member }
  local ok, err = pcall(api.nvim_cmd, {
    cmd = 'edit',
    args = { uri },
    mods = { noswapfile = true },
    magic = { file = false, bar = false },
  }, {})
  if not ok then
    pending_reads[uri] = nil
    error(err, 0)
  end
end

---@param ctx nvim.dir.Ctx
function M.open_parent(ctx)
  local state = ctx.provider_state ---@cast state nvim.zip.Session
  if state.prefix ~= '' then
    state.pending_prefix = state.prefix:sub(1, -2):match('^(.*[/])') or ''
    require('nvim.dir').open(ctx.buf, ctx.name, M)
    return
  end
  require('nvim.dir._filesystem').open_parent_path(state.source)
end

---@param ctx nvim.dir.Ctx
function M.attach(ctx)
  vim.b[ctx.buf].nvim_zip = true
  api.nvim_set_option_value('filetype', 'zip', { buf = ctx.buf })
  api.nvim_buf_call(ctx.buf, function()
    vim.wo.wrap = false
  end)
end

return M
