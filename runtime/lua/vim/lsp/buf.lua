local api = vim.api
local validate = vim.validate
local util = require('vim.lsp.util')
local npcall = vim.F.npcall
local ms = require('vim.lsp.protocol').Methods

local M = {}

--- Sends an async request to all active clients attached to the current
--- buffer.
---
---@param method (string) LSP method name
---@param params (table|nil) Parameters to send to the server
---@param handler lsp.Handler? See |lsp-handler|. Follows |lsp-handler-resolution|
---
---@return table<integer, integer> client_request_ids Map of client-id:request-id pairs
---for all successful requests.
---@return function _cancel_all_requests Function which can be used to
---cancel all the requests. You could instead
---iterate all clients and call their `cancel_request()` methods.
---
---@see |vim.lsp.buf_request()|
local function request(method, params, handler)
  validate({
    method = { method, 's' },
    handler = { handler, 'f', true },
  })
  return vim.lsp.buf_request(0, method, params, handler)
end

--- Displays hover information about the symbol under the cursor in a floating
--- window. Calling the function twice will jump into the floating window.
function M.hover()
  local params = util.make_position_params()
  request(ms.textDocument_hover, params)
end

local function request_with_options(name, params, options)
  local req_handler --- @type function?
  if options then
    req_handler = function(err, result, ctx, config)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      local handler = client.handlers[name] or vim.lsp.handlers[name]
      handler(err, result, ctx, vim.tbl_extend('force', config or {}, options))
    end
  end
  request(name, params, req_handler)
end

--- @class vim.lsp.ListOpts
---
--- list-handler replacing the default handler.
--- Called for any non-empty result.
--- This table can be used with |setqflist()| or |setloclist()|. E.g.:
--- ```lua
--- local function on_list(options)
---   vim.fn.setqflist({}, ' ', options)
---   vim.cmd.cfirst()
--- end
---
--- vim.lsp.buf.definition({ on_list = on_list })
--- vim.lsp.buf.references(nil, { on_list = on_list })
--- ```
---
--- If you prefer loclist do something like this:
--- ```lua
--- local function on_list(options)
---   vim.fn.setloclist(0, {}, ' ', options)
---   vim.cmd.lopen()
--- end
--- ```
--- @field on_list? fun(t: vim.lsp.LocationOpts.OnList)

--- @class vim.lsp.LocationOpts.OnList
--- @field items table[] Structured like |setqflist-what|
--- @field title? string Title for the list.
--- @field context? table `ctx` from |lsp-handler|

--- @class vim.lsp.LocationOpts: vim.lsp.ListOpts
---
--- Jump to existing window if buffer is already open.
--- @field reuse_win? boolean

--- Jumps to the declaration of the symbol under the cursor.
--- @note Many servers do not implement this method. Generally, see |vim.lsp.buf.definition()| instead.
--- @param options? vim.lsp.LocationOpts
function M.declaration(options)
  local params = util.make_position_params()
  request_with_options(ms.textDocument_declaration, params, options)
end

--- Jumps to the definition of the symbol under the cursor.
--- @param options? vim.lsp.LocationOpts
function M.definition(options)
  local params = util.make_position_params()
  request_with_options(ms.textDocument_definition, params, options)
end

--- Jumps to the definition of the type of the symbol under the cursor.
--- @param options? vim.lsp.LocationOpts
function M.type_definition(options)
  local params = util.make_position_params()
  request_with_options(ms.textDocument_typeDefinition, params, options)
end

--- Lists all the implementations for the symbol under the cursor in the
--- quickfix window.
--- @param options? vim.lsp.LocationOpts
function M.implementation(options)
  local params = util.make_position_params()
  request_with_options(ms.textDocument_implementation, params, options)
end

--- Displays signature information about the symbol under the cursor in a
--- floating window.
function M.signature_help()
  local params = util.make_position_params()
  request(ms.textDocument_signatureHelp, params)
end

--- Retrieves the completion items at the current cursor position. Can only be
--- called in Insert mode.
---
---@param context table (context support not yet implemented) Additional information
--- about the context in which a completion was triggered (how it was triggered,
--- and by which trigger character, if applicable)
---
---@see vim.lsp.protocol.CompletionTriggerKind
function M.completion(context)
  local params = util.make_position_params()
  params.context = context
  return request(ms.textDocument_completion, params)
end

---@param bufnr integer
---@param mode "v"|"V"
---@return table {start={row,col}, end={row,col}} using (1, 0) indexing
local function range_from_selection(bufnr, mode)
  -- TODO: Use `vim.region()` instead https://github.com/neovim/neovim/pull/13896

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
  if mode == 'V' then
    start_col = 1
    local lines = api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)
    end_col = #lines[1]
  end
  return {
    ['start'] = { start_row, start_col - 1 },
    ['end'] = { end_row, end_col - 1 },
  }
end

--- @class vim.lsp.buf.format.Opts
--- @inlinedoc
---
--- Can be used to specify FormattingOptions. Some unspecified options will be
--- automatically derived from the current Nvim options.
--- See https://microsoft.github.io/language-server-protocol/specification/#formattingOptions
--- @field formatting_options? table
---
--- Time in milliseconds to block for formatting requests. No effect if async=true.
--- (default: `1000`)
--- @field timeout_ms? integer
---
--- Restrict formatting to the clients attached to the given buffer.
--- (default: current buffer)
--- @field bufnr? integer
---
--- Predicate used to filter clients. Receives a client as argument and must
--- return a boolean. Clients matching the predicate are included. Example:
--- ```lua
--- -- Never request typescript-language-server for formatting
--- vim.lsp.buf.format {
---   filter = function(client) return client.name ~= "tsserver" end
--- }
--- ```
--- @field filter? fun(client: vim.lsp.Client): boolean?
---
--- If true the method won't block.
--- Editing the buffer while formatting asynchronous can lead to unexpected
--- changes.
--- (Default: false)
--- @field async? boolean
---
--- Restrict formatting to the client with ID (client.id) matching this field.
--- @field id? integer
---
--- Restrict formatting to the client with name (client.name) matching this field.
--- @field name? string
---
--- Range to format.
--- Table must contain `start` and `end` keys with {row,col} tuples using
--- (1,0) indexing.
--- (Default: current selection in visual mode, `nil` in other modes,
--- formatting the full buffer)
--- @field range? {start:integer[],end:integer[]}

--- Formats a buffer using the attached (and optionally filtered) language
--- server clients.
---
--- @param options? vim.lsp.buf.format.Opts
function M.format(options)
  options = options or {}
  local bufnr = options.bufnr or api.nvim_get_current_buf()
  local mode = api.nvim_get_mode().mode
  local range = options.range
  if not range and mode == 'v' or mode == 'V' then
    range = range_from_selection(bufnr, mode)
  end
  local method = range and ms.textDocument_rangeFormatting or ms.textDocument_formatting

  local clients = vim.lsp.get_clients({
    id = options.id,
    bufnr = bufnr,
    name = options.name,
    method = method,
  })
  if options.filter then
    clients = vim.tbl_filter(options.filter, clients)
  end

  if #clients == 0 then
    vim.notify('[LSP] Format request failed, no matching language servers.')
  end

  --- @param client vim.lsp.Client
  --- @param params lsp.DocumentFormattingParams
  --- @return lsp.DocumentFormattingParams
  local function set_range(client, params)
    if range then
      local range_params =
        util.make_given_range_params(range.start, range['end'], bufnr, client.offset_encoding)
      params.range = range_params.range
    end
    return params
  end

  if options.async then
    local function do_format(idx, client)
      if not client then
        return
      end
      local params = set_range(client, util.make_formatting_params(options.formatting_options))
      client.request(method, params, function(...)
        local handler = client.handlers[method] or vim.lsp.handlers[method]
        handler(...)
        do_format(next(clients, idx))
      end, bufnr)
    end
    do_format(next(clients))
  else
    local timeout_ms = options.timeout_ms or 1000
    for _, client in pairs(clients) do
      local params = set_range(client, util.make_formatting_params(options.formatting_options))
      local result, err = client.request_sync(method, params, timeout_ms, bufnr)
      if result and result.result then
        util.apply_text_edits(result.result, bufnr, client.offset_encoding)
      elseif err then
        vim.notify(string.format('[LSP][%s] %s', client.name, err), vim.log.levels.WARN)
      end
    end
  end
end

--- @class vim.lsp.buf.rename.Opts
--- @inlinedoc
---
--- Predicate used to filter clients. Receives a client as argument and
--- must return a boolean. Clients matching the predicate are included.
--- @field filter? fun(client: vim.lsp.Client): boolean?
---
--- Restrict clients used for rename to ones where client.name matches
--- this field.
--- @field name? string
---
--- (default: current buffer)
--- @field bufnr? integer

--- Renames all references to the symbol under the cursor.
---
---@param new_name string|nil If not provided, the user will be prompted for a new
---                name using |vim.ui.input()|.
---@param options? vim.lsp.buf.rename.Opts Additional options:
function M.rename(new_name, options)
  options = options or {}
  local bufnr = options.bufnr or api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    name = options.name,
    -- Clients must at least support rename, prepareRename is optional
    method = ms.textDocument_rename,
  })
  if options.filter then
    clients = vim.tbl_filter(options.filter, clients)
  end

  if #clients == 0 then
    vim.notify('[LSP] Rename, no matching language servers with rename capability.')
  end

  local win = api.nvim_get_current_win()

  -- Compute early to account for cursor movements after going async
  local cword = vim.fn.expand('<cword>')

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

  local function try_use_client(idx, client)
    if not client then
      return
    end

    --- @param name string
    local function rename(name)
      local params = util.make_position_params(win, client.offset_encoding)
      params.newName = name
      local handler = client.handlers[ms.textDocument_rename]
        or vim.lsp.handlers[ms.textDocument_rename]
      client.request(ms.textDocument_rename, params, function(...)
        handler(...)
        try_use_client(next(clients, idx))
      end, bufnr)
    end

    if client.supports_method(ms.textDocument_prepareRename) then
      local params = util.make_position_params(win, client.offset_encoding)
      client.request(ms.textDocument_prepareRename, params, function(err, result)
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
        client.supports_method(ms.textDocument_rename),
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
---@param context (table|nil) Context for the request
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_references
---@param options? vim.lsp.ListOpts
function M.references(context, options)
  validate({ context = { context, 't', true } })
  local params = util.make_position_params()
  params.context = context or {
    includeDeclaration = true,
  }
  request_with_options(ms.textDocument_references, params, options)
end

--- Lists all symbols in the current buffer in the quickfix window.
--- @param options? vim.lsp.ListOpts
function M.document_symbol(options)
  local params = { textDocument = util.make_text_document_params() }
  request_with_options(ms.textDocument_documentSymbol, params, options)
end

--- @param call_hierarchy_items lsp.CallHierarchyItem[]?
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

--- @param method string
local function call_hierarchy(method)
  local params = util.make_position_params()
  --- @param result lsp.CallHierarchyItem[]?
  request(ms.textDocument_prepareCallHierarchy, params, function(err, result, ctx)
    if err then
      vim.notify(err.message, vim.log.levels.WARN)
      return
    end
    if not result then
      vim.notify('No item resolved', vim.log.levels.WARN)
      return
    end
    local call_hierarchy_item = pick_call_hierarchy_item(result)
    if not call_hierarchy_item then
      return
    end
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
--- items, the user can pick one in the |inputlist()|.
function M.incoming_calls()
  call_hierarchy(ms.callHierarchy_incomingCalls)
end

--- Lists all the items that are called by the symbol under the
--- cursor in the |quickfix| window. If the symbol can resolve to
--- multiple items, the user can pick one in the |inputlist()|.
function M.outgoing_calls()
  call_hierarchy(ms.callHierarchy_outgoingCalls)
end

--- @param method string
local function type_hierarchy(method)
  --- Merge results from multiple clients into a single table. Client-ID is preserved.
  ---
  --- @param results table<integer, {error: lsp.ResponseError, result: lsp.TypeHierarchyItem[]?}>
  local function merge_results(results)
    local merged_results = {}
    for client_id, client_result in pairs(results) do
      if client_result.error then
        vim.notify(client_result.error.message, vim.log.levels.WARN)
      elseif client_result.result then
        for _, item in pairs(client_result.result) do
          table.insert(merged_results, { client_id, item })
        end
      end
    end
    return merged_results
  end

  local bufnr = api.nvim_get_current_buf()
  local params = util.make_position_params()
  --- @param results table<integer, {error: lsp.ResponseError, result: lsp.TypeHierarchyItem[]?}>
  vim.lsp.buf_request_all(bufnr, ms.textDocument_prepareTypeHierarchy, params, function(results)
    local merged_results = merge_results(results)
    if #merged_results == 0 then
      vim.notify('No items resolved', vim.log.levels.INFO)
      return
    end

    if #merged_results == 1 then
      --- @type {integer, lsp.TypeHierarchyItem}
      local item = merged_results[1]
      local client = vim.lsp.get_client_by_id(item[1])
      if client then
        --- @type lsp.TypeHierarchyItem
        client.request(method, { item = item[2] }, nil, bufnr)
      else
        vim.notify(
          string.format('Client with id=%d disappeared during call hierarchy request', item[1]),
          vim.log.levels.WARN
        )
      end
    else
      local opts = {
        prompt = 'Select a type hierarchy item:',
        kind = 'typehierarchy',
        format_item = function(item)
          if not item[2].detail or #item[2].detail == 0 then
            return item[2].name
          end
          return string.format('%s %s', item[2].name, item[2].detail)
        end,
      }

      vim.ui.select(merged_results, opts, function(item)
        local client = vim.lsp.get_client_by_id(item[1])
        if client then
          --- @type lsp.TypeHierarchyItem
          client.request(method, { item = item[2] }, nil, bufnr)
        else
          vim.notify(
            string.format('Client with id=%d disappeared during call hierarchy request', item[1]),
            vim.log.levels.WARN
          )
        end
      end)
    end
  end)
end

--- Lists all the subtypes of the symbol under the
--- cursor in the |quickfix| window. If the symbol can resolve to
--- multiple items, the user can pick one using |vim.ui.select()|.
function M.subtypes()
  type_hierarchy(ms.typeHierarchy_subtypes)
end

--- Lists all the supertypes of the symbol under the
--- cursor in the |quickfix| window. If the symbol can resolve to
--- multiple items, the user can pick one using |vim.ui.select()|.
function M.supertypes()
  type_hierarchy(ms.typeHierarchy_supertypes)
end

--- List workspace folders.
---
function M.list_workspace_folders()
  local workspace_folders = {}
  for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
    for _, folder in pairs(client.workspace_folders or {}) do
      table.insert(workspace_folders, folder.name)
    end
  end
  return workspace_folders
end

--- Add the folder at path to the workspace folders. If {path} is
--- not provided, the user will be prompted for a path using |input()|.
--- @param workspace_folder? string
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
  local bufnr = api.nvim_get_current_buf()
  for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    client:_add_workspace_folder(workspace_folder)
  end
end

--- Remove the folder at path from the workspace folders. If
--- {path} is not provided, the user will be prompted for
--- a path using |input()|.
--- @param workspace_folder? string
function M.remove_workspace_folder(workspace_folder)
  workspace_folder = workspace_folder
    or npcall(vim.fn.input, 'Workspace Folder: ', vim.fn.expand('%:p:h'))
  api.nvim_command('redraw')
  if not workspace_folder or #workspace_folder == 0 then
    return
  end
  local bufnr = api.nvim_get_current_buf()
  for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    client:_remove_workspace_folder(workspace_folder)
  end
  print(workspace_folder, 'is not currently part of the workspace')
end

--- Lists all symbols in the current workspace in the quickfix window.
---
--- The list is filtered against {query}; if the argument is omitted from the
--- call, the user is prompted to enter a string on the command line. An empty
--- string means no filtering is done.
---
--- @param query string? optional
--- @param options? vim.lsp.ListOpts
function M.workspace_symbol(query, options)
  query = query or npcall(vim.fn.input, 'Query: ')
  if query == nil then
    return
  end
  local params = { query = query }
  request_with_options(ms.workspace_symbol, params, options)
end

--- Send request to the server to resolve document highlights for the current
--- text document position. This request can be triggered by a  key mapping or
--- by events such as `CursorHold`, e.g.:
---
--- ```vim
--- autocmd CursorHold  <buffer> lua vim.lsp.buf.document_highlight()
--- autocmd CursorHoldI <buffer> lua vim.lsp.buf.document_highlight()
--- autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
--- ```
---
--- Note: Usage of |vim.lsp.buf.document_highlight()| requires the following highlight groups
---       to be defined or you won't be able to see the actual highlights.
---         |hl-LspReferenceText|
---         |hl-LspReferenceRead|
---         |hl-LspReferenceWrite|
function M.document_highlight()
  local params = util.make_position_params()
  request(ms.textDocument_documentHighlight, params)
end

--- Removes document highlights from current buffer.
function M.clear_references()
  util.buf_clear_references()
end

---@nodoc
---@class vim.lsp.CodeActionResultEntry
---@field error? lsp.ResponseError
---@field result? (lsp.Command|lsp.CodeAction)[]
---@field ctx lsp.HandlerContext

--- @class vim.lsp.buf.code_action.Opts
--- @inlinedoc
---
--- Corresponds to `CodeActionContext` of the LSP specification:
---   - {diagnostics}? (`table`) LSP `Diagnostic[]`. Inferred from the current
---     position if not provided.
---   - {only}? (`table`) List of LSP `CodeActionKind`s used to filter the code actions.
---     Most language servers support values like `refactor`
---     or `quickfix`.
---   - {triggerKind}? (`integer`) The reason why code actions were requested.
--- @field context? lsp.CodeActionContext
---
--- Predicate taking an `CodeAction` and returning a boolean.
--- @field filter? fun(x: lsp.CodeAction|lsp.Command):boolean
---
--- When set to `true`, and there is just one remaining action
--- (after filtering), the action is applied without user query.
--- @field apply? boolean
---
--- Range for which code actions should be requested.
--- If in visual mode this defaults to the active selection.
--- Table must contain `start` and `end` keys with {row,col} tuples
--- using mark-like indexing. See |api-indexing|
--- @field range? {start: integer[], end: integer[]}

--- This is not public because the main extension point is
--- vim.ui.select which can be overridden independently.
---
--- Can't call/use vim.lsp.handlers['textDocument/codeAction'] because it expects
--- `(err, CodeAction[] | Command[], ctx)`, but we want to aggregate the results
--- from multiple clients to have 1 single UI prompt for the user, yet we still
--- need to be able to link a `CodeAction|Command` to the right client for
--- `codeAction/resolve`
---@param results table<integer, vim.lsp.CodeActionResultEntry>
---@param opts? vim.lsp.buf.code_action.Opts
local function on_code_action_results(results, opts)
  ---@param a lsp.Command|lsp.CodeAction
  local function action_filter(a)
    -- filter by specified action kind
    if opts and opts.context and opts.context.only then
      if not a.kind then
        return false
      end
      local found = false
      for _, o in ipairs(opts.context.only) do
        -- action kinds are hierarchical with . as a separator: when requesting only 'type-annotate'
        -- this filter allows both 'type-annotate' and 'type-annotate.foo', for example
        if a.kind == o or vim.startswith(a.kind, o .. '.') then
          found = true
          break
        end
      end
      if not found then
        return false
      end
    end
    -- filter by user function
    if opts and opts.filter and not opts.filter(a) then
      return false
    end
    -- no filter removed this action
    return true
  end

  ---@type {action: lsp.Command|lsp.CodeAction, ctx: lsp.HandlerContext}[]
  local actions = {}
  for _, result in pairs(results) do
    for _, action in pairs(result.result or {}) do
      if action_filter(action) then
        table.insert(actions, { action = action, ctx = result.ctx })
      end
    end
  end
  if #actions == 0 then
    vim.notify('No code actions available', vim.log.levels.INFO)
    return
  end

  ---@param action lsp.Command|lsp.CodeAction
  ---@param client vim.lsp.Client
  ---@param ctx lsp.HandlerContext
  local function apply_action(action, client, ctx)
    if action.edit then
      util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    local a_cmd = action.command
    if a_cmd then
      local command = type(a_cmd) == 'table' and a_cmd or action
      client:_exec_cmd(command, ctx)
    end
  end

  ---@param choice {action: lsp.Command|lsp.CodeAction, ctx: lsp.HandlerContext}
  local function on_user_choice(choice)
    if not choice then
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
    local client = assert(vim.lsp.get_client_by_id(choice.ctx.client_id))
    local action = choice.action
    local bufnr = assert(choice.ctx.bufnr, 'Must have buffer number')

    local reg = client.dynamic_capabilities:get(ms.textDocument_codeAction, { bufnr = bufnr })

    local supports_resolve = vim.tbl_get(reg or {}, 'registerOptions', 'resolveProvider')
      or client.supports_method(ms.codeAction_resolve)

    if not action.edit and client and supports_resolve then
      client.request(ms.codeAction_resolve, action, function(err, resolved_action)
        if err then
          if action.command then
            apply_action(action, client, choice.ctx)
          else
            vim.notify(err.code .. ': ' .. err.message, vim.log.levels.ERROR)
          end
        else
          apply_action(resolved_action, client, choice.ctx)
        end
      end, bufnr)
    else
      apply_action(action, client, choice.ctx)
    end
  end

  -- If options.apply is given, and there are just one remaining code action,
  -- apply it directly without querying the user.
  if opts and opts.apply and #actions == 1 then
    on_user_choice(actions[1])
    return
  end

  ---@param item {action: lsp.Command|lsp.CodeAction}
  local function format_item(item)
    local title = item.action.title:gsub('\r\n', '\\r\\n')
    return title:gsub('\n', '\\n')
  end
  local select_opts = {
    prompt = 'Code actions:',
    kind = 'codeaction',
    format_item = format_item,
  }
  vim.ui.select(actions, select_opts, on_user_choice)
end

--- Selects a code action available at the current
--- cursor position.
---
---@param options? vim.lsp.buf.code_action.Opts
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
---@see vim.lsp.protocol.CodeActionTriggerKind
function M.code_action(options)
  validate({ options = { options, 't', true } })
  options = options or {}
  -- Detect old API call code_action(context) which should now be
  -- code_action({ context = context} )
  --- @diagnostic disable-next-line:undefined-field
  if options.diagnostics or options.only then
    options = { options = options }
  end
  local context = options.context or {}
  if not context.triggerKind then
    context.triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked
  end
  if not context.diagnostics then
    local bufnr = api.nvim_get_current_buf()
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
  end
  local mode = api.nvim_get_mode().mode
  local bufnr = api.nvim_get_current_buf()
  local win = api.nvim_get_current_win()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_codeAction })
  local remaining = #clients
  if remaining == 0 then
    if next(vim.lsp.get_clients({ bufnr = bufnr })) then
      vim.notify(vim.lsp._unsupported_method(ms.textDocument_codeAction), vim.log.levels.WARN)
    end
    return
  end

  ---@type table<integer, vim.lsp.CodeActionResultEntry>
  local results = {}

  ---@param err? lsp.ResponseError
  ---@param result? (lsp.Command|lsp.CodeAction)[]
  ---@param ctx lsp.HandlerContext
  local function on_result(err, result, ctx)
    results[ctx.client_id] = { error = err, result = result, ctx = ctx }
    remaining = remaining - 1
    if remaining == 0 then
      on_code_action_results(results, options)
    end
  end

  for _, client in ipairs(clients) do
    ---@type lsp.CodeActionParams
    local params
    if options.range then
      assert(type(options.range) == 'table', 'code_action range must be a table')
      local start = assert(options.range.start, 'range must have a `start` property')
      local end_ = assert(options.range['end'], 'range must have a `end` property')
      params = util.make_given_range_params(start, end_, bufnr, client.offset_encoding)
    elseif mode == 'v' or mode == 'V' then
      local range = range_from_selection(bufnr, mode)
      params =
        util.make_given_range_params(range.start, range['end'], bufnr, client.offset_encoding)
    else
      params = util.make_range_params(win, client.offset_encoding)
    end
    params.context = context
    client.request(ms.textDocument_codeAction, params, on_result, bufnr)
  end
end

--- Executes an LSP server command.
--- @param command_params lsp.ExecuteCommandParams
--- @see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_executeCommand
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
  request(ms.workspace_executeCommand, command_params)
end

return M
