local log = require 'vim.lsp.log'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'
local vim = vim
local api = vim.api
local buf = require 'vim.lsp.buf'

local M = {}

local function err_message(...)
  api.nvim_err_writeln(table.concat(vim.tbl_flatten{...}))
  api.nvim_command("redraw")
end

M['workspace/executeCommand'] = function(err, _)
  if err then
    error("Could not execute code action: "..err.message)
  end
end

M['textDocument/codeAction'] = function(_, _, actions)
  if actions == nil or vim.tbl_isempty(actions) then
    print("No code actions available")
    return
  end

  local option_strings = {"Code Actions:"}
  for i, action in ipairs(actions) do
    local title = action.title:gsub('\r\n', '\\r\\n')
    title = title:gsub('\n', '\\n')
    table.insert(option_strings, string.format("%d. %s", i, title))
  end

  local choice = vim.fn.inputlist(option_strings)
  if choice < 1 or choice > #actions then
    return
  end
  local action_chosen = actions[choice]
  -- textDocument/codeAction can return either Command[] or CodeAction[].
  -- If it is a CodeAction, it can have either an edit, a command or both.
  -- Edits should be executed first
  if action_chosen.edit or type(action_chosen.command) == "table" then
    if action_chosen.edit then
      util.apply_workspace_edit(action_chosen.edit)
    end
    if type(action_chosen.command) == "table" then
      buf.execute_command(action_chosen.command)
    end
  else
    buf.execute_command(action_chosen)
  end
end

M['workspace/applyEdit'] = function(_, _, workspace_edit)
  if not workspace_edit then return end
  -- TODO(ashkan) Do something more with label?
  if workspace_edit.label then
    print("Workspace edit", workspace_edit.label)
  end
  local status, result = pcall(util.apply_workspace_edit, workspace_edit.edit)
  return {
    applied = status;
    failureReason = result;
  }
end

M['textDocument/publishDiagnostics'] = function(_, _, result)
  if not result then return end
  local uri = result.uri
  local bufnr = vim.uri_to_bufnr(uri)
  if not bufnr then
    err_message("LSP.publishDiagnostics: Couldn't find buffer for ", uri)
    return
  end

  -- Unloaded buffers should not handle diagnostics.
  --    When the buffer is loaded, we'll call on_attach, which sends textDocument/didOpen.
  --    This should trigger another publish of the diagnostics.
  --
  -- In particular, this stops a ton of spam when first starting a server for current
  -- unloaded buffers.
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  util.buf_clear_diagnostics(bufnr)

  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#diagnostic
  -- The diagnostic's severity. Can be omitted. If omitted it is up to the
  -- client to interpret diagnostics as error, warning, info or hint.
  -- TODO: Replace this with server-specific heuristics to infer severity.
  for _, diagnostic in ipairs(result.diagnostics) do
    if diagnostic.severity == nil then
      diagnostic.severity = protocol.DiagnosticSeverity.Error
    end
  end

  util.buf_diagnostics_save_positions(bufnr, result.diagnostics)
  util.buf_diagnostics_underline(bufnr, result.diagnostics)
  util.buf_diagnostics_virtual_text(bufnr, result.diagnostics)
  util.buf_diagnostics_signs(bufnr, result.diagnostics)
  vim.api.nvim_command("doautocmd User LspDiagnosticsChanged")
end

M['textDocument/references'] = function(_, _, result)
  if not result then return end
  util.set_qflist(util.locations_to_items(result))
  api.nvim_command("copen")
  api.nvim_command("wincmd p")
end

local symbol_callback = function(_, _, result, _, bufnr)
  if not result or vim.tbl_isempty(result) then return end

  util.set_qflist(util.symbols_to_items(result, bufnr))
  api.nvim_command("copen")
  api.nvim_command("wincmd p")
end
M['textDocument/documentSymbol'] = symbol_callback
M['workspace/symbol'] = symbol_callback

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
  local prefix = line_to_cursor:sub(textMatch+1)

  local matches = util.text_document_completion_list_to_complete_items(result, prefix)
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

  -- textDocument/definition can return Location or Location[]
  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition

  if vim.tbl_islist(result) then
    util.jump_to_location(result[1])

    if #result > 1 then
      util.set_qflist(util.locations_to_items(result))
      api.nvim_command("copen")
      api.nvim_command("wincmd p")
    end
  else
    util.jump_to_location(result)
  end
end

M['textDocument/declaration'] = location_callback
M['textDocument/definition'] = location_callback
M['textDocument/typeDefinition'] = location_callback
M['textDocument/implementation'] = location_callback

M['textDocument/signatureHelp'] = function(_, method, result)
  util.focusable_preview(method, function()
    if not (result and result.signatures and result.signatures[1]) then
      return { 'No signature available' }
    end
    -- TODO show popup when signatures is empty?
    local lines = util.convert_signature_help_to_markdown_lines(result)
    lines = util.trim_empty_lines(lines)
    if vim.tbl_isempty(lines) then
      return { 'No signature available' }
    end
    return lines, util.try_trim_markdown_code_blocks(lines)
  end)
end

M['textDocument/documentHighlight'] = function(_, _, result, _)
  if not result then return end
  local bufnr = api.nvim_get_current_buf()
  util.buf_highlight_references(bufnr, result)
end

M['window/logMessage'] = function(_, _, result, client_id)
  local message_type = result.type
  local message = result.message
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format("id=%d", client_id)
  if not client then
    err_message("LSP[", client_name, "] client has shut down after sending the message")
  end
  if message_type == protocol.MessageType.Error then
    log.error(message)
  elseif message_type == protocol.MessageType.Warning then
    log.warn(message)
  elseif message_type == protocol.MessageType.Info then
    log.info(message)
  else
    log.debug(message)
  end
  return result
end

M['window/showMessage'] = function(_, _, result, client_id)
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

-- Add boilerplate error validation and logging for all of these.
for k, fn in pairs(M) do
  M[k] = function(err, method, params, client_id, bufnr)
    log.debug('default_callback', method, { params = params, client_id = client_id, err = err, bufnr = bufnr })
    if err then
      error(tostring(err))
    end
    return fn(err, method, params, client_id, bufnr)
  end
end

return M
-- vim:sw=2 ts=2 et
