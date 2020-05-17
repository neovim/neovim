local vim = vim
local validate = vim.validate
local api = vim.api
local vfn = vim.fn
local util = require 'vim.lsp.util'
local log = require 'vim.lsp.log'
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

--[[ Location requests: Queries the server for locations related to current symbol
  * The callbacks accepted from the user is a list of locations if there are any.
    Errors or no locations won't call the user provided callback.
--]]
M.location_req_default_callback = function(locations)
  if #locations == 1 then
    util.jump_to_location(locations[1])
  else
    util.set_qflist(util.locations_to_items(locations))
    api.nvim_command("copen")
    api.nvim_command("wincmd p")
  end
end

M.references_defaults = {
  includeDeclaration = false;
  on_locations = function(locations)
    util.set_qflist(util.locations_to_items(locations))
    api.nvim_command("copen")
    api.nvim_command("wincmd p")
  end
}
-- on_locations_callback: will be called with a list of locations if there are any returned
function M.locations_request(method, on_locations_callback, context)
  local params = util.make_position_params()

  if context then
    params['context'] = context
  end
  local process_locations_response_callback = function(err, _, response)
    if response == nil or vim.tbl_isempty(response) then
      local _ = log.info() and log.info(method, 'No location found')
      return nil
    end
    if err then
      local _ = log.error() and log.error(method, err)
    end
    -- textDocument/definition can return Location or Location[]
    -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition
    if vim.tbl_islist(response) then
      on_locations_callback(response)
    else
      on_locations_callback({response})
    end
  end
  request(method, params, process_locations_response_callback)
end

local function get_callback(args)
  if args and args.on_locations then
    return args.on_locations
  else
    return M.location_req_default_callback
  end
end

function M.declaration(args)     M.locations_request('textDocument/declaration',    get_callback(args)) end
function M.definition(args)      M.locations_request('textDocument/definition',     get_callback(args)) end
function M.implementation(args)  M.locations_request('textDocument/implementation', get_callback(args)) end
function M.type_definition(args) M.locations_request('textDocument/typeDefinition', get_callback(args)) end

function M.references(args)
  local on_locations_callback
  local references_context = { includeDeclaration = M.references_defaults.includeDeclaration }
  if args and args.on_locations then
    on_locations_callback = args.on_locations
  else
    on_locations_callback = M.references_defaults.on_locations
  end

  if args and args.includeDeclaration ~= nil then
    references_context = { includeDeclaration = args.includeDeclaration }
  end
  M.locations_request('textDocument/references', on_locations_callback, references_context)
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

function M.document_symbol()
  local params = { textDocument = util.make_text_document_params() }
  request('textDocument/documentSymbol', params)
end

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
