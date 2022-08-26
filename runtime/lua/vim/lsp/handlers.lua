local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local util = require('vim.lsp.util')
local vim = vim
local api = vim.api

local M = {}

-- FIXME: DOC: Expose in vimdocs

---@private
--- Writes to error buffer.
---@param ... (table of strings) Will be concatenated before being written
local function err_message(...)
  vim.notify(table.concat(vim.tbl_flatten({ ... })), vim.log.levels.ERROR)
  api.nvim_command('redraw')
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_executeCommand
M['workspace/executeCommand'] = function(_, _, _, _)
  -- Error handling is done implicitly by wrapping all handlers; see end of this file
end

---@private
local function progress_handler(_, result, ctx, _)
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format('id=%d', client_id)
  if not client then
    err_message('LSP[', client_name, '] client has shut down during progress update')
    return vim.NIL
  end
  local val = result.value -- unspecified yet
  local token = result.token -- string or number

  if type(val) ~= 'table' then
    val = { content = val }
  end
  if val.kind then
    if val.kind == 'begin' then
      client.messages.progress[token] = {
        title = val.title,
        cancellable = val.cancellable,
        message = val.message,
        percentage = val.percentage,
      }
    elseif val.kind == 'report' then
      client.messages.progress[token].cancellable = val.cancellable
      client.messages.progress[token].message = val.message
      client.messages.progress[token].percentage = val.percentage
    elseif val.kind == 'end' then
      if client.messages.progress[token] == nil then
        err_message('LSP[', client_name, '] received `end` message with no corresponding `begin`')
      else
        client.messages.progress[token].message = val.message
        client.messages.progress[token].done = true
      end
    end
  else
    client.messages.progress[token] = val
    client.messages.progress[token].done = true
  end

  api.nvim_exec_autocmds('User', { pattern = 'LspProgressUpdate', modeline = false })
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress
M['$/progress'] = progress_handler

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_workDoneProgress_create
M['window/workDoneProgress/create'] = function(_, result, ctx)
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  local token = result.token -- string or number
  local client_name = client and client.name or string.format('id=%d', client_id)
  if not client then
    err_message('LSP[', client_name, '] client has shut down while creating progress report')
    return vim.NIL
  end
  client.messages.progress[token] = {}
  return vim.NIL
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showMessageRequest
M['window/showMessageRequest'] = function(_, result)
  local actions = result.actions
  print(result.message)
  local option_strings = { result.message, '\nRequest Actions:' }
  for i, action in ipairs(actions) do
    local title = action.title:gsub('\r\n', '\\r\\n')
    title = title:gsub('\n', '\\n')
    table.insert(option_strings, string.format('%d. %s', i, title))
  end

  -- window/showMessageRequest can return either MessageActionItem[] or null.
  local choice = vim.fn.inputlist(option_strings)
  if choice < 1 or choice > #actions then
    return vim.NIL
  else
    return actions[choice]
  end
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#client_registerCapability
M['client/registerCapability'] = function(_, _, ctx)
  local client_id = ctx.client_id
  local warning_tpl = 'The language server %s triggers a registerCapability '
    .. 'handler despite dynamicRegistration set to false. '
    .. 'Report upstream, this warning is harmless'
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format('id=%d', client_id)
  local warning = string.format(warning_tpl, client_name)
  log.warn(warning)
  return vim.NIL
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
M['workspace/applyEdit'] = function(_, workspace_edit, ctx)
  if not workspace_edit then
    return
  end
  -- TODO(ashkan) Do something more with label?
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  if workspace_edit.label then
    print('Workspace edit', workspace_edit.label)
  end
  local status, result =
    pcall(util.apply_workspace_edit, workspace_edit.edit, client.offset_encoding)
  return {
    applied = status,
    failureReason = result,
  }
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_configuration
M['workspace/configuration'] = function(_, result, ctx)
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    err_message(
      'LSP[',
      client_id,
      '] client has shut down after sending a workspace/configuration request'
    )
    return
  end
  if not result.items then
    return {}
  end

  local response = {}
  for _, item in ipairs(result.items) do
    if item.section then
      local value = util.lookup_section(client.config.settings, item.section)
      -- For empty sections with no explicit '' key, return settings as is
      if value == vim.NIL and item.section == '' then
        value = client.config.settings or vim.NIL
      end
      table.insert(response, value)
    end
  end
  return response
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_workspaceFolders
M['workspace/workspaceFolders'] = function(_, _, ctx)
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    err_message('LSP[id=', client_id, '] client has shut down after sending the message')
    return
  end
  return client.workspace_folders or vim.NIL
end

M['textDocument/publishDiagnostics'] = function(...)
  return require('vim.lsp.diagnostic').on_publish_diagnostics(...)
end

M['textDocument/codeLens'] = function(...)
  return require('vim.lsp.codelens').on_codelens(...)
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_references
M['textDocument/references'] = function(_, result, ctx, config)
  if not result or vim.tbl_isempty(result) then
    vim.notify('No references found')
  else
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    config = config or {}
    local title = 'References'
    local items = util.locations_to_items(result, client.offset_encoding)

    if config.loclist then
      vim.fn.setloclist(0, {}, ' ', { title = title, items = items, context = ctx })
      api.nvim_command('lopen')
    elseif config.on_list then
      assert(type(config.on_list) == 'function', 'on_list is not a function')
      config.on_list({ title = title, items = items, context = ctx })
    else
      vim.fn.setqflist({}, ' ', { title = title, items = items, context = ctx })
      api.nvim_command('botright copen')
    end
  end
end

---@private
--- Return a function that converts LSP responses to list items and opens the list
---
--- The returned function has an optional {config} parameter that accepts a table
--- with the following keys:
---
---   loclist: (boolean) use the location list (default is to use the quickfix list)
---
---@param map_result function `((resp, bufnr) -> list)` to convert the response
---@param entity string name of the resource used in a `not found` error message
---@param title_fn function Function to call to generate list title
local function response_to_list(map_result, entity, title_fn)
  return function(_, result, ctx, config)
    if not result or vim.tbl_isempty(result) then
      vim.notify('No ' .. entity .. ' found')
    else
      config = config or {}
      local title = title_fn(ctx)
      local items = map_result(result, ctx.bufnr)

      if config.loclist then
        vim.fn.setloclist(0, {}, ' ', { title = title, items = items, context = ctx })
        api.nvim_command('lopen')
      elseif config.on_list then
        assert(type(config.on_list) == 'function', 'on_list is not a function')
        config.on_list({ title = title, items = items, context = ctx })
      else
        vim.fn.setqflist({}, ' ', { title = title, items = items, context = ctx })
        api.nvim_command('botright copen')
      end
    end
  end
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
M['textDocument/documentSymbol'] = response_to_list(
  util.symbols_to_items,
  'document symbols',
  function(ctx)
    local fname = vim.fn.fnamemodify(vim.uri_to_fname(ctx.params.textDocument.uri), ':.')
    return string.format('Symbols in %s', fname)
  end
)

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_symbol
M['workspace/symbol'] = response_to_list(util.symbols_to_items, 'symbols', function(ctx)
  return string.format("Symbols matching '%s'", ctx.params.query)
end)

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rename
M['textDocument/rename'] = function(_, result, ctx, _)
  if not result then
    vim.notify("Language server couldn't provide rename result", vim.log.levels.INFO)
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  util.apply_workspace_edit(result, client.offset_encoding)
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rangeFormatting
M['textDocument/rangeFormatting'] = function(_, result, ctx, _)
  if not result then
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  util.apply_text_edits(result, ctx.bufnr, client.offset_encoding)
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_formatting
M['textDocument/formatting'] = function(_, result, ctx, _)
  if not result then
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  util.apply_text_edits(result, ctx.bufnr, client.offset_encoding)
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
M['textDocument/completion'] = function(_, result, _, _)
  if vim.tbl_isempty(result or {}) then
    return
  end
  local row, col = unpack(api.nvim_win_get_cursor(0))
  local line = assert(api.nvim_buf_get_lines(0, row - 1, row, false)[1])
  local line_to_cursor = line:sub(col + 1)
  local textMatch = vim.fn.match(line_to_cursor, '\\k*$')
  local prefix = line_to_cursor:sub(textMatch + 1)

  local matches = util.text_document_completion_list_to_complete_items(result, prefix)
  vim.fn.complete(textMatch + 1, matches)
end

--- |lsp-handler| for the method "textDocument/hover"
--- <pre>
--- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
---   vim.lsp.handlers.hover, {
---     -- Use a sharp border with `FloatBorder` highlights
---     border = "single"
---   }
--- )
--- </pre>
---@param config table Configuration table.
---     - border:     (default=nil)
---         - Add borders to the floating window
---         - See |nvim_open_win()|
function M.hover(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  if not (result and result.contents) then
    vim.notify('No information available')
    return
  end
  local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
  markdown_lines = util.trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    vim.notify('No information available')
    return
  end
  return util.open_floating_preview(markdown_lines, 'markdown', config)
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
M['textDocument/hover'] = M.hover

---@private
--- Jumps to a location. Used as a handler for multiple LSP methods.
---@param _ (not used)
---@param result (table) result of LSP method; a location or a list of locations.
---@param ctx (table) table containing the context of the request, including the method
---(`textDocument/definition` can return `Location` or `Location[]`
local function location_handler(_, result, ctx, config)
  if result == nil or vim.tbl_isempty(result) then
    local _ = log.info() and log.info(ctx.method, 'No location found')
    return nil
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)

  config = config or {}

  -- textDocument/definition can return Location or Location[]
  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition

  if vim.tbl_islist(result) then
    local title = 'LSP locations'
    local items = util.locations_to_items(result, client.offset_encoding)

    if config.on_list then
      assert(type(config.on_list) == 'function', 'on_list is not a function')
      config.on_list({ title = title, items = items })
    else
      if #result == 1 then
        util.jump_to_location(result[1], client.offset_encoding, config.reuse_win)
        return
      end
      vim.fn.setqflist({}, ' ', { title = title, items = items })
      api.nvim_command('botright copen')
    end
  else
    util.jump_to_location(result, client.offset_encoding, config.reuse_win)
  end
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_declaration
M['textDocument/declaration'] = location_handler
--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition
M['textDocument/definition'] = location_handler
--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_typeDefinition
M['textDocument/typeDefinition'] = location_handler
--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_implementation
M['textDocument/implementation'] = location_handler

--- |lsp-handler| for the method "textDocument/signatureHelp".
--- The active parameter is highlighted with |hl-LspSignatureActiveParameter|.
--- <pre>
--- vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
---   vim.lsp.handlers.signature_help, {
---     -- Use a sharp border with `FloatBorder` highlights
---     border = "single"
---   }
--- )
--- </pre>
---@param config table Configuration table.
---     - border:     (default=nil)
---         - Add borders to the floating window
---         - See |vim.api.nvim_open_win()|
function M.signature_help(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
  -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
  if not (result and result.signatures and result.signatures[1]) then
    if config.silent ~= true then
      print('No signature help available')
    end
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  local triggers =
    vim.tbl_get(client.server_capabilities, 'signatureHelpProvider', 'triggerCharacters')
  local ft = api.nvim_buf_get_option(ctx.bufnr, 'filetype')
  local lines, hl = util.convert_signature_help_to_markdown_lines(result, ft, triggers)
  lines = util.trim_empty_lines(lines)
  if vim.tbl_isempty(lines) then
    if config.silent ~= true then
      print('No signature help available')
    end
    return
  end
  local fbuf, fwin = util.open_floating_preview(lines, 'markdown', config)
  if hl then
    api.nvim_buf_add_highlight(fbuf, -1, 'LspSignatureActiveParameter', 0, unpack(hl))
  end
  return fbuf, fwin
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
M['textDocument/signatureHelp'] = M.signature_help

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight
M['textDocument/documentHighlight'] = function(_, result, ctx, _)
  if not result then
    return
  end
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    return
  end
  util.buf_highlight_references(ctx.bufnr, result, client.offset_encoding)
end

---@private
---
--- Displays call hierarchy in the quickfix window.
---
---@param direction `"from"` for incoming calls and `"to"` for outgoing calls
---@returns `CallHierarchyIncomingCall[]` if {direction} is `"from"`,
---@returns `CallHierarchyOutgoingCall[]` if {direction} is `"to"`,
local make_call_hierarchy_handler = function(direction)
  return function(_, result)
    if not result then
      return
    end
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
    vim.fn.setqflist({}, ' ', { title = 'LSP call hierarchy', items = items })
    api.nvim_command('botright copen')
  end
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy_incomingCalls
M['callHierarchy/incomingCalls'] = make_call_hierarchy_handler('from')

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy_outgoingCalls
M['callHierarchy/outgoingCalls'] = make_call_hierarchy_handler('to')

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_logMessage
M['window/logMessage'] = function(_, result, ctx, _)
  local message_type = result.type
  local message = result.message
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format('id=%d', client_id)
  if not client then
    err_message('LSP[', client_name, '] client has shut down after sending ', message)
  end
  if message_type == protocol.MessageType.Error then
    log.error(message)
  elseif message_type == protocol.MessageType.Warning then
    log.warn(message)
  elseif message_type == protocol.MessageType.Info or message_type == protocol.MessageType.Log then
    log.info(message)
  else
    log.debug(message)
  end
  return result
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showMessage
M['window/showMessage'] = function(_, result, ctx, _)
  local message_type = result.type
  local message = result.message
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format('id=%d', client_id)
  if not client then
    err_message('LSP[', client_name, '] client has shut down after sending ', message)
  end
  if message_type == protocol.MessageType.Error then
    err_message('LSP[', client_name, '] ', message)
  else
    local message_type_name = protocol.MessageType[message_type]
    api.nvim_out_write(string.format('LSP[%s][%s] %s\n', client_name, message_type_name, message))
  end
  return result
end

-- Add boilerplate error validation and logging for all of these.
for k, fn in pairs(M) do
  M[k] = function(err, result, ctx, config)
    local _ = log.trace()
      and log.trace('default_handler', ctx.method, {
        err = err,
        result = result,
        ctx = vim.inspect(ctx),
        config = config,
      })

    if err then
      -- LSP spec:
      -- interface ResponseError:
      --  code: integer;
      --  message: string;
      --  data?: string | number | boolean | array | object | null;

      -- Per LSP, don't show ContentModified error to the user.
      if err.code ~= protocol.ErrorCodes.ContentModified then
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        local client_name = client and client.name or string.format('client_id=%d', ctx.client_id)

        err_message(client_name .. ': ' .. tostring(err.code) .. ': ' .. err.message)
      end
      return
    end

    return fn(err, result, ctx, config)
  end
end

return M
-- vim:sw=2 ts=2 et
