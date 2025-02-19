local protocol = require('vim.lsp.protocol')
local sync = require('vim.lsp.sync')
local util = require('vim.lsp.util')

local api = vim.api
local uv = vim.uv

local M = {}

--- LSP has 3 different sync modes:
---   - None (Servers will read the files themselves when needed)
---   - Full (Client sends the full buffer content on updates)
---   - Incremental (Client sends only the changed parts)
---
--- Changes are tracked per buffer.
--- A buffer can have multiple clients attached and each client needs to send the changes
--- To minimize the amount of changesets to compute, computation is grouped:
---
---   None: One group for all clients
---   Full: One group for all clients
---   Incremental: One group per `position_encoding`
---
--- Sending changes can be debounced per buffer. To simplify the implementation the
--- smallest debounce interval is used and we don't group clients by different intervals.
---
--- @class vim.lsp.CTGroup
--- @field sync_kind integer TextDocumentSyncKind, considers config.flags.allow_incremental_sync
--- @field position_encoding "utf-8"|"utf-16"|"utf-32"
---
--- @class vim.lsp.CTBufferState
--- @field name string name of the buffer
--- @field lines string[] snapshot of buffer lines from last didChange
--- @field lines_tmp string[]
--- @field pending_changes table[] List of debounced changes in incremental sync mode
--- @field timer uv.uv_timer_t? uv_timer
--- @field last_flush nil|number uv.hrtime of the last flush/didChange-notification
--- @field needs_flush boolean true if buffer updates haven't been sent to clients/servers yet
--- @field refs integer how many clients are using this group
---
--- @class vim.lsp.CTGroupState
--- @field buffers table<integer,vim.lsp.CTBufferState>
--- @field debounce integer debounce duration in ms
--- @field clients table<integer, vim.lsp.Client> clients using this state. {client_id, client}

---@param group vim.lsp.CTGroup
---@return string
local function group_key(group)
  if group.sync_kind == protocol.TextDocumentSyncKind.Incremental then
    return tostring(group.sync_kind) .. '\0' .. group.position_encoding
  end
  return tostring(group.sync_kind)
end

---@type table<vim.lsp.CTGroup,vim.lsp.CTGroupState>
local state_by_group = setmetatable({}, {
  __index = function(tbl, k)
    return rawget(tbl, group_key(k))
  end,
  __newindex = function(tbl, k, v)
    rawset(tbl, group_key(k), v)
  end,
})

---@param client vim.lsp.Client
---@return vim.lsp.CTGroup
local function get_group(client)
  local allow_inc_sync = vim.F.if_nil(client.flags.allow_incremental_sync, true)
  local change_capability = vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'change')
  local sync_kind = change_capability or protocol.TextDocumentSyncKind.None
  if not allow_inc_sync and change_capability == protocol.TextDocumentSyncKind.Incremental then
    sync_kind = protocol.TextDocumentSyncKind.Full --[[@as integer]]
  end
  return {
    sync_kind = sync_kind,
    position_encoding = client.offset_encoding,
  }
end

---@param state vim.lsp.CTBufferState
---@param encoding string
---@param bufnr integer
---@param firstline integer
---@param lastline integer
---@param new_lastline integer
---@return lsp.TextDocumentContentChangeEvent
local function incremental_changes(state, encoding, bufnr, firstline, lastline, new_lastline)
  local prev_lines = state.lines
  local curr_lines = state.lines_tmp

  local changed_lines = api.nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
  for i = 1, firstline do
    curr_lines[i] = prev_lines[i]
  end
  for i = firstline + 1, new_lastline do
    curr_lines[i] = changed_lines[i - firstline]
  end
  for i = lastline + 1, #prev_lines do
    curr_lines[i - lastline + new_lastline] = prev_lines[i]
  end
  if vim.tbl_isempty(curr_lines) then
    -- Can happen when deleting the entire contents of a buffer, see https://github.com/neovim/neovim/issues/16259.
    curr_lines[1] = ''
  end

  local line_ending = vim.lsp._buf_get_line_ending(bufnr)
  local incremental_change = sync.compute_diff(
    state.lines,
    curr_lines,
    firstline,
    lastline,
    new_lastline,
    encoding,
    line_ending
  )

  -- Double-buffering of lines tables is used to reduce the load on the garbage collector.
  -- At this point the prev_lines table is useless, but its internal storage has already been allocated,
  -- so let's keep it around for the next didChange event, in which it will become the next
  -- curr_lines table. Note that setting elements to nil doesn't actually deallocate slots in the
  -- internal storage - it merely marks them as free, for the GC to deallocate them.
  for i in ipairs(prev_lines) do
    prev_lines[i] = nil
  end
  state.lines = curr_lines
  state.lines_tmp = prev_lines

  return incremental_change
end

---@param client vim.lsp.Client
---@param bufnr integer
function M.init(client, bufnr)
  assert(client.offset_encoding, 'lsp client must have an offset_encoding')
  local group = get_group(client)
  local state = state_by_group[group]
  if state then
    state.debounce = math.min(state.debounce, client.flags.debounce_text_changes or 150)
    state.clients[client.id] = client
  else
    state = {
      buffers = {},
      debounce = client.flags.debounce_text_changes or 150,
      clients = {
        [client.id] = client,
      },
    }
    state_by_group[group] = state
  end
  local buf_state = state.buffers[bufnr]
  if buf_state then
    buf_state.refs = buf_state.refs + 1
  else
    buf_state = {
      name = api.nvim_buf_get_name(bufnr),
      lines = {},
      lines_tmp = {},
      pending_changes = {},
      needs_flush = false,
      refs = 1,
    }
    state.buffers[bufnr] = buf_state
    if group.sync_kind == protocol.TextDocumentSyncKind.Incremental then
      buf_state.lines = api.nvim_buf_get_lines(bufnr, 0, -1, true)
    end
  end
end

--- @param client vim.lsp.Client
--- @param bufnr integer
--- @param name string
--- @return string
function M._get_and_set_name(client, bufnr, name)
  local state = state_by_group[get_group(client)] or {}
  local buf_state = (state.buffers or {})[bufnr]
  local old_name = buf_state.name
  buf_state.name = name
  return old_name
end

---@param buf_state vim.lsp.CTBufferState
local function reset_timer(buf_state)
  local timer = buf_state.timer
  if timer then
    buf_state.timer = nil
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

--- @param client vim.lsp.Client
--- @param bufnr integer
function M.reset_buf(client, bufnr)
  M.flush(client, bufnr)
  local state = state_by_group[get_group(client)]
  if not state then
    return
  end
  assert(state.buffers, 'CTGroupState must have buffers')
  local buf_state = state.buffers[bufnr]
  buf_state.refs = buf_state.refs - 1
  assert(buf_state.refs >= 0, 'refcount on buffer state must not get negative')
  if buf_state.refs == 0 then
    state.buffers[bufnr] = nil
    reset_timer(buf_state)
  end
end

--- @param client vim.lsp.Client
function M.reset(client)
  local state = state_by_group[get_group(client)]
  if not state then
    return
  end
  state.clients[client.id] = nil
  if vim.tbl_count(state.clients) == 0 then
    for _, buf_state in pairs(state.buffers) do
      reset_timer(buf_state)
    end
    state.buffers = {}
  end
end

-- Adjust debounce time by taking time of last didChange notification into
-- consideration. If the last didChange happened more than `debounce` time ago,
-- debounce can be skipped and otherwise maybe reduced.
--
-- This turns the debounce into a kind of client rate limiting
--
---@param debounce integer
---@param buf_state vim.lsp.CTBufferState
---@return number
local function next_debounce(debounce, buf_state)
  if debounce == 0 then
    return 0
  end
  local ns_to_ms = 0.000001
  if not buf_state.last_flush then
    return debounce
  end
  local now = uv.hrtime()
  local ms_since_last_flush = (now - buf_state.last_flush) * ns_to_ms
  return math.max(debounce - ms_since_last_flush, 0)
end

---@param bufnr integer
---@param sync_kind integer protocol.TextDocumentSyncKind
---@param state vim.lsp.CTGroupState
---@param buf_state vim.lsp.CTBufferState
local function send_changes(bufnr, sync_kind, state, buf_state)
  if not buf_state.needs_flush then
    return
  end
  buf_state.last_flush = uv.hrtime()
  buf_state.needs_flush = false

  if not api.nvim_buf_is_valid(bufnr) then
    buf_state.pending_changes = {}
    return
  end

  local changes --- @type lsp.TextDocumentContentChangeEvent[]
  if sync_kind == protocol.TextDocumentSyncKind.None then
    return
  elseif sync_kind == protocol.TextDocumentSyncKind.Incremental then
    changes = buf_state.pending_changes
    buf_state.pending_changes = {}
  else
    changes = {
      { text = vim.lsp._buf_get_full_text(bufnr) },
    }
  end
  local uri = vim.uri_from_bufnr(bufnr)
  for _, client in pairs(state.clients) do
    if not client:is_stopped() and vim.lsp.buf_is_attached(bufnr, client.id) then
      client:notify(protocol.Methods.textDocument_didChange, {
        textDocument = {
          uri = uri,
          version = util.buf_versions[bufnr],
        },
        contentChanges = changes,
      })
    end
  end
end

--- @param bufnr integer
--- @param firstline integer
--- @param lastline integer
--- @param new_lastline integer
--- @param group vim.lsp.CTGroup
local function send_changes_for_group(bufnr, firstline, lastline, new_lastline, group)
  local state = state_by_group[group]
  if not state then
    error(
      string.format(
        'changetracking.init must have been called for all LSP clients. group=%s states=%s',
        vim.inspect(group),
        vim.inspect(vim.tbl_keys(state_by_group))
      )
    )
  end
  local buf_state = state.buffers[bufnr]
  buf_state.needs_flush = true
  reset_timer(buf_state)
  local debounce = next_debounce(state.debounce, buf_state)
  if group.sync_kind == protocol.TextDocumentSyncKind.Incremental then
    -- This must be done immediately and cannot be delayed
    -- The contents would further change and startline/endline may no longer fit
    local changes = incremental_changes(
      buf_state,
      group.position_encoding,
      bufnr,
      firstline,
      lastline,
      new_lastline
    )
    table.insert(buf_state.pending_changes, changes)
  end
  if debounce == 0 then
    send_changes(bufnr, group.sync_kind, state, buf_state)
  else
    local timer = assert(uv.new_timer(), 'Must be able to create timer')
    buf_state.timer = timer
    timer:start(
      debounce,
      0,
      vim.schedule_wrap(function()
        reset_timer(buf_state)
        send_changes(bufnr, group.sync_kind, state, buf_state)
      end)
    )
  end
end

--- @param bufnr integer
--- @param firstline integer
--- @param lastline integer
--- @param new_lastline integer
function M.send_changes(bufnr, firstline, lastline, new_lastline)
  local groups = {} ---@type table<string,vim.lsp.CTGroup>
  for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    local group = get_group(client)
    groups[group_key(group)] = group
  end
  for _, group in pairs(groups) do
    send_changes_for_group(bufnr, firstline, lastline, new_lastline, group)
  end
end

--- Flushes any outstanding change notification.
---@param client vim.lsp.Client
---@param bufnr? integer
function M.flush(client, bufnr)
  local group = get_group(client)
  local state = state_by_group[group]
  if not state then
    return
  end
  if bufnr then
    local buf_state = state.buffers[bufnr] or {}
    reset_timer(buf_state)
    send_changes(bufnr, group.sync_kind, state, buf_state)
  else
    for buf, buf_state in pairs(state.buffers) do
      reset_timer(buf_state)
      send_changes(buf, group.sync_kind, state, buf_state)
    end
  end
end

return M
