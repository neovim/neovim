local log = require 'vim.lsp.log'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'
local vim = vim
local api = vim.api

local M = {}

local function err_message(...)
  api.nvim_err_writeln(table.concat(vim.tbl_flatten{...}))
  api.nvim_command("redraw")
end

M['workspace/applyEdit'] = function(_, _, workspace_edit)
  if not workspace_edit then return end
  -- TODO(ashkan) Do something more with label?
  if workspace_edit.label then
    print("Workspace edit", workspace_edit.label)
  end
  util.apply_workspace_edit(workspace_edit.edit)
end

M['textDocument/publishDiagnostics'] = function(_, _, result)
  if not result then return end
  local uri = result.uri
  local bufnr = vim.uri_to_bufnr(uri)
  if not bufnr then
    err_message("LSP.publishDiagnostics: Couldn't find buffer for ", uri)
    return
  end
  util.buf_clear_diagnostics(bufnr)
  util.buf_diagnostics_save_positions(bufnr, result.diagnostics)
  util.buf_diagnostics_underline(bufnr, result.diagnostics)
  util.buf_diagnostics_virtual_text(bufnr, result.diagnostics)
  -- util.set_loclist(result.diagnostics)
end

M['textDocument/references'] = function(_, _, result)
  if not result then return end
  util.set_qflist(result)
  api.nvim_command("copen")
  api.nvim_command("wincmd p")
end

M['textDocument/rename'] = function(_, _, result)
  if not result then return end
  util.apply_workspace_edit(result)
end

M['textDocument/rangeFormatting'] = function(_, _, result)
  if not result then return end
  util.apply_text_edits(result)
end

M['textDocument/formatting'] = function(_, _, result)
  if not result then return end
  util.apply_text_edits(result)
end

M['textDocument/completion'] = function(_, _, result)
  if vim.tbl_isempty(result or {}) then return end
  local row, col = unpack(api.nvim_win_get_cursor(0))
  local line = assert(api.nvim_buf_get_lines(0, row-1, row, false)[1])
  local line_to_cursor = line:sub(col+1)
  local textMatch = vim.fn.match(line_to_cursor, '\\k*$')

  local matches = util.text_document_completion_list_to_complete_items(result)
  vim.fn.complete(textMatch+1, matches)
end

M['textDocument/hover'] = function(_, method, result)
  util.focusable_float(method, function()
    if not (result and result.contents) then
      -- return { 'No information available' }
      return
    end
    local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
    markdown_lines = util.trim_empty_lines(markdown_lines)
    if vim.tbl_isempty(markdown_lines) then
      -- return { 'No information available' }
      return
    end
    local bufnr, winnr = util.fancy_floating_markdown(markdown_lines, {
      pad_left = 1; pad_right = 1;
    })
    util.close_preview_autocmd({"CursorMoved", "BufHidden", "InsertCharPre"}, winnr)
    return bufnr, winnr
  end)
end

local function location_callback(_, method, result)
  if result == nil or vim.tbl_isempty(result) then
    local _ = log.info() and log.info(method, 'No location found')
    return nil
  end
  util.jump_to_location(result[1])
  if #result > 1 then
    util.set_qflist(result)
    api.nvim_command("copen")
    api.nvim_command("wincmd p")
  end
end

M['textDocument/declaration'] = location_callback
M['textDocument/definition'] = location_callback
M['textDocument/typeDefinition'] = location_callback
M['textDocument/implementation'] = location_callback

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
  vim.list_extend(contents, vim.split(signature.label, '\n', true))
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

M['textDocument/signatureHelp'] = function(_, method, result)
  util.focusable_preview(method, function()
    if not (result and result.signatures and result.signatures[1]) then
      return { 'No signature available' }
    end
    -- TODO show popup when signatures is empty?
    local lines = signature_help_to_preview_contents(result)
    lines = util.trim_empty_lines(lines)
    if vim.tbl_isempty(lines) then
      return { 'No signature available' }
    end
    return lines, util.try_trim_markdown_code_blocks(lines)
  end)
end

M['textDocument/peekDefinition'] = function(_, _, result, _)
  if not (result and result[1]) then return end
  local loc = result[1]
  local bufnr = vim.uri_to_bufnr(loc.uri) or error("not found: "..tostring(loc.uri))
  local start = loc.range.start
  local finish = loc.range["end"]
  util.open_floating_peek_preview(bufnr, start, finish, { offset_x = 1 })
  local headbuf = util.open_floating_preview({"Peek:"}, nil, {
    offset_y = -(finish.line - start.line);
    width = finish.character - start.character + 2;
  })
  -- TODO(ashkan) change highlight group?
  api.nvim_buf_add_highlight(headbuf, -1, 'Keyword', 0, -1)
end

local function log_message(_, _, result, client_id)
  local message_type = result.type
  local message = result.message
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format("id=%d", client_id)
  if not client then
    err_message("LSP[", client_name, "] client has shut down after sending the message")
  end
  if message_type == protocol.MessageType.Error then
    err_message("LSP[", client_name, "] ", message)
  else
    local message_type_name = protocol.MessageType[message_type]
    api.nvim_out_write(string.format("LSP[%s][%s] %s\n", client_name, message_type_name, message))
  end
  return result
end

M['window/showMessage'] = log_message
M['window/logMessage'] = log_message

-- Add boilerplate error validation and logging for all of these.
for k, fn in pairs(M) do
  M[k] = function(err, method, params, client_id)
    local _ = log.debug() and log.debug('default_callback', method, { params = params, client_id = client_id, err = err })
    if err then
      error(tostring(err))
    end
    return fn(err, method, params, client_id)
  end
end

return M
-- vim:sw=2 ts=2 et
