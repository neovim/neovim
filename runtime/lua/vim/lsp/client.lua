local uv = vim.uv
local api = vim.api
local lsp = vim.lsp
local log = lsp.log
local ms = lsp.protocol.Methods
local changetracking = lsp._changetracking

--- @class lsp.Client.Progress: vim.Ringbuf<{token: integer|string, value: any}>
--- @field pending table<lsp.ProgressToken,lsp.LSPAny>

--- @class lsp.Client
---
--- The id allocated to the client.
--- @field id integer
---
--- If a name is specified on creation, that will be used. Otherwise it is just
--- the client id. This is used for logs and messages.
--- @field name string
---
--- RPC client object, for low level interaction with the client.
--- See |vim.lsp.rpc.start()|.
--- @field rpc vim.lsp.rpc.PublicClient
---
--- The encoding used for communicating with the server. You can modify this in
--- the `config`'s `on_init` method before text is sent to the server.
--- @field offset_encoding string
---
--- The handlers used by the client as described in |lsp-handler|.
--- @field handlers table<string,lsp.Handler>
---
--- The current pending requests in flight to the server. Entries are key-value
--- pairs with the key being the request ID while the value is a table with
--- `type`, `bufnr`, and `method` key-value pairs. `type` is either "pending"
--- for an active request, or "cancel" for a cancel request. It will be
--- "complete" ephemerally while executing |LspRequest| autocmds when replies
--- are received from the server.
--- @field requests table<integer,{ type: string, bufnr: integer, method: string}>
---
--- copy of the table that was passed by the user
--- to |vim.lsp.start_client()|.
--- @field config lsp.ClientConfig
---
--- Response from the server sent on
--- initialize` describing the server's capabilities.
--- @field server_capabilities lsp.ServerCapabilities
---
--- A ring buffer (|vim.ringbuf()|) containing progress messages
--- sent by the server.
--- @field progress lsp.Client.Progress
---
--- @field initialized true?
--- @field workspace_folders lsp.WorkspaceFolder[]?
--- @field attached_buffers table<integer,true>
--- @field commands table<string,function>
--- @field private _log_prefix string
--- Track this so that we can escalate automatically if we've already tried a
--- graceful shutdown
--- @field private _graceful_shutdown_failed true?
---
--- @field dynamic_capabilities lsp.DynamicCapabilities
---
--- Sends a request to the server.
--- This is a thin wrapper around {client.rpc.request} with some additional
--- checking.
--- If {handler} is not specified,  If one is not found there, then an error
--- will occur. Returns: {status}, {[client_id]}. {status} is a boolean
--- indicating if the notification was successful. If it is `false`, then it
--- will always be `false` (the client has shutdown).
--- If {status} is `true`, the function returns {request_id} as the second
--- result. You can use this with `client.cancel_request(request_id)` to cancel
--- the request.
--- @field request fun(method: string, params: table?, handler: lsp.Handler?, bufnr: integer): boolean, integer?
---
--- Sends a request to the server and synchronously waits for the response.
--- This is a wrapper around {client.request}
--- Returns: { err=err, result=result }, a dictionary, where `err` and `result`
--- come from the |lsp-handler|. On timeout, cancel or error, returns `(nil,
--- err)` where `err` is a string describing the failure reason. If the request
--- was unsuccessful returns `nil`.
--- @field request_sync fun(method: string, params: table?, timeout_ms: integer?, bufnr: integer): {err: lsp.ResponseError|nil, result:any}|nil, string|nil err # a dictionary, where
---
--- Sends a notification to an LSP server.
--- Returns: a boolean to indicate if the notification was successful. If
--- it is false, then it will always be false (the client has shutdown).
--- @field notify fun(method: string, params: table?): boolean
---
--- Cancels a request with a given request id.
--- Returns: same as `notify()`.
--- @field cancel_request fun(id: integer): boolean
---
--- Stops a client, optionally with force.
--- By default, it will just ask the server to shutdown without force.
--- If you request to stop a client which has previously been requested to
--- shutdown, it will automatically escalate and force shutdown.
--- @field stop fun(force?: boolean)
---
--- Runs the on_attach function from the client's config if it was defined.
--- Useful for buffer-local setup.
--- @field on_attach fun(bufnr: integer)
---
--- Checks if a client supports a given method.
--- Always returns true for unknown off-spec methods.
--- [opts] is a optional `{bufnr?: integer}` table.
--- Some language server capabilities can be file specific.
--- @field supports_method fun(method: string, opts?: {bufnr: integer?}): boolean
---
--- Checks whether a client is stopped.
--- Returns: true if the client is fully stopped.
--- @field is_stopped fun(): boolean
local Client = {}
Client.__index = Client

--- @param cls table
--- @param meth any
--- @return function
local function method_wrapper(cls, meth)
  return function(...)
    return meth(cls, ...)
  end
end

--- @package
--- @param id integer
--- @param rpc vim.lsp.rpc.PublicClient
--- @param handlers table<string,lsp.Handler>
--- @param offset_encoding string
--- @param config lsp.ClientConfig
--- @return lsp.Client
function Client.new(id, rpc, handlers, offset_encoding, config)
  local name = config.name or tostring(id)

  --- @class lsp.Client
  local self = {
    id = id,
    config = config,
    handlers = handlers,
    rpc = rpc,
    offset_encoding = offset_encoding,
    name = name,
    _log_prefix = string.format('LSP[%s]', name),
    requests = {},
    commands = config.commands or {},
    attached_buffers = {},
    server_capabilities = {},
    dynamic_capabilities = vim.lsp._dynamic.new(id),

    --- Contains $/progress report messages.
    --- They have the format {token: integer|string, value: any}
    --- For "work done progress", value will be one of:
    --- - lsp.WorkDoneProgressBegin,
    --- - lsp.WorkDoneProgressReport (extended with title from Begin)
    --- - lsp.WorkDoneProgressEnd    (extended with title from Begin)
    progress = vim.ringbuf(50) --[[@as lsp.Client.Progress]],

    --- @deprecated use client.progress instead
    messages = { name = name, messages = {}, progress = {}, status = {} },
  }

  self.request = method_wrapper(self, Client._request)
  self.request_sync = method_wrapper(self, Client._request_sync)
  self.notify = method_wrapper(self, Client._notify)
  self.cancel_request = method_wrapper(self, Client._cancel_request)
  self.stop = method_wrapper(self, Client._stop)
  self.is_stopped = method_wrapper(self, Client._is_stopped)
  self.on_attach = method_wrapper(self, Client._on_attach)
  self.supports_method = method_wrapper(self, Client._supports_method)

  ---@type table<string|integer, string> title of unfinished progress sequences by token
  self.progress.pending = {}

  return setmetatable(self, Client)
end

--- @private
--- @param cb fun()
function Client:initialize(cb)
  local valid_traces = {
    off = 'off',
    messages = 'messages',
    verbose = 'verbose',
  }

  local config = self.config

  local workspace_folders --- @type lsp.WorkspaceFolder[]?
  local root_uri --- @type string?
  local root_path --- @type string?
  if config.workspace_folders or config.root_dir then
    if config.root_dir and not config.workspace_folders then
      workspace_folders = {
        {
          uri = vim.uri_from_fname(config.root_dir),
          name = string.format('%s', config.root_dir),
        },
      }
    else
      workspace_folders = config.workspace_folders
    end
    root_uri = workspace_folders[1].uri
    root_path = vim.uri_to_fname(root_uri)
  else
    workspace_folders = nil
    root_uri = nil
    root_path = nil
  end

  local initialize_params = {
    -- The process Id of the parent process that started the server. Is null if
    -- the process has not been started by another process.  If the parent
    -- process is not alive then the server should exit (see exit notification)
    -- its process.
    processId = uv.os_getpid(),
    -- Information about the client
    -- since 3.15.0
    clientInfo = {
      name = 'Neovim',
      version = tostring(vim.version()),
    },
    -- The rootPath of the workspace. Is null if no folder is open.
    --
    -- @deprecated in favour of rootUri.
    rootPath = root_path or vim.NIL,
    -- The rootUri of the workspace. Is null if no folder is open. If both
    -- `rootPath` and `rootUri` are set `rootUri` wins.
    rootUri = root_uri or vim.NIL,
    -- The workspace folders configured in the client when the server starts.
    -- This property is only available if the client supports workspace folders.
    -- It can be `null` if the client supports workspace folders but none are
    -- configured.
    workspaceFolders = workspace_folders or vim.NIL,
    -- User provided initialization options.
    initializationOptions = config.init_options,
    -- The capabilities provided by the client (editor or tool)
    capabilities = config.capabilities,
    -- The initial trace setting. If omitted trace is disabled ("off").
    -- trace = "off" | "messages" | "verbose";
    trace = valid_traces[config.trace] or 'off',
  }
  if config.before_init then
    --- @type boolean, string?
    local status, err = pcall(config.before_init, initialize_params, config)
    if not status then
      self:write_error(lsp.client_errors.BEFORE_INIT_CALLBACK_ERROR, err)
    end
  end

  log.trace(self._log_prefix, 'initialize_params', initialize_params)

  local rpc = self.rpc

  rpc.request('initialize', initialize_params, function(init_err, result)
    assert(not init_err, tostring(init_err))
    assert(result, 'server sent empty result')
    rpc.notify('initialized', vim.empty_dict())
    self.initialized = true
    self.workspace_folders = workspace_folders

    -- These are the cleaned up capabilities we use for dynamically deciding
    -- when to send certain events to clients.
    self.server_capabilities =
      assert(result.capabilities, "initialize result doesn't contain capabilities")
    self.server_capabilities = assert(lsp.protocol.resolve_capabilities(self.server_capabilities))

    if self.server_capabilities.positionEncoding then
      self.offset_encoding = self.server_capabilities.positionEncoding
    end

    if next(config.settings) then
      self:_notify(ms.workspace_didChangeConfiguration, { settings = config.settings })
    end

    if config.on_init then
      --- @type boolean, string?
      local status, err = pcall(config.on_init, self, result)
      if not status then
        self:write_error(lsp.client_errors.ON_INIT_CALLBACK_ERROR, err)
      end
    end

    log.info(
      self._log_prefix,
      'server_capabilities',
      { server_capabilities = self.server_capabilities }
    )

    cb()
  end)
end

--- @private
--- Returns the handler associated with an LSP method.
--- Returns the default handler if the user hasn't set a custom one.
---
--- @param method (string) LSP method name
--- @return lsp.Handler|nil handler for the given method, if defined, or the default from |vim.lsp.handlers|
function Client:_resolve_handler(method)
  return self.handlers[method] or lsp.handlers[method]
end

--- Returns the buffer number for the given {bufnr}.
---
--- @param bufnr (integer|nil) Buffer number to resolve. Defaults to current buffer
--- @return integer bufnr
local function resolve_bufnr(bufnr)
  vim.validate({ bufnr = { bufnr, 'n', true } })
  if bufnr == nil or bufnr == 0 then
    return api.nvim_get_current_buf()
  end
  return bufnr
end

--- @private
--- Sends a request to the server.
---
--- This is a thin wrapper around {client.rpc.request} with some additional
--- checks for capabilities and handler availability.
---
--- @param method string LSP method name.
--- @param params table|nil LSP request params.
--- @param handler lsp.Handler|nil Response |lsp-handler| for this method.
--- @param bufnr integer Buffer handle (0 for current).
--- @return boolean status, integer|nil request_id {status} is a bool indicating
--- whether the request was successful. If it is `false`, then it will
--- always be `false` (the client has shutdown). If it was
--- successful, then it will return {request_id} as the
--- second result. You can use this with `client.cancel_request(request_id)`
--- to cancel the-request.
--- @see |vim.lsp.buf_request_all()|
function Client:_request(method, params, handler, bufnr)
  if not handler then
    handler = assert(
      self:_resolve_handler(method),
      string.format('not found: %q request handler for client %q.', method, self.name)
    )
  end
  -- Ensure pending didChange notifications are sent so that the server doesn't operate on a stale state
  changetracking.flush(self, bufnr)
  local version = lsp.util.buf_versions[bufnr]
  bufnr = resolve_bufnr(bufnr)
  log.debug(self._log_prefix, 'client.request', self.id, method, params, handler, bufnr)
  local success, request_id = self.rpc.request(method, params, function(err, result)
    local context = {
      method = method,
      client_id = self.id,
      bufnr = bufnr,
      params = params,
      version = version,
    }
    handler(err, result, context)
  end, function(request_id)
    local request = self.requests[request_id]
    request.type = 'complete'
    api.nvim_exec_autocmds('LspRequest', {
      buffer = api.nvim_buf_is_valid(bufnr) and bufnr or nil,
      modeline = false,
      data = { client_id = self.id, request_id = request_id, request = request },
    })
    self.requests[request_id] = nil
  end)

  if success and request_id then
    local request = { type = 'pending', bufnr = bufnr, method = method }
    self.requests[request_id] = request
    api.nvim_exec_autocmds('LspRequest', {
      buffer = bufnr,
      modeline = false,
      data = { client_id = self.id, request_id = request_id, request = request },
    })
  end

  return success, request_id
end

-- TODO(lewis6991): duplicated from lsp.lua
local wait_result_reason = { [-1] = 'timeout', [-2] = 'interrupted', [-3] = 'error' }

-- TODO(lewis6991): duplicated from lsp.lua
--- Concatenates and writes a list of strings to the Vim error buffer.
---
---@param ... string List to write to the buffer
local function err_message(...)
  api.nvim_err_writeln(table.concat(vim.tbl_flatten({ ... })))
  api.nvim_command('redraw')
end

--- @private
--- Sends a request to the server and synchronously waits for the response.
---
--- This is a wrapper around {client.request}
---
--- @param method (string) LSP method name.
--- @param params (table) LSP request params.
--- @param timeout_ms (integer|nil) Maximum time in milliseconds to wait for
---                                a result. Defaults to 1000
--- @param bufnr (integer) Buffer handle (0 for current).
--- @return {err: lsp.ResponseError|nil, result:any}|nil, string|nil err # a dictionary, where
--- `err` and `result` come from the |lsp-handler|.
--- On timeout, cancel or error, returns `(nil, err)` where `err` is a
--- string describing the failure reason. If the request was unsuccessful
--- returns `nil`.
--- @see |vim.lsp.buf_request_sync()|
function Client:_request_sync(method, params, timeout_ms, bufnr)
  local request_result = nil
  local function _sync_handler(err, result)
    request_result = { err = err, result = result }
  end

  local success, request_id = self:_request(method, params, _sync_handler, bufnr)
  if not success then
    return nil
  end

  local wait_result, reason = vim.wait(timeout_ms or 1000, function()
    return request_result ~= nil
  end, 10)

  if not wait_result then
    if request_id then
      self:_cancel_request(request_id)
    end
    return nil, wait_result_reason[reason]
  end
  return request_result
end

--- @private
--- Sends a notification to an LSP server.
---
--- @param method string LSP method name.
--- @param params table|nil LSP request params.
--- @return boolean status true if the notification was successful.
--- If it is false, then it will always be false
--- (the client has shutdown).
function Client:_notify(method, params)
  if method ~= ms.textDocument_didChange then
    changetracking.flush(self)
  end

  local client_active = self.rpc.notify(method, params)

  if client_active then
    vim.schedule(function()
      api.nvim_exec_autocmds('LspNotify', {
        modeline = false,
        data = {
          client_id = self.id,
          method = method,
          params = params,
        },
      })
    end)
  end

  return client_active
end

--- @private
--- Cancels a request with a given request id.
---
--- @param id (integer) id of request to cancel
--- @return boolean status true if notification was successful. false otherwise
--- @see |vim.lsp.client.notify()|
function Client:_cancel_request(id)
  vim.validate({ id = { id, 'n' } })
  local request = self.requests[id]
  if request and request.type == 'pending' then
    request.type = 'cancel'
    api.nvim_exec_autocmds('LspRequest', {
      buffer = request.bufnr,
      modeline = false,
      data = { client_id = self.id, request_id = id, request = request },
    })
  end
  return self.rpc.notify(ms.dollar_cancelRequest, { id = id })
end

--- @nodoc
--- Stops a client, optionally with force.
---
--- By default, it will just ask the - server to shutdown without force. If
--- you request to stop a client which has previously been requested to
--- shutdown, it will automatically escalate and force shutdown.
---
--- @param force boolean|nil
function Client:_stop(force)
  local rpc = self.rpc

  if rpc.is_closing() then
    return
  end

  if force or not self.initialized or self._graceful_shutdown_failed then
    rpc.terminate()
    return
  end

  -- Sending a signal after a process has exited is acceptable.
  rpc.request(ms.shutdown, nil, function(err, _)
    if err == nil then
      rpc.notify(ms.exit)
    else
      -- If there was an error in the shutdown request, then term to be safe.
      rpc.terminate()
      self._graceful_shutdown_failed = true
    end
  end)
end

--- @private
--- Checks whether a client is stopped.
---
--- @return boolean # true if client is stopped or in the process of being
--- stopped; false otherwise
function Client:_is_stopped()
  return self.rpc.is_closing()
end

--- @private
--- Execute a lsp command, either via client command function (if available)
--- or via workspace/executeCommand (if supported by the server)
---
--- @param command lsp.Command
--- @param context? {bufnr: integer}
--- @param handler? lsp.Handler only called if a server command
function Client:_exec_cmd(command, context, handler)
  context = vim.deepcopy(context or {}, true) --[[@as lsp.HandlerContext]]
  context.bufnr = context.bufnr or api.nvim_get_current_buf()
  context.client_id = self.id
  local cmdname = command.command
  local fn = self.commands[cmdname] or lsp.commands[cmdname]
  if fn then
    fn(command, context)
    return
  end

  local command_provider = self.server_capabilities.executeCommandProvider
  local commands = type(command_provider) == 'table' and command_provider.commands or {}
  if not vim.list_contains(commands, cmdname) then
    vim.notify_once(
      string.format(
        'Language server `%s` does not support command `%s`. This command may require a client extension.',
        self.name,
        cmdname
      ),
      vim.log.levels.WARN
    )
    return
  end
  -- Not using command directly to exclude extra properties,
  -- see https://github.com/python-lsp/python-lsp-server/issues/146
  local params = {
    command = command.command,
    arguments = command.arguments,
  }
  self.request(ms.workspace_executeCommand, params, handler, context.bufnr)
end

--- @package
--- Default handler for the 'textDocument/didOpen' LSP notification.
---
--- @param bufnr integer Number of the buffer, or 0 for current
function Client:_text_document_did_open_handler(bufnr)
  changetracking.init(self, bufnr)
  if not vim.tbl_get(self.server_capabilities, 'textDocumentSync', 'openClose') then
    return
  end
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local filetype = vim.bo[bufnr].filetype

  local params = {
    textDocument = {
      version = 0,
      uri = vim.uri_from_bufnr(bufnr),
      languageId = self.config.get_language_id(bufnr, filetype),
      text = lsp._buf_get_full_text(bufnr),
    },
  }
  self.notify(ms.textDocument_didOpen, params)
  lsp.util.buf_versions[bufnr] = params.textDocument.version

  -- Next chance we get, we should re-do the diagnostics
  vim.schedule(function()
    -- Protect against a race where the buffer disappears
    -- between `did_open_handler` and the scheduled function firing.
    if api.nvim_buf_is_valid(bufnr) then
      local namespace = vim.lsp.diagnostic.get_namespace(self.id)
      vim.diagnostic.show(namespace, bufnr)
    end
  end)
end

--- @private
--- Runs the on_attach function from the client's config if it was defined.
--- @param bufnr integer Buffer number
function Client:_on_attach(bufnr)
  self:_text_document_did_open_handler(bufnr)

  lsp._set_defaults(self, bufnr)

  api.nvim_exec_autocmds('LspAttach', {
    buffer = bufnr,
    modeline = false,
    data = { client_id = self.id },
  })

  if self.config.on_attach then
    --- @type boolean, string?
    local status, err = pcall(self.config.on_attach, self, bufnr)
    if not status then
      self:write_error(lsp.client_errors.ON_ATTACH_ERROR, err)
    end
  end

  -- schedule the initialization of semantic tokens to give the above
  -- on_attach and LspAttach callbacks the ability to schedule wrap the
  -- opt-out (deleting the semanticTokensProvider from capabilities)
  vim.schedule(function()
    if vim.tbl_get(self.server_capabilities, 'semanticTokensProvider', 'full') then
      lsp.semantic_tokens.start(bufnr, self.id)
    end
  end)

  self.attached_buffers[bufnr] = true
end

--- @private
--- Logs the given error to the LSP log and to the error buffer.
--- @param code integer Error code
--- @param err any Error arguments
function Client:write_error(code, err)
  log.error(self._log_prefix, 'on_error', { code = lsp.client_errors[code], err = err })
  err_message(self._log_prefix, ': Error ', lsp.client_errors[code], ': ', vim.inspect(err))
end

--- @param method string
--- @param opts? {bufnr: integer?}
function Client:_supports_method(method, opts)
  opts = opts or {}
  local required_capability = lsp._request_name_to_capability[method]
  -- if we don't know about the method, assume that the client supports it.
  if not required_capability then
    return true
  end
  if vim.tbl_get(self.server_capabilities, unpack(required_capability)) then
    return true
  else
    if self.dynamic_capabilities:supports_registration(method) then
      return self.dynamic_capabilities:supports(method, opts)
    end
    return false
  end
end

return Client
