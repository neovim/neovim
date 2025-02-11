local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local ms = protocol.Methods
local util = require('vim.lsp.util')
local api = vim.api
local completion = require('vim.lsp.completion')

--- @type table<string, lsp.Handler>
local M = {}

--- @deprecated
--- Client to server response handlers.
--- @type table<vim.lsp.protocol.Method.ClientToServer, lsp.Handler>
local RCS = {}

--- Server to client request handlers.
--- @type table<vim.lsp.protocol.Method.ServerToClient, lsp.Handler>
local RSC = {}

--- Server to client notification handlers.
--- @type table<vim.lsp.protocol.Method.ServerToClient, lsp.Handler>
local NSC = {}

--- Writes to error buffer.
---@param ... string Will be concatenated before being written
local function err_message(...)
  vim.notify(table.concat(vim.iter({ ... }):flatten():totable()), vim.log.levels.ERROR)
  api.nvim_command('redraw')
end

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_executeCommand
RCS[ms.workspace_executeCommand] = function(_, _, _)
  -- Error handling is done implicitly by wrapping all handlers; see end of this file
end

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#progress
---@param params lsp.ProgressParams
---@param ctx lsp.HandlerContext
---@diagnostic disable-next-line:no-unknown
RSC[ms.dollar_progress] = function(_, params, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('LSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end
  local kind = nil
  local value = params.value

  if type(value) == 'table' then
    kind = value.kind --- @type string
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
    data = { client_id = ctx.client_id, params = params },
  })
end

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_workDoneProgress_create
---@param params lsp.WorkDoneProgressCreateParams
---@param ctx lsp.HandlerContext
RSC[ms.window_workDoneProgress_create] = function(_, params, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('LSP[id=', tostring(ctx.client_id), '] client has shut down during progress update')
    return vim.NIL
  end
  client.progress:push(params)
  return vim.NIL
end

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showMessageRequest
---@param params lsp.ShowMessageRequestParams
RSC[ms.window_showMessageRequest] = function(_, params)
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

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#client_registerCapability
--- @param params lsp.RegistrationParams
RSC[ms.client_registerCapability] = function(_, params, ctx)
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  client:_register(params.registrations)
  for bufnr in pairs(client.attached_buffers) do
    vim.lsp._set_defaults(client, bufnr)
  end
  return vim.NIL
end

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#client_unregisterCapability
--- @param params lsp.UnregistrationParams
RSC[ms.client_unregisterCapability] = function(_, params, ctx)
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  client:_unregister(params.unregisterations)
  return vim.NIL
end

-- TODO(lewis6991): Do we need to notify other servers?
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
RSC[ms.workspace_applyEdit] = function(_, params, ctx)
  assert(
    params,
    'workspace/applyEdit must be called with `ApplyWorkspaceEditParams`. Server is violating the specification'
  )
  -- TODO(ashkan) Do something more with label?
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  if params.label then
    print('Workspace edit', params.label)
  end
  local status, result = pcall(util.apply_workspace_edit, params.edit, client.offset_encoding)
  return {
    applied = status,
    failureReason = result,
  }
end

---@param table   table e.g., { foo = { bar = "z" } }
---@param section string indicating the field of the table, e.g., "foo.bar"
---@return any|nil setting value read from the table, or `nil` not found
local function lookup_section(table, section)
  local keys = vim.split(section, '.', { plain = true }) --- @type string[]
  return vim.tbl_get(table, unpack(keys))
end

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_configuration
--- @param params lsp.ConfigurationParams
RSC[ms.workspace_configuration] = function(_, params, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message(
      'LSP[',
      ctx.client_id,
      '] client has shut down after sending a workspace/configuration request'
    )
    return
  end
  if not params.items then
    return {}
  end

  local response = {}
  for _, item in ipairs(params.items) do
    if item.section then
      local value = lookup_section(client.settings, item.section)
      -- For empty sections with no explicit '' key, return settings as is
      if value == nil and item.section == '' then
        value = client.settings
      end
      if value == nil then
        value = vim.NIL
      end
      table.insert(response, value)
    end
  end
  return response
end

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_workspaceFolders
RSC[ms.workspace_workspaceFolders] = function(_, _, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    err_message('LSP[id=', ctx.client_id, '] client has shut down after sending the message')
    return
  end
  return client.workspace_folders or vim.NIL
end

NSC[ms.textDocument_publishDiagnostics] = function(...)
  return vim.lsp.diagnostic.on_publish_diagnostics(...)
end

--- @private
RCS[ms.textDocument_diagnostic] = function(...)
  return vim.lsp.diagnostic.on_diagnostic(...)
end

--- @private
RCS[ms.textDocument_codeLens] = function(...)
  return vim.lsp.codelens.on_codelens(...)
end

--- @private
RCS[ms.textDocument_inlayHint] = function(...)
  return vim.lsp.inlay_hint.on_inlayhint(...)
end

--- Return a function that converts LSP responses to list items and opens the list
---
--- The returned function has an optional {config} parameter that accepts |vim.lsp.ListOpts|
---
---@param map_result fun(resp, bufnr: integer, position_encoding: 'utf-8'|'utf-16'|'utf-32'): table to convert the response
---@param entity string name of the resource used in a `not found` error message
---@param title_fn fun(ctx: lsp.HandlerContext): string Function to call to generate list title
---@return lsp.Handler
local function response_to_list(map_result, entity, title_fn)
  --- @diagnostic disable-next-line:redundant-parameter
  return function(_, result, ctx, config)
    if not result or vim.tbl_isempty(result) then
      vim.notify('No ' .. entity .. ' found')
      return
    end
    config = config or {}
    local title = title_fn(ctx)
    local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    local items = map_result(result, ctx.bufnr, client.offset_encoding)

    local list = { title = title, items = items, context = ctx }
    if config.on_list then
      assert(vim.is_callable(config.on_list), 'on_list is not a function')
      config.on_list(list)
    elseif config.loclist then
      vim.fn.setloclist(0, {}, ' ', list)
      vim.cmd.lopen()
    else
      vim.fn.setqflist({}, ' ', list)
      vim.cmd('botright copen')
    end
  end
end

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
RCS[ms.textDocument_documentSymbol] = response_to_list(
  util.symbols_to_items,
  'document symbols',
  function(ctx)
    local fname = vim.fn.fnamemodify(vim.uri_to_fname(ctx.params.textDocument.uri), ':.')
    return string.format('Symbols in %s', fname)
  end
)

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_symbol
RCS[ms.workspace_symbol] = response_to_list(util.symbols_to_items, 'symbols', function(ctx)
  return string.format("Symbols matching '%s'", ctx.params.query)
end)

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rename
RCS[ms.textDocument_rename] = function(_, result, ctx)
  if not result then
    vim.notify("Language server couldn't provide rename result", vim.log.levels.INFO)
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  util.apply_workspace_edit(result, client.offset_encoding)
end

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rangeFormatting
RCS[ms.textDocument_rangeFormatting] = function(_, result, ctx)
  if not result then
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  util.apply_text_edits(result, ctx.bufnr, client.offset_encoding)
end

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_formatting
RCS[ms.textDocument_formatting] = function(_, result, ctx)
  if not result then
    return
  end
  local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
  util.apply_text_edits(result, ctx.bufnr, client.offset_encoding)
end

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
RCS[ms.textDocument_completion] = function(_, result, _)
  if vim.tbl_isempty(result or {}) then
    return
  end
  local cursor = api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  local line = assert(api.nvim_buf_get_lines(0, row - 1, row, false)[1])
  local line_to_cursor = line:sub(col + 1)
  local textMatch = vim.fn.match(line_to_cursor, '\\k*$')
  local prefix = line_to_cursor:sub(textMatch + 1)

  local matches = completion._lsp_to_complete_items(result, prefix)
  vim.fn.complete(textMatch + 1, matches)
end

--- @deprecated
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
---@param _ lsp.ResponseError?
---@param result lsp.Hover
---@param ctx lsp.HandlerContext
---@param config table Configuration table.
---     - border:     (default=nil)
---         - Add borders to the floating window
---         - See |vim.lsp.util.open_floating_preview()| for more options.
--- @diagnostic disable-next-line:redundant-parameter
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

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
--- @diagnostic disable-next-line: deprecated
RCS[ms.textDocument_hover] = M.hover

local sig_help_ns = api.nvim_create_namespace('nvim.lsp.signature_help')

--- @deprecated remove in 0.13
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
---@param _ lsp.ResponseError?
---@param result lsp.SignatureHelp? Response from the language server
---@param ctx lsp.HandlerContext Client context
---@param config table Configuration table.
---     - border:     (default=nil)
---         - Add borders to the floating window
---         - See |vim.lsp.util.open_floating_preview()| for more options
--- @diagnostic disable-next-line:redundant-parameter
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
  -- Highlight the active parameter.
  if hl then
    vim.hl.range(
      fbuf,
      sig_help_ns,
      'LspSignatureActiveParameter',
      { hl[1], hl[2] },
      { hl[3], hl[4] }
    )
  end
  return fbuf, fwin
end

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
--- @diagnostic disable-next-line:deprecated
RCS[ms.textDocument_signatureHelp] = M.signature_help

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight
RCS[ms.textDocument_documentHighlight] = function(_, result, ctx)
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

--- @private
---
--- Displays call hierarchy in the quickfix window.
---
--- @param direction 'from'|'to' `"from"` for incoming calls and `"to"` for outgoing calls
--- @overload fun(direction:'from'): fun(_, result: lsp.CallHierarchyIncomingCall[]?)
--- @overload fun(direction:'to'): fun(_, result: lsp.CallHierarchyOutgoingCall[]?)
local function make_call_hierarchy_handler(direction)
  --- @param result lsp.CallHierarchyIncomingCall[]|lsp.CallHierarchyOutgoingCall[]
  return function(_, result)
    if not result then
      return
    end
    local items = {}
    for _, call_hierarchy_call in pairs(result) do
      --- @type lsp.CallHierarchyItem
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
    vim.cmd('botright copen')
  end
end

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy_incomingCalls
RCS[ms.callHierarchy_incomingCalls] = make_call_hierarchy_handler('from')

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy_outgoingCalls
RCS[ms.callHierarchy_outgoingCalls] = make_call_hierarchy_handler('to')

--- Displays type hierarchy in the quickfix window.
local function make_type_hierarchy_handler()
  --- @param result lsp.TypeHierarchyItem[]
  return function(_, result, ctx, _)
    if not result then
      return
    end
    local function format_item(item)
      if not item.detail or #item.detail == 0 then
        return item.name
      end
      return string.format('%s %s', item.name, item.detail)
    end
    local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    local items = {}
    for _, type_hierarchy_item in pairs(result) do
      local col = util._get_line_byte_from_position(
        ctx.bufnr,
        type_hierarchy_item.range.start,
        client.offset_encoding
      )
      table.insert(items, {
        filename = assert(vim.uri_to_fname(type_hierarchy_item.uri)),
        text = format_item(type_hierarchy_item),
        lnum = type_hierarchy_item.range.start.line + 1,
        col = col + 1,
      })
    end
    vim.fn.setqflist({}, ' ', { title = 'LSP type hierarchy', items = items })
    vim.cmd('botright copen')
  end
end

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#typeHierarchy_incomingCalls
RCS[ms.typeHierarchy_subtypes] = make_type_hierarchy_handler()

--- @deprecated remove in 0.13
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#typeHierarchy_outgoingCalls
RCS[ms.typeHierarchy_supertypes] = make_type_hierarchy_handler()

--- @see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_logMessage
--- @param params lsp.LogMessageParams
NSC['window/logMessage'] = function(_, params, ctx)
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
  return params
end

--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showMessage
--- @param params lsp.ShowMessageParams
NSC['window/showMessage'] = function(_, params, ctx)
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
    message = ('LSP[%s][%s] %s\n'):format(client_name, protocol.MessageType[message_type], message)
    api.nvim_echo({ { message } }, true, {})
  end
  return params
end

--- @private
--- @see # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#window_showDocument
--- @param params lsp.ShowDocumentParams
RSC[ms.window_showDocument] = function(_, params, ctx)
  local uri = params.uri

  if params.external then
    -- TODO(lvimuser): ask the user for confirmation
    local cmd, err = vim.ui.open(uri)
    local ret = cmd and cmd:wait(2000) or nil

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
    range = params.selection,
  }

  local success = util.show_document(location, client.offset_encoding, {
    reuse_win = true,
    focus = params.takeFocus,
  })
  return { success = success or false }
end

---@see https://microsoft.github.io/language-server-protocol/specification/#workspace_inlayHint_refresh
RSC[ms.workspace_inlayHint_refresh] = function(err, result, ctx)
  return vim.lsp.inlay_hint.on_refresh(err, result, ctx)
end

---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#semanticTokens_refreshRequest
RSC[ms.workspace_semanticTokens_refresh] = function(err, result, ctx)
  return vim.lsp.semantic_tokens._refresh(err, result, ctx)
end

--- @nodoc
--- @type table<string, lsp.Handler>
M = vim.tbl_extend('force', M, RSC, NSC, RCS)

-- Add boilerplate error validation and logging for all of these.
for k, fn in pairs(M) do
  --- @diagnostic disable-next-line:redundant-parameter
  M[k] = function(err, result, ctx, config)
    if log.trace() then
      log.trace('default_handler', ctx.method, {
        err = err,
        result = result,
        ctx = vim.inspect(ctx),
      })
    end

    -- ServerCancelled errors should be propagated to the request handler
    if err and err.code ~= protocol.ErrorCodes.ServerCancelled then
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

    --- @diagnostic disable-next-line:redundant-parameter
    return fn(err, result, ctx, config)
  end
end

return M
