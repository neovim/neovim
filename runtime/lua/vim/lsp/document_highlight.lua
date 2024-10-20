local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api

local M = {}

local namespace = api.nvim_create_namespace('vim_lsp_document_highlight')
local augroup = api.nvim_create_augroup('vim_lsp_document_highlight', {})

local globalstate = {
  enabled = false,
}

---Buffer-local state for document highlights
---@class (private) vim.lsp.document_highlight.BufState
---
---Whether document highlights are enabled for this buffer,
---`nil` indicates following the global state.
---@field enabled? boolean
---
---Each data change generates a unique version,
---not garanteed, numbers may be reused over time.
---@field version integer
---
---Latest `version` with data applied.
---@field applied? integer
---
---Each client attached to this buffer must exists.
---
---Index in the form of client_id -> (row -> highlights)
---@field client_highlights table<integer, table<integer, lsp.DocumentHighlight[]?>?>

---Each buffer attached by at least one supported LSP server must exists,
---otherwise it should not exists or be cleaned up.
---
---Index in the form of bufnr -> bufstate
---@type table<integer, vim.lsp.document_highlight.BufState?>
local bufstates = {}
for _, client in ipairs(vim.lsp.get_clients()) do
  for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
    if client:supports_method(ms.textDocument_documentHighlight, bufnr) then
      local bufstate = bufstates[bufnr] or { version = 0 }
      local client_highlights = bufstate.client_highlights or {}

      if not client_highlights[client.id] then
        client_highlights[client.id] = {}
      end

      bufstate.client_highlights = client_highlights
      bufstates[bufnr] = bufstate
    end
  end
end
api.nvim_create_autocmd('LspAttach', {
  group = augroup,
  callback = function(args)
    ---@type integer
    local client_id = args.data.client_id
    if
      not assert(vim.lsp.get_client_by_id(client_id)):supports_method(
        ms.textDocument_documentHighlight
      )
    then
      return
    end

    ---@type integer
    local bufnr = args.buf
    local bufstate = bufstates[bufnr] or { version = 0 }
    bufstates[bufnr] = bufstate

    local client_highlights = bufstate.client_highlights or {}
    client_highlights[client_id] = {}
    bufstate.client_highlights = client_highlights
  end,
})
api.nvim_create_autocmd('LspDetach', {
  group = augroup,
  callback = function(args)
    ---@type integer
    local bufnr = args.buf
    local bufstate = bufstates[bufnr]
    if not bufstate then
      return
    end

    ---@type integer
    local client_id = args.data.client_id
    bufstate.client_highlights[client_id] = nil
    if vim.tbl_isempty(bufstate.client_highlights) then
      bufstates[bufnr] = nil
    end
  end,
})

---|lsp-handler| for the method `textDocument/documentHighlight`
---Store hints for a specific buffer and client
---@param result? lsp.DocumentHighlight[]
---@param ctx lsp.HandlerContext
function M.on_document_highlight(err, result, ctx)
  if err then
    log.error('document highlight', err)
  end

  local bufnr = assert(ctx.bufnr)
  local client_id = assert(ctx.client_id)
  local client = assert(vim.lsp.get_client_by_id(client_id))

  ---@type table<integer, lsp.DocumentHighlight[]?>
  local row_highlights = {}
  for _, highlight in pairs(result or {}) do
    highlight.range['start'].character =
      util._get_line_byte_from_position(bufnr, highlight.range['start'], client.offset_encoding)
    highlight.range['end'].character =
      util._get_line_byte_from_position(bufnr, highlight.range['end'], client.offset_encoding)

    for row = highlight.range['start'].line, highlight.range['end'].line do
      -- `highlights` is sorted by `highlight.range['start'].character`.
      -- In practice, LSP almost always returns sorted results.
      local highlights = row_highlights[row] or {}
      ---@type integer
      local pos = 0
      for i = #highlights, 1, -1 do
        if highlight.range['start'].character > highlights[i].range['start'].character then
          pos = i
          break
        end
      end
      highlights[pos + 1] = highlight
      row_highlights[row] = highlights
    end
  end

  local bufstate = assert(bufstates[bufnr])
  local client_highlights = bufstate.client_highlights
  client_highlights[client_id] = row_highlights
  bufstate.version = (bufstate.version + 1) % 8

  api.nvim__redraw({ buf = bufnr, valid = true })
end

---@param bufnr integer
local function refresh(bufnr)
  local bufstate = assert(bufstates[bufnr])
  local enabled = bufstate.enabled
  if enabled == nil then
    enabled = globalstate.enabled
  end

  if not enabled then
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    api.nvim__redraw({ buf = bufnr, valid = true })
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_documentHighlight })
  for _, client in ipairs(clients) do
    local params = util.make_position_params(0, client.offset_encoding)
    client:request(ms.textDocument_documentHighlight, params, nil, bufnr)
  end
end

---@param f function
---@param timeout integer
local function debunce(f, timeout)
  ---@type uv.uv_timer_t?
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      vim.uv.timer_stop(timer)
      timer:close()
      timer = nil
    end
    timer = assert(vim.uv.new_timer())
    vim.uv.timer_start(
      timer,
      timeout,
      0,
      vim.schedule_wrap(function()
        if timer then
          vim.uv.timer_stop(timer)
          timer:close()
          timer = nil
        end
        f(unpack(args))
      end)
    )
  end
end

-- The interval for reporting keyboard events is usually 30ms,
-- 100ms is a reasonable value to debounce the cursor movement.
local debounced_refresh = debunce(refresh, 100)

api.nvim_create_autocmd('CursorMoved', {
  group = augroup,
  desc = 'Refresh document highlights on cursor movement',
  callback = function(args)
    ---@type integer
    local bufnr = args.buf
    if bufstates[bufnr] then
      debounced_refresh(bufnr)
    end
  end,
})
api.nvim_create_autocmd('LspNotify', {
  group = augroup,
  desc = 'Refresh document highlights on document change or open',
  callback = function(args)
    ---@type integer
    local bufnr = args.buf
    if
      bufstates[bufnr]
      and (
        args.data.method == ms.textDocument_didChange
        or args.data.method == ms.textDocument_didOpen
      )
    then
      refresh(bufnr)
    end
  end,
})

---@param kind lsp.DocumentHighlightKind
---@return string
local function hl_group_from_kind(kind)
  if kind == 2 then
    return 'LspReferenceRead'
  elseif kind == 3 then
    return 'LspReferenceWrite'
  else -- kind == 1 also the default
    return 'LspReferenceText'
  end
end

api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, toprow, botrow)
    local bufstate = bufstates[bufnr]
    if not bufstate then
      return
    end

    if bufstate.version == bufstate.applied then
      return
    end

    local enabled = bufstate.enabled
    if enabled == nil then
      enabled = globalstate.enabled
    end

    if not enabled then
      return
    end

    local client_highlights = bufstate.client_highlights

    for row = toprow, botrow do
      api.nvim_buf_clear_namespace(bufnr, namespace, row, row + 1)

      for _, row_highlights in pairs(client_highlights) do
        local highlights = row_highlights[row] or {}

        for _, highlight in pairs(highlights) do
          local col = highlight.range['start'].character
          local end_row = highlight.range['end'].line
          local end_col = highlight.range['end'].character

          api.nvim_buf_set_extmark(bufnr, namespace, row, col, {
            end_row = end_row,
            end_col = end_col,
            ephemeral = false,
            hl_group = hl_group_from_kind(highlight.kind),
          })
        end
      end
    end

    bufstate.applied = bufstate.version
  end,
})

---Optional filters |kwargs|, or `nil` for all.
---@class vim.lsp.document_highlight.enable.Filter
---@inlinedoc
---
---Buffer number, or 0 for current buffer, or nil for all.
---@field bufnr? integer

---Query whether document highlight is enabled in the {filter}ed scope
---@param filter? vim.lsp.document_highlight.enable.Filter
---@return boolean
function M.is_enabled(filter)
  vim.validate({ filter = { filter, 'table', true } })
  filter = filter or {}

  local bufnr = filter.bufnr
  if bufnr == nil then
    return globalstate.enabled
  end

  bufnr = bufnr == 0 and api.nvim_get_current_buf() or bufnr
  local bufstate = bufstates[bufnr]
  if not bufstate then
    return false
  end

  if bufstate.enabled == nil then
    return globalstate.enabled
  else
    return bufstate.enabled
  end
end

---Enables or disables document highlights for the {filter}ed scope.
---
---To "toggle", pass the inverse of `is_enabled()`:
---
---```lua
---vim.lsp.document_highlight.enable(not vim.lsp.document_highlight.is_enabled())
---```
---@param enable? boolean
---@param filter? vim.lsp.document_highlight.enable.Filter
function M.enable(enable, filter)
  vim.validate('enable', enable, 'boolean', true)
  vim.validate('filter', filter, 'table', true)
  enable = enable == nil or enable
  filter = filter or {}

  local bufnr = filter.bufnr
  if bufnr == nil then
    globalstate.enabled = enable
    for b, bufstate in pairs(bufstates) do
      bufstate.enabled = nil
      refresh(b)
    end
  else
    bufnr = bufnr == 0 and api.nvim_get_current_buf() or bufnr
    local bufstate = bufstates[bufnr]
    if not bufstate then
      return
    end

    if enable == globalstate.enabled then
      bufstate.enabled = nil
    else
      bufstate.enabled = enable
    end
    refresh(bufnr)
  end
end

return M
