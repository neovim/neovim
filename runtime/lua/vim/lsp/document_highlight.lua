local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api

local M = {}

local namespace = api.nvim_create_namespace('vim_lsp_document_highlight')
local augroup = api.nvim_create_augroup('vim_lsp_document_highlight', {})

---Buffer-local state for document highlights
---@class (private) vim.lsp.document_highlight.BufState
---
---Whether document highlights are enabled for this buffer,
---`nil` indicates following the global state.
---@field enabled? boolean
---
---Each client attached to this buffer must exists.
---
---Index in the form of client_id -> (row -> highlights)
---@field client_highlights table<integer, table<integer, lsp.DocumentHighlight[]?>?>

---Each buffer attached by at least one LSP server must exists,
---otherwise it should not exists or be cleaned up.
---
---Index in the form of bufnr -> bufstate
---@type table<integer, vim.lsp.document_highlight.BufState?>
local bufstates = {}
for _, client in ipairs(vim.lsp.get_clients()) do
  for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
    local bufstate = bufstates[bufnr] or {}
    local client_highlights = bufstate.client_highlights or {}

    if not client_highlights[client.id] then
      client_highlights[client.id] = {}
    end

    bufstate.client_highlights = client_highlights
    bufstates[bufnr] = bufstate
  end
end
api.nvim_create_autocmd('LspAttach', {
  group = augroup,
  callback = function(args)
    ---@type integer
    local bufnr = args.buf
    local bufstate = bufstates[bufnr] or {}
    bufstates[bufnr] = bufstate

    ---@type integer
    local client_id = args.data.client_id
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

  ---@type table<integer, lsp.DocumentHighlight[]?>
  local row_highlights = {}
  for _, highlight in pairs(result or {}) do
    for row = highlight.range['start'].line, highlight.range['end'].line do
      local highlights = row_highlights[row] or {}
      highlights[#highlights + 1] = highlight
      row_highlights[row] = highlights
    end
  end

  local bufstate = assert(bufstates[bufnr])
  local client_highlights = bufstate.client_highlights
  client_highlights[client_id] = row_highlights

  api.nvim__redraw({ buf = bufnr, valid = true })
end

---@param bufnr integer
local function refresh(bufnr)
  local params = util.make_position_params()
  vim.lsp.buf_request(bufnr, ms.textDocument_documentHighlight, params)
end

api.nvim_create_autocmd('CursorMoved', {
  group = augroup,
  desc = 'Refresh document highlights on cursor movement',
  callback = function(args)
    ---@type integer
    local bufnr = args.buf
    if bufstates[bufnr] then
      refresh(bufnr)
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

    local client_highlights = bufstate.client_highlights

    for row = toprow, botrow do
      api.nvim_buf_clear_namespace(bufnr, namespace, row, row + 1)
      -- TODO(ofseed): When deleting characters at the end of a line or the entire line,
      -- the extmark range might still remain as it was before the deletion,
      -- causing outbounds error when trying to set the extmark.
      -- Better to avoid rendering expired extmarks.
      local max_col = #api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

      for _, row_highlights in pairs(client_highlights) do
        local highlights = row_highlights[row] or {}

        for _, highlight in pairs(highlights) do
          local col = math.min(highlight.range['start'].character, max_col)
          local end_row = highlight.range['end'].line
          local end_col = math.min(highlight.range['end'].character, max_col)

          api.nvim_buf_set_extmark(bufnr, namespace, row, col, {
            end_row = end_row,
            end_col = end_col,
            ephemeral = false,
            hl_group = hl_group_from_kind(highlight.kind),
          })
        end
      end
    end
  end,
})

---@class vim.lsp.document_highlight.enable.Filter
---@inlinedoc

---@param enable boolean
---@param filter? vim.lsp.document_highlight.enable.Filter
function M.enable(enable, filter)
  vim.validate('enable', enable, 'boolean', true)
  vim.validate('filter', filter, 'table', true)
  enable = enable == nil or enable
  filter = filter or {}
end

return M
