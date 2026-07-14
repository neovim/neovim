--- @brief
--- Directory listing for `:edit <dir>`.

local api = vim.api

local M = {}

--- An entry rendered as one line in a listing buffer.
---@class (private) nvim.dir.Entry
---@field name string
---@field dir boolean
---@field path? string

--- Callback for `Driver.list_entries`; call once with either an error or entries.
---@alias (private) nvim.dir.ListCallback fun(err: string?, entries: nvim.dir.Entry[]?)

--- State for one buffer opened through `nvim.dir.open()`.
---@class (private) nvim.dir.Ctx
---@field buf integer
---@field name string
---@field driver nvim.dir.Driver
--- Last entries rendered; indexes match buffer lines.
---@field entries nvim.dir.Entry[]
--- Driver-owned mutable state preserved across reloads.
---@field driver_state table
--- Incremented for each list call to ignore stale callbacks.
---@field list_generation integer

--- Source adapter that provides entries and listing actions.
---@class (private) nvim.dir.Driver
--- Produce entries for this listing.
---@field list_entries fun(ctx: nvim.dir.Ctx, cb: nvim.dir.ListCallback)
--- Open an entry from the listing.
---@field open_entry fun(ctx: nvim.dir.Ctx, entry: nvim.dir.Entry)
--- Open the parent listing.
---@field open_parent fun(ctx: nvim.dir.Ctx)
--- Run driver-specific buffer setup after the first render.
---@field attach? fun(ctx: nvim.dir.Ctx)

--- Active listing sessions used by maps/reloads and stale callback checks.
---@type table<integer,nvim.dir.Ctx>
local active_sessions = {}

---@type table<nvim.dir.Ctx,integer>
local session_groups = {}

---@type table<nvim.dir.Ctx,true>
local rendered_sessions = {}

---@param operation string?
---@param err any
local function notify_error(operation, err)
  local prefix = operation and (operation .. ': ') or ''
  vim.notify('dir: ' .. prefix .. tostring(err), vim.log.levels.ERROR)
end

---@param buf integer?
---@param allow_nil boolean
---@return integer
local function resolve_buf(buf, allow_nil)
  vim.validate('buf', buf, 'number', allow_nil)
  if buf == nil or buf == 0 then
    buf = api.nvim_get_current_buf()
  end
  if not api.nvim_buf_is_valid(buf) then
    error('invalid buffer: ' .. buf, 2)
  end
  return buf
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
---@param method string
---@param ... any
---@return boolean
local function call_driver(ctx, method, ...)
  local fn = ctx.driver[method]
  if fn == nil then
    return true
  end
  local ok, err = pcall(fn, ctx, ...)
  if not ok then
    notify_error(method, err)
    return false
  end
  return true
end

--- Stop tracking a listing session and remove its autocmds.
---@param ctx nvim.dir.Ctx
local function close_session(ctx)
  if active_sessions[ctx.buf] == ctx then
    active_sessions[ctx.buf] = nil
  end
  local group = session_groups[ctx]
  if group then
    pcall(api.nvim_del_augroup_by_id, group)
    session_groups[ctx] = nil
  end
  rendered_sessions[ctx] = nil
end

---@param buf integer
---@param ctx nvim.dir.Ctx
local function set_maps(buf, ctx)
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
  local group = api.nvim_create_augroup(('nvim.dir.%d'):format(ctx.buf), { clear = true })
  session_groups[ctx] = group
  api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = ctx.buf,
    once = true,
    callback = function()
      if active_sessions[ctx.buf] == ctx then
        close_session(ctx)
      end
    end,
  })
end

---@param ctx nvim.dir.Ctx
local function setup_render_autocmds(ctx)
  api.nvim_create_autocmd('BufReadCmd', {
    group = session_groups[ctx],
    buffer = ctx.buf,
    nested = true,
    desc = 'Reload directory listing',
    callback = function()
      if active_sessions[ctx.buf] == ctx then
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
  local first_render = rendered_sessions[ctx] == nil
  local done = false

  ---@param err string?
  ---@param entries nvim.dir.Entry[]?
  local function on_list(err, entries)
    if done then
      return
    end
    done = true
    if active_sessions[ctx.buf] ~= ctx or list_generation ~= ctx.list_generation then
      return
    end
    if not api.nvim_buf_is_valid(ctx.buf) then
      close_session(ctx)
      return
    end
    if err ~= nil then
      notify_error(nil, err)
      if first_render then
        close_session(ctx)
      end
      return
    end

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
    vim.b[ctx.buf].nvim_dir = ctx.name

    if not first_render then
      return
    end

    setup_render_autocmds(ctx)
    rendered_sessions[ctx] = true
    set_maps(ctx.buf, ctx)
    if ctx.driver.attach then
      call_driver(ctx, 'attach')
    end
  end

  local ok, err = pcall(ctx.driver.list_entries, ctx, on_list)
  if not ok then
    on_list(tostring(err))
  end
end

--- Open {buf} as a listing named {name} using {driver}.
---@param buf integer
---@param name string
---@param driver nvim.dir.Driver
---@return nvim.dir.Ctx
function M.open(buf, name, driver)
  buf = resolve_buf(buf, false)
  vim.validate('name', name, 'string')
  vim.validate('driver', driver, 'table')
  vim.validate('driver.list_entries', driver.list_entries, 'function')
  vim.validate('driver.open_entry', driver.open_entry, 'function')
  vim.validate('driver.open_parent', driver.open_parent, 'function')

  local old = active_sessions[buf]
  if old then
    close_session(old)
  end

  local ctx = {
    buf = buf,
    name = name,
    driver = driver,
    entries = {},
    driver_state = {},
    list_generation = 0,
  }

  active_sessions[buf] = ctx
  setup_session_autocmds(ctx)
  load(ctx)
  return ctx
end

--- Return the active listing session for {buf}.
---@param buf integer
---@return nvim.dir.Ctx?
function M.session(buf)
  return active_sessions[resolve_buf(buf, false)]
end

--- Return the entry rendered at {lnum}, or at the cursor in current {buf}.
---@param buf integer
---@param lnum? integer
---@return nvim.dir.Entry?
function M.entry(buf, lnum)
  buf = resolve_buf(buf, false)
  vim.validate('lnum', lnum, 'number', true)
  local ctx = active_sessions[buf]
  if not ctx then
    return nil
  end
  if lnum == nil then
    if api.nvim_get_current_buf() ~= buf then
      error('lnum required unless buf is current buffer', 2)
    end
    lnum = api.nvim_win_get_cursor(0)[1]
  end
  if lnum < 1 or lnum ~= math.floor(lnum) or lnum > #ctx.entries then
    return nil
  end
  return ctx.entries[lnum]
end

function M._open_entry()
  local buf = api.nvim_get_current_buf()
  local ctx = active_sessions[buf]
  local entry = M.entry(buf)
  if ctx and entry then
    call_driver(ctx, 'open_entry', entry)
  end
end

function M._open_parent()
  local buf = api.nvim_get_current_buf()
  local ctx = active_sessions[buf]
  if ctx then
    call_driver(ctx, 'open_parent')
    return
  end
  -- Keep the global `-` mapping useful from regular file buffers.
  require('nvim.dir._filesystem').open_parent_path(api.nvim_buf_get_name(buf))
end

---@param buf? integer
function M._reload(buf)
  buf = resolve_buf(buf, true)
  local ctx = active_sessions[buf]
  if not ctx then
    return
  end
  load(ctx, vim.fn.winsaveview())
end

---@param buf integer
---@param path string
function M.try_open(buf, path)
  buf = resolve_buf(buf, false)
  vim.validate('path', path, 'string')
  local fs_driver = require('nvim.dir._filesystem')
  if fs_driver.is_navigating() or path == '' then
    return
  end
  if active_sessions[buf] ~= nil then
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
  M.open(buf, fs_driver.normalize(path), fs_driver)
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
