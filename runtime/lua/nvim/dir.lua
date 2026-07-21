--- @brief
--- Directory listing for `:edit <dir>`.

local api = vim.api

local M = {}

--- An entry rendered as one line in a listing buffer.
---@class (private) nvim.dir.Entry
---@field name string
---@field dir boolean
---@field path? string

--- Callback for `Provider.list_entries`; call once with either an error or entries.
---@alias (private) nvim.dir.ListCallback fun(err: string?, entries: nvim.dir.Entry[]?)

--- State for one buffer opened through `nvim.dir.open()`.
---@class (private) nvim.dir.Ctx
---@field buf integer
---@field name string
---@field provider nvim.dir.Provider
--- Last entries rendered; indexes match buffer lines.
---@field entries nvim.dir.Entry[]
--- Provider-owned mutable state preserved across reloads.
---@field provider_state table
--- Incremented for each list call to ignore stale callbacks.
---@field list_generation integer
---@field group? integer
---@field rendered boolean

--- Source adapter that provides entries and listing actions.
---@class (private) nvim.dir.Provider
--- Produce entries for this listing.
---@field list_entries fun(ctx: nvim.dir.Ctx, cb: nvim.dir.ListCallback)
--- Open an entry from the listing.
---@field open_entry fun(ctx: nvim.dir.Ctx, entry: nvim.dir.Entry)
--- Open the parent listing.
---@field open_parent fun(ctx: nvim.dir.Ctx)
--- Run provider-specific buffer setup after the first render.
---@field attach? fun(ctx: nvim.dir.Ctx)

--- Active listing sessions used by maps/reloads and stale callback checks.
---@param buf integer
---@return nvim.dir.Ctx?
local function get_session(buf)
  if not api.nvim_buf_is_valid(buf) then
    return nil
  end
  local session = vim.b[buf].nvim_dir
  return type(session) == 'function' and session() or nil
end

---@param ctx nvim.dir.Ctx
---@return boolean
local function is_current(ctx)
  return get_session(ctx.buf) == ctx
end

---@param operation string?
---@param err any
local function notify_error(operation, err)
  local prefix = operation and (operation .. ': ') or ''
  vim.notify('dir: ' .. prefix .. tostring(err), vim.log.levels.ERROR)
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

---@param ctx nvim.dir.Ctx
---@param operation string
---@param fn fun(ctx: nvim.dir.Ctx, ...)
---@param ... any
---@return boolean
local function call_provider(ctx, operation, fn, ...)
  local ok, err = pcall(fn, ctx, ...) ---@type boolean, any
  if not ok then
    notify_error(operation, err)
    return false
  end
  return true
end

--- Stop tracking a listing session and remove its autocmds.
---@param ctx nvim.dir.Ctx
local function close_session(ctx)
  if is_current(ctx) then
    vim.b[ctx.buf].nvim_dir = nil
  end
  if ctx.group then
    pcall(api.nvim_del_augroup_by_id, ctx.group)
    ctx.group = nil
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

---@param ctx nvim.dir.Ctx
local function setup_session_autocmds(ctx)
  ctx.group = api.nvim_create_augroup(('nvim.dir.%d'):format(ctx.buf), { clear = true })
  api.nvim_create_autocmd('BufWipeout', {
    group = ctx.group,
    buffer = ctx.buf,
    once = true,
    callback = function()
      close_session(ctx)
    end,
  })
end

---@param ctx nvim.dir.Ctx
local function setup_render_autocmds(ctx)
  api.nvim_create_autocmd('BufReadCmd', {
    group = ctx.group,
    buffer = ctx.buf,
    nested = true,
    desc = 'Reload directory listing',
    callback = function()
      if is_current(ctx) then
        M._reload(ctx.buf)
      end
    end,
  })
end

--- Request entries and render the current list generation.
---@param ctx nvim.dir.Ctx
---@param restore_view? table
local function load(ctx, restore_view)
  ctx.list_generation = ctx.list_generation + 1
  local list_generation = ctx.list_generation
  -- Used to abort failed first opens while preserving the old listing on reload failure.
  local first_render = not ctx.rendered
  local done = false

  ---@param err string?
  ---@param entries nvim.dir.Entry[]?
  local function on_list(err, entries)
    if done then
      return
    end
    done = true
    if list_generation ~= ctx.list_generation then
      return
    end
    if not api.nvim_buf_is_valid(ctx.buf) then
      close_session(ctx)
      return
    end
    if not is_current(ctx) then
      return
    end
    if err ~= nil then
      notify_error(nil, err)
      if first_render then
        close_session(ctx)
      end
      return
    end
    ---@cast entries nvim.dir.Entry[]

    if not render_entries(ctx.buf, ctx.name, entries) then
      if first_render then
        close_session(ctx)
      end
      return
    end
    if restore_view and api.nvim_get_current_buf() == ctx.buf then
      vim.fn.winrestview(restore_view)
    end
    ctx.entries = entries

    if not first_render then
      return
    end

    setup_render_autocmds(ctx)
    ctx.rendered = true
    set_maps(ctx.buf)
    if ctx.provider.attach then
      call_provider(ctx, 'attach', ctx.provider.attach)
    end
  end

  local ok, err = pcall(ctx.provider.list_entries, ctx, on_list) ---@type boolean, any
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

  local old = get_session(buf)
  if old then
    if old.name == name and old.provider == provider then
      load(old, api.nvim_get_current_buf() == buf and vim.fn.winsaveview() or nil)
      return
    end
    close_session(old)
  end

  ---@type nvim.dir.Ctx
  local ctx = {
    buf = buf,
    name = name,
    provider = provider,
    entries = {},
    provider_state = {},
    list_generation = 0,
    rendered = false,
  }

  vim.b[buf].nvim_dir = function()
    return ctx
  end
  setup_session_autocmds(ctx)
  load(ctx)
end

---@param buf integer
---@return nvim.dir.Entry?
local function current_entry(buf)
  local ctx = get_session(buf)
  if not ctx or api.nvim_get_current_buf() ~= buf then
    return nil
  end
  return ctx.entries[api.nvim_win_get_cursor(0)[1]]
end

function M._open_entry()
  local buf = api.nvim_get_current_buf()
  local ctx = get_session(buf)
  local entry = current_entry(buf)
  if ctx and entry then
    call_provider(ctx, 'open_entry', ctx.provider.open_entry, entry)
  end
end

function M._open_parent()
  local buf = api.nvim_get_current_buf()
  local ctx = get_session(buf)
  if ctx then
    call_provider(ctx, 'open_parent', ctx.provider.open_parent)
    return
  end
  -- Keep the global `-` mapping useful from regular file buffers.
  require('nvim.dir.filesystem').open_parent_path(api.nvim_buf_get_name(buf))
end

---@param buf? integer
function M._reload(buf)
  buf = vim._resolve_bufnr(buf)
  local ctx = get_session(buf)
  if not ctx then
    return
  end
  load(ctx, vim.fn.winsaveview())
end

---@param buf integer
---@param path string
function M.try_open(buf, path)
  buf = vim._resolve_bufnr(buf)
  local fs_provider = require('nvim.dir.filesystem')
  if fs_provider.is_navigating() or path == '' then
    return
  end
  if get_session(buf) ~= nil then
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
