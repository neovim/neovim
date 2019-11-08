--- Implements the following default callbacks:
--
-- vim.api.nvim_buf_set_lines(0, 0, 0, false, vim.tbl_keys(vim.lsp.builtin_callbacks))
--
-- textDocument/completion
-- textDocument/declaration
-- textDocument/definition
-- textDocument/hover
-- textDocument/implementation
-- textDocument/rename
-- textDocument/signatureHelp
-- textDocument/typeDefinition
-- window/logMessage
-- window/showMessage
-- TODO codeLens/resolve
-- TODO completionItem/resolve
-- TODO documentLink/resolve
-- TODO textDocument/codeAction
-- TODO textDocument/codeLens
-- TODO textDocument/documentHighlight
-- TODO textDocument/documentLink
-- TODO textDocument/documentSymbol
-- TODO textDocument/formatting
-- TODO textDocument/onTypeFormatting
-- TODO textDocument/publishDiagnostics
-- TODO textDocument/rangeFormatting
-- TODO textDocument/references

local log = require 'vim.lsp.log'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'

local function split_lines(value)
  return vim.split(value, '\n', true)
end

local builtin_callbacks = {}

-- textDocument/completion
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
builtin_callbacks['textDocument/completion'] = function(err, _, result)
  if not result or vim.tbl_isempty(result) then
    return
  end
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]
  local line = assert(vim.api.nvim_buf_get_lines(0, row-1, row, false)[1])
  local line_to_cursor = line:sub(col+1)

  local matches = util.text_document_completion_list_to_complete_items(result, line_to_cursor)
  local match_result = vim.fn.matchstrpos(line_to_cursor, '\\k\\+$')
  local match_start, match_finish = match_result[2], match_result[3]

  vim.fn.complete(col + 1 - (match_finish - match_start), matches)
end

-- textDocument/rename
builtin_callbacks['textDocument/rename'] = function(_, _, result)
  if not result then return end
  util.workspace_apply_workspace_edit(result)
end


-- textDocument/hover
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_hover
-- @params MarkedString | MarkedString[] | MarkupContent
builtin_callbacks['textDocument/hover'] = function(_, _, result)
  if result == nil or vim.tbl_isempty(result) then
    return
  end

  if result.contents ~= nil then
    local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
    if vim.tbl_isempty(markdown_lines) then
      markdown_lines = { 'No information available' }
    end
    util.open_floating_preview(markdown_lines, 'markdown')
  end
end

--- Convert SignatureHelp response to preview contents.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_signatureHelp
local function signature_help_to_preview_contents(input)
  if not input.signatures then
    return
  end
  --The active signature. If omitted or the value lies outside the range of
  --`signatures` the value defaults to zero or is ignored if `signatures.length
  --=== 0`. Whenever possible implementors should make an active decision about
  --the active signature and shouldn't rely on a default value.
  local contents = {}
  local active_signature = input.activeSignature or 0
  -- If the activeSignature is not inside the valid range, then clip it.
  if active_signature >= #input.signatures then
    active_signature = 0
  end
  local signature = input.signatures[active_signature + 1]
  if not signature then
    return
  end
  vim.list_extend(contents, split_lines(signature.label))
  if signature.documentation then
    util.convert_input_to_markdown_lines(signature.documentation, contents)
  end
  if input.parameters then
    local active_parameter = input.activeParameter or 0
    -- If the activeParameter is not inside the valid range, then clip it.
    if active_parameter >= #input.parameters then
      active_parameter = 0
    end
    local parameter = signature.parameters and signature.parameters[active_parameter]
    if parameter then
      --[=[
      --Represents a parameter of a callable-signature. A parameter can
      --have a label and a doc-comment.
      interface ParameterInformation {
        --The label of this parameter information.
        --
        --Either a string or an inclusive start and exclusive end offsets within its containing
        --signature label. (see SignatureInformation.label). The offsets are based on a UTF-16
        --string representation as `Position` and `Range` does.
        --
        --*Note*: a label of type string should be a substring of its containing signature label.
        --Its intended use case is to highlight the parameter label part in the `SignatureInformation.label`.
        label: string | [number, number];
        --The human-readable doc-comment of this parameter. Will be shown
        --in the UI but can be omitted.
        documentation?: string | MarkupContent;
      }
      --]=]
      -- TODO highlight parameter
      if parameter.documentation then
        util.convert_input_to_markdown_lines(parameter.documentation, contents)
      end
    end
  end
  return contents
end

-- textDocument/signatureHelp
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_signatureHelp
builtin_callbacks['textDocument/signatureHelp'] = function(_, _, result)
  if result == nil or vim.tbl_isempty(result) then
    return
  end

  -- TODO show empty popup when signatures is empty?
  if #result.signatures > 0 then
    local markdown_lines = signature_help_to_preview_contents(result)
    if vim.tbl_isempty(markdown_lines) then
      markdown_lines = { 'No signature available' }
    end
    util.open_floating_preview(markdown_lines, 'markdown')
  end
end

local function update_tagstack()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.fn.line('.')
  local col = vim.fn.col('.')
  local tagname = vim.fn.expand('<cWORD>')
  local item = { bufnr = bufnr, from = { bufnr, line, col, 0 }, tagname = tagname }
  local winid = vim.fn.win_getid()
  local tagstack = vim.fn.gettagstack(winid)

  local action

  if tagstack.length == tagstack.curidx then
    action = 'r'
    tagstack.items[tagstack.curidx] = item
  elseif tagstack.length > tagstack.curidx then
    action = 'r'
    if tagstack.curidx > 1 then
      tagstack.items = table.insert(tagstack.items[tagstack.curidx - 1], item)
    else
      tagstack.items = { item }
    end
  else
    action = 'a'
    tagstack.items = { item }
  end

  tagstack.curidx = tagstack.curidx + 1
  vim.fn.settagstack(winid, tagstack, action)
end

local function handle_location(result)
  local current_file = vim.fn.expand('%:p')

  -- We can sometimes get a list of locations, so set the first value as the
  -- only value we want to handle
  -- TODO(ashkan) was this correct^? We could use location lists.
  if result[1] ~= nil then
    result = result[1]
  end

  if result.uri == nil then
    vim.api.nvim_err_writeln('[LSP] Could not find a valid location')
    return
  end

  if type(result.uri) ~= 'string' then
    vim.api.nvim_err_writeln('Invalid uri')
    return
  end

  local result_file = vim.uri_to_fname(result.uri)

  update_tagstack()
  if result_file ~= vim.uri_from_fname(current_file) then
    vim.api.nvim_command('silent drop ' .. result_file)
  end

  local start = result.range.start
  vim.api.nvim_win_set_cursor(0, {start.line + 1, start.character})
end

local function location_callback(_, method, result)
  if result == nil or vim.tbl_isempty(result) then
    _ = log.info() and log.info(method, 'No location found')
    return nil
  end
  handle_location(result)
  return true
end

local location_callbacks = {
  -- https://microsoft.github.io/language-server-protocol/specification#textDocument_declaration
  'textDocument/declaration';
  -- https://microsoft.github.io/language-server-protocol/specification#textDocument_definition
  'textDocument/definition';
  -- https://microsoft.github.io/language-server-protocol/specification#textDocument_implementation
  'textDocument/implementation';
  -- https://microsoft.github.io/language-server-protocol/specification#textDocument_typeDefinition
  'textDocument/typeDefinition';
}

for _, location_method in ipairs(location_callbacks) do
  builtin_callbacks[location_method] = location_callback
end

local function log_message(_, _, result, client_id)
  local message_type = result.type
  local message = result.message
  local client_name = vim.lsp.get_client_by_id(client_id).name
  if message_type == protocol.MessageType.Error then
    -- Might want to not use err_writeln,
    -- but displaying a message with red highlights or something
    vim.api.nvim_err_writeln(string.format("LSP[%s] %s", client_name, message))
  else
    local message_type_name = protocol.MessageType[message_type]
    vim.api.nvim_out_write(string.format("LSP[%s][%s] %s\n", client_name, message_type_name, message))
  end
  return result
end

builtin_callbacks['window/showMessage'] = log_message
builtin_callbacks['window/logMessage'] = log_message

-- Add boilerplate error validation and logging for all of these.
for k, fn in pairs(builtin_callbacks) do
  builtin_callbacks[k] = function(err, method, params, client_id)
    _ = log.debug() and log.debug('builtin_callback', method, { params = params, client_id = client_id, err = err })
    if err then
      error(tostring(err))
    end
    fn(err, method, params, client_id)
  end
end

return builtin_callbacks
-- vim:sw=2 ts=2 et
