--- @brief
--- Directory listing for `:edit <dir>`.
---
--- The plugin can be disabled by setting `g:loaded_nvim_directory_plugin = 1`.

local api = vim.api
local fs = vim.fs
local uv = vim.uv

local M = {}

---@class nvim.dir.Entry
---@field display string
---@field name string
---@field path string
---@field type string
---@field parent? boolean

---@class nvim.dir.State
---@field dir string
---@field entries nvim.dir.Entry[]

---@type table<integer,nvim.dir.State>
local states = {}

---@type fun(path: string, opts?: { buf?: integer })
local open
---@type fun(buf: integer)
local open_entry
---@type fun(buf: integer)
local open_parent
---@type fun(buf: integer)
local refresh

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

---@param path string
---@return string
local function normalize_dir(path)
  return fs.normalize(fs.abspath(path))
end

---@param path string
---@return boolean
local function is_dir(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == 'directory'
end

---@param name string
---@return string
local function display_name(name)
  return (name:gsub('\n', '\0'))
end

---@param dir string
---@return nvim.dir.Entry[]
local function read_entries(dir)
  ---@type nvim.dir.Entry[]
  local entries = {}

  local parent = fs.dirname(dir)
  if parent ~= dir then
    entries[#entries + 1] = {
      display = '../',
      name = '..',
      path = parent,
      type = 'directory',
      parent = true,
    }
  end

  ---@type nvim.dir.Entry[]
  local children = {}

  for name, type in fs.dir(dir) do
    local path = fs.joinpath(dir, name)
    if type == 'link' and is_dir(path) then
      type = 'directory'
    end
    children[#children + 1] = {
      display = display_name(name) .. (type == 'directory' and '/' or ''),
      name = name,
      path = path,
      type = type,
    }
  end

  table.sort(children, function(a, b)
    if (a.type == 'directory') ~= (b.type == 'directory') then
      return a.type == 'directory'
    end
    return a.name < b.name
  end)
  vim.list_extend(entries, children)

  return entries
end

---@param buf integer
---@param dir string
---@param entries nvim.dir.Entry[]
---@return boolean
local function set_lines(buf, dir, entries)
  local lines = {} ---@type string[]
  for i, entry in ipairs(entries) do
    lines[i] = entry.display
  end

  if
    not set_buf_options(buf, {
      { 'modeline', false },
      { 'buftype', 'nowrite' },
      { 'bufhidden', 'hide' },
      { 'buflisted', true },
      { 'swapfile', false },
      { 'readonly', false },
      { 'modifiable', true },
    })
  then
    return false
  end
  api.nvim_buf_set_name(buf, dir)
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
local function set_maps(buf)
  vim.keymap.set('n', '<CR>', function()
    open_entry(buf)
  end, { buf = buf, silent = true, desc = 'Open directory entry' })

  vim.keymap.set('n', '-', function()
    open_parent(buf)
  end, { buf = buf, silent = true, desc = 'Open parent directory' })

  vim.keymap.set('n', 'R', function()
    refresh(buf)
  end, { buf = buf, silent = true, desc = 'Refresh directory' })
end

---@param path string
local function edit(path)
  api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }, {})
end

---@param buf integer
---@return string?
local function current_entry_name(buf)
  local state = states[buf]
  if not state or api.nvim_get_current_buf() ~= buf then
    return nil
  end
  local lnum = api.nvim_win_get_cursor(0)[1]
  local entry = state.entries[lnum]
  return entry and entry.name or nil
end

---@param buf integer
---@param name string?
local function restore_cursor(buf, name)
  if not name or api.nvim_get_current_buf() ~= buf then
    return
  end
  local state = states[buf]
  if not state then
    return
  end
  for i, entry in ipairs(state.entries) do
    if entry.name == name then
      api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end
end

---@param path string
---@param opts? { buf?: integer }
function open(path, opts)
  opts = opts or {}
  local dir = normalize_dir(path)
  if not is_dir(dir) then
    return
  end

  local buf = opts.buf or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local keep_name = current_entry_name(buf)
  local is_new_directory_buffer = vim.b[buf].nvim_directory == nil
  local entries = read_entries(dir)
  if not set_lines(buf, dir, entries) then
    states[buf] = nil
    return
  end
  states[buf] = { dir = dir, entries = entries }
  vim.b[buf].nvim_directory = dir
  if is_new_directory_buffer then
    set_maps(buf)
  end
  if api.nvim_get_current_buf() == buf then
    vim.wo.wrap = false
    if not api.nvim_buf_is_valid(buf) then
      states[buf] = nil
      return
    end
  end
  if vim.bo[buf].filetype ~= 'directory' then
    vim._with({ buf = buf }, function()
      vim.bo.filetype = 'directory'
    end)
  end
  if not api.nvim_buf_is_valid(buf) then
    states[buf] = nil
    return
  end
  restore_cursor(buf, keep_name)
end

---@param buf integer
function open_entry(buf)
  local state = states[buf]
  if not state or api.nvim_get_current_buf() ~= buf then
    return
  end
  local lnum = api.nvim_win_get_cursor(0)[1]
  local entry = state.entries[lnum]
  if not entry then
    return
  end
  edit(entry.path)
end

---@param buf integer
function open_parent(buf)
  local state = states[buf]
  if not state then
    return
  end
  edit(fs.dirname(state.dir))
end

---@param buf integer
function refresh(buf)
  local state = states[buf]
  if not state then
    return
  end
  open(state.dir, { buf = buf })
end

---@param buf integer
---@param path string
function M.try_open(buf, path)
  if path == '' then
    return
  end
  if vim.bo[buf].buftype ~= '' and vim.b[buf].nvim_directory == nil then
    return
  end
  if vim.bo[buf].filetype == 'netrw' or vim.b[buf].netrw_curdir ~= nil then
    return
  end

  local dir = normalize_dir(path)
  if is_dir(dir) then
    open(dir, { buf = buf })
  end
end

function M.handle_startup_dirs()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_is_valid(win) then
      api.nvim_win_call(win, function()
        local buf = api.nvim_get_current_buf()
        M.try_open(buf, api.nvim_buf_get_name(buf))
      end)
    end
  end
end

---@param buf integer
function M.clear(buf)
  states[buf] = nil
end

return M
