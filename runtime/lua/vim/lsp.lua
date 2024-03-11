local api = vim.api
local tbl_isempty, tbl_extend = vim.tbl_isempty, vim.tbl_extend
local validate = vim.validate
local if_nil = vim.F.if_nil

local lsp = vim._defer_require('vim.lsp', {
  _changetracking = ..., --- @module 'vim.lsp._changetracking'
  _completion = ..., --- @module 'vim.lsp._completion'
  _dynamic = ..., --- @module 'vim.lsp._dynamic'
  _snippet_grammar = ..., --- @module 'vim.lsp._snippet_grammar'
  _tagfunc = ..., --- @module 'vim.lsp._tagfunc'
  _watchfiles = ..., --- @module 'vim.lsp._watchfiles'
  buf = ..., --- @module 'vim.lsp.buf'
  client = ..., --- @module 'vim.lsp.client'
  codelens = ..., --- @module 'vim.lsp.codelens'
  diagnostic = ..., --- @module 'vim.lsp.diagnostic'
  handlers = ..., --- @module 'vim.lsp.handlers'
  inlay_hint = ..., --- @module 'vim.lsp.inlay_hint'
  log = ..., --- @module 'vim.lsp.log'
  protocol = ..., --- @module 'vim.lsp.protocol'
  rpc = ..., --- @module 'vim.lsp.rpc'
  semantic_tokens = ..., --- @module 'vim.lsp.semantic_tokens'
  util = ..., --- @module 'vim.lsp.util'
})

local log = lsp.log
local protocol = lsp.protocol
local ms = protocol.Methods
local util = lsp.util
local changetracking = lsp._changetracking

-- Export these directly from rpc.
---@nodoc
lsp.rpc_response_error = lsp.rpc.rpc_response_error

-- maps request name to the required server_capability in the client.
lsp._request_name_to_capability = {
  [ms.textDocument_hover] = { 'hoverProvider' },
  [ms.textDocument_signatureHelp] = { 'signatureHelpProvider' },
  [ms.textDocument_definition] = { 'definitionProvider' },
  [ms.textDocument_implementation] = { 'implementationProvider' },
  [ms.textDocument_declaration] = { 'declarationProvider' },
  [ms.textDocument_typeDefinition] = { 'typeDefinitionProvider' },
  [ms.textDocument_documentSymbol] = { 'documentSymbolProvider' },
  [ms.textDocument_prepareCallHierarchy] = { 'callHierarchyProvider' },
  [ms.callHierarchy_incomingCalls] = { 'callHierarchyProvider' },
  [ms.callHierarchy_outgoingCalls] = { 'callHierarchyProvider' },
  [ms.textDocument_rename] = { 'renameProvider' },
  [ms.textDocument_prepareRename] = { 'renameProvider', 'prepareProvider' },
  [ms.textDocument_codeAction] = { 'codeActionProvider' },
  [ms.textDocument_codeLens] = { 'codeLensProvider' },
  [ms.codeLens_resolve] = { 'codeLensProvider', 'resolveProvider' },
  [ms.codeAction_resolve] = { 'codeActionProvider', 'resolveProvider' },
  [ms.workspace_executeCommand] = { 'executeCommandProvider' },
  [ms.workspace_symbol] = { 'workspaceSymbolProvider' },
  [ms.textDocument_references] = { 'referencesProvider' },
  [ms.textDocument_rangeFormatting] = { 'documentRangeFormattingProvider' },
  [ms.textDocument_formatting] = { 'documentFormattingProvider' },
  [ms.textDocument_completion] = { 'completionProvider' },
  [ms.textDocument_documentHighlight] = { 'documentHighlightProvider' },
  [ms.textDocument_semanticTokens_full] = { 'semanticTokensProvider' },
  [ms.textDocument_semanticTokens_full_delta] = { 'semanticTokensProvider' },
  [ms.textDocument_inlayHint] = { 'inlayHintProvider' },
  [ms.textDocument_diagnostic] = { 'diagnosticProvider' },
  [ms.inlayHint_resolve] = { 'inlayHintProvider', 'resolveProvider' },
}

-- TODO improve handling of scratch buffers with LSP attached.

--- Returns the buffer number for the given {bufnr}.
---
---@param bufnr (integer|nil) Buffer number to resolve. Defaults to current buffer
---@return integer bufnr
local function resolve_bufnr(bufnr)
  validate({ bufnr = { bufnr, 'n', true } })
  if bufnr == nil or bufnr == 0 then
    return api.nvim_get_current_buf()
  end
  return bufnr
end

---@private
--- Called by the client when trying to call a method that's not
--- supported in any of the servers registered for the current buffer.
---@param method (string) name of the method
function lsp._unsupported_method(method)
  local msg = string.format(
    'method %s is not supported by any of the servers registered for the current buffer',
    method
  )
  log.warn(msg)
  return msg
end

local wait_result_reason = { [-1] = 'timeout', [-2] = 'interrupted', [-3] = 'error' }

local format_line_ending = {
  ['unix'] = '\n',
  ['dos'] = '\r\n',
  ['mac'] = '\r',
}

---@private
---@param bufnr (number)
---@return string
function lsp._buf_get_line_ending(bufnr)
  return format_line_ending[vim.bo[bufnr].fileformat] or '\n'
end

-- Tracks all clients created via lsp.start_client
local active_clients = {} --- @type table<integer,vim.lsp.Client>
local all_buffer_active_clients = {} --- @type table<integer,table<integer,true>>
local uninitialized_clients = {} --- @type table<integer,vim.lsp.Client>

---@param bufnr? integer
---@param fn fun(client: vim.lsp.Client, client_id: integer, bufnr: integer)
local function for_each_buffer_client(bufnr, fn, restrict_client_ids)
  validate({
    fn = { fn, 'f' },
    restrict_client_ids = { restrict_client_ids, 't', true },
  })
  bufnr = resolve_bufnr(bufnr)
  local client_ids = all_buffer_active_clients[bufnr]
  if not client_ids or tbl_isempty(client_ids) then
    return
  end

  if restrict_client_ids and #restrict_client_ids > 0 then
    local filtered_client_ids = {} --- @type table<integer,true>
    for client_id in pairs(client_ids) do
      if vim.list_contains(restrict_client_ids, client_id) then
        filtered_client_ids[client_id] = true
      end
    end
    client_ids = filtered_client_ids
  end

  for client_id in pairs(client_ids) do
    local client = active_clients[client_id]
    if client then
      fn(client, client_id, bufnr)
    end
  end
end

local client_errors_base = table.maxn(lsp.rpc.client_errors)
local client_errors_offset = 0

local function client_error(name)
  client_errors_offset = client_errors_offset + 1
  local index = client_errors_base + client_errors_offset
  return { [name] = index, [index] = name }
end

--- Error codes to be used with `on_error` from |vim.lsp.start_client|.
--- Can be used to look up the string from a the number or the number
--- from the string.
--- @nodoc
lsp.client_errors = tbl_extend(
  'error',
  lsp.rpc.client_errors,
  client_error('BEFORE_INIT_CALLBACK_ERROR'),
  client_error('ON_INIT_CALLBACK_ERROR'),
  client_error('ON_ATTACH_ERROR'),
  client_error('ON_EXIT_CALLBACK_ERROR')
)

---@private
--- Returns full text of buffer {bufnr} as a string.
---
---@param bufnr (number) Buffer handle, or 0 for current.
---@return string # Buffer text as string.
function lsp._buf_get_full_text(bufnr)
  local line_ending = lsp._buf_get_line_ending(bufnr)
  local text = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, true), line_ending)
  if vim.bo[bufnr].eol then
    text = text .. line_ending
  end
  return text
end

--- Memoizes a function. On first run, the function return value is saved and
--- immediately returned on subsequent runs. If the function returns a multival,
--- only the first returned value will be memoized and returned. The function will only be run once,
--- even if it has side effects.
---
---@generic T: function
---@param fn (T) Function to run
---@return T
local function once(fn)
  local value --- @type function
  local ran = false
  return function(...)
    if not ran then
      value = fn(...) --- @type function
      ran = true
    end
    return value
  end
end

--- @class vim.lsp.start.Opts
--- @inlinedoc
---
--- Predicate used to decide if a client should be re-used. Used on all
--- running clients. The default implementation re-uses a client if name and
--- root_dir matches.
--- @field reuse_client fun(client: vim.lsp.Client, config: table): boolean
---
--- Buffer handle to attach to if starting or re-using a client (0 for current).
--- @field bufnr integer

--- Create a new LSP client and start a language server or reuses an already
--- running client if one is found matching `name` and `root_dir`.
--- Attaches the current buffer to the client.
---
--- Example:
---
--- ```lua
--- vim.lsp.start({
---    name = 'my-server-name',
---    cmd = {'name-of-language-server-executable'},
---    root_dir = vim.fs.dirname(vim.fs.find({'pyproject.toml', 'setup.py'}, { upward = true })[1]),
--- })
--- ```
---
--- See |vim.lsp.start_client()| for all available options. The most important are:
---
--- - `name` arbitrary name for the LSP client. Should be unique per language server.
--- - `cmd` command string[] or function, described at |vim.lsp.start_client()|.
--- - `root_dir` path to the project root. By default this is used to decide if an existing client
---   should be re-used. The example above uses |vim.fs.find()| and |vim.fs.dirname()| to detect the
---   root by traversing the file system upwards starting from the current directory until either
---   a `pyproject.toml` or `setup.py` file is found.
--- - `workspace_folders` list of `{ uri:string, name: string }` tables specifying the project root
---   folders used by the language server. If `nil` the property is derived from `root_dir` for
---   convenience.
---
--- Language servers use this information to discover metadata like the
--- dependencies of your project and they tend to index the contents within the
--- project folder.
---
---
--- To ensure a language server is only started for languages it can handle,
--- make sure to call |vim.lsp.start()| within a |FileType| autocmd.
--- Either use |:au|, |nvim_create_autocmd()| or put the call in a
--- `ftplugin/<filetype_name>.lua` (See |ftplugin-name|)
---
--- @param config vim.lsp.ClientConfig Configuration for the server.
--- @param opts vim.lsp.start.Opts? Optional keyword arguments
--- @return integer? client_id
function lsp.start(config, opts)
  opts = opts or {}
  local reuse_client = opts.reuse_client
    or function(client, conf)
      return client.root_dir == conf.root_dir and client.name == conf.name
    end

  local bufnr = resolve_bufnr(opts.bufnr)

  for _, clients in ipairs({ uninitialized_clients, lsp.get_clients() }) do
    for _, client in pairs(clients) do
      if reuse_client(client, config) then
        lsp.buf_attach_client(bufnr, client.id)
        return client.id
      end
    end
  end

  local client_id = lsp.start_client(config)

  if not client_id then
    return -- lsp.start_client will have printed an error
  end

  lsp.buf_attach_client(bufnr, client_id)
  return client_id
end

--- Consumes the latest progress messages from all clients and formats them as a string.
--- Empty if there are no clients or if no new messages
---
---@return string
function lsp.status()
  local percentage = nil
  local messages = {} --- @type string[]
  for _, client in ipairs(vim.lsp.get_clients()) do
    --- @diagnostic disable-next-line:no-unknown
    for progress in client.progress do
      --- @cast progress {token: lsp.ProgressToken, value: lsp.LSPAny}
      local value = progress.value
      if type(value) == 'table' and value.kind then
        local message = value.message and (value.title .. ': ' .. value.message) or value.title
        messages[#messages + 1] = message
        if value.percentage then
          percentage = math.max(percentage or 0, value.percentage)
        end
      end
      -- else: Doesn't look like work done progress and can be in any format
      -- Just ignore it as there is no sensible way to display it
    end
  end
  local message = table.concat(messages, ', ')
  if percentage then
    return string.format('%3d%%: %s', percentage, message)
  end
  return message
end

-- Determines whether the given option can be set by `set_defaults`.
---@param bufnr integer
---@param option string
---@return boolean
local function is_empty_or_default(bufnr, option)
  if vim.bo[bufnr][option] == '' then
    return true
  end

  local info = api.nvim_get_option_info2(option, { buf = bufnr })
  local scriptinfo = vim.tbl_filter(function(e)
    return e.sid == info.last_set_sid
  end, vim.fn.getscriptinfo())

  if #scriptinfo ~= 1 then
    return false
  end

  return vim.startswith(scriptinfo[1].name, vim.fn.expand('$VIMRUNTIME'))
end

---@private
---@param client vim.lsp.Client
---@param bufnr integer
function lsp._set_defaults(client, bufnr)
  if
    client.supports_method(ms.textDocument_definition) and is_empty_or_default(bufnr, 'tagfunc')
  then
    vim.bo[bufnr].tagfunc = 'v:lua.vim.lsp.tagfunc'
  end
  if
    client.supports_method(ms.textDocument_completion) and is_empty_or_default(bufnr, 'omnifunc')
  then
    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
  end
  if
    client.supports_method(ms.textDocument_rangeFormatting)
    and is_empty_or_default(bufnr, 'formatprg')
    and is_empty_or_default(bufnr, 'formatexpr')
  then
    vim.bo[bufnr].formatexpr = 'v:lua.vim.lsp.formatexpr()'
  end
  api.nvim_buf_call(bufnr, function()
    if
      client.supports_method(ms.textDocument_hover)
      and is_empty_or_default(bufnr, 'keywordprg')
      and vim.fn.maparg('K', 'n', false, false) == ''
    then
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = bufnr })
    end
  end)
  if client.supports_method(ms.textDocument_diagnostic) then
    lsp.diagnostic._enable(bufnr)
  end
end

--- Reset defaults set by `set_defaults`.
--- Must only be called if the last client attached to a buffer exits.
local function reset_defaults(bufnr)
  if vim.bo[bufnr].tagfunc == 'v:lua.vim.lsp.tagfunc' then
    vim.bo[bufnr].tagfunc = nil
  end
  if vim.bo[bufnr].omnifunc == 'v:lua.vim.lsp.omnifunc' then
    vim.bo[bufnr].omnifunc = nil
  end
  if vim.bo[bufnr].formatexpr == 'v:lua.vim.lsp.formatexpr()' then
    vim.bo[bufnr].formatexpr = nil
  end
  api.nvim_buf_call(bufnr, function()
    local keymap = vim.fn.maparg('K', 'n', false, true)
    if keymap and keymap.callback == vim.lsp.buf.hover then
      vim.keymap.del('n', 'K', { buffer = bufnr })
    end
  end)
end

--- @param client vim.lsp.Client
local function on_client_init(client)
  local id = client.id
  uninitialized_clients[id] = nil
  -- Only assign after initialized.
  active_clients[id] = client
  -- If we had been registered before we start, then send didOpen This can
  -- happen if we attach to buffers before initialize finishes or if
  -- someone restarts a client.
  for bufnr, client_ids in pairs(all_buffer_active_clients) do
    if client_ids[id] then
      client.on_attach(bufnr)
    end
  end
end

--- @param code integer
--- @param signal integer
--- @param client_id integer
local function on_client_exit(code, signal, client_id)
  local client = active_clients[client_id] or uninitialized_clients[client_id]

  for bufnr, client_ids in pairs(all_buffer_active_clients) do
    if client_ids[client_id] then
      vim.schedule(function()
        if client and client.attached_buffers[bufnr] then
          api.nvim_exec_autocmds('LspDetach', {
            buffer = bufnr,
            modeline = false,
            data = { client_id = client_id },
          })
        end

        local namespace = vim.lsp.diagnostic.get_namespace(client_id)
        vim.diagnostic.reset(namespace, bufnr)

        client_ids[client_id] = nil
        if vim.tbl_isempty(client_ids) then
          reset_defaults(bufnr)
        end
      end)
    end
  end

  local name = client.name or 'unknown'

  -- Schedule the deletion of the client object so that it exists in the execution of LspDetach
  -- autocommands
  vim.schedule(function()
    active_clients[client_id] = nil
    uninitialized_clients[client_id] = nil

    -- Client can be absent if executable starts, but initialize fails
    -- init/attach won't have happened
    if client then
      changetracking.reset(client)
    end
    if code ~= 0 or (signal ~= 0 and signal ~= 15) then
      local msg = string.format(
        'Client %s quit with exit code %s and signal %s. Check log for errors: %s',
        name,
        code,
        signal,
        lsp.get_log_path()
      )
      vim.notify(msg, vim.log.levels.WARN)
    end
  end)
end

--- Starts and initializes a client with the given configuration.
--- @param config vim.lsp.ClientConfig Configuration for the server.
--- @return integer|nil client_id |vim.lsp.get_client_by_id()| Note: client may not be
--- fully initialized. Use `on_init` to do any actions once
--- the client has been initialized.
function lsp.start_client(config)
  local client = require('vim.lsp.client').create(config)

  if not client then
    return
  end

  --- @diagnostic disable-next-line: invisible
  table.insert(client._on_init_cbs, on_client_init)
  --- @diagnostic disable-next-line: invisible
  table.insert(client._on_exit_cbs, on_client_exit)

  -- Store the uninitialized_clients for cleanup in case we exit before initialize finishes.
  uninitialized_clients[client.id] = client

  client:initialize()

  return client.id
end

--- Notify all attached clients that a buffer has changed.
---@param _ integer
---@param bufnr integer
---@param changedtick integer
---@param firstline integer
---@param lastline integer
---@param new_lastline integer
---@return true?
local function text_document_did_change_handler(
  _,
  bufnr,
  changedtick,
  firstline,
  lastline,
  new_lastline
)
  -- Detach (nvim_buf_attach) via returning True to on_lines if no clients are attached
  if tbl_isempty(all_buffer_active_clients[bufnr] or {}) then
    return true
  end
  util.buf_versions[bufnr] = changedtick
  changetracking.send_changes(bufnr, firstline, lastline, new_lastline)
end

---Buffer lifecycle handler for textDocument/didSave
--- @param bufnr integer
local function text_document_did_save_handler(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  local text = once(lsp._buf_get_full_text)
  for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
    local name = api.nvim_buf_get_name(bufnr)
    local old_name = changetracking._get_and_set_name(client, bufnr, name)
    if old_name and name ~= old_name then
      client.notify(ms.textDocument_didClose, {
        textDocument = {
          uri = vim.uri_from_fname(old_name),
        },
      })
      client.notify(ms.textDocument_didOpen, {
        textDocument = {
          version = 0,
          uri = uri,
          languageId = client.get_language_id(bufnr, vim.bo[bufnr].filetype),
          text = lsp._buf_get_full_text(bufnr),
        },
      })
      util.buf_versions[bufnr] = 0
    end
    local save_capability = vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'save')
    if save_capability then
      local included_text --- @type string?
      if type(save_capability) == 'table' and save_capability.includeText then
        included_text = text(bufnr)
      end
      client.notify(ms.textDocument_didSave, {
        textDocument = {
          uri = uri,
        },
        text = included_text,
      })
    end
  end
end

--- Implements the `textDocument/did…` notifications required to track a buffer
--- for any language server.
---
--- Without calling this, the server won't be notified of changes to a buffer.
---
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client_id (integer) Client id
---@return boolean success `true` if client was attached successfully; `false` otherwise
function lsp.buf_attach_client(bufnr, client_id)
  validate({
    bufnr = { bufnr, 'n', true },
    client_id = { client_id, 'n' },
  })
  bufnr = resolve_bufnr(bufnr)
  if not api.nvim_buf_is_loaded(bufnr) then
    log.warn(string.format('buf_attach_client called on unloaded buffer (id: %d): ', bufnr))
    return false
  end
  local buffer_client_ids = all_buffer_active_clients[bufnr]
  -- This is our first time attaching to this buffer.
  if not buffer_client_ids then
    buffer_client_ids = {}
    all_buffer_active_clients[bufnr] = buffer_client_ids

    local uri = vim.uri_from_bufnr(bufnr)
    local augroup = ('lsp_c_%d_b_%d_save'):format(client_id, bufnr)
    local group = api.nvim_create_augroup(augroup, { clear = true })
    api.nvim_create_autocmd('BufWritePre', {
      group = group,
      buffer = bufnr,
      desc = 'vim.lsp: textDocument/willSave',
      callback = function(ctx)
        for _, client in ipairs(lsp.get_clients({ bufnr = ctx.buf })) do
          local params = {
            textDocument = {
              uri = uri,
            },
            reason = protocol.TextDocumentSaveReason.Manual,
          }
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'willSave') then
            client.notify(ms.textDocument_willSave, params)
          end
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'willSaveWaitUntil') then
            local result, err =
              client.request_sync(ms.textDocument_willSaveWaitUntil, params, 1000, ctx.buf)
            if result and result.result then
              util.apply_text_edits(result.result, ctx.buf, client.offset_encoding)
            elseif err then
              log.error(vim.inspect(err))
            end
          end
        end
      end,
    })
    api.nvim_create_autocmd('BufWritePost', {
      group = group,
      buffer = bufnr,
      desc = 'vim.lsp: textDocument/didSave handler',
      callback = function(ctx)
        text_document_did_save_handler(ctx.buf)
      end,
    })
    -- First time, so attach and set up stuff.
    api.nvim_buf_attach(bufnr, false, {
      on_lines = text_document_did_change_handler,
      on_reload = function()
        local params = { textDocument = { uri = uri } }
        for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
          changetracking.reset_buf(client, bufnr)
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
            client.notify(ms.textDocument_didClose, params)
          end
          client:_text_document_did_open_handler(bufnr)
        end
      end,
      on_detach = function()
        local params = { textDocument = { uri = uri } }
        for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
          changetracking.reset_buf(client, bufnr)
          if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
            client.notify(ms.textDocument_didClose, params)
          end
          client.attached_buffers[bufnr] = nil
        end
        util.buf_versions[bufnr] = nil
        all_buffer_active_clients[bufnr] = nil
      end,
      -- TODO if we know all of the potential clients ahead of time, then we
      -- could conditionally set this.
      --      utf_sizes = size_index > 1;
      utf_sizes = true,
    })
  end

  if buffer_client_ids[client_id] then
    return true
  end
  -- This is our first time attaching this client to this buffer.
  buffer_client_ids[client_id] = true

  local client = active_clients[client_id]
  -- Send didOpen for the client if it is initialized. If it isn't initialized
  -- then it will send didOpen on initialize.
  if client then
    client:_on_attach(bufnr)
  end
  return true
end

--- Detaches client from the specified buffer.
--- Note: While the server is notified that the text document (buffer)
--- was closed, it is still able to send notifications should it ignore this notification.
---
---@param bufnr integer Buffer handle, or 0 for current
---@param client_id integer Client id
function lsp.buf_detach_client(bufnr, client_id)
  validate({
    bufnr = { bufnr, 'n', true },
    client_id = { client_id, 'n' },
  })
  bufnr = resolve_bufnr(bufnr)

  local client = lsp.get_client_by_id(client_id)
  if not client or not client.attached_buffers[bufnr] then
    vim.notify(
      string.format(
        'Buffer (id: %d) is not attached to client (id: %d). Cannot detach.',
        bufnr,
        client_id
      )
    )
    return
  end

  api.nvim_exec_autocmds('LspDetach', {
    buffer = bufnr,
    modeline = false,
    data = { client_id = client_id },
  })

  changetracking.reset_buf(client, bufnr)

  if vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
    local uri = vim.uri_from_bufnr(bufnr)
    local params = { textDocument = { uri = uri } }
    client.notify(ms.textDocument_didClose, params)
  end

  client.attached_buffers[bufnr] = nil
  util.buf_versions[bufnr] = nil

  all_buffer_active_clients[bufnr][client_id] = nil
  if #vim.tbl_keys(all_buffer_active_clients[bufnr]) == 0 then
    all_buffer_active_clients[bufnr] = nil
  end

  local namespace = lsp.diagnostic.get_namespace(client_id)
  vim.diagnostic.reset(namespace, bufnr)
end

--- Checks if a buffer is attached for a particular client.
---
---@param bufnr (integer) Buffer handle, or 0 for current
---@param client_id (integer) the client id
function lsp.buf_is_attached(bufnr, client_id)
  return (all_buffer_active_clients[resolve_bufnr(bufnr)] or {})[client_id] == true
end

--- Gets a client by id, or nil if the id is invalid.
--- The returned client may not yet be fully initialized.
---
---@param client_id integer client id
---
---@return (nil|vim.lsp.Client) client rpc object
function lsp.get_client_by_id(client_id)
  return active_clients[client_id] or uninitialized_clients[client_id]
end

--- Returns list of buffers attached to client_id.
---
---@param client_id integer client id
---@return integer[] buffers list of buffer ids
function lsp.get_buffers_by_client_id(client_id)
  local client = lsp.get_client_by_id(client_id)
  return client and vim.tbl_keys(client.attached_buffers) or {}
end

--- Stops a client(s).
---
--- You can also use the `stop()` function on a |vim.lsp.Client| object.
--- To stop all clients:
---
--- ```lua
--- vim.lsp.stop_client(vim.lsp.get_clients())
--- ```
---
--- By default asks the server to shutdown, unless stop was requested
--- already for this client, then force-shutdown is attempted.
---
---@param client_id integer|vim.lsp.Client id or |vim.lsp.Client| object, or list thereof
---@param force boolean|nil shutdown forcefully
function lsp.stop_client(client_id, force)
  local ids = type(client_id) == 'table' and client_id or { client_id }
  for _, id in ipairs(ids) do
    if type(id) == 'table' and id.stop ~= nil then
      id.stop(force)
    elseif active_clients[id] then
      active_clients[id].stop(force)
    elseif uninitialized_clients[id] then
      uninitialized_clients[id].stop(true)
    end
  end
end

--- Key-value pairs used to filter the returned clients.
--- @class vim.lsp.get_clients.Filter
--- @inlinedoc
---
--- Only return clients with the given id
--- @field id? integer
---
--- Only return clients attached to this buffer
--- @field bufnr? integer
---
--- Only return clients with the given name
--- @field name? string
---
--- Only return clients supporting the given method
--- @field method? string

--- Get active clients.
---
---@param filter? vim.lsp.get_clients.Filter
---@return vim.lsp.Client[]: List of |vim.lsp.Client| objects
function lsp.get_clients(filter)
  validate({ filter = { filter, 't', true } })

  filter = filter or {}

  local clients = {} --- @type vim.lsp.Client[]

  local t = filter.bufnr and (all_buffer_active_clients[resolve_bufnr(filter.bufnr)] or {})
    or active_clients
  for client_id in pairs(t) do
    local client = active_clients[client_id]
    if
      client
      and (filter.id == nil or client.id == filter.id)
      and (filter.name == nil or client.name == filter.name)
      and (filter.method == nil or client.supports_method(filter.method, { bufnr = filter.bufnr }))
    then
      clients[#clients + 1] = client
    end
  end
  return clients
end

---@private
---@deprecated
function lsp.get_active_clients(filter)
  vim.deprecate('vim.lsp.get_active_clients()', 'vim.lsp.get_clients()', '0.12')
  return lsp.get_clients(filter)
end

api.nvim_create_autocmd('VimLeavePre', {
  desc = 'vim.lsp: exit handler',
  callback = function()
    log.info('exit_handler', active_clients)
    for _, client in pairs(uninitialized_clients) do
      client.stop(true)
    end
    -- TODO handle v:dying differently?
    if tbl_isempty(active_clients) then
      return
    end
    for _, client in pairs(active_clients) do
      client.stop()
    end

    local timeouts = {} --- @type table<integer,integer>
    local max_timeout = 0
    local send_kill = false

    for client_id, client in pairs(active_clients) do
      local timeout = if_nil(client.flags.exit_timeout, false)
      if timeout then
        send_kill = true
        timeouts[client_id] = timeout
        max_timeout = math.max(timeout, max_timeout)
      end
    end

    local poll_time = 50

    local function check_clients_closed()
      for client_id, timeout in pairs(timeouts) do
        timeouts[client_id] = timeout - poll_time
      end

      for client_id, _ in pairs(active_clients) do
        if timeouts[client_id] ~= nil and timeouts[client_id] > 0 then
          return false
        end
      end
      return true
    end

    if send_kill then
      if not vim.wait(max_timeout, check_clients_closed, poll_time) then
        for client_id, client in pairs(active_clients) do
          if timeouts[client_id] ~= nil then
            client.stop(true)
          end
        end
      end
    end
  end,
})

---@private
--- Sends an async request for all active clients attached to the
--- buffer.
---
---@param bufnr (integer) Buffer handle, or 0 for current.
---@param method (string) LSP method name
---@param params table|nil Parameters to send to the server
---@param handler? lsp.Handler See |lsp-handler|
---       If nil, follows resolution strategy defined in |lsp-handler-configuration|
---
---@return table<integer, integer> client_request_ids Map of client-id:request-id pairs
---for all successful requests.
---@return function _cancel_all_requests Function which can be used to
---cancel all the requests. You could instead
---iterate all clients and call their `cancel_request()` methods.
function lsp.buf_request(bufnr, method, params, handler)
  validate({
    bufnr = { bufnr, 'n', true },
    method = { method, 's' },
    handler = { handler, 'f', true },
  })

  bufnr = resolve_bufnr(bufnr)
  local method_supported = false
  local clients = lsp.get_clients({ bufnr = bufnr })
  local client_request_ids = {} --- @type table<integer,integer>
  for _, client in ipairs(clients) do
    if client.supports_method(method, { bufnr = bufnr }) then
      method_supported = true

      local request_success, request_id = client.request(method, params, handler, bufnr)
      -- This could only fail if the client shut down in the time since we looked
      -- it up and we did the request, which should be rare.
      if request_success then
        client_request_ids[client.id] = request_id
      end
    end
  end

  -- if has client but no clients support the given method, notify the user
  if next(clients) and not method_supported then
    vim.notify(lsp._unsupported_method(method), vim.log.levels.ERROR)
    vim.cmd.redraw()
    return {}, function() end
  end

  local function _cancel_all_requests()
    for client_id, request_id in pairs(client_request_ids) do
      local client = active_clients[client_id]
      client.cancel_request(request_id)
    end
  end

  return client_request_ids, _cancel_all_requests
end

--- Sends an async request for all active clients attached to the buffer and executes the `handler`
--- callback with the combined result.
---
---@param bufnr (integer) Buffer handle, or 0 for current.
---@param method (string) LSP method name
---@param params (table|nil) Parameters to send to the server
---@param handler fun(results: table<integer, {error: lsp.ResponseError, result: any}>) (function)
--- Handler called after all requests are completed. Server results are passed as
--- a `client_id:result` map.
---@return function cancel Function that cancels all requests.
function lsp.buf_request_all(bufnr, method, params, handler)
  local results = {} --- @type table<integer,{error:string, result:any}>
  local result_count = 0
  local expected_result_count = 0

  local set_expected_result_count = once(function()
    for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
      if client.supports_method(method, { bufnr = bufnr }) then
        expected_result_count = expected_result_count + 1
      end
    end
  end)

  local function _sync_handler(err, result, ctx)
    results[ctx.client_id] = { error = err, result = result }
    result_count = result_count + 1
    set_expected_result_count()

    if result_count >= expected_result_count then
      handler(results)
    end
  end

  local _, cancel = lsp.buf_request(bufnr, method, params, _sync_handler)

  return cancel
end

--- Sends a request to all server and waits for the response of all of them.
---
--- Calls |vim.lsp.buf_request_all()| but blocks Nvim while awaiting the result.
--- Parameters are the same as |vim.lsp.buf_request_all()| but the result is
--- different. Waits a maximum of {timeout_ms}.
---
---@param bufnr integer Buffer handle, or 0 for current.
---@param method string LSP method name
---@param params table? Parameters to send to the server
---@param timeout_ms integer? Maximum time in milliseconds to wait for a result.
---                           (default: `1000`)
---@return table<integer, {err: lsp.ResponseError, result: any}>? result Map of client_id:request_result.
---@return string? err On timeout, cancel, or error, `err` is a string describing the failure reason, and `result` is nil.
function lsp.buf_request_sync(bufnr, method, params, timeout_ms)
  local request_results

  local cancel = lsp.buf_request_all(bufnr, method, params, function(it)
    request_results = it
  end)

  local wait_result, reason = vim.wait(timeout_ms or 1000, function()
    return request_results ~= nil
  end, 10)

  if not wait_result then
    cancel()
    return nil, wait_result_reason[reason]
  end

  return request_results
end

--- Send a notification to a server
---@param bufnr (integer|nil) The number of the buffer
---@param method (string) Name of the request method
---@param params (any) Arguments to send to the server
---
---@return boolean success true if any client returns true; false otherwise
function lsp.buf_notify(bufnr, method, params)
  validate({
    bufnr = { bufnr, 'n', true },
    method = { method, 's' },
  })
  local resp = false
  for _, client in ipairs(lsp.get_clients({ bufnr = bufnr })) do
    if client.rpc.notify(method, params) then
      resp = true
    end
  end
  return resp
end

--- Implements 'omnifunc' compatible LSP completion.
---
---@see |complete-functions|
---@see |complete-items|
---@see |CompleteDone|
---
---@param findstart integer 0 or 1, decides behavior
---@param base integer findstart=0, text to match against
---
---@return integer|table Decided by {findstart}:
--- - findstart=0: column where the completion starts, or -2 or -3
--- - findstart=1: list of matches (actually just calls |complete()|)
function lsp.omnifunc(findstart, base)
  log.debug('omnifunc.findstart', { findstart = findstart, base = base })
  return vim.lsp._completion.omnifunc(findstart, base)
end

--- @class vim.lsp.formatexpr.Opts
--- @inlinedoc
---
--- The timeout period for the formatting request.
--- (default: 500ms).
--- @field timeout_ms integer

--- Provides an interface between the built-in client and a `formatexpr` function.
---
--- Currently only supports a single client. This can be set via
--- `setlocal formatexpr=v:lua.vim.lsp.formatexpr()` but will typically or in `on_attach`
--- via `vim.bo[bufnr].formatexpr = 'v:lua.vim.lsp.formatexpr(#{timeout_ms:250})'`.
---
---@param opts? vim.lsp.formatexpr.Opts
function lsp.formatexpr(opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or 500

  if vim.list_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    -- `formatexpr` is also called when exceeding `textwidth` in insert mode
    -- fall back to internal formatting
    return 1
  end

  local start_lnum = vim.v.lnum
  local end_lnum = start_lnum + vim.v.count - 1

  if start_lnum <= 0 or end_lnum <= 0 then
    return 0
  end
  local bufnr = api.nvim_get_current_buf()
  for _, client in pairs(lsp.get_clients({ bufnr = bufnr })) do
    if client.supports_method(ms.textDocument_rangeFormatting) then
      local params = util.make_formatting_params()
      local end_line = vim.fn.getline(end_lnum) --[[@as string]]
      local end_col = util._str_utfindex_enc(end_line, nil, client.offset_encoding)
      --- @cast params +lsp.DocumentRangeFormattingParams
      params.range = {
        start = {
          line = start_lnum - 1,
          character = 0,
        },
        ['end'] = {
          line = end_lnum - 1,
          character = end_col,
        },
      }
      local response =
        client.request_sync(ms.textDocument_rangeFormatting, params, timeout_ms, bufnr)
      if response and response.result then
        lsp.util.apply_text_edits(response.result, bufnr, client.offset_encoding)
        return 0
      end
    end
  end

  -- do not run builtin formatter.
  return 0
end

--- Provides an interface between the built-in client and 'tagfunc'.
---
--- When used with normal mode commands (e.g. |CTRL-]|) this will invoke
--- the "textDocument/definition" LSP method to find the tag under the cursor.
--- Otherwise, uses "workspace/symbol". If no results are returned from
--- any LSP servers, falls back to using built-in tags.
---
---@param pattern string Pattern used to find a workspace symbol
---@param flags string See |tag-function|
---
---@return table[] tags A list of matching tags
function lsp.tagfunc(pattern, flags)
  return vim.lsp._tagfunc(pattern, flags)
end

---Checks whether a client is stopped.
---
---@param client_id (integer)
---@return boolean stopped true if client is stopped, false otherwise.
function lsp.client_is_stopped(client_id)
  assert(client_id, 'missing client_id param')
  return active_clients[client_id] == nil and not uninitialized_clients[client_id]
end

--- Gets a map of client_id:client pairs for the given buffer, where each value
--- is a |vim.lsp.Client| object.
---
---@param bufnr (integer|nil): Buffer handle, or 0 for current
---@return table result is table of (client_id, client) pairs
---@deprecated Use |vim.lsp.get_clients()| instead.
function lsp.buf_get_clients(bufnr)
  vim.deprecate('vim.lsp.buf_get_clients()', 'vim.lsp.get_clients()', '0.12')
  local result = {} --- @type table<integer,vim.lsp.Client>
  for _, client in ipairs(lsp.get_clients({ bufnr = resolve_bufnr(bufnr) })) do
    result[client.id] = client
  end
  return result
end

--- Log level dictionary with reverse lookup as well.
---
--- Can be used to lookup the number from the name or the
--- name from the number.
--- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
--- Level numbers begin with "TRACE" at 0
--- @nodoc
lsp.log_levels = log.levels

--- Sets the global log level for LSP logging.
---
--- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
---
--- Level numbers begin with "TRACE" at 0
---
--- Use `lsp.log_levels` for reverse lookup.
---
---@see |vim.lsp.log_levels|
---
---@param level (integer|string) the case insensitive level name or number
function lsp.set_log_level(level)
  if type(level) == 'string' or type(level) == 'number' then
    log.set_level(level)
  else
    error(string.format('Invalid log level: %q', level))
  end
end

--- Gets the path of the logfile used by the LSP client.
---@return string path to log file
function lsp.get_log_path()
  return log.get_filename()
end

---@private
--- Invokes a function for each LSP client attached to a buffer.
---
---@param bufnr integer Buffer number
---@param fn function Function to run on each client attached to buffer
---                   {bufnr}. The function takes the client, client ID, and
---                   buffer number as arguments.
---@deprecated use lsp.get_clients({ bufnr = bufnr }) with regular loop
function lsp.for_each_buffer_client(bufnr, fn)
  vim.deprecate(
    'vim.lsp.for_each_buffer_client()',
    'lsp.get_clients({ bufnr = bufnr }) with regular loop',
    '0.12'
  )
  return for_each_buffer_client(bufnr, fn)
end

--- Function to manage overriding defaults for LSP handlers.
---@param handler (lsp.Handler) See |lsp-handler|
---@param override_config (table) Table containing the keys to override behavior of the {handler}
function lsp.with(handler, override_config)
  return function(err, result, ctx, config)
    return handler(err, result, ctx, vim.tbl_deep_extend('force', config or {}, override_config))
  end
end

--- Helper function to use when implementing a handler.
--- This will check that all of the keys in the user configuration
--- are valid keys and make sense to include for this handler.
---
--- Will error on invalid keys (i.e. keys that do not exist in the options)
--- @param name string
--- @param options table<string,any>
--- @param user_config table<string,any>
function lsp._with_extend(name, options, user_config)
  user_config = user_config or {}

  local resulting_config = {} --- @type table<string,any>
  for k, v in pairs(user_config) do
    if options[k] == nil then
      error(
        debug.traceback(
          string.format(
            'Invalid option for `%s`: %s. Valid options are:\n%s',
            name,
            k,
            vim.inspect(vim.tbl_keys(options))
          )
        )
      )
    end

    resulting_config[k] = v
  end

  for k, v in pairs(options) do
    if resulting_config[k] == nil then
      resulting_config[k] = v
    end
  end

  return resulting_config
end

--- Registry for client side commands.
--- This is an extension point for plugins to handle custom commands which are
--- not part of the core language server protocol specification.
---
--- The registry is a table where the key is a unique command name,
--- and the value is a function which is called if any LSP action
--- (code action, code lenses, ...) triggers the command.
---
--- If a LSP response contains a command for which no matching entry is
--- available in this registry, the command will be executed via the LSP server
--- using `workspace/executeCommand`.
---
--- The first argument to the function will be the `Command`:
---   Command
---     title: String
---     command: String
---     arguments?: any[]
---
--- The second argument is the `ctx` of |lsp-handler|
--- @type table<string,function>
lsp.commands = setmetatable({}, {
  __newindex = function(tbl, key, value)
    assert(type(key) == 'string', 'The key for commands in `vim.lsp.commands` must be a string')
    assert(type(value) == 'function', 'Command added to `vim.lsp.commands` must be a function')
    rawset(tbl, key, value)
  end,
})

return lsp
