--- @brief
--- Directory listing for `:edit <dir>`.

local api = vim.api
local fs = vim.fs
local uv = vim.uv

local M = {}

---@class nvim.dir.Entry
---@field name string
---@field dir boolean
---@field path string

---@class nvim.dir.Source
---@field name string
---@field filetype string
---@field list fun(callback: fun(err: string?, entries: nvim.dir.Entry[]?))
---@field open fun(entry: nvim.dir.Entry, buf: integer)
---@field parent? fun(buf: integer)

---@class (private) nvim.dir.Session
---@field source nvim.dir.Source
---@field entries nvim.dir.Entry[]

---@type table<integer,nvim.dir.Session>
local sessions = {}

---@param buf integer
---@param options [string, any][]
---@return boolean
local function set_buf_options(buf, options)
  for _, option in ipairs(options) do
    if not api.nvim_buf_is_valid(buf) then
      return false
    end
    api.nvim_set_option_value(option[1], option[2], { buf = buf })
  end
  return api.nvim_buf_is_valid(buf)
end

---@param name string
---@return string
local function encode_name(name)
  return (name:gsub('\n', '\0'))
end

---@param entry nvim.dir.Entry
---@return string
local function entry_line(entry)
  return encode_name(entry.name) .. (entry.dir and '/' or '')
end

---@param buf integer
---@param source nvim.dir.Source
---@param entries nvim.dir.Entry[]
---@return boolean
local function render_entries(buf, source, entries)
  local lines = {} ---@type string[]
  for i, entry in ipairs(entries) do
    lines[i] = entry_line(entry)
  end

  if
    not set_buf_options(buf, {
      { 'modeline', false },
      { 'buftype', 'nowrite' },
      { 'buflisted', true },
      { 'swapfile', false },
      { 'readonly', false },
      { 'modifiable', true },
    })
  then
    return false
  end
  api.nvim_buf_set_name(buf, source.name)
  if not api.nvim_buf_is_valid(buf) then
    return false
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if not api.nvim_buf_is_valid(buf) then
    return false
  end
  return set_buf_options(buf, {
    { 'modified', false },
    { 'readonly', true },
    { 'modifiable', false },
  })
end

---@param buf integer
---@param source nvim.dir.Source
---@param callback fun(ok: boolean, entries?: nvim.dir.Entry[])
local function render_source(buf, source, callback)
  source.list(function(err, entries)
    if not api.nvim_buf_is_valid(buf) then
      callback(false)
      return
    end
    if err then
      vim.notify('dir: ' .. err, vim.log.levels.ERROR)
      callback(false)
      return
    end
    entries = entries or {}
    callback(render_entries(buf, source, entries), entries)
  end)
end

---@param buf integer
---@return nvim.dir.Entry?, nvim.dir.Source?
local function current_entry(buf)
  local session = sessions[buf]
  if session then
    local lnum = api.nvim_win_get_cursor(0)[1]
    return session.entries[lnum], session.source
  end
end

---@param buf integer
local function reload(buf)
  local session = sessions[buf]
  if not session then
    return
  end
  local view = vim.fn.winsaveview()
  render_source(buf, session.source, function(ok, entries)
    if ok then
      session.entries = entries or {}
      vim.fn.winrestview(view)
    end
  end)
end

---@param buf integer
local function open_entry(buf)
  local entry, source = current_entry(buf)
  if entry and source then
    source.open(entry, buf)
  end
end

---@param buf integer
local function open_parent(buf)
  local session = sessions[buf]
  if session and session.source.parent then
    session.source.parent(buf)
  end
end

---@param buf integer
local function set_maps(buf)
  ---@param lhs string
  ---@param plug string
  local function map(lhs, plug)
    if vim.fn.hasmapto(plug, 'n') == 0 then
      vim.keymap.set('n', lhs, plug, { buffer = buf, silent = true })
    end
  end
  map('<CR>', '<Plug>(nvim-dir-open)')
  map('-', '<Plug>(nvim-dir-up)')
  map('R', '<Plug>(nvim-dir-reload)')
end

---@param buf integer
---@param source nvim.dir.Source
function M.open(buf, source)
  buf = buf == 0 and api.nvim_get_current_buf() or buf
  render_source(buf, source, function(ok, entries)
    if not ok or not api.nvim_buf_is_valid(buf) then
      return
    end
    local has_session = sessions[buf] ~= nil
    sessions[buf] = { source = source, entries = entries or {} }
    vim.b[buf].nvim_dir = source.name
    set_maps(buf)
    if not has_session then
      api.nvim_create_autocmd('BufReadCmd', {
        buffer = buf,
        nested = true,
        desc = 'Reload directory listing',
        callback = function()
          if vim.b[buf].nvim_dir ~= nil then
            reload(buf)
          end
        end,
      })
      api.nvim_create_autocmd('BufWipeout', {
        buffer = buf,
        once = true,
        callback = function()
          sessions[buf] = nil
        end,
      })
    end
    if api.nvim_get_option_value('filetype', { buf = buf }) ~= source.filetype then
      api.nvim_set_option_value('filetype', source.filetype, { buf = buf })
    end
  end)
end

local filesystem_navigating = false

---@param path string
---@return string
local function filesystem_normalize_dir(path)
  return fs.normalize(fs.abspath(path))
end

---@param path string
local function filesystem_edit(path)
  filesystem_navigating = true
  api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }, {})
  filesystem_navigating = false
end

---@param entries nvim.dir.Entry[]
---@return nvim.dir.Entry[]
local function filesystem_sort_entries(entries)
  table.sort(entries, function(a, b)
    if a.dir ~= b.dir then
      return a.dir
    end
    return a.name < b.name
  end)
  return entries
end

---@param dir string
---@param navigate fun(path: string)
---@return nvim.dir.Source
local function filesystem_source(dir, navigate)
  return {
    name = dir,
    filetype = 'directory',
    list = function(callback)
      -- TODO(#39878): drop this scandir probe once vim.fs.dir() can report
      -- traversal errors.
      local handle, err = uv.fs_scandir(dir)
      if not handle then
        callback(err or ('cannot read directory: ' .. dir))
        return
      end

      local entries = {} ---@type nvim.dir.Entry[]
      for name, type in fs.dir(dir) do
        if type == 'link' and vim.fn.isdirectory(fs.joinpath(dir, name)) == 1 then
          type = 'directory'
        end
        entries[#entries + 1] = {
          name = name,
          dir = type == 'directory',
          path = fs.joinpath(dir, name),
        }
      end
      callback(nil, filesystem_sort_entries(entries))
    end,
    open = function(entry)
      navigate(entry.path)
    end,
    parent = function()
      navigate(fs.dirname(dir))
    end,
  }
end

---@param path string
local function filesystem_navigate(path)
  filesystem_edit(path)
  local buf = api.nvim_get_current_buf()
  local dir = filesystem_normalize_dir(api.nvim_buf_get_name(buf))
  if vim.fn.isdirectory(dir) == 0 then
    return
  end
  if sessions[buf] == nil then
    M.open(buf, filesystem_source(dir, filesystem_navigate))
  else
    reload(buf)
  end
end

function M._open_entry()
  open_entry(api.nvim_get_current_buf())
end

function M._open_parent()
  local buf = api.nvim_get_current_buf()
  if sessions[buf] then
    open_parent(buf)
  else
    filesystem_navigate(fs.dirname(api.nvim_buf_get_name(buf)))
  end
end

function M._reload()
  reload(api.nvim_get_current_buf())
end

---@param buf integer
---@param path string
function M.try_open(buf, path)
  if filesystem_navigating or path == '' then
    return
  end
  if sessions[buf] ~= nil then
    return
  end
  if vim.bo[buf].buftype ~= '' then
    return
  end
  if vim.bo[buf].filetype ~= 'directory' or vim.b[buf].netrw_curdir ~= nil then
    return
  end

  if vim.fn.isdirectory(path) == 0 then
    return
  end
  M.open(buf, filesystem_source(filesystem_normalize_dir(path), filesystem_navigate))
end

return M
