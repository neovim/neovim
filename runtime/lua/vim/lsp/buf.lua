local vim = vim
local validate = vim.validate
local api = vim.api
local vfn = vim.fn
local util = require 'vim.lsp.util'
local list_extend = vim.list_extend

local M = {}

local function ok_or_nil(status, ...)
  if not status then return end
  return ...
end
local function npcall(fn, ...)
  return ok_or_nil(pcall(fn, ...))
end

local function request(method, params, callback)
  validate {
    method = {method, 's'};
    callback = {callback, 'f', true};
  }
  return vim.lsp.buf_request(0, method, params, callback)
end

--- Sends a notification through all clients associated with current buffer.
--
--@return `true` if server responds.
function M.server_ready()
  return not not vim.lsp.buf_notify(0, "window/progress", {})
end

--- Displays hover information about the symbol under the cursor in a floating
--- window. Calling the function twice will jump into the floating window.
function M.hover()
  local params = util.make_position_params()
  request('textDocument/hover', params)
end

--- Jumps to the declaration of the symbol under the cursor.
---
function M.declaration()
  local params = util.make_position_params()
  request('textDocument/declaration', params)
end

--- Jumps to the definition of the symbol under the cursor.
---
function M.definition()
  local params = util.make_position_params()
  request('textDocument/definition', params)
end

--- Jumps to the definition of the type of the symbol under the cursor.
---
function M.type_definition()
  local params = util.make_position_params()
  request('textDocument/typeDefinition', params)
end

--- Lists all the implementations for the symbol under the cursor in the
--- quickfix window.
function M.implementation()
  local params = util.make_position_params()
  request('textDocument/implementation', params)
end

--- Displays signature information about the symbol under the cursor in a
--- floating window.
function M.signature_help()
  local params = util.make_position_params()
  request('textDocument/signatureHelp', params)
end

--- Retrieves the completion items at the current cursor position. Can only be
--- called in Insert mode.
function M.completion(context)
  local params = util.make_position_params()
  params.context = context
  return request('textDocument/completion', params)
end

--- Formats the current buffer.
---
--- The optional {options} table can be used to specify FormattingOptions, a
--- list of which is available at
--- https://microsoft.github.io/language-server-protocol/specification#textDocument_formatting.
--- Some unspecified options will be automatically derived from the current
--- Neovim options.
function M.formatting(options)
  local params = util.make_formatting_params(options)
  return request('textDocument/formatting', params)
end

--- Perform |vim.lsp.buf.formatting()| synchronously.
---
--- Useful for running on save, to make sure buffer is formatted prior to being
--- saved.  {timeout_ms} is passed on to |vim.lsp.buf_request_sync()|.
function M.formatting_sync(options, timeout_ms)
  local params = util.make_formatting_params(options)
  local result = vim.lsp.buf_request_sync(0, "textDocument/formatting", params, timeout_ms)
  if not result then return end
  result = result[1].result
  vim.lsp.util.apply_text_edits(result)
end

function M.range_formatting(options, start_pos, end_pos)
  validate {
    options = {options, 't', true};
    start_pos = {start_pos, 't', true};
    end_pos = {end_pos, 't', true};
  }
  local sts = vim.bo.softtabstop;
  options = vim.tbl_extend('keep', options or {}, {
    tabSize = (sts > 0 and sts) or (sts < 0 and vim.bo.shiftwidth) or vim.bo.tabstop;
    insertSpaces = vim.bo.expandtab;
  })
  local A = list_extend({}, start_pos or api.nvim_buf_get_mark(0, '<'))
  local B = list_extend({}, end_pos or api.nvim_buf_get_mark(0, '>'))
  -- convert to 0-index
  A[1] = A[1] - 1
  B[1] = B[1] - 1
  -- account for encoding.
  if A[2] > 0 then
    A = {A[1], util.character_offset(0, A[1], A[2])}
  end
  if B[2] > 0 then
    B = {B[1], util.character_offset(0, B[1], B[2])}
  end
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(0) };
    range = {
      start = { line = A[1]; character = A[2]; };
      ["end"] = { line = B[1]; character = B[2]; };
    };
    options = options;
  }
  return request('textDocument/rangeFormatting', params)
end

--- Renames all references to the symbol under the cursor. If {new_name} is not
--- provided, the user will be prompted for a new name using |input()|.
function M.rename(new_name)
  -- TODO(ashkan) use prepareRename
  -- * result: [`Range`](#range) \| `{ range: Range, placeholder: string }` \| `null` describing the range of the string to rename and optionally a placeholder text of the string content to be renamed. If `null` is returned then it is deemed that a 'textDocument/rename' request is not valid at the given position.
  local params = util.make_position_params()
  new_name = new_name or npcall(vfn.input, "New Name: ", vfn.expand('<cword>'))
  if not (new_name and #new_name > 0) then return end
  params.newName = new_name
  request('textDocument/rename', params)
end

--- Lists all the references to the symbol under the cursor in the quickfix window.
---
function M.references(context)
  validate { context = { context, 't', true } }
  local params = util.make_position_params()
  params.context = context or {
    includeDeclaration = true;
  }
  params[vim.type_idx] = vim.types.dictionary
  request('textDocument/references', params)
end

--- Lists all symbols in the current buffer in the quickfix window.
---
function M.document_symbol()
  local params = { textDocument = util.make_text_document_params() }
  request('textDocument/documentSymbol', params)
end

local function pick_call_hierarchy_item(call_hierarchy_items)
  if not call_hierarchy_items then return end
  if #call_hierarchy_items == 1 then
    return call_hierarchy_items[1]
  end
  local items = {}
  for i, item in ipairs(call_hierarchy_items) do
    local entry = item.detail or item.name
    table.insert(items, string.format("%d. %s", i, entry))
  end
  local choice = vim.fn.inputlist(items)
  if choice < 1 or choice > #items then
    return
  end
  return choice
end

function M.incoming_calls()
  local params = util.make_position_params()
  request('textDocument/prepareCallHierarchy', params, function(_, _, result)
    local call_hierarchy_item = pick_call_hierarchy_item(result)
    vim.lsp.buf_request(0, 'callHierarchy/incomingCalls', { item = call_hierarchy_item })
  end)
end

function M.outgoing_calls()
  local params = util.make_position_params()
  request('textDocument/prepareCallHierarchy', params, function(_, _, result)
    local call_hierarchy_item = pick_call_hierarchy_item(result)
    vim.lsp.buf_request(0, 'callHierarchy/outgoingCalls', { item = call_hierarchy_item })
  end)
end

--- Lists all symbols in the current workspace in the quickfix window.
---
--- The list is filtered against the optional argument {query};
--- if the argument is omitted from the call, the user is prompted to enter a string on the command line.
--- An empty string means no filtering is done.
function M.workspace_symbol(query)
  query = query or npcall(vfn.input, "Query: ")
  local params = {query = query}
  request('workspace/symbol', params)
end

--- Send request to server to resolve document highlights for the
--- current text document position. This request can be associated
--- to key mapping or to events such as `CursorHold`, eg:
---
--- <pre>
--- vim.api.nvim_command [[autocmd CursorHold  <buffer> lua vim.lsp.buf.document_highlight()]]
--- vim.api.nvim_command [[autocmd CursorHoldI <buffer> lua vim.lsp.buf.document_highlight()]]
--- vim.api.nvim_command [[autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()]]
--- </pre>
function M.document_highlight()
  local params = util.make_position_params()
  request('textDocument/documentHighlight', params)
end

function M.clear_references()
  util.buf_clear_references()
end

function M.code_action(context)
  validate { context = { context, 't', true } }
  context = context or { diagnostics = util.get_line_diagnostics() }
  local params = util.make_range_params()
  params.context = context
  request('textDocument/codeAction', params)
end

function M.execute_command(command)
  validate {
    command = { command.command, 's' },
    arguments = { command.arguments, 't', true }
  }
  request('workspace/executeCommand', command)
end

return M
-- vim:sw=2 ts=2 et
