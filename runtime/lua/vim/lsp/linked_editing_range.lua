local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
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
---@param client_id integer
function LinkedEditor:detach(client_id)
  local client_state = self.client_states[client_id]
  if not client_state then
    return
  end

  --TODO: delete namespace if/when that becomes possible
  api.nvim_buf_clear_namespace(self.bufnr, client_state.namespace, 0, -1)
  self.client_states[client_id] = nil

  -- Destroy the LinkedEditor instance if we are detaching the last client
  if vim.tbl_isempty(self.client_states) then
    api.nvim_del_augroup_by_id(self.augroup)
    LinkedEditor.active[self.bufnr] = nil
  end
end

---@package
---@param bufnr integer
---@param client_state vim.lsp.linked_editing_range.state
local function clear_ranges(bufnr, client_state)
  api.nvim_buf_clear_namespace(bufnr, client_state.namespace, 0, -1)
  client_state.range_index = nil
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

  vim.cmd.undojoin()
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

  local client = assert(vim.lsp.get_client_by_id(client_id))

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
  local method = ms.textDocument_linkedEditingRange
  local bufnr = self.bufnr

  util._cancel_requests({
    bufnr = bufnr,
    method = method,
    type = 'pending',
  })
  vim.lsp.buf_request(bufnr, method, function(client)
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
---@param client_id integer
local function enable_linked_editing(bufnr, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    vim.notify('[LSP] No client with id ' .. client_id, vim.log.levels.ERROR)
    return
  end

  if not vim.lsp.buf_is_attached(bufnr, client_id) then
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
---@param client_id integer
local function disable_linked_editing(bufnr, client_id)
  local linked_editor = LinkedEditor.active[bufnr]
  if not linked_editor then
    return
  end

  linked_editor:detach(client_id)
end

--- Enable or disable a linked editing session for the given buffer with the given client. When
--- enabling, the client must already be attached to the buffer.
---
--- NOTE: Linked editing is automatically enabled by |vim.lsp.buf_attach_client()|. To opt-out of
--- linked editing ranges with a server that supports it, you can delete the
--- `linkedEditingRangeProvider` table from the {server_capabilities} of your client in
--- your |LspAttach| callback or your configuration's `on_attach` callback:
---
--- ```lua
--- client.server_capabilities.linkedEditingRangeProvider = nil
--- ```
---
---@param enable boolean
---@param bufnr integer
---@param client_id integer
function M.enable(enable, bufnr, client_id)
  vim.validate('enable', enable, 'boolean')
  vim.validate('bufnr', bufnr, 'number')
  vim.validate('client_id', client_id, 'number')

  bufnr = vim._resolve_bufnr(bufnr)

  if enable then
    enable_linked_editing(bufnr, client_id)
  else
    disable_linked_editing(bufnr, client_id)
  end
end

return M
