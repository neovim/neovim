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

function M.server_ready()
  return not not vim.lsp.buf_notify(0, "window/progress", {})
end

function M.hover()
  local params = util.make_position_params()
  request('textDocument/hover', params)
end

function M.declaration()
  local params = util.make_position_params()
  request('textDocument/declaration', params)
end

function M.definition()
  local params = util.make_position_params()
  request('textDocument/definition', params)
end

function M.type_definition()
  local params = util.make_position_params()
  request('textDocument/typeDefinition', params)
end

function M.implementation()
  local params = util.make_position_params()
  request('textDocument/implementation', params)
end

function M.signature_help()
  local params = util.make_position_params()
  request('textDocument/signatureHelp', params)
end

-- TODO(ashkan) ?
function M.completion(context)
  local params = util.make_position_params()
  params.context = context
  return request('textDocument/completion', params)
end

function M.formatting(options)
  validate { options = {options, 't', true} }
  local sts = vim.bo.softtabstop;
  options = vim.tbl_extend('keep', options or {}, {
    tabSize = (sts > 0 and sts) or (sts < 0 and vim.bo.shiftwidth) or vim.bo.tabstop;
    insertSpaces = vim.bo.expandtab;
  })
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(0) };
    options = options;
  }
  return request('textDocument/formatting', params)
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

function M.rename(new_name)
  -- TODO(ashkan) use prepareRename
  -- * result: [`Range`](#range) \| `{ range: Range, placeholder: string }` \| `null` describing the range of the string to rename and optionally a placeholder text of the string content to be renamed. If `null` is returned then it is deemed that a 'textDocument/rename' request is not valid at the given position.
  local params = util.make_position_params()
  new_name = new_name or npcall(vfn.input, "New Name: ")
  if not (new_name and #new_name > 0) then return end
  params.newName = new_name
  request('textDocument/rename', params)
end

function M.references(context)
  validate { context = { context, 't', true } }
  local params = util.make_position_params()
  params.context = context or {
    includeDeclaration = true;
  }
  params[vim.type_idx] = vim.types.dictionary
  request('textDocument/references', params)
end

function M.document_symbol()
  local params = { textDocument = util.make_text_document_params() }
  request('textDocument/documentSymbol', params)
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

return M
-- vim:sw=2 ts=2 et
