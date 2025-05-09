--- @brief
--- The `vim.lsp.linked_editing_range` module enables "linked editing" via a language server's
--- `textDocument/linkedEditingRange` request. Linked editing ranges are synchronized text regions,
--- meaning changes in one range are mirrored in all the others. This is helpful in HTML files for
--- example, where the language server can update the text of a closing tag if its opening tag was
--- changed.
---
--- LSP spec: https://microsoft.github.io/language-server-protocol/specification/#textDocument_linkedEditingRange

local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local lsp = vim.lsp
local method = require('vim.lsp.protocol').Methods.textDocument_linkedEditingRange
local Range = require('vim.treesitter._range')
local api = vim.api
local M = {}

---@class (private) vim.lsp.linked_editing_range.state Global state for linked editing ranges
---An optional word pattern (regular expression) that describes valid contents for the given ranges.
---@field word_pattern string
---@field range_index? integer The index of the range that the cursor is on.
---@field namespace integer namespace for range extmarks

---@class (private) vim.lsp.linked_editing_range.LinkedEditor
---@field active table<integer, vim.lsp.linked_editing_range.LinkedEditor>
---@field bufnr integer
---@field augroup integer augroup for buffer events
---@field client_states table<integer, vim.lsp.linked_editing_range.state>
local LinkedEditor = { active = {} }

---@package
---@param client_id integer
function LinkedEditor:attach(client_id)
  if self.client_states[client_id] then
    return
  end
  self.client_states[client_id] = {
    namespace = api.nvim_create_namespace('nvim.lsp.linked_editing_range:' .. client_id),
    word_pattern = '^[%w%-_]*$',
  }
end

---@package
---@param bufnr integer
---@param client_state vim.lsp.linked_editing_range.state
local function clear_ranges(bufnr, client_state)
  api.nvim_buf_clear_namespace(bufnr, client_state.namespace, 0, -1)
  client_state.range_index = nil
end

---@package
---@param client_id integer
function LinkedEditor:detach(client_id)
  local client_state = self.client_states[client_id]
  if not client_state then
    return
  end

  --TODO: delete namespace if/when that becomes possible
  clear_ranges(self.bufnr, client_state)
  self.client_states[client_id] = nil

  -- Destroy the LinkedEditor instance if we are detaching the last client
  if vim.tbl_isempty(self.client_states) then
    api.nvim_del_augroup_by_id(self.augroup)
    LinkedEditor.active[self.bufnr] = nil
  end
end

---Syncs the text of each linked editing range after a range has been edited.
---
---@package
---@param bufnr integer
---@param client_state vim.lsp.linked_editing_range.state
local function update_ranges(bufnr, client_state)
  if not client_state.range_index then
    return
  end

  local ns = client_state.namespace
  local ranges = api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
  if #ranges <= 1 then
    return
  end

  local r = assert(ranges[client_state.range_index])
  local replacement = api.nvim_buf_get_text(bufnr, r[2], r[3], r[4].end_row, r[4].end_col, {})

  if not string.match(table.concat(replacement, '\n'), client_state.word_pattern) then
    clear_ranges(bufnr, client_state)
    return
  end

  -- Join text update changes into one undo chunk. If we came here from an undo, then return.
  local success = pcall(vim.cmd.undojoin)
  if not success then
    return
  end

  for i, range in ipairs(ranges) do
    if i ~= client_state.range_index then
      api.nvim_buf_set_text(
        bufnr,
        range[2],
        range[3],
        range[4].end_row,
        range[4].end_col,
        replacement
      )
    end
  end
end

---|lsp-handler| for the `textDocument/linkedEditingRange` request. Sets marks for the given ranges
---(if present) and tracks which range the cursor is currently inside.
---
---@package
---@param err lsp.ResponseError?
---@param result lsp.LinkedEditingRanges?
---@param ctx lsp.HandlerContext
function LinkedEditor:handler(err, result, ctx)
  if err then
    log.error('linkededitingrange', err)
    return
  end

  local client_id = ctx.client_id
  local client_state = self.client_states[client_id]
  if not client_state then
    return
  end

  local bufnr = assert(ctx.bufnr)
  if not api.nvim_buf_is_loaded(bufnr) or util.buf_versions[bufnr] ~= ctx.version then
    return
  end

  clear_ranges(bufnr, client_state)

  if not result then
    return
  end

  local client = assert(lsp.get_client_by_id(client_id))

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local curpos = api.nvim_win_get_cursor(0)
  local cursor_range = { curpos[1] - 1, curpos[2], curpos[1] - 1, curpos[2] }
  for i, range in ipairs(result.ranges) do
    local start_line = range.start.line
    local line = lines and lines[start_line + 1] or ''
    local start_col = vim.str_byteindex(line, client.offset_encoding, range.start.character, false)
    local end_line = range['end'].line
    line = lines and lines[end_line + 1] or ''
    local end_col = vim.str_byteindex(line, client.offset_encoding, range['end'].character, false)

    api.nvim_buf_set_extmark(bufnr, client_state.namespace, start_line, start_col, {
      end_line = end_line,
      end_col = end_col,
      hl_group = 'LspReferenceTarget',
      right_gravity = false,
      end_right_gravity = true,
    })

    local range_tuple = { start_line, start_col, end_line, end_col }
    if Range.contains(range_tuple, cursor_range) then
      client_state.range_index = i
    end
  end

  -- TODO: Apply the client's own word pattern, if it exists
end

---Refreshes the linked editing ranges by issuing a new request.
---@package
function LinkedEditor:refresh()
  local bufnr = self.bufnr

  util._cancel_requests({
    bufnr = bufnr,
    method = method,
    type = 'pending',
  })
  lsp.buf_request(bufnr, method, function(client)
    return util.make_position_params(0, client.offset_encoding)
  end, function(...)
    self:handler(...)
  end)
end

---Construct a new LinkedEditor for the buffer.
---
---@private
---@param bufnr integer
---@return vim.lsp.linked_editing_range.LinkedEditor
function LinkedEditor.new(bufnr)
  local self = setmetatable({}, { __index = LinkedEditor })

  self.bufnr = bufnr
  local augroup =
    api.nvim_create_augroup('nvim.lsp.linked_editing_range:' .. bufnr, { clear = true })
  self.augroup = augroup
  self.client_states = {}

  api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = bufnr,
    group = augroup,
    callback = function()
      for _, client_state in pairs(self.client_states) do
        update_ranges(bufnr, client_state)
      end
      self:refresh()
    end,
  })
  api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      self:refresh()
    end,
  })
  api.nvim_create_autocmd('LspDetach', {
    group = augroup,
    buffer = bufnr,
    callback = function(args)
      self:detach(args.data.client_id)
    end,
  })

  LinkedEditor.active[bufnr] = self
  return self
end

---@param bufnr integer
---@param client vim.lsp.Client
local function attach_linked_editor(bufnr, client)
  local client_id = client.id
  if not lsp.buf_is_attached(bufnr, client_id) then
    vim.notify(
      '[LSP] Client with id ' .. client_id .. ' not attached to buffer ' .. bufnr,
      vim.log.levels.WARN
    )
    return
  end

  if not vim.tbl_get(client.server_capabilities, 'linkedEditingRangeProvider') then
    vim.notify('[LSP] Server does not support linked editing ranges', vim.log.levels.WARN)
    return
  end

  local linked_editor = LinkedEditor.active[bufnr] or LinkedEditor.new(bufnr)
  linked_editor:attach(client_id)
  linked_editor:refresh()
end

---@param bufnr integer
---@param client vim.lsp.Client
local function detach_linked_editor(bufnr, client)
  local linked_editor = LinkedEditor.active[bufnr]
  if not linked_editor then
    return
  end

  linked_editor:detach(client.id)
end

api.nvim_create_autocmd('LspAttach', {
  desc = 'Enable linked editing ranges for all buffers this client attaches to, if enabled',
  callback = function(ev)
    local client = assert(lsp.get_client_by_id(ev.data.client_id))
    if not client._linked_editing_enabled or not client:supports_method(method, ev.buf) then
      return
    end

    attach_linked_editor(ev.buf, client)
  end,
})

---@param enable boolean
---@param client vim.lsp.Client
local function toggle_linked_editing_for_client(enable, client)
  local handler = enable and attach_linked_editor or detach_linked_editor

  -- Toggle for buffers already attached.
  for bufnr, _ in pairs(client.attached_buffers) do
    handler(bufnr, client)
  end

  client._linked_editing_enabled = enable
end

---@param enable boolean
local function toggle_linked_editing_globally(enable)
  -- Toggle for clients that have already attached.
  local clients = lsp.get_clients({ method = method })
  for _, client in ipairs(clients) do
    toggle_linked_editing_for_client(enable, client)
  end

  -- If disabling, only clear the attachment autocmd. If enabling, create it.
  local group = api.nvim_create_augroup('nvim.lsp.linked_editing_range', { clear = true })
  if enable then
    api.nvim_create_autocmd('LspAttach', {
      group = group,
      desc = 'Enable linked editing ranges for all clients',
      callback = function(ev)
        local client = assert(lsp.get_client_by_id(ev.data.client_id))
        if client:supports_method(method, ev.buf) then
          attach_linked_editor(ev.buf, client)
        end
      end,
    })
  end
end

--- Optional filters |kwargs|:
--- @inlinedoc
--- @class vim.lsp.linked_editing_range.enable.Filter
--- @field client_id integer? Client ID, or `nil` for all.

--- Enable or disable a linked editing session globally or for a specific client. The following is a
--- practical usage example:
---
--- ```lua
--- vim.lsp.start({
---   name = 'html',
---   cmd = '…',
---   on_attach = function(client)
---     vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
---   end,
--- })
--- ```
---
---@param enable boolean? `true` or `nil` to enable, `false` to disable.
---@param filter vim.lsp.linked_editing_range.enable.Filter?
function M.enable(enable, filter)
  vim.validate('enable', enable, 'boolean', true)
  vim.validate('filter', filter, 'table', true)

  enable = enable ~= false
  filter = filter or {}

  if filter.client_id then
    local client =
      assert(lsp.get_client_by_id(filter.client_id), 'Client not found for id ' .. filter.client_id)
    toggle_linked_editing_for_client(enable, client)
  else
    toggle_linked_editing_globally(enable)
  end
end

return M
