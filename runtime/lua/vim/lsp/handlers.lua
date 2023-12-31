local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local ms = protocol.Methods
local util = require('vim.lsp.util')
local api = vim.api

--- @type table<string, vim.lsp.Handler>
local M = {}

-- FIXME: DOC: Expose in vimdocs

--- Writes to error buffer.
---@param ... string Will be concatenated before being written
local function err_message(...)
  vim.notify(table.concat(vim.tbl_flatten({ ... })), vim.log.levels.ERROR)
  api.nvim_command('redraw')
end

-- Request: LSP
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_executeCommand
---@type vim.lsp.ResponseHandler
M[ms.workspace_executeCommand] = function(_, _, _, _)
  -- Error handling is done implicitly by wrapping all handlers; see end of this file
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress
---@param params lsp.ProgressParams
---@type vim.lsp.NotificationHandler
M[ms.dollar_progress] = function(_, params, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('LSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end
  local kind = nil
  local value = params.value

  if type(value) == 'table' then
    kind = value.kind
    -- Carry over title of `begin` messages to `report` and `end` messages
    -- So that consumers always have it available, even if they consume a
    -- subset of the full sequence
    if kind == 'begin' then
      client.progress.pending[params.token] = value.title
    else
      value.title = client.progress.pending[params.token]
      if kind == 'end' then
        client.progress.pending[params.token] = nil
      end
    end
  end

  client.progress:push(params)

  api.nvim_exec_autocmds('LspProgress', {
    pattern = kind,
    modeline = false,
    data = { client_id = ctx.client_id, result = params },
  })
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_workDoneProgress_create
---@param result lsp.WorkDoneProgressCreateParams
---@return any void TODO see #16472
---@type vim.lsp.RequestHandler
M[ms.window_workDoneProgress_create] = function(_, result, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('LSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end
  client.progress:push(result)
  return vim.NIL -- TODO: this seems to be a non-error case, should not return NIL?
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showMessageRequest
---@param params lsp.ShowMessageRequestParams
---@return lsp.MessageActionItem|nil  TODO vim.NIL ???
---@type vim.lsp.RequestHandler
M[ms.window_showMessageRequest] = function(_, params, _, _)
  local actions = params.actions or {}
  local co, is_main = coroutine.running()
  if co and not is_main then
    local opts = {
      prompt = params.message .. ': ',
      format_item = function(action)
        return (action.title:gsub('\r\n', '\\r\\n')):gsub('\n', '\\n')
      end,
    }
    vim.ui.select(actions, opts, function(choice)
      -- schedule to ensure resume doesn't happen _before_ yield with
      -- default synchronous vim.ui.select
      vim.schedule(function()
        coroutine.resume(co, choice or vim.NIL)
      end)
    end)
    return coroutine.yield()
  else
    local option_strings = { params.message, '\nRequest Actions:' }
    for i, action in ipairs(actions) do
      local title = action.title:gsub('\r\n', '\\r\\n')
      title = title:gsub('\n', '\\n')
      table.insert(option_strings, string.format('%d. %s', i, title))
    end
    local choice = vim.fn.inputlist(option_strings)
    if choice < 1 or choice > #actions then
      return vim.NIL
    else
      return actions[choice]
    end
  end
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#client_registerCapability
---@param params lsp.RegistrationParams
---@return any void TODO
---@type vim.lsp.RequestHandler
M[ms.client_registerCapability] = function(_, params, ctx, _)
  local client_id = ctx.client_id
  local client = assert(vim.lsp.get_client_by_id(client_id))

  client.dynamic_capabilities:register(params.registrations)
  for bufnr, _ in pairs(client.attached_buffers) do
    vim.lsp._set_defaults(client, bufnr)
  end

  ---@type string[]
  local unsupported = {}
  for _, reg in ipairs(params.registrations) do
    if reg.method == ms.workspace_didChangeWatchedFiles then
      require('vim.lsp._watchfiles').register(reg, ctx)
    elseif not client.dynamic_capabilities:supports_registration(reg.method) then
      unsupported[#unsupported + 1] = reg.method
    end
  end
  if #unsupported > 0 then
    local warning_tpl = 'The language server %s triggers a registerCapability '
      .. 'handler for %s despite dynamicRegistration set to false. '
      .. 'Report upstream, this warning is harmless'
    local client_name = client and client.name or string.format('id=%d', client_id)
    local warning = string.format(warning_tpl, client_name, table.concat(unsupported, ', '))
    log.warn(warning)
  end
  return vim.NIL
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#client_unregisterCapability
---@param params lsp.UnregistrationParams
---@return any void TODO
---@type vim.lsp.RequestHandler
M[ms.client_unregisterCapability] = function(_, params, ctx, _)
  local client_id = ctx.client_id
  local client = assert(vim.lsp.get_client_by_id(client_id))
  client.dynamic_capabilities:unregister(params.unregisterations)

  for _, unreg in ipairs(params.unregisterations) do
    if unreg.method == ms.workspace_didChangeWatchedFiles then
      require('vim.lsp._watchfiles').unregister(unreg, ctx)
    end
  end
  return vim.NIL
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
---@param workspace_edit lsp.ApplyWorkspaceEditParams
---@return lsp.ApplyWorkspaceEditResult result
---@type vim.lsp.RequestHandler
M[ms.workspace_applyEdit] = function(_, workspace_edit, ctx, _)
  assert(
    workspace_edit,
    'workspace/applyEdit must be called with `ApplyWorkspaceEditParams`. Server is violating the specification'
  )
  -- TODO(ashkan) Do something more with label?
  local client_id = ctx.client_id
  local client = assert(vim.lsp.get_client_by_id(client_id))
  if workspace_edit.label then
    print('Workspace edit', workspace_edit.label)
  end
  local status, errmsg =
    pcall(util.apply_workspace_edit, workspace_edit.edit, client.offset_encoding)

  ---@type lsp.ApplyWorkspaceEditResult
  local result = {
    applied = status,
    failureReason = errmsg,
  }
  return result
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_configuration
---@param params lsp.ConfigurationParams
---@return lsp.LSPAny[] result
---@type vim.lsp.RequestHandler
M[ms.workspace_configuration] = function(_, params, ctx, _)
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
  if not params.items then
    return {}
  end

  ---@type lsp.LSPAny[]
  local response = {}
  for _, item in ipairs(params.items) do
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

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_workspaceFolders
---@type vim.lsp.RequestHandler
---@return lsp.WorkspaceFolder[]|nil  TODO vim.NIL
M[ms.workspace_workspaceFolders] = function(_, _, ctx, _)
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    err_message('LSP[id=', client_id, '] client has shut down after sending the message')
    return
  end
  return client.workspace_folders or vim.NIL
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_publishDiagnostics
---@type vim.lsp.NotificationHandler
M[ms.textDocument_publishDiagnostics] = function(...)
  return require('vim.lsp.diagnostic').on_publish_diagnostics(...)
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_diagnostic
---@type vim.lsp.ResponseHandler
M[ms.textDocument_diagnostic] = function(...)
  return require('vim.lsp.diagnostic').on_diagnostic(...)
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeLens
---@type vim.lsp.ResponseHandler
M[ms.textDocument_codeLens] = function(...)
  return require('vim.lsp.codelens').on_codelens(...)
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_inlayHint
---@type vim.lsp.ResponseHandler
M[ms.textDocument_inlayHint] = function(...)
  return require('vim.lsp.inlay_hint').on_inlayhint(...)
end

-- https://microsoft.github.io/language-server-protocol/specification/#workspace_inlayHint_refresh
---@type vim.lsp.RequestHandler
M[ms.workspace_inlayHint_refresh] = function(...)
  return require('vim.lsp.inlay_hint').on_refresh(...)
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_references
---@param result lsp.Location[]|nil
---@type vim.lsp.ResponseHandler
M[ms.textDocument_references] = function(_, result, ctx, config)
  if not result or vim.tbl_isempty(result) then
    vim.notify('No references found')
    return
  end

  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
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

--- Return a function that converts LSP responses to list items and opens the list
---
--- The returned function has an optional {config} parameter that accepts a table
--- with the following keys:
---
---   loclist: (boolean) use the location list (default is to use the quickfix list)
---
---@param map_result fun(resp: lsp.DocumentSymbol[]|lsp.WorkspaceSymbol[]|lsp.SymbolInformation[], bufnr: integer|nil):vim.lsp.util.LocationItem[]
---                    Function `((resp, bufnr) -> list)` to convert the LSP response into location items
---@param entity string name of the resource used in a `not found` error message
---@param title_fn fun(ctx: lsp.HandlerContext): string Function to call to generate list title
---@return vim.lsp.ResponseHandler
local function _response_to_list_handler(map_result, entity, title_fn)
  ---@type vim.lsp.ResponseHandler
  return function(_, result, ctx, config)
    if not result or vim.tbl_isempty(result) then
      vim.notify('No ' .. entity .. ' found')
      return
    end
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

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
---@type vim.lsp.ResponseHandler
M[ms.textDocument_documentSymbol] = _response_to_list_handler(
  util.symbols_to_items,
  'document symbols',
  function(ctx)
    local fname = vim.fn.fnamemodify(vim.uri_to_fname(ctx.params.textDocument.uri), ':.')
    return string.format('Symbols in %s', fname)
  end
)

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_symbol
---@type vim.lsp.ResponseHandler
M[ms.workspace_symbol] = _response_to_list_handler(
  util.symbols_to_items,
  'workspace symbols',
  function(ctx)
    return string.format("Symbols matching '%s'", ctx.params.query)
  end
)

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rename
---@param result lsp.WorkspaceEdit|nil
---@type vim.lsp.ResponseHandler
M[ms.textDocument_rename] = function(_, result, ctx, _)
  if not result then
    vim.notify("Language server couldn't provide rename result", vim.log.levels.INFO)
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  util.apply_workspace_edit(result, client.offset_encoding)
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rangeFormatting
---@param result lsp.TextEdit[]|nil
---@type vim.lsp.ResponseHandler
M[ms.textDocument_rangeFormatting] = function(_, result, ctx, _)
  if not result then
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  util.apply_text_edits(result, ctx.bufnr, client.offset_encoding)
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_formatting
---@param result lsp.TextEdit[]|nil
---@type vim.lsp.ResponseHandler
M[ms.textDocument_formatting] = function(_, result, ctx, _)
  if not result then
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  util.apply_text_edits(result, ctx.bufnr, client.offset_encoding)
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
---@param result lsp.CompletionItem[] | lsp.CompletionList | nil
---@type vim.lsp.ResponseHandler
M[ms.textDocument_completion] = function(_, result, _, _)
  if result == nil or vim.tbl_isempty(result) then
    return
  end
  local cursor = api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  local line = assert(api.nvim_buf_get_lines(0, row - 1, row, false)[1])
  local line_to_cursor = line:sub(col + 1)
  local textMatch = vim.fn.match(line_to_cursor, '\\k*$')
  local prefix = line_to_cursor:sub(textMatch + 1)

  local matches = util.text_document_completion_list_to_complete_items(result, prefix)
  vim.fn.complete(textMatch + 1, matches)
end

--- |lsp-handler| for the method "textDocument/hover"
---
--- ```lua
--- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
---   vim.lsp.handlers.hover, {
---     -- Use a sharp border with `FloatBorder` highlights
---     border = "single",
---     -- add the title in hover float window
---     title = "hover"
---   }
--- )
--- ```
---
---@param result lsp.Hover|nil
---@param ctx lsp.HandlerContext
---@param config table Configuration table.
---     - border:     (default=nil)
---         - Add borders to the floating window
---         - See |vim.lsp.util.open_floating_preview()| for more options.
---@type vim.lsp.ResponseHandler
function M.hover(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  if api.nvim_get_current_buf() ~= ctx.bufnr then
    -- Ignore result since buffer changed. This happens for slow language servers.
    return
  end
  if not (result and result.contents) then
    if config.silent ~= true then
      vim.notify('No information available')
    end
    return
  end
  local format = 'markdown'
  local contents ---@type string[]
  if type(result.contents) == 'table' and result.contents.kind == 'plaintext' then
    format = 'plaintext'
    contents = vim.split(result.contents.value or '', '\n', { trimempty = true })
  else
    contents = util.convert_input_to_markdown_lines(result.contents)
  end
  if vim.tbl_isempty(contents) then
    if config.silent ~= true then
      vim.notify('No information available')
    end
    return
  end
  return util.open_floating_preview(contents, format, config)
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
---@type vim.lsp.ResponseHandler
M[ms.textDocument_hover] = M.hover

--- Jumps to a location. Used as a handler for multiple LSP methods.
---@param _ any not used (error code)
---@param result lsp.Location|lsp.Location[]|lsp.LocationLink[]|nil
---@param ctx lsp.HandlerContext table containing the context of the request, including the method
---@type vim.lsp.ResponseHandler
local function location_handler(_, result, ctx, config)
  if result == nil or vim.tbl_isempty(result) then
    if log.info() then
      log.info(ctx.method, 'No location found')
    end
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))

  config = config or {}

  -- textDocument/definition can return Location or Location[]
  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition
  if not vim.tbl_islist(result) then
    result = { result }
  end

  local title = 'LSP locations'
  local items = util.locations_to_items(result, client.offset_encoding)

  if config.on_list then
    assert(type(config.on_list) == 'function', 'on_list is not a function')
    config.on_list({ title = title, items = items })
    return
  end
  if #result == 1 then
    util.jump_to_location(result[1], client.offset_encoding, config.reuse_win)
    return
  end
  vim.fn.setqflist({}, ' ', { title = title, items = items })
  api.nvim_command('botright copen')
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_declaration
---@type vim.lsp.ResponseHandler
M[ms.textDocument_declaration] = location_handler

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition
---@type vim.lsp.ResponseHandler
M[ms.textDocument_definition] = location_handler

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_typeDefinition
---@type vim.lsp.ResponseHandler
M[ms.textDocument_typeDefinition] = location_handler

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_implementation
---@type vim.lsp.ResponseHandler
M[ms.textDocument_implementation] = location_handler

--- |lsp-handler| for the method "textDocument/signatureHelp".
---
--- The active parameter is highlighted with |hl-LspSignatureActiveParameter|.
---
--- ```lua
--- vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
---   vim.lsp.handlers.signature_help, {
---     -- Use a sharp border with `FloatBorder` highlights
---     border = "single"
---   }
--- )
--- ```
---
---@param result lsp.SignatureHelp|nil Response from the language server
---@param ctx lsp.HandlerContext Client context
---@param config table Configuration table.
---     - border:     (default=nil)
---         - Add borders to the floating window
---         - See |vim.lsp.util.open_floating_preview()| for more options
---@type vim.lsp.ResponseHandler
function M.signature_help(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  if api.nvim_get_current_buf() ~= ctx.bufnr then
    -- Ignore result since buffer changed. This happens for slow language servers.
    return
  end
  -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
  -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
  if not (result and result.signatures and result.signatures[1]) then
    if config.silent ~= true then
      print('No signature help available')
    end
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  local triggers =
    vim.tbl_get(client.server_capabilities, 'signatureHelpProvider', 'triggerCharacters')
  local ft = vim.bo[ctx.bufnr].filetype
  local lines, hl = util.convert_signature_help_to_markdown_lines(result, ft, triggers)
  if not lines or vim.tbl_isempty(lines) then
    if config.silent ~= true then
      print('No signature help available')
    end
    return
  end
  local fbuf, fwin = util.open_floating_preview(lines, 'markdown', config)
  if hl then
    -- Highlight the second line if the signature is wrapped in a Markdown code block.
    local line = vim.startswith(lines[1], '```') and 1 or 0
    api.nvim_buf_add_highlight(fbuf, -1, 'LspSignatureActiveParameter', line, unpack(hl))
  end
  return fbuf, fwin
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
---@type vim.lsp.ResponseHandler
M[ms.textDocument_signatureHelp] = M.signature_help

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight
---@param result lsp.DocumentHighlight[]|nil
---@type vim.lsp.ResponseHandler
M[ms.textDocument_documentHighlight] = function(_, result, ctx, _)
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
---@param direction 'from'|'to' `"from"` for incoming calls and `"to"` for outgoing calls
---  whose {result} param is:
--- `CallHierarchyIncomingCall[]` if {direction} is `"from"`,
--- `CallHierarchyOutgoingCall[]` if {direction} is `"to"`,
---@return vim.lsp.ResponseHandler
local make_call_hierarchy_handler = function(direction)
  ---@param result lsp.CallHierarchyIncomingCall[] | lsp.CallHierarchyOutgoingCall[]
  return function(_, result, _, _)
    if not result then
      return
    end
    local items = {}
    for _, call_hierarchy_call in ipairs(result) do
      ---@type lsp.CallHierarchyItem
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

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy_incomingCalls
---@type vim.lsp.ResponseHandler
M[ms.callHierarchy_incomingCalls] = make_call_hierarchy_handler('from')

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy_outgoingCalls
---@type vim.lsp.ResponseHandler
M[ms.callHierarchy_outgoingCalls] = make_call_hierarchy_handler('to')

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_logMessage
---@param params lsp.LogMessageParams
---@type vim.lsp.NotificationHandler
M[ms.window_logMessage] = function(_, params, ctx, _)
  local message_type = params.type
  local message = params.message
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
  -- TODO: remove return value, should not be used
  return params
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showMessage
---@param params lsp.ShowMessageParams
---@type vim.lsp.NotificationHandler
M[ms.window_showMessage] = function(_, params, ctx, _)
  local message_type = params.type
  local message = params.message
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format('id=%d', client_id)
  if not client then
    err_message('LSP[', client_name, '] client has shut down after sending ', message)
  end
  if message_type == protocol.MessageType.Error then
    err_message('LSP[', client_name, '] ', message)
  else
    local message_type_name = protocol.MessageType[message_type] ---@type lsp.MessageType
    api.nvim_out_write(string.format('LSP[%s][%s] %s\n', client_name, message_type_name, message))
  end
  -- TODO: remove return value, should not be used
  return params
end

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showDocument
---@param result lsp.ShowDocumentParams
---@return lsp.ShowDocumentResult
---@type vim.lsp.RequestHandler
M[ms.window_showDocument] = function(_, result, ctx, _)
  local uri = result.uri

  if result.external then
    -- TODO(lvimuser): ask the user for confirmation
    local ret, err = vim.ui.open(uri)

    if ret == nil or ret.code ~= 0 then
      return {
        success = false,
        error = {
          code = protocol.ErrorCodes.UnknownErrorCode,
          message = ret and ret.stderr or err,
        },
      }
    end

    return { success = true }
  end

  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format('id=%d', client_id)
  if not client then
    err_message('LSP[', client_name, '] client has shut down after sending ', ctx.method)
    return vim.NIL
  end

  local location = {
    uri = uri,
    range = result.selection,
  }

  local success = util.show_document(location, client.offset_encoding, {
    reuse_win = true,
    focus = result.takeFocus,
  })
  return { success = success or false }
end

-- Add boilerplate error validation and logging for all of these.
for k, fn in pairs(M) do
  ---@param err lsp.ResponseError
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
