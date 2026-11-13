-- Filesystem backend.

local api = vim.api
local fs = vim.fs
local is_url = vim._core.path_is_url

local M = {}

local navigating = false
---@type table<integer, { path: string, cancel: fun() }>
local watchers = {}

---@param path string
---@return string
function M.normalize(path)
  return fs.normalize(fs.abspath(path), { plain = true })
end

---@param buf integer
local function stop_watcher(buf)
  local watcher = watchers[buf]
  if watcher then
    watcher.cancel()
    watchers[buf] = nil
  end
end

local group = api.nvim_create_augroup('nvim.dir.fs', { clear = false })
api.nvim_create_autocmd({ 'BufUnload', 'BufWipeout', 'BufFilePost' }, {
  group = group,
  callback = function(ev)
    local watcher = watchers[ev.buf]
    if
      watcher
      and (ev.event ~= 'BufFilePost' or M.normalize(api.nvim_buf_get_name(ev.buf)) ~= watcher.path)
    then
      stop_watcher(ev.buf)
    end
  end,
})
api.nvim_create_autocmd('VimLeavePre', {
  group = group,
  callback = function()
    for buf in pairs(watchers) do
      stop_watcher(buf)
    end
  end,
})

---@param buf integer
---@param path string
local function watch_directory(buf, path)
  path = M.normalize(path)
  if watchers[buf] and watchers[buf].path == path then
    return
  end
  stop_watcher(buf)
  local timer = assert(vim.uv.new_timer())
  local refresh = vim.schedule_wrap(function()
    if timer:is_closing() or timer:is_active() then
      return
    end
    local state = api.nvim_buf_is_loaded(buf) and vim.b[buf].nvim_dir
    if not state or not state.provider or state.provider.list ~= M.list then
      stop_watcher(buf)
      return
    end
    require('nvim.dir')._reload(buf)
  end)
  local cancel = vim._watch.watch(path, {}, function(fullpath)
    if not timer:is_closing() and (fullpath == path or fs.dirname(fullpath) == path) then
      timer:start(100, 0, refresh)
    end
  end)
  watchers[buf] = {
    path = path,
    cancel = function()
      cancel()
      timer:stop()
      timer:close()
    end,
  }
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
    mods = { keepalt = vim.b.nvim_dir ~= nil },
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
  if path == '' or is_url(path) then
    navigate('.')
    return
  end
  path = M.normalize(path)
  navigate(fs.dirname(path), { name = fs.basename(path), dir = vim.fn.isdirectory(path) == 1 })
end

---@param buf integer
---@param path string
---@param cb fun(err?: string, entries?: nvim.dir.Entry[])
function M.list(buf, path, cb)
  local entries = {} ---@type nvim.dir.Entry[]
  for name, type, err in fs.dir(path, { err = true, plain = true }) do
    if err then
      stop_watcher(buf)
      cb(err)
      return
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
  watch_directory(buf, path)
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
---@param path string
function M.init(buf, path)
  if api.nvim_get_option_value('filetype', { buf = buf }) ~= 'directory' then
    api.nvim_set_option_value('filetype', 'directory', { buf = buf })
  end
  local dir = require('nvim.dir')
  vim.keymap.set('n', '<Plug>(nvim-dir-vsplit)', function()
    dir._open_entry('vsplit')
  end, { buffer = buf, silent = true, desc = 'Open directory entry in a vertical split' })
  vim.keymap.set('n', '<Plug>(nvim-dir-split)', function()
    dir._open_entry('split')
  end, { buffer = buf, silent = true, desc = 'Open directory entry in a horizontal split' })
  dir._map(buf, 'a', '<Plug>(nvim-dir-vsplit)')
  dir._map(buf, 'o', '<Plug>(nvim-dir-split)')
  api.nvim_buf_call(buf, function()
    pcall(api.nvim_cmd, {
      cmd = 'bcd',
      args = { path },
      magic = { file = false, bar = false },
    })
  end)
end

return M
