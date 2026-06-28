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
local nvim_on = require('vim._core.util').nvim_on
local lsp = vim.lsp
local Capability = require('vim.lsp._capability')
local method = 'textDocument/linkedEditingRange'
local Range = require('vim.treesitter._range')
local api = vim.api
local M = {}

---@class (private) vim.lsp.linked_editing_range.state Global state for linked editing ranges
---An optional word pattern (regular expression) that describes valid contents for the given ranges.
---@field word_pattern string
---@field range_index? integer The index of the range that the cursor is on.
---@field namespace integer namespace for range extmarks

---@class (private) vim.lsp.linked_editing_range.LinkedEditor : vim.lsp.Capability
---@field active table<integer, vim.lsp.linked_editing_range.LinkedEditor>
---@field client_state? table<integer, vim.lsp.linked_editing_range.state>
local LinkedEditor = {
  name = 'linked_editing_range',
  method = method,
  active = {},
}
LinkedEditor.__index = LinkedEditor
setmetatable(LinkedEditor, Capability)
Capability.all[LinkedEditor.name] = LinkedEditor

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
    log.error('linked_editing_range', err)
    return
  end

  local client_id = ctx.client_id
  local client_state = self.client_state[client_id]
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

---@package
function LinkedEditor:new(bufnr)
  self = Capability.new(self, bufnr)

  nvim_on({ 'TextChanged', 'TextChangedI' }, self.augroup, { buf = self.bufnr }, function()
    for _, state in pairs(self.client_state) do
      update_ranges(self.bufnr, state)
    end

    self:refresh()
  end)

  nvim_on('CursorMoved', self.augroup, { buf = self.bufnr }, function()
    self:refresh()
  end)

  return self
end

---@package
---@param client_id integer
function LinkedEditor:on_attach(client_id)
  local state = self.client_state[client_id]
  if not state then
    state = {
      namespace = api.nvim_create_namespace('nvim.lsp.linked_editing_range:' .. client_id),
      word_pattern = '^[%w%-_]*$',
    }
    self.client_state[client_id] = state
  end

  self:refresh()
end

---@package
---@param client_id integer
function LinkedEditor:on_detach(client_id)
  local client_state = self.client_state[client_id]
  if client_state then
    --TODO: delete namespace if/when that becomes possible
    clear_ranges(self.bufnr, client_state)
    self.client_state[client_id] = nil
  end
end

--- Enable or disable a linked editing session for the {filter}ed scope. The following is a
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
---@param filter vim.lsp.capability.enable.Filter?
function M.enable(enable, filter)
  vim.lsp._capability.enable('linked_editing_range', enable, filter)
end

return M
