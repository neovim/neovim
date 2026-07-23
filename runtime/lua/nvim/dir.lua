--- @brief
--- Directory listing for `:edit <dir>`.

local api = vim.api

local M = {}

--- An entry rendered as one line in a listing buffer.
---@class (private) nvim.dir.Entry
---@field name string
---@field dir boolean

--- Handler for `Provider.list`; call once with either an error or entries.
---@alias (private) nvim.dir.ListHandler fun(err: string?, entries: nvim.dir.Entry[]?)

--- Source adapter that provides entries and listing actions.
---@class (private) nvim.dir.Provider
--- Produce entries for this listing.
---@field list fun(buf: integer, name: string, cb: nvim.dir.ListHandler)
--- Open an entry from the listing.
---@field open fun(buf: integer, name: string, entry: nvim.dir.Entry)
--- Open the parent listing.
---@field open_parent fun(buf: integer, name: string)
--- Run provider-specific buffer setup after a successful open.
---@field init? fun(buf: integer, name: string)

---@class (private) nvim.dir.State
---@field gen integer
---@field provider? nvim.dir.Provider

local listing_group = api.nvim_create_augroup('nvim.dir.listing', { clear = false })

---@param err any
local function notify_error(err)
  vim.notify('dir: ' .. tostring(err), vim.log.levels.ERROR)
end

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

---@param entry nvim.dir.Entry
local function select_entry(entry)
  local line = entry_line(entry)
  vim.fn.search([[\C\m^\V]] .. vim.fn.escape(line, [[\]]) .. [[\m$]], 'cw')
end

---@param buf integer
---@param name string
---@param entries nvim.dir.Entry[]
---@return boolean
local function render_entries(buf, name, entries)
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
  api.nvim_buf_call(buf, function()
    api.nvim_cmd({
      cmd = 'file',
      args = { name },
      mods = { keepalt = true },
      magic = { file = false, bar = false },
    }, {})
  end)
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

--- Stop tracking a listing and remove its autocmds.
---@param buf integer
local function close_listing(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  vim.b[buf].nvim_dir = nil
  api.nvim_clear_autocmds({ group = listing_group, buffer = buf })
end

---@param buf integer
---@return nvim.dir.State?
local function get_state(buf)
  if not api.nvim_buf_is_valid(buf) then
    return nil
  end
  local state = vim.b[buf].nvim_dir
  return type(state) == 'table' and state or nil
end

---@param buf integer
---@return nvim.dir.Entry?
local function current_entry(buf)
  local state = get_state(buf)
  if not state or not state.provider or api.nvim_get_current_buf() ~= buf then
    return nil
  end
  local line = api.nvim_get_current_line()
  if line == '' then
    return nil
  end
  local dir = line:sub(-1) == '/'
  if dir then
    line = line:sub(1, -2)
  end
  if line == '' then
    return nil
  end
  return { name = line:gsub('%z', '\n'), dir = dir }
end

---@type fun(buf: integer, name: string, provider: nvim.dir.Provider, restore_view?: table, setup?: boolean, select?: nvim.dir.Entry)
local load

---@param buf integer
---@param provider nvim.dir.Provider
local function reload(buf, provider)
  local state = get_state(buf)
  if not state or not state.provider then
    return
  end
  local restore_view = api.nvim_get_current_buf() == buf and vim.fn.winsaveview() or nil
  load(buf, api.nvim_buf_get_name(buf), provider, restore_view)
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
  ---@param lhs string
  ---@param plug string
  local function default_map(lhs, plug)
    if vim.fn.mapcheck(lhs, 'n') == '' and vim.fn.hasmapto(plug, 'n') == 0 then
      vim.keymap.set('n', lhs, plug, { buffer = buf, silent = true })
    end
  end
  map('<CR>', '<Plug>(nvim-dir-open)')
  default_map('-', '<Plug>(nvim-dir-up)')
  map('R', '<Plug>(nvim-dir-reload)')
end

---@param buf integer
local function setup_render_autocmds(buf)
  api.nvim_clear_autocmds({ group = listing_group, buffer = buf })
  api.nvim_create_autocmd('BufReadCmd', {
    group = listing_group,
    buffer = buf,
    nested = true,
    desc = 'Reload directory listing',
    callback = function()
      M._reload(buf)
    end,
  })
end

--- Request entries and render the current list generation.
---@param buf integer
---@param name string
---@param provider nvim.dir.Provider
---@param restore_view? table
---@param setup? boolean
---@param select? nvim.dir.Entry
function load(buf, name, provider, restore_view, setup, select)
  local state = get_state(buf) or { gen = 0 }
  local list_gen = state.gen + 1
  state.gen = list_gen
  vim.b[buf].nvim_dir = state
  -- Discard the listing state if the initial load fails, but preserve an existing listing on reload failure.
  local first_render = state.provider == nil
  local done = false

  ---@param err string?
  ---@param entries nvim.dir.Entry[]?
  local function on_list(err, entries)
    if done then
      return
    end
    done = true
    local current_state = get_state(buf)
    if not current_state or current_state.gen ~= list_gen then
      return
    end
    if err ~= nil then
      notify_error(err)
      if first_render then
        close_listing(buf)
      end
      return
    end
    ---@cast entries nvim.dir.Entry[]

    if not render_entries(buf, name, entries) then
      if first_render then
        close_listing(buf)
      end
      return
    end
    if restore_view and api.nvim_get_current_buf() == buf then
      vim.fn.winrestview(restore_view)
    end
    if select and api.nvim_get_current_buf() == buf then
      select_entry(select)
    end
    current_state.provider = provider
    vim.b[buf].nvim_dir = current_state

    if not setup then
      return
    end

    setup_render_autocmds(buf)
    set_maps(buf)
    if provider.init then
      provider.init(buf, name)
    end
  end

  local ok, call_err = pcall(provider.list, buf, name, on_list) ---@type boolean, any
  if not ok then
    -- Route provider exceptions through the list handler so failures share one cleanup path.
    on_list(tostring(call_err), nil)
  end
end

--- Open {buf} as a listing named {name} using {provider}.
---@param buf integer
---@param name string
---@param provider nvim.dir.Provider
---@param select? nvim.dir.Entry
function M.open(buf, name, provider, select)
  buf = vim._resolve_bufnr(buf)
  local state = get_state(buf)
  local restore_view = state
      and state.provider
      and api.nvim_get_current_buf() == buf
      and vim.fn.winsaveview()
    or nil
  load(buf, name, provider, restore_view, true, select)
end

---@param buf integer
---@return nvim.dir.Provider?
local function get_provider(buf)
  local state = get_state(buf)
  return state and state.provider or nil
end

function M._open_entry()
  local buf = api.nvim_get_current_buf()
  local provider = get_provider(buf)
  local entry = current_entry(buf)
  if provider and entry then
    provider.open(buf, api.nvim_buf_get_name(buf), entry)
  end
end

function M._open_parent()
  local buf = api.nvim_get_current_buf()
  local provider = get_provider(buf)
  if provider then
    provider.open_parent(buf, api.nvim_buf_get_name(buf))
    return
  end
  -- Keep the global `-` mapping useful from regular file buffers.
  local name = api.nvim_buf_get_name(buf)
  if name == '' then
    M.try_open(buf, vim.fn.getcwd())
    return
  end
  require('nvim.dir.fs').open_parent_path(api.nvim_buf_get_name(buf))
end

--- Reload the existing listing with its current buffer name and provider.
--- Replace the lines and restore the view only after a successful list; preserve the existing
--- listing on failure. Do not rerun provider initialization or reinstall listing handlers.
---@param buf? integer
function M._reload(buf)
  buf = vim._resolve_bufnr(buf)
  local provider = get_provider(buf)
  if provider then
    reload(buf, provider)
  end
end

---@param buf integer
---@param path string
function M.try_open(buf, path)
  buf = vim._resolve_bufnr(buf)
  local fs_provider = require('nvim.dir.fs')
  if fs_provider.is_navigating() or path == '' then
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

  if vim.fn.isdirectory(path) == 0 then
    return
  end
  M.open(buf, fs_provider.normalize(path), fs_provider)
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
