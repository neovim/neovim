--- @brief
--- Directory listing for `:edit <dir>`.

local api = vim.api

local M = {}

--- An entry rendered as one line in a listing buffer.
---@class (private) nvim.dir.Entry
---@field name string
---@field dir boolean

--- Callback for `Provider.list_entries`; call once with either an error or entries.
---@alias (private) nvim.dir.ListCallback fun(err: string?, entries: nvim.dir.Entry[]?)

--- Source adapter that provides entries and listing actions.
---@class (private) nvim.dir.Provider
--- Produce entries for this listing.
---@field list_entries fun(buf: integer, name: string, cb: nvim.dir.ListCallback)
--- Open an entry from the listing.
---@field open_entry fun(buf: integer, name: string, entry: nvim.dir.Entry)
--- Open the parent listing.
---@field open_parent fun(buf: integer, name: string)
--- Run provider-specific buffer setup after a successful open.
---@field attach? fun(buf: integer, name: string)

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
  vim.b[buf].nvim_dir_gen = nil
  vim.b[buf].nvim_dir_provider = nil
  api.nvim_clear_autocmds({ group = listing_group, buffer = buf })
end

---@param buf integer
---@return nvim.dir.Entry?
local function current_entry(buf)
  if vim.b[buf].nvim_dir == nil or api.nvim_get_current_buf() ~= buf then
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

---@type fun(buf: integer, name: string, provider: nvim.dir.Provider, restore_view?: table, setup?: boolean)
local load

---@param buf integer
---@param provider nvim.dir.Provider
local function reload(buf, provider)
  if not api.nvim_buf_is_valid(buf) or vim.b[buf].nvim_dir == nil then
    return
  end
  local restore_view = api.nvim_get_current_buf() == buf and vim.fn.winsaveview() or nil
  load(buf, api.nvim_buf_get_name(buf), provider, restore_view)
end

---@param buf integer
---@param provider nvim.dir.Provider
local function set_maps(buf, provider)
  vim.b[buf].nvim_dir_provider = provider

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
function load(buf, name, provider, restore_view, setup)
  local list_gen = vim._assert_integer(vim.b[buf].nvim_dir_gen or 0) + 1
  vim.b[buf].nvim_dir_gen = list_gen
  -- Used to abort failed first opens while preserving the old listing on reload failure.
  local first_render = vim.b[buf].nvim_dir == nil
  local done = false

  ---@param err string?
  ---@param entries nvim.dir.Entry[]?
  local function on_list(err, entries)
    if done then
      return
    end
    done = true
    if not api.nvim_buf_is_valid(buf) or vim.b[buf].nvim_dir_gen ~= list_gen then
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
    vim.b[buf].nvim_dir = name

    if not setup then
      return
    end

    setup_render_autocmds(buf)
    set_maps(buf, provider)
    if provider.attach then
      provider.attach(buf, name)
    end
  end

  local ok, err = pcall(provider.list_entries, buf, name, on_list) ---@type boolean, any
  if not ok then
    on_list(tostring(err))
  end
end

--- Open {buf} as a listing named {name} using {provider}.
---@param buf integer
---@param name string
---@param provider nvim.dir.Provider
function M.open(buf, name, provider)
  buf = vim._resolve_bufnr(buf)
  local restore_view = vim.b[buf].nvim_dir ~= nil
      and api.nvim_get_current_buf() == buf
      and vim.fn.winsaveview()
    or nil
  load(buf, name, provider, restore_view, true)
end

---@param buf integer
---@return nvim.dir.Provider?
local function get_provider(buf)
  if not api.nvim_buf_is_valid(buf) then
    return nil
  end
  local provider = vim.b[buf].nvim_dir_provider
  return type(provider) == 'table' and provider or nil
end

function M._open_entry()
  local buf = api.nvim_get_current_buf()
  local provider = get_provider(buf)
  local entry = current_entry(buf)
  if provider and entry then
    provider.open_entry(buf, api.nvim_buf_get_name(buf), entry)
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
  require('nvim.dir.fs').open_parent_path(api.nvim_buf_get_name(buf))
end

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
