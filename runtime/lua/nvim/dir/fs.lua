-- Filesystem backend.

local api = vim.api
local fs = vim.fs

local M = {}

local navigating = false

---@param path string
---@return string
function M.normalize(path)
  return fs.normalize(fs.abspath(path), { expand_env = false })
end

---@return boolean
function M.is_navigating()
  return navigating
end

---@param path string
local function edit(path)
  navigating = true
  local ok, err = pcall(api.nvim_cmd, {
    cmd = 'edit',
    args = { path },
    magic = { file = false, bar = false },
  })
  navigating = false
  if not ok then
    error(err, 0)
  end
end

---@param path string
---@param select? nvim.dir.Entry
local function navigate(path, select)
  edit(path)
  local buf = api.nvim_get_current_buf()
  local dir = M.normalize(api.nvim_buf_get_name(buf))
  if vim.fn.isdirectory(dir) == 0 then
    return
  end

  require('nvim.dir').open(buf, dir, M, select)
end

---@param path string
function M.open_parent_path(path)
  if path == '' then
    navigate('.')
    return
  end
  path = M.normalize(path)
  navigate(fs.dirname(path), { name = fs.basename(path), dir = vim.fn.isdirectory(path) == 1 })
end

---@param _ integer
---@param path string
---@param cb fun(err?: string, entries?: nvim.dir.Entry[])
function M.list(_, path, cb)
  local scan, err = vim.uv.fs_scandir(path)
  if not scan then
    cb(err)
    return
  end

  local entries = {} ---@type nvim.dir.Entry[]
  while true do
    local name, type = vim.uv.fs_scandir_next(scan)
    if not name then
      break
    end
    if not type then
      type = (vim.uv.fs_lstat(fs.joinpath(path, name)) or {}).type or 'unknown'
    end
    if type == 'link' and vim.fn.isdirectory(fs.joinpath(path, name)) == 1 then
      type = 'directory'
    end
    entries[#entries + 1] = {
      name = name,
      dir = type == 'directory',
    }
  end
  table.sort(entries, function(a, b)
    if a.dir ~= b.dir then
      return a.dir
    end
    return a.name < b.name
  end)
  cb(nil, entries)
end

---@param _ integer
---@param path string
---@param entry nvim.dir.Entry
function M.open(_, path, entry)
  navigate(fs.joinpath(path, entry.name))
end

---@param _ integer
---@param path string
function M.open_parent(_, path)
  M.open_parent_path(path)
end

---@param buf integer
function M.init(buf)
  if api.nvim_get_option_value('filetype', { buf = buf }) ~= 'directory' then
    api.nvim_set_option_value('filetype', 'directory', { buf = buf })
  end
end

return M
