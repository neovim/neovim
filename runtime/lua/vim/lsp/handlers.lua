local log = require 'vim.lsp.log'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'
local vim = vim
local api = vim.api
local buf = require 'vim.lsp.buf'

local M = {}

-- FIXME: DOC: Expose in vimdocs

--@private
--- Writes to error buffer.
--@param ... (table of strings) Will be concatenated before being written
local function err_message(...)
  vim.notify(table.concat(vim.tbl_flatten{...}), vim.log.levels.ERROR)
  api.nvim_command("redraw")
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_executeCommand
M['workspace/executeCommand'] = function(err, _)
  if err then
    error("Could not execute code action: "..err.message)
  end
end

-- @msg of type ProgressParams
-- Basically a token of type number/string
local function progress_handler(_, _, params, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format("id=%d", client_id)
  if not client then
    err_message("LSP[", client_name, "] client has shut down after sending the message")
  end
  local val = params.value    -- unspecified yet
  local token = params.token  -- string or number


  if val.kind then
    if val.kind == 'begin' then
      client.messages.progress[token] = {
        title = val.title,
        message = val.message,
        percentage = val.percentage,
      }
    elseif val.kind == 'report' then
      client.messages.progress[token].message = val.message;
      client.messages.progress[token].percentage = val.percentage;
    elseif val.kind == 'end' then
      if client.messages.progress[token] == nil then
        err_message("LSP[", client_name, "] received `end` message with no corresponding `begin`")
      else
        client.messages.progress[token].message = val.message
        client.messages.progress[token].done = true
      end
    end
  else
    table.insert(client.messages, {content = val, show_once = true, shown = 0})
  end

  vim.api.nvim_command("doautocmd <nomodeline> User LspProgressUpdate")
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress
M['$/progress'] = progress_handler

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_workDoneProgress_create
M['window/workDoneProgress/create'] =  function(_, _, params, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  local token = params.token  -- string or number
  local client_name = client and client.name or string.format("id=%d", client_id)
  if not client then
    err_message("LSP[", client_name, "] client has shut down after sending the message")
  end
  client.messages.progress[token] = {}
  return vim.NIL
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showMessageRequest
M['window/showMessageRequest'] = function(_, _, params)

  local actions = params.actions
  print(params.message)
  local option_strings = {params.message, "\nRequest Actions:"}
  for i, action in ipairs(actions) do
    local title = action.title:gsub('\r\n', '\\r\\n')
    title = title:gsub('\n', '\\n')
    table.insert(option_strings, string.format("%d. %s", i, title))
  end

  -- window/showMessageRequest can return either MessageActionItem[] or null.
  local choice = vim.fn.inputlist(option_strings)
  if choice < 1 or choice > #actions then
      return vim.NIL
  else
    return actions[choice]
  end
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#client_registerCapability
M['client/registerCapability'] = function(_, _, _, client_id)
  local warning_tpl = "The language server %s triggers a registerCapability "..
                      "handler despite dynamicRegistration set to false. "..
                      "Report upstream, this warning is harmless"
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format("id=%d", client_id)
  local warning = string.format(warning_tpl, client_name)
  log.warn(warning)
  return vim.NIL
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
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

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
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

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_configuration
M['workspace/configuration'] = function(err, _, params, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    err_message("LSP[id=", client_id, "] client has shut down after sending the message")
    return
  end
  if err then error(vim.inspect(err)) end
  if not params.items then
    return {}
  end

  local result = {}
  for _, item in ipairs(params.items) do
    if item.section then
      local value = util.lookup_section(client.config.settings, item.section) or vim.NIL
      -- For empty sections with no explicit '' key, return settings as is
      if value == vim.NIL and item.section == '' then
        value = client.config.settings or vim.NIL
      end
      table.insert(result, value)
    end
  end
  return result
end

M['textDocument/publishDiagnostics'] = function(...)
  return require('vim.lsp.diagnostic').on_publish_diagnostics(...)
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_references
M['textDocument/references'] = function(_, _, result)
  if not result then return end
  util.set_qflist(util.locations_to_items(result))
  api.nvim_command("copen")
  api.nvim_command("wincmd p")
end

--@private
--- Prints given list of symbols to the quickfix list.
--@param _ (not used)
--@param _ (not used)
--@param result (list of Symbols) LSP method name
--@param result (table) result of LSP method; a location or a list of locations.
---(`textDocument/definition` can return `Location` or `Location[]`
local symbol_handler = function(_, _, result, _, bufnr)
  if not result or vim.tbl_isempty(result) then return end

  util.set_qflist(util.symbols_to_items(result, bufnr))
  api.nvim_command("copen")
  api.nvim_command("wincmd p")
end
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
M['textDocument/documentSymbol'] = symbol_handler
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_symbol
M['workspace/symbol'] = symbol_handler

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rename
M['textDocument/rename'] = function(_, _, result)
  if not result then return end
  util.apply_workspace_edit(result)
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rangeFormatting
M['textDocument/rangeFormatting'] = function(_, _, result)
  if not result then return end
  util.apply_text_edits(result)
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_formatting
M['textDocument/formatting'] = function(_, _, result)
  if not result then return end
  util.apply_text_edits(result)
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
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

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
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

--@private
--- Jumps to a location. Used as a handler for multiple LSP methods.
--@param _ (not used)
--@param method (string) LSP method name
--@param result (table) result of LSP method; a location or a list of locations.
---(`textDocument/definition` can return `Location` or `Location[]`
local function location_handler(_, method, result)
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

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_declaration
M['textDocument/declaration'] = location_handler
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition
M['textDocument/definition'] = location_handler
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_typeDefinition
M['textDocument/typeDefinition'] = location_handler
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_implementation
M['textDocument/implementation'] = location_handler

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
M['textDocument/signatureHelp'] = function(_, method, result)
  -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
  -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
  if not (result and result.signatures and result.signatures[1]) then
    print('No signature help available')
    return
  end
  local lines = util.convert_signature_help_to_markdown_lines(result)
  lines = util.trim_empty_lines(lines)
  if vim.tbl_isempty(lines) then
    print('No signature help available')
    return
  end
  util.focusable_preview(method, function()
    return lines, util.try_trim_markdown_code_blocks(lines)
  end)
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight
M['textDocument/documentHighlight'] = function(_, _, result, _, bufnr, _)
  if not result then return end
  util.buf_highlight_references(bufnr, result)
end

--@private
---
--- Displays call hierarchy in the quickfix window.
---
--@param direction `"from"` for incoming calls and `"to"` for outgoing calls
--@returns `CallHierarchyIncomingCall[]` if {direction} is `"from"`,
--@returns `CallHierarchyOutgoingCall[]` if {direction} is `"to"`,
local make_call_hierarchy_handler = function(direction)
  return function(_, _, result)
    if not result then return end
    local items = {}
    for _, call_hierarchy_call in pairs(result) do
      local call_hierarchy_item = call_hierarchy_call[direction]
      for _, range in pairs(call_hierarchy_call.fromRanges) do
        table.insert(items, {
          filename = assert(vim.uri_to_fname(call_hierarchy_item.uri)),
          text = call_hierarchy_item.name,
          lnum = range.start.line + 1,
          col = range.start.character + 1,
        })
      end
    end
    util.set_qflist(items)
    api.nvim_command("copen")
    api.nvim_command("wincmd p")
  end
end

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy/incomingCalls
M['callHierarchy/incomingCalls'] = make_call_hierarchy_handler('from')

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy/outgoingCalls
M['callHierarchy/outgoingCalls'] = make_call_hierarchy_handler('to')

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window/logMessage
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

--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window/showMessage
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
  M[k] = function(err, method, params, client_id, bufnr, config)
    local _ = log.debug() and log.debug('default_handler', method, {
      params = params, client_id = client_id, err = err, bufnr = bufnr, config = config
    })

    if err then
      return err_message(tostring(err))
    end

    return fn(err, method, params, client_id, bufnr, config)
  end
end

return M
-- vim:sw=2 ts=2 et
