local vim = vim
local api = vim.api
local validate = vim.validate
local util = require('vim.lsp.util')
local npcall = vim.F.npcall

local M = {}

---@private
--- Sends an async request to all active clients attached to the current
--- buffer.
---
---@param method (string) LSP method name
---@param params (table|nil) Parameters to send to the server
---@param handler (function|nil) See |lsp-handler|. Follows |lsp-handler-resolution|
--
---@returns 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
---
---@see |vim.lsp.buf_request()|
local function request(method, params, handler)
  validate({
    method = { method, 's' },
    handler = { handler, 'f', true },
  })
  return vim.lsp.buf_request(0, method, params, handler)
end

--- Checks whether the language servers attached to the current buffer are
--- ready.
---
---@returns `true` if server responds.
function M.server_ready()
  return not not vim.lsp.buf_notify(0, 'window/progress', {})
end

--- Displays hover information about the symbol under the cursor in a floating
--- window. Calling the function twice will jump into the floating window.
function M.hover()
  local params = util.make_position_params()
  request('textDocument/hover', params)
end

---@private
local function request_with_options(name, params, options)
  local req_handler
  if options then
    req_handler = function(err, result, ctx, config)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      local handler = client.handlers[name] or vim.lsp.handlers[name]
      handler(err, result, ctx, vim.tbl_extend('force', config or {}, options))
    end
  end
  request(name, params, req_handler)
end

--- Jumps to the declaration of the symbol under the cursor.
---@note Many servers do not implement this method. Generally, see |vim.lsp.buf.definition()| instead.
---
---@param options table|nil additional options
---     - reuse_win: (boolean) Jump to existing window if buffer is already open.
---     - on_list: (function) handler for list results. See |on-list-handler|
function M.declaration(options)
  local params = util.make_position_params()
  request_with_options('textDocument/declaration', params, options)
end

--- Jumps to the definition of the symbol under the cursor.
---
---@param options table|nil additional options
---     - reuse_win: (boolean) Jump to existing window if buffer is already open.
---     - on_list: (function) handler for list results. See |on-list-handler|
function M.definition(options)
  local params = util.make_position_params()
  request_with_options('textDocument/definition', params, options)
end

--- Jumps to the definition of the type of the symbol under the cursor.
---
---@param options table|nil additional options
---     - reuse_win: (boolean) Jump to existing window if buffer is already open.
---     - on_list: (function) handler for list results. See |on-list-handler|
function M.type_definition(options)
  local params = util.make_position_params()
  request_with_options('textDocument/typeDefinition', params, options)
end

--- Lists all the implementations for the symbol under the cursor in the
--- quickfix window.
---
---@param options table|nil additional options
---     - on_list: (function) handler for list results. See |on-list-handler|
function M.implementation(options)
  local params = util.make_position_params()
  request_with_options('textDocument/implementation', params, options)
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
---@param context (context support not yet implemented) Additional information
--- about the context in which a completion was triggered (how it was triggered,
--- and by which trigger character, if applicable)
---
---@see |vim.lsp.protocol.constants.CompletionTriggerKind|
function M.completion(context)
  local params = util.make_position_params()
  params.context = context
  return request('textDocument/completion', params)
end

---@private
--- If there is more than one client that supports the given method,
--- asks the user to select one.
--
---@returns The client that the user selected or nil
local function select_client(method, on_choice)
  validate({
    on_choice = { on_choice, 'function', false },
  })
  local clients = vim.tbl_values(vim.lsp.buf_get_clients())
  clients = vim.tbl_filter(function(client)
    return client.supports_method(method)
  end, clients)
  -- better UX when choices are always in the same order (between restarts)
  table.sort(clients, function(a, b)
    return a.name < b.name
  end)

  if #clients > 1 then
    vim.ui.select(clients, {
      prompt = 'Select a language server:',
      format_item = function(client)
        return client.name
      end,
    }, on_choice)
  elseif #clients < 1 then
    on_choice(nil)
  else
    on_choice(clients[1])
  end
end

--- Formats a buffer using the attached (and optionally filtered) language
--- server clients.
---
--- @param options table|nil Optional table which holds the following optional fields:
---     - formatting_options (table|nil):
---         Can be used to specify FormattingOptions. Some unspecified options will be
---         automatically derived from the current Neovim options.
---         See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#formattingOptions
---     - timeout_ms (integer|nil, default 1000):
---         Time in milliseconds to block for formatting requests. No effect if async=true
---     - bufnr (number|nil):
---         Restrict formatting to the clients attached to the given buffer, defaults to the current
---         buffer (0).
---
---     - filter (function|nil):
---         Predicate used to filter clients. Receives a client as argument and must return a
---         boolean. Clients matching the predicate are included. Example:
---
---         <pre>
---         -- Never request typescript-language-server for formatting
---         vim.lsp.buf.format {
---           filter = function(client) return client.name ~= "tsserver" end
---         }
---         </pre>
---
---     - async boolean|nil
---         If true the method won't block. Defaults to false.
---         Editing the buffer while formatting asynchronous can lead to unexpected
---         changes.
---
---     - id (number|nil):
---         Restrict formatting to the client with ID (client.id) matching this field.
---     - name (string|nil):
---         Restrict formatting to the client with name (client.name) matching this field.

function M.format(options)
  options = options or {}
  local bufnr = options.bufnr or api.nvim_get_current_buf()
  local clients = vim.lsp.get_active_clients({
    id = options.id,
    bufnr = bufnr,
    name = options.name,
  })

  if options.filter then
    clients = vim.tbl_filter(options.filter, clients)
  end

  clients = vim.tbl_filter(function(client)
    return client.supports_method('textDocument/formatting')
  end, clients)

  if #clients == 0 then
    vim.notify('[LSP] Format request failed, no matching language servers.')
  end

  if options.async then
    local do_format
    do_format = function(idx, client)
      if not client then
        return
      end
      local params = util.make_formatting_params(options.formatting_options)
      client.request('textDocument/formatting', params, function(...)
        local handler = client.handlers['textDocument/formatting']
          or vim.lsp.handlers['textDocument/formatting']
        handler(...)
        do_format(next(clients, idx))
      end, bufnr)
    end
    do_format(next(clients))
  else
    local timeout_ms = options.timeout_ms or 1000
    for _, client in pairs(clients) do
      local params = util.make_formatting_params(options.formatting_options)
      local result, err = client.request_sync('textDocument/formatting', params, timeout_ms, bufnr)
      if result and result.result then
        util.apply_text_edits(result.result, bufnr, client.offset_encoding)
      elseif err then
        vim.notify(string.format('[LSP][%s] %s', client.name, err), vim.log.levels.WARN)
      end
    end
  end
end

--- Formats the current buffer.
---
---@param options (table|nil) Can be used to specify FormattingOptions.
--- Some unspecified options will be automatically derived from the current
--- Neovim options.
--
---@see https://microsoft.github.io/language-server-protocol/specification#textDocument_formatting
function M.formatting(options)
  vim.notify_once(
    'vim.lsp.buf.formatting is deprecated. Use vim.lsp.buf.format { async = true } instead',
    vim.log.levels.WARN
  )
  local params = util.make_formatting_params(options)
  local bufnr = api.nvim_get_current_buf()
  select_client('textDocument/formatting', function(client)
    if client == nil then
      return
    end

    return client.request('textDocument/formatting', params, nil, bufnr)
  end)
end

--- Performs |vim.lsp.buf.formatting()| synchronously.
---
--- Useful for running on save, to make sure buffer is formatted prior to being
--- saved. {timeout_ms} is passed on to |vim.lsp.buf_request_sync()|. Example:
---
--- <pre>
--- autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()
--- </pre>
---
---@param options table|nil with valid `FormattingOptions` entries
---@param timeout_ms (number) Request timeout
---@see |vim.lsp.buf.formatting_seq_sync|
function M.formatting_sync(options, timeout_ms)
  vim.notify_once(
    'vim.lsp.buf.formatting_sync is deprecated. Use vim.lsp.buf.format instead',
    vim.log.levels.WARN
  )
  local params = util.make_formatting_params(options)
  local bufnr = api.nvim_get_current_buf()
  select_client('textDocument/formatting', function(client)
    if client == nil then
      return
    end

    local result, err = client.request_sync('textDocument/formatting', params, timeout_ms, bufnr)
    if result and result.result then
      util.apply_text_edits(result.result, bufnr, client.offset_encoding)
    elseif err then
      vim.notify('vim.lsp.buf.formatting_sync: ' .. err, vim.log.levels.WARN)
    end
  end)
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
---@param options (table|nil) `FormattingOptions` entries
---@param timeout_ms (number|nil) Request timeout
---@param order (table|nil) List of client names. Formatting is requested from clients
---in the following order: first all clients that are not in the `order` list, then
---the remaining clients in the order as they occur in the `order` list.
function M.formatting_seq_sync(options, timeout_ms, order)
  vim.notify_once(
    'vim.lsp.buf.formatting_seq_sync is deprecated. Use vim.lsp.buf.format instead',
    vim.log.levels.WARN
  )
  local clients = vim.tbl_values(vim.lsp.buf_get_clients())
  local bufnr = api.nvim_get_current_buf()

  -- sort the clients according to `order`
  for _, client_name in pairs(order or {}) do
    -- if the client exists, move to the end of the list
    for i, client in pairs(clients) do
      if client.name == client_name then
        table.insert(clients, table.remove(clients, i))
        break
      end
    end
  end

  -- loop through the clients and make synchronous formatting requests
  for _, client in pairs(clients) do
    if vim.tbl_get(client.server_capabilities, 'documentFormattingProvider') then
      local params = util.make_formatting_params(options)
      local result, err = client.request_sync(
        'textDocument/formatting',
        params,
        timeout_ms,
        api.nvim_get_current_buf()
      )
      if result and result.result then
        util.apply_text_edits(result.result, bufnr, client.offset_encoding)
      elseif err then
        vim.notify(
          string.format('vim.lsp.buf.formatting_seq_sync: (%s) %s', client.name, err),
          vim.log.levels.WARN
        )
      end
    end
  end
end

--- Formats a given range.
---
---@param options Table with valid `FormattingOptions` entries.
---@param start_pos ({number, number}, optional) mark-indexed position.
---Defaults to the start of the last visual selection.
---@param end_pos ({number, number}, optional) mark-indexed position.
---Defaults to the end of the last visual selection.
function M.range_formatting(options, start_pos, end_pos)
  local params = util.make_given_range_params(start_pos, end_pos)
  params.options = util.make_formatting_params(options).options
  select_client('textDocument/rangeFormatting', function(client)
    if client == nil then
      return
    end

    return client.request('textDocument/rangeFormatting', params)
  end)
end

--- Renames all references to the symbol under the cursor.
---
---@param new_name string|nil If not provided, the user will be prompted for a new
---                name using |vim.ui.input()|.
---@param options table|nil additional options
---     - filter (function|nil):
---         Predicate used to filter clients. Receives a client as argument and
---         must return a boolean. Clients matching the predicate are included.
---     - name (string|nil):
---         Restrict clients used for rename to ones where client.name matches
---         this field.
function M.rename(new_name, options)
  options = options or {}
  local bufnr = options.bufnr or api.nvim_get_current_buf()
  local clients = vim.lsp.get_active_clients({
    bufnr = bufnr,
    name = options.name,
  })
  if options.filter then
    clients = vim.tbl_filter(options.filter, clients)
  end

  -- Clients must at least support rename, prepareRename is optional
  clients = vim.tbl_filter(function(client)
    return client.supports_method('textDocument/rename')
  end, clients)

  if #clients == 0 then
    vim.notify('[LSP] Rename, no matching language servers with rename capability.')
  end

  local win = api.nvim_get_current_win()

  -- Compute early to account for cursor movements after going async
  local cword = vim.fn.expand('<cword>')

  ---@private
  local function get_text_at_range(range, offset_encoding)
    return api.nvim_buf_get_text(
      bufnr,
      range.start.line,
      util._get_line_byte_from_position(bufnr, range.start, offset_encoding),
      range['end'].line,
      util._get_line_byte_from_position(bufnr, range['end'], offset_encoding),
      {}
    )[1]
  end

  local try_use_client
  try_use_client = function(idx, client)
    if not client then
      return
    end

    ---@private
    local function rename(name)
      local params = util.make_position_params(win, client.offset_encoding)
      params.newName = name
      local handler = client.handlers['textDocument/rename']
        or vim.lsp.handlers['textDocument/rename']
      client.request('textDocument/rename', params, function(...)
        handler(...)
        try_use_client(next(clients, idx))
      end, bufnr)
    end

    if client.supports_method('textDocument/prepareRename') then
      local params = util.make_position_params(win, client.offset_encoding)
      client.request('textDocument/prepareRename', params, function(err, result)
        if err or result == nil then
          if next(clients, idx) then
            try_use_client(next(clients, idx))
          else
            local msg = err and ('Error on prepareRename: ' .. (err.message or ''))
              or 'Nothing to rename'
            vim.notify(msg, vim.log.levels.INFO)
          end
          return
        end

        if new_name then
          rename(new_name)
          return
        end

        local prompt_opts = {
          prompt = 'New Name: ',
        }
        -- result: Range | { range: Range, placeholder: string }
        if result.placeholder then
          prompt_opts.default = result.placeholder
        elseif result.start then
          prompt_opts.default = get_text_at_range(result, client.offset_encoding)
        elseif result.range then
          prompt_opts.default = get_text_at_range(result.range, client.offset_encoding)
        else
          prompt_opts.default = cword
        end
        vim.ui.input(prompt_opts, function(input)
          if not input or #input == 0 then
            return
          end
          rename(input)
        end)
      end, bufnr)
    else
      assert(
        client.supports_method('textDocument/rename'),
        'Client must support textDocument/rename'
      )
      if new_name then
        rename(new_name)
        return
      end

      local prompt_opts = {
        prompt = 'New Name: ',
        default = cword,
      }
      vim.ui.input(prompt_opts, function(input)
        if not input or #input == 0 then
          return
        end
        rename(input)
      end)
    end
  end

  try_use_client(next(clients))
end

--- Lists all the references to the symbol under the cursor in the quickfix window.
---
---@param context (table) Context for the request
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_references
---@param options table|nil additional options
---     - on_list: (function) handler for list results. See |on-list-handler|
function M.references(context, options)
  validate({ context = { context, 't', true } })
  local params = util.make_position_params()
  params.context = context or {
    includeDeclaration = true,
  }
  request_with_options('textDocument/references', params, options)
end

--- Lists all symbols in the current buffer in the quickfix window.
---
---@param options table|nil additional options
---     - on_list: (function) handler for list results. See |on-list-handler|
function M.document_symbol(options)
  local params = { textDocument = util.make_text_document_params() }
  request_with_options('textDocument/documentSymbol', params, options)
end

---@private
local function pick_call_hierarchy_item(call_hierarchy_items)
  if not call_hierarchy_items then
    return
  end
  if #call_hierarchy_items == 1 then
    return call_hierarchy_items[1]
  end
  local items = {}
  for i, item in pairs(call_hierarchy_items) do
    local entry = item.detail or item.name
    table.insert(items, string.format('%d. %s', i, entry))
  end
  local choice = vim.fn.inputlist(items)
  if choice < 1 or choice > #items then
    return
  end
  return choice
end

---@private
local function call_hierarchy(method)
  local params = util.make_position_params()
  request('textDocument/prepareCallHierarchy', params, function(err, result, ctx)
    if err then
      vim.notify(err.message, vim.log.levels.WARN)
      return
    end
    local call_hierarchy_item = pick_call_hierarchy_item(result)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client then
      client.request(method, { item = call_hierarchy_item }, nil, ctx.bufnr)
    else
      vim.notify(
        string.format('Client with id=%d disappeared during call hierarchy request', ctx.client_id),
        vim.log.levels.WARN
      )
    end
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
  for _, client in pairs(vim.lsp.buf_get_clients()) do
    for _, folder in pairs(client.workspace_folders or {}) do
      table.insert(workspace_folders, folder.name)
    end
  end
  return workspace_folders
end

--- Add the folder at path to the workspace folders. If {path} is
--- not provided, the user will be prompted for a path using |input()|.
function M.add_workspace_folder(workspace_folder)
  workspace_folder = workspace_folder
    or npcall(vim.fn.input, 'Workspace Folder: ', vim.fn.expand('%:p:h'), 'dir')
  api.nvim_command('redraw')
  if not (workspace_folder and #workspace_folder > 0) then
    return
  end
  if vim.fn.isdirectory(workspace_folder) == 0 then
    print(workspace_folder, ' is not a valid directory')
    return
  end
  local params = util.make_workspace_params(
    { { uri = vim.uri_from_fname(workspace_folder), name = workspace_folder } },
    { {} }
  )
  for _, client in pairs(vim.lsp.buf_get_clients()) do
    local found = false
    for _, folder in pairs(client.workspace_folders or {}) do
      if folder.name == workspace_folder then
        found = true
        print(workspace_folder, 'is already part of this workspace')
        break
      end
    end
    if not found then
      vim.lsp.buf_notify(0, 'workspace/didChangeWorkspaceFolders', params)
      if not client.workspace_folders then
        client.workspace_folders = {}
      end
      table.insert(client.workspace_folders, params.event.added[1])
    end
  end
end

--- Remove the folder at path from the workspace folders. If
--- {path} is not provided, the user will be prompted for
--- a path using |input()|.
function M.remove_workspace_folder(workspace_folder)
  workspace_folder = workspace_folder
    or npcall(vim.fn.input, 'Workspace Folder: ', vim.fn.expand('%:p:h'))
  api.nvim_command('redraw')
  if not (workspace_folder and #workspace_folder > 0) then
    return
  end
  local params = util.make_workspace_params(
    { {} },
    { { uri = vim.uri_from_fname(workspace_folder), name = workspace_folder } }
  )
  for _, client in pairs(vim.lsp.buf_get_clients()) do
    for idx, folder in pairs(client.workspace_folders) do
      if folder.name == workspace_folder then
        vim.lsp.buf_notify(0, 'workspace/didChangeWorkspaceFolders', params)
        client.workspace_folders[idx] = nil
        return
      end
    end
  end
  print(workspace_folder, 'is not currently part of the workspace')
end

--- Lists all symbols in the current workspace in the quickfix window.
---
--- The list is filtered against {query}; if the argument is omitted from the
--- call, the user is prompted to enter a string on the command line. An empty
--- string means no filtering is done.
---
---@param query (string, optional)
---@param options table|nil additional options
---     - on_list: (function) handler for list results. See |on-list-handler|
function M.workspace_symbol(query, options)
  query = query or npcall(vim.fn.input, 'Query: ')
  if query == nil then
    return
  end
  local params = { query = query }
  request_with_options('workspace/symbol', params, options)
end

--- Send request to the server to resolve document highlights for the current
--- text document position. This request can be triggered by a  key mapping or
--- by events such as `CursorHold`, e.g.:
---
--- <pre>
--- autocmd CursorHold  <buffer> lua vim.lsp.buf.document_highlight()
--- autocmd CursorHoldI <buffer> lua vim.lsp.buf.document_highlight()
--- autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
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

---@private
--
--- This is not public because the main extension point is
--- vim.ui.select which can be overridden independently.
---
--- Can't call/use vim.lsp.handlers['textDocument/codeAction'] because it expects
--- `(err, CodeAction[] | Command[], ctx)`, but we want to aggregate the results
--- from multiple clients to have 1 single UI prompt for the user, yet we still
--- need to be able to link a `CodeAction|Command` to the right client for
--- `codeAction/resolve`
local function on_code_action_results(results, ctx, options)
  local action_tuples = {}

  ---@private
  local function action_filter(a)
    -- filter by specified action kind
    if options and options.context and options.context.only then
      if not a.kind then
        return false
      end
      local found = false
      for _, o in ipairs(options.context.only) do
        -- action kinds are hierarchical with . as a separator: when requesting only
        -- 'quickfix' this filter allows both 'quickfix' and 'quickfix.foo', for example
        if a.kind:find('^' .. o .. '$') or a.kind:find('^' .. o .. '%.') then
          found = true
          break
        end
      end
      if not found then
        return false
      end
    end
    -- filter by user function
    if options and options.filter and not options.filter(a) then
      return false
    end
    -- no filter removed this action
    return true
  end

  for client_id, result in pairs(results) do
    for _, action in pairs(result.result or {}) do
      if action_filter(action) then
        table.insert(action_tuples, { client_id, action })
      end
    end
  end
  if #action_tuples == 0 then
    vim.notify('No code actions available', vim.log.levels.INFO)
    return
  end

  ---@private
  local function apply_action(action, client)
    if action.edit then
      util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    if action.command then
      local command = type(action.command) == 'table' and action.command or action
      local fn = client.commands[command.command] or vim.lsp.commands[command.command]
      if fn then
        local enriched_ctx = vim.deepcopy(ctx)
        enriched_ctx.client_id = client.id
        fn(command, enriched_ctx)
      else
        -- Not using command directly to exclude extra properties,
        -- see https://github.com/python-lsp/python-lsp-server/issues/146
        local params = {
          command = command.command,
          arguments = command.arguments,
          workDoneToken = command.workDoneToken,
        }
        client.request('workspace/executeCommand', params, nil, ctx.bufnr)
      end
    end
  end

  ---@private
  local function on_user_choice(action_tuple)
    if not action_tuple then
      return
    end
    -- textDocument/codeAction can return either Command[] or CodeAction[]
    --
    -- CodeAction
    --  ...
    --  edit?: WorkspaceEdit    -- <- must be applied before command
    --  command?: Command
    --
    -- Command:
    --  title: string
    --  command: string
    --  arguments?: any[]
    --
    local client = vim.lsp.get_client_by_id(action_tuple[1])
    local action = action_tuple[2]
    if
      not action.edit
      and client
      and vim.tbl_get(client.server_capabilities, 'codeActionProvider', 'resolveProvider')
    then
      client.request('codeAction/resolve', action, function(err, resolved_action)
        if err then
          vim.notify(err.code .. ': ' .. err.message, vim.log.levels.ERROR)
          return
        end
        apply_action(resolved_action, client)
      end)
    else
      apply_action(action, client)
    end
  end

  -- If options.apply is given, and there are just one remaining code action,
  -- apply it directly without querying the user.
  if options and options.apply and #action_tuples == 1 then
    on_user_choice(action_tuples[1])
    return
  end

  vim.ui.select(action_tuples, {
    prompt = 'Code actions:',
    kind = 'codeaction',
    format_item = function(action_tuple)
      local title = action_tuple[2].title:gsub('\r\n', '\\r\\n')
      return title:gsub('\n', '\\n')
    end,
  }, on_user_choice)
end

--- Requests code actions from all clients and calls the handler exactly once
--- with all aggregated results
---@private
local function code_action_request(params, options)
  local bufnr = api.nvim_get_current_buf()
  local method = 'textDocument/codeAction'
  vim.lsp.buf_request_all(bufnr, method, params, function(results)
    local ctx = { bufnr = bufnr, method = method, params = params }
    on_code_action_results(results, ctx, options)
  end)
end

--- Selects a code action available at the current
--- cursor position.
---
---@param options table|nil Optional table which holds the following optional fields:
---  - context: (table|nil)
---      Corresponds to `CodeActionContext` of the LSP specification:
---        - diagnostics (table|nil):
---                      LSP `Diagnostic[]`. Inferred from the current
---                      position if not provided.
---        - only (table|nil):
---               List of LSP `CodeActionKind`s used to filter the code actions.
---               Most language servers support values like `refactor`
---               or `quickfix`.
---  - filter: (function|nil)
---           Predicate taking an `CodeAction` and returning a boolean.
---  - apply: (boolean|nil)
---           When set to `true`, and there is just one remaining action
---          (after filtering), the action is applied without user query.
---
---  - range: (table|nil)
---           Range for which code actions should be requested.
---           If in visual mode this defaults to the active selection.
---           Table must contain `start` and `end` keys with {row, col} tuples
---           using mark-like indexing. See |api-indexing|
---
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
function M.code_action(options)
  validate({ options = { options, 't', true } })
  options = options or {}
  -- Detect old API call code_action(context) which should now be
  -- code_action({ context = context} )
  if options.diagnostics or options.only then
    options = { options = options }
  end
  local context = options.context or {}
  if not context.diagnostics then
    local bufnr = api.nvim_get_current_buf()
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
  end
  local params
  local mode = api.nvim_get_mode().mode
  if options.range then
    assert(type(options.range) == 'table', 'code_action range must be a table')
    local start = assert(options.range.start, 'range must have a `start` property')
    local end_ = assert(options.range['end'], 'range must have a `end` property')
    params = util.make_given_range_params(start, end_)
  elseif mode == 'v' or mode == 'V' then
    -- [bufnum, lnum, col, off]; both row and column 1-indexed
    local start = vim.fn.getpos('v')
    local end_ = vim.fn.getpos('.')
    local start_row = start[2]
    local start_col = start[3]
    local end_row = end_[2]
    local end_col = end_[3]

    -- A user can start visual selection at the end and move backwards
    -- Normalize the range to start < end
    if start_row == end_row and end_col < start_col then
      end_col, start_col = start_col, end_col
    elseif end_row < start_row then
      start_row, end_row = end_row, start_row
      start_col, end_col = end_col, start_col
    end
    params = util.make_given_range_params({ start_row, start_col - 1 }, { end_row, end_col - 1 })
  else
    params = util.make_range_params()
  end
  params.context = context
  code_action_request(params, options)
end

--- Performs |vim.lsp.buf.code_action()| for a given range.
---
---
---@param context table|nil `CodeActionContext` of the LSP specification:
---               - diagnostics: (table|nil)
---                             LSP `Diagnostic[]`. Inferred from the current
---                             position if not provided.
---               - only: (table|nil)
---                      List of LSP `CodeActionKind`s used to filter the code actions.
---                      Most language servers support values like `refactor`
---                      or `quickfix`.
---@param start_pos ({number, number}, optional) mark-indexed position.
---Defaults to the start of the last visual selection.
---@param end_pos ({number, number}, optional) mark-indexed position.
---Defaults to the end of the last visual selection.
function M.range_code_action(context, start_pos, end_pos)
  vim.deprecate('vim.lsp.buf.range_code_action', 'vim.lsp.buf.code_action', '0.9.0')
  validate({ context = { context, 't', true } })
  context = context or {}
  if not context.diagnostics then
    local bufnr = api.nvim_get_current_buf()
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
  end
  local params = util.make_given_range_params(start_pos, end_pos)
  params.context = context
  code_action_request(params)
end

--- Executes an LSP server command.
---
---@param command_params table A valid `ExecuteCommandParams` object
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_executeCommand
function M.execute_command(command_params)
  validate({
    command = { command_params.command, 's' },
    arguments = { command_params.arguments, 't', true },
  })
  command_params = {
    command = command_params.command,
    arguments = command_params.arguments,
    workDoneToken = command_params.workDoneToken,
  }
  request('workspace/executeCommand', command_params)
end

return M
-- vim:sw=2 ts=2 et
