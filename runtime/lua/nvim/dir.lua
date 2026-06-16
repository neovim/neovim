--- @brief
--- Directory listing for `:edit <dir>`.
---
--- [g:loaded_nvim_dir_plugin]()
--- The plugin can be disabled by setting `g:loaded_nvim_dir_plugin = 1`.

local api = vim.api
local fs = vim.fs
local uv = vim.uv

local M = {}

---@type fun(buf: integer, dir: string)
local first_open

local navigating = false

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
local function encode_name(name)
  return (name:gsub('\n', '\0'))
end

---@param line string
---@return string
local function decode_line(line)
  if line:sub(-1) == '/' then
    line = line:sub(1, -2)
  end
  return (line:gsub('%z', '\n'))
end

---@param buf integer
---@param dir string
---@return boolean
local function render(buf, dir)
  -- TODO(#39878): drop this scandir probe once vim.fs.dir() can report
  -- traversal errors.
  local handle, err = uv.fs_scandir(dir)
  if not handle then
    vim.notify('dir: ' .. (err or ('cannot read directory: ' .. dir)), vim.log.levels.ERROR)
    return false
  end

  ---@type { name: string, dir: boolean }[]
  local items = {}
  for name, type in fs.dir(dir) do
    if type == 'link' and is_dir(fs.joinpath(dir, name)) then
      type = 'directory'
    end
    items[#items + 1] = { name = name, dir = type == 'directory' }
  end
  table.sort(items, function(a, b)
    if a.dir ~= b.dir then
      return a.dir
    end
    return a.name < b.name
  end)

  local lines = {} ---@type string[]
  for i, item in ipairs(items) do
    lines[i] = encode_name(item.name) .. (item.dir and '/' or '')
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
---@return string?
local function entry_path(buf)
  local lnum = api.nvim_win_get_cursor(0)[1]
  local line = api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
  if not line or line == '' then
    return nil
  end
  return fs.joinpath(api.nvim_buf_get_name(buf), decode_line(line))
end

---@param path string
local function edit(path)
  navigating = true
  api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }, {})
  navigating = false
end

---@param buf integer
local function reload(buf)
  local view = vim.fn.winsaveview()
  if render(buf, api.nvim_buf_get_name(buf)) then
    vim.fn.winrestview(view)
  end
end

---@param path string
local function navigate(path)
  edit(path)
  local buf = api.nvim_get_current_buf()
  local dir = normalize_dir(api.nvim_buf_get_name(buf))
  if not is_dir(dir) then
    return
  end
  if vim.b[buf].nvim_dir == nil then
    first_open(buf, dir)
  else
    reload(buf)
  end
end

---@param buf integer
local function open_entry(buf)
  local path = entry_path(buf)
  if path then
    navigate(path)
  end
end

---@param buf integer
local function open_parent(buf)
  navigate(fs.dirname(api.nvim_buf_get_name(buf)))
end

---@param buf integer
local function set_maps(buf)
  ---@param lhs string
  ---@param plug string
  ---@param rhs function
  ---@param desc string
  local function map(lhs, plug, rhs, desc)
    vim.keymap.set('n', plug, rhs, { buffer = buf, silent = true, desc = desc })
    if vim.fn.hasmapto(plug, 'n') == 0 then
      vim.keymap.set('n', lhs, plug, { buffer = buf, silent = true })
    end
  end
  map('<CR>', '<Plug>(nvim-dir-open)', function()
    open_entry(buf)
  end, 'Open directory entry')
  map('-', '<Plug>(nvim-dir-up)', function()
    open_parent(buf)
  end, 'Open parent directory')
  map('R', '<Plug>(nvim-dir-reload)', function()
    reload(buf)
  end, 'Reload directory')
end

---@param buf integer
---@param dir string
function first_open(buf, dir)
  if not render(buf, dir) then
    return
  end
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  vim.b[buf].nvim_dir = dir
  set_maps(buf)
  if api.nvim_get_option_value('filetype', { buf = buf }) ~= 'directory' then
    api.nvim_set_option_value('filetype', 'directory', { buf = buf })
  end
end

---@param buf integer
---@param path string
function M.try_open(buf, path)
  if navigating or path == '' then
    return
  end
  if vim.b[buf].nvim_dir ~= nil then
    return
  end
  if vim.bo[buf].buftype ~= '' then
    return
  end
  if vim.bo[buf].filetype == 'netrw' or vim.b[buf].netrw_curdir ~= nil then
    return
  end

  local dir = normalize_dir(path)
  if is_dir(dir) then
    first_open(buf, dir)
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

return M
