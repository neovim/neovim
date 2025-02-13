local M = {}

---@class vim._explorer.Explorer
---@field buf integer
---@field watcher userdata uv_fs_event_t
---@field refresh function

-- Costants
local uv = vim.uv
local ns_id = vim.api.nvim_create_namespace('tree')
local sysname = uv.os_uname().sysname:lower()
local iswin = not not (sysname:find('windows') or sysname:find('mingw'))
local os_sep = iswin and '\\' or '/'

local last_filebuf, last_altbuf = -1, -1

---@type vim._explorer.Explorer[]
local explorers = {}

---@return string?
local function get_current_path()
  local line = vim.api.nvim_get_current_line()
  if line == '' then
    return nil
  end
  local path = vim.fs.joinpath(vim.b.cwd, line)
  return vim.fs.normalize(path)
end

local function restore_altbuf()
  if not vim.api.nvim_buf_is_valid(last_altbuf) then
    return
  end
  vim.fn.setreg('#', last_altbuf)
end

---@param handle string | integer
local function edit(handle)
  local buf = vim.fn.bufnr(handle)
  if buf == -1 then
    vim.cmd('silent! keepalt edit ' .. handle)
  else
    vim.cmd('silent! keepalt buffer ' .. handle)
  end
  restore_altbuf()
end

---@param path string
---@return string
local function fs_type(path)
  return (uv.fs_stat(path) or {}).type
end

---@param path string
---@return boolean
local function fs_is_dir(path)
  return fs_type(path) == 'directory'
end

---@param path string
---@return boolean
local function fs_is_link_dir(path)
  local abspath = vim.fs.abspath(path)
  return fs_is_dir(abspath)
end

---@param path string
---@return string[]
local function fs_read_dir(path)
  local paths = {}

  local dirname = vim.fs.abspath(path)
  for name in vim.fs.dir(path) do
    table.insert(paths, vim.fs.joinpath(dirname, name))
  end

  vim.tbl_filter(M.filter, paths)

  table.sort(paths, M.sort)

  return paths
end

local function map_quit()
  edit(last_filebuf)
  restore_altbuf()
end

local function map_open()
  local path = get_current_path()
  if not path then
    return
  end

  if fs_is_dir(path) then
    M.open(path)
  else
    edit(path)
  end
end

local function map_goto_parent()
  M.open(vim.fs.dirname(vim.b.cwd))
end

---@param buf integer
local function init_mappings(buf)
  local map = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, nowait = true })
  end

  map('n', '<CR>', map_open)
  map('n', '-', map_goto_parent)
  map('n', 'q', map_quit)
  map('n', '<C-6>', map_quit)
  map('n', '<C-^>', map_quit)
end

---@param path string
---@return integer
local function create_buffer(path)
  local buf = vim.api.nvim_create_buf(false, true)
  init_mappings(buf)
  local relpath = path:gsub(uv.os_homedir() or '', '~')
  vim.api.nvim_buf_set_name(buf, relpath)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = 'directory'
  vim.b[buf].cwd = path
  return buf
end

---@param self vim._explorer.Explorer
---@param lines string[]
local function explorer_refresh(self, lines)
  if not vim.api.nvim_buf_is_valid(self.buf) then
    return
  end

  vim.bo[self.buf].modifiable = true

  ---@type table<string, any>[]
  local ranges = {}

  lines = vim
    .iter(lines)
    :enumerate()
    :map(function(i, path)
      local basename = vim.fs.basename(path)

      local range = {
        { i - 1, 0 },
        { i - 1, #basename },
      }

      local type = fs_type(path)

      if type == 'directory' then
        ---@type string
        basename = basename .. os_sep
        -- include trailing slash
        range[2][2] = range[2][2] + 1
        table.insert(ranges, { 'Directory', range })
      elseif type == 'link' then
        if fs_is_link_dir(path) then
          ---@type string
          basename = basename .. os_sep
          -- include trailing slash
          range[2][2] = range[2][2] + 1
        end
        table.insert(ranges, { 'Question', range })
      end

      return basename
    end)
    :totable()

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)

  for _, pair in ipairs(ranges) do
    vim.hl.range(self.buf, ns_id, pair[1], unpack(pair[2]))
  end

  vim.bo[self.buf].modifiable = false
end

local on_fs_event = vim.schedule_wrap(function(explorer, events)
  if events.rename then
    ---@type string
    local path = explorer.watcher:getpath()
    local entries = fs_read_dir(path)
    explorer:refresh(entries)
  end
end)

---@param path string
---@return vim._explorer.Explorer
local function create_explorer(path)
  local watcher = uv.new_fs_event()
  local explorer = {
    buf = create_buffer(path),
    watcher = watcher,
    refresh = explorer_refresh,
  }

  if not watcher then
    error('Failed to watch directory', 0)
  end

  watcher:start(path, { watch_entry = true }, function(_, _, events)
    on_fs_event(explorer, events or {})
  end)

  explorers[path] = explorer
  return explorer
end

---@param path string
---@return vim._explorer.Explorer
local function get_explorer(path)
  local explorer = explorers[path]
  if not explorer then
    explorer = create_explorer(path)
  elseif explorer and not vim.api.nvim_buf_is_valid(explorer.buf) then
    explorer.buf = create_buffer(path)
  end
  return explorer
end

---@return boolean
function M.filter(_)
  return true
end

---@param path1 string
---@param path2 string
---@return boolean
function M.sort(path1, path2)
  if fs_is_dir(path1) and not fs_is_dir(path2) then
    return true
  end

  if not fs_is_dir(path1) and fs_is_dir(path2) then
    return false
  end

  -- Otherwise order alphabetically ignoring case
  return path1:lower() < path2:lower()
end

---@param path string
function M.open(path)
  vim.validate('path', path, { 'string', 'nil' })

  local current_buf = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(current_buf)

  if not fs_is_dir(current_file) then
    last_filebuf = current_buf
    local alternate_file = vim.fn.bufnr('#')
    if vim.api.nvim_buf_is_valid(alternate_file) then
      last_altbuf = alternate_file
    end
  end

  if not path then
    path = current_file == '' and uv.cwd() or vim.fs.dirname(current_file)
  end

  local paths = fs_read_dir(path)
  local explorer = get_explorer(path)

  explorer:refresh(paths)
  edit(explorer.buf)
end

return M
