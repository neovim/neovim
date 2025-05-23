local uv = vim.uv

local M = {}

local Namespace = vim.api.nvim_create_namespace('vim.ui.exploer')
local PathSep = vim.fn.has('win32') == 1 and '\\' or '/'

local LastBuf, LastAltBuf = -1, -1

---@nodoc
---@class (private) vim.ui.explorer.Explorer
---@field buf integer
---@field watcher uv.uv_fs_event_t
---
---
---@type table<string, vim.ui.explorer.Explorer>
local Explorers = {}

---@param path string?
---@return string
local function fs_type(path)
  return (uv.fs_stat(path or '') or {}).type
end

---@param path string?
---@return boolean
local function fs_is_dir(path)
  return fs_type(path) == 'directory'
end

---@param path string?
---@return boolean
local function fs_is_link_dir(path)
  local abspath = vim.fs.abspath(path or '')
  return fs_is_dir(abspath)
end

--- @class vim.ui.explorer.Opts
---
--- Predicate to change the ordering of filepaths in the buffer
--- @see table.sort()
--- @field sort fun(path1: string, path2: string):boolean
---
--- List of |lua pattern|s to exclude from the directory view (default: `{}`)
--- @field exclude string[]
local Config = {
  sort = function(path1, path2)
    if fs_is_dir(path1) and not fs_is_dir(path2) then
      return true
    end

    if not fs_is_dir(path1) and fs_is_dir(path2) then
      return false
    end

    -- Otherwise order alphabetically ignoring case
    return path1:lower() < path2:lower()
  end,
  exclude = {},
}

---@param path string
---@return string[]
local function fs_read_dir(path)
  local paths = {}

  local dirname = vim.fs.abspath(path)
  for name in vim.fs.dir(path) do
    local is_to_exclude = vim.tbl_contains(Config.exclude, function(x)
      return name:match(x)
    end, { predicate = true })

    if not is_to_exclude then
      table.insert(paths, vim.fs.joinpath(dirname, name))
    end
  end

  table.sort(paths, Config.sort)

  return paths
end

local function restore_altbuf()
  if not vim.api.nvim_buf_is_valid(LastAltBuf) then
    return
  end
  vim.fn.setreg('#', LastAltBuf)
end

---@param handle string | integer
local function open_buffer(handle)
  local buf = vim.fn.bufnr(handle)
  if buf == -1 then
    vim.cmd('silent! keepjumps keepalt edit ' .. handle)
  else
    vim.cmd('silent! keepjumps keepalt buffer ' .. handle)
  end
  restore_altbuf()
end

local function mapping_quit()
  open_buffer(LastBuf)
  restore_altbuf()
end

local function mapping_open()
  local path = vim.api.nvim_get_current_line()
  if path == '' then
    return
  end

  path = vim.fs.normalize(path)

  if fs_is_dir(path) then
    M.open(path)
  else
    open_buffer(path)
  end
end

local function mapping_goto_parent()
  local cwd = vim.api.nvim_buf_get_name(0)
  local parent = vim.fs.dirname(cwd)
  M.open(vim.fs.normalize(parent))
end

---@param buf integer
local function init_mappings(buf)
  local map = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, nowait = true })
  end

  map('n', '<CR>', mapping_open)
  map('n', '-', mapping_goto_parent)
  map('n', 'q', mapping_quit)
  map('n', '<C-6>', mapping_quit)
  map('n', '<C-^>', mapping_quit)
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
  return buf
end

---@param explorer vim.ui.explorer.Explorer
---@param paths string[]
local function explorer_populate(explorer, paths)
  vim.bo[explorer.buf].modifiable = true

  ---@type table<string, any>[]
  local ranges = {}

  paths = vim
    .iter(paths)
    :enumerate()
    :map(function(i, path)
      local range = {
        { i - 1, 0 },
        { i - 1, #path },
      }

      local type = fs_type(path)

      if type == 'directory' then
        -- include trailing slash
        ---@type string
        path = path .. PathSep
        range[2][2] = range[2][2] + 1
        table.insert(ranges, { 'Directory', range })
      elseif type == 'link' then
        if fs_is_link_dir(path) then
          ---@type string
          path = path .. PathSep
          -- include trailing slash
          range[2][2] = range[2][2] + 1
        end
        table.insert(ranges, { 'Question', range })
      end

      return path
    end)
    :totable()

  vim.api.nvim_buf_set_lines(explorer.buf, 0, -1, false, paths)

  for _, pair in ipairs(ranges) do
    vim.hl.range(explorer.buf, Namespace, pair[1], unpack(pair[2]))
  end

  vim.bo[explorer.buf].modifiable = false
end

---@param explorer vim.ui.explorer.Explorer
local function explorer_refresh(explorer)
  local path = explorer.watcher:getpath()
  local paths = fs_read_dir(path or '')
  explorer_populate(explorer, paths)
end

local on_fs_event = vim.schedule_wrap(function(explorer)
  explorer_refresh(explorer)
end)

---@param path string
---@return vim.ui.explorer.Explorer
local function create_explorer(path)
  local watcher = uv.new_fs_event()
  local explorer = {
    buf = create_buffer(path),
    watcher = watcher,
  }

  if not watcher then
    error('Failed to watch directory', 0)
  end

  watcher:start(path, { watch_entry = true }, function(_, _, events)
    on_fs_event(explorer, events or {})
  end)

  return explorer
end

---@param path string
---@return vim.ui.explorer.Explorer
local function get_explorer(path)
  local explorer = Explorers[path]
  if not explorer then
    explorer = create_explorer(path)
    Explorers[path] = explorer
  elseif explorer and not vim.api.nvim_buf_is_valid(explorer.buf) then
    explorer.buf = create_buffer(path)
  end
  return explorer
end

---@param opts vim.ui.explorer.Opts? When omitted or `nil`, retrieve the current
---       configuration. Otherwise, a configuration table (see |vim.ui.explorer.Opts|).
---@return vim.ui.explorer.Opts? : Current explorer config if {opts} is omitted.
function M.config(opts)
  vim.validate('opts', opts, 'table', true)

  if not opts then
    return vim.deepcopy(Config, true)
  end

  Config = vim.tbl_extend('force', Config, opts)
end

---@param path string
function M.open(path)
  vim.validate('path', path, { 'string', 'nil' }, true)

  if path and not fs_is_dir(path) then
    error('path must be a directory')
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(current_buf)

  if not fs_is_dir(current_file) then
    LastBuf = current_buf
    local alternate_file = vim.fn.bufnr('#')
    if vim.api.nvim_buf_is_valid(alternate_file) then
      LastAltBuf = alternate_file
    end
  end

  -- Handle scratch buffer
  if not path then
    path = current_file == '' and uv.cwd() or vim.fs.dirname(current_file)
  end

  local explorer = get_explorer(path)
  explorer_refresh(explorer)
  open_buffer(explorer.buf)
end

do
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'directory',
    group = vim.api.nvim_create_augroup('vim.ui.explorer', {}),
    callback = function(args)
      -- Hack to make it evaluate when the window shows up
      vim.defer_fn(function()
        vim.wo.conceallevel = 3
        vim.wo.concealcursor = 'nc'
      end, 0)
      local path = vim.fs.abspath(args.file)
      -- Conceal path with would be the cwd of the buffer
      vim.cmd(('syn match Conceal %q conceal'):format(path .. PathSep))
    end,
  })
end

return M
