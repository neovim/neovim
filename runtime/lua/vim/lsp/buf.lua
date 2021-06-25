local vim = vim
local validate = vim.validate
local vfn = vim.fn
local util = require 'vim.lsp.util'

local M = {}

--@private
--- Returns nil if {status} is false or nil, otherwise returns the rest of the
--- arguments.
local function ok_or_nil(status, ...)
  if not status then return end
  return ...
end

--@private
--- Swallows errors.
---
--@param fn Function to run
--@param ... Function arguments
--@returns Result of `fn(...)` if there are no errors, otherwise nil.
--- Returns nil if errors occur during {fn}, otherwise returns
local function npcall(fn, ...)
  return ok_or_nil(pcall(fn, ...))
end

--@private
--- Sends an async request to all active clients attached to the current
--- buffer.
---
--@param method (string) LSP method name
--@param params (optional, table) Parameters to send to the server
--@param handler (optional, functionnil) See |lsp-handler|. Follows |lsp-handler-resolution|
--
--@returns 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
---
--@see |vim.lsp.buf_request()|
local function request(method, params, handler)
  validate {
    method = {method, 's'};
    handler = {handler, 'f', true};
  }
  return vim.lsp.buf_request(0, method, params, handler)
end

--- Checks whether the language servers attached to the current buffer are
--- ready.
---
--@returns `true` if server responds.
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
--@note Many servers do not implement this method. Generally, see |vim.lsp.buf.definition()| instead.
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
---
--@param context (context support not yet implemented) Additional information
--- about the context in which a completion was triggered (how it was triggered,
--- and by which trigger character, if applicable)
---
--@see |vim.lsp.protocol.constants.CompletionTriggerKind|
function M.completion(context)
  local params = util.make_position_params()
  params.context = context
  return request('textDocument/completion', params)
end

--@private
--- If there is more than one client that supports the given method,
--- asks the user to select one.
--
--@returns The client that the user selected or nil
local function select_client(method)
  local clients = vim.tbl_values(vim.lsp.buf_get_clients());
  clients = vim.tbl_filter(function (client)
    return client.supports_method(method)
  end, clients)
  -- better UX when choices are always in the same order (between restarts)
  table.sort(clients, function (a, b) return a.name < b.name end)

  if #clients > 1 then
    local choices = {}
    for k,v in ipairs(clients) do
      table.insert(choices, string.format("%d %s", k, v.name))
    end
    local user_choice = vim.fn.confirm(
      "Select a language server:",
      table.concat(choices, "\n"),
      0,
      "Question"
    )
    if user_choice == 0 then return nil end
    return clients[user_choice]
  elseif #clients < 1 then
    return nil
  else
    return clients[1]
  end
end

--- Formats the current buffer.
---
--@param options (optional, table) Can be used to specify FormattingOptions.
--- Some unspecified options will be automatically derived from the current
--- Neovim options.
--
--@see https://microsoft.github.io/language-server-protocol/specification#textDocument_formatting
function M.formatting(options)
  local client = select_client("textDocument/formatting")
  if client == nil then return end

  local params = util.make_formatting_params(options)
  return client.request("textDocument/formatting", params, nil, vim.api.nvim_get_current_buf())
end

--- Performs |vim.lsp.buf.formatting()| synchronously.
---
--- Useful for running on save, to make sure buffer is formatted prior to being
--- saved. {timeout_ms} is passed on to |vim.lsp.buf_request_sync()|. Example:
---
--- <pre>
--- vim.api.nvim_command[[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()]]
--- </pre>
---
--@param options Table with valid `FormattingOptions` entries
--@param timeout_ms (number) Request timeout
--@see |vim.lsp.buf.formatting_seq_sync|
function M.formatting_sync(options, timeout_ms)
  local client = select_client("textDocument/formatting")
  if client == nil then return end

  local params = util.make_formatting_params(options)
  local result, err = client.request_sync("textDocument/formatting", params, timeout_ms, vim.api.nvim_get_current_buf())
  if result and result.result then
    util.apply_text_edits(result.result)
  elseif err then
    vim.notify("vim.lsp.buf.formatting_sync: " .. err, vim.log.levels.WARN)
  end
end

--- Formats the current buffer by sequentially requesting formatting from attached clients.
---
--- Useful when multiple clients with formatting capability are attached.
---
--- Since it's synchronous, can be used for running on save, to make sure buffer is formatted
--- prior to being saved. {timeout_ms} is passed on to the |vim.lsp.client| `request_sync` method.
--- Example:
--- <pre>
--- vim.api.nvim_command[[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
--- </pre>
---
--@param options (optional, table) `FormattingOptions` entries
--@param timeout_ms (optional, number) Request timeout
--@param order (optional, table) List of client names. Formatting is requested from clients
---in the following order: first all clients that are not in the `order` list, then
---the remaining clients in the order as they occur in the `order` list.
function M.formatting_seq_sync(options, timeout_ms, order)
  local clients = vim.tbl_values(vim.lsp.buf_get_clients());

  -- sort the clients according to `order`
  for _, client_name in ipairs(order or {}) do
    -- if the client exists, move to the end of the list
    for i, client in ipairs(clients) do
      if client.name == client_name then
        table.insert(clients, table.remove(clients, i))
        break
      end
    end
  end

  -- loop through the clients and make synchronous formatting requests
  for _, client in ipairs(clients) do
    if client.resolved_capabilities.document_formatting then
      local params = util.make_formatting_params(options)
      local result, err = client.request_sync("textDocument/formatting", params, timeout_ms, vim.api.nvim_get_current_buf())
      if result and result.result then
        util.apply_text_edits(result.result)
      elseif err then
        vim.notify(string.format("vim.lsp.buf.formatting_seq_sync: (%s) %s", client.name, err), vim.log.levels.WARN)
      end
    end
  end
end

--- Formats a given range.
---
--@param options Table with valid `FormattingOptions` entries.
--@param start_pos ({number, number}, optional) mark-indexed position.
---Defaults to the start of the last visual selection.
--@param end_pos ({number, number}, optional) mark-indexed position.
---Defaults to the end of the last visual selection.
function M.range_formatting(options, start_pos, end_pos)
  local client = select_client("textDocument/rangeFormatting")
  if client == nil then return end

  local params = util.make_given_range_params(start_pos, end_pos)
  params.options = util.make_formatting_params(options).options
  return client.request("textDocument/rangeFormatting", params)
end

--- Renames all references to the symbol under the cursor.
---
--@param new_name (string) If not provided, the user will be prompted for a new
---name using |input()|.
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
--@param context (table) Context for the request
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_references
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

--@private
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

--@private
local function call_hierarchy(method)
  local params = util.make_position_params()
  request('textDocument/prepareCallHierarchy', params, function(err, _, result)
    if err then
      vim.notify(err.message, vim.log.levels.WARN)
      return
    end
    local call_hierarchy_item = pick_call_hierarchy_item(result)
    vim.lsp.buf_request(0, method, { item = call_hierarchy_item })
  end)
end

--- Lists all the call sites of the symbol under the cursor in the
--- |quickfix| window. If the symbol can resolve to multiple
--- items, the user can pick one in the |inputlist|.
function M.incoming_calls()
  call_hierarchy('callHierarchy/incomingCalls')
end

--- Lists all the items that are called by the symbol under the
--- cursor in the |quickfix| window. If the symbol can resolve to
--- multiple items, the user can pick one in the |inputlist|.
function M.outgoing_calls()
  call_hierarchy('callHierarchy/outgoingCalls')
end

--- List workspace folders.
---
function M.list_workspace_folders()
  local workspace_folders = {}
  for _, client in ipairs(vim.lsp.buf_get_clients()) do
    for _, folder in ipairs(client.workspaceFolders) do
      table.insert(workspace_folders, folder.name)
    end
  end
  return workspace_folders
end

--- Add the folder at path to the workspace folders. If {path} is
--- not provided, the user will be prompted for a path using |input()|.
function M.add_workspace_folder(workspace_folder)
  workspace_folder = workspace_folder or npcall(vfn.input, "Workspace Folder: ", vfn.expand('%:p:h'), 'dir')
  vim.api.nvim_command("redraw")
  if not (workspace_folder and #workspace_folder > 0) then return end
  if vim.fn.isdirectory(workspace_folder) == 0 then
    print(workspace_folder, " is not a valid directory")
    return
  end
  local params = util.make_workspace_params({{uri = vim.uri_from_fname(workspace_folder); name = workspace_folder}}, {{}})
  for _, client in ipairs(vim.lsp.buf_get_clients()) do
    local found = false
    for _, folder in ipairs(client.workspaceFolders) do
      if folder.name == workspace_folder then
        found = true
        print(workspace_folder, "is already part of this workspace")
        break
      end
    end
    if not found then
      vim.lsp.buf_notify(0, 'workspace/didChangeWorkspaceFolders', params)
      table.insert(client.workspaceFolders, params.event.added[1])
    end
  end
end

--- Remove the folder at path from the workspace folders. If
--- {path} is not provided, the user will be prompted for
--- a path using |input()|.
function M.remove_workspace_folder(workspace_folder)
  workspace_folder = workspace_folder or npcall(vfn.input, "Workspace Folder: ", vfn.expand('%:p:h'))
  vim.api.nvim_command("redraw")
  if not (workspace_folder and #workspace_folder > 0) then return end
  local params = util.make_workspace_params({{}}, {{uri = vim.uri_from_fname(workspace_folder); name = workspace_folder}})
  for _, client in ipairs(vim.lsp.buf_get_clients()) do
    for idx, folder in ipairs(client.workspaceFolders) do
      if folder.name == workspace_folder then
        vim.lsp.buf_notify(0, 'workspace/didChangeWorkspaceFolders', params)
        client.workspaceFolders[idx] = nil
        return
      end
    end
  end
  print(workspace_folder,  "is not currently part of the workspace")
end

--- Lists all symbols in the current workspace in the quickfix window.
---
--- The list is filtered against {query}; if the argument is omitted from the
--- call, the user is prompted to enter a string on the command line. An empty
--- string means no filtering is done.
---
--@param query (string, optional)
function M.workspace_symbol(query)
  query = query or npcall(vfn.input, "Query: ")
  local params = {query = query}
  request('workspace/symbol', params)
end

--- Send request to the server to resolve document highlights for the current
--- text document position. This request can be triggered by a  key mapping or
--- by events such as `CursorHold`, eg:
---
--- <pre>
--- vim.api.nvim_command [[autocmd CursorHold  <buffer> lua vim.lsp.buf.document_highlight()]]
--- vim.api.nvim_command [[autocmd CursorHoldI <buffer> lua vim.lsp.buf.document_highlight()]]
--- vim.api.nvim_command [[autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()]]
--- </pre>
---
--- Note: Usage of |vim.lsp.buf.document_highlight()| requires the following highlight groups
---       to be defined or you won't be able to see the actual highlights.
---         |LspReferenceText|
---         |LspReferenceRead|
---         |LspReferenceWrite|
function M.document_highlight()
  local params = util.make_position_params()
  request('textDocument/documentHighlight', params)
end

--- Removes document highlights from current buffer.
---
function M.clear_references()
  util.buf_clear_references()
end

--- Selects a code action from the input list that is available at the current
--- cursor position.
--
--@param context: (table, optional) Valid `CodeActionContext` object
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
function M.code_action(context)
  validate { context = { context, 't', true } }
  context = context or { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
  local params = util.make_range_params()
  params.context = context
  request('textDocument/codeAction', params)
end

--- Performs |vim.lsp.buf.code_action()| for a given range.
---
--@param context: (table, optional) Valid `CodeActionContext` object
--@param start_pos ({number, number}, optional) mark-indexed position.
---Defaults to the start of the last visual selection.
--@param end_pos ({number, number}, optional) mark-indexed position.
---Defaults to the end of the last visual selection.
function M.range_code_action(context, start_pos, end_pos)
  validate { context = { context, 't', true } }
  context = context or { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
  local params = util.make_given_range_params(start_pos, end_pos)
  params.context = context
  request('textDocument/codeAction', params)
end

--- Executes an LSP server command.
---
--@param command A valid `ExecuteCommandParams` object
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_executeCommand
function M.execute_command(command)
  validate {
    command = { command.command, 's' },
    arguments = { command.arguments, 't', true }
  }
  request('workspace/executeCommand', command)
end

return M
-- vim:sw=2 ts=2 et
