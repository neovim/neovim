local uv = vim.uv
local api = vim.api
local lsp = vim.lsp
local log = lsp.log
local ms = lsp.protocol.Methods
local changetracking = lsp._changetracking
local validate = vim.validate

--- @alias vim.lsp.client.on_init_cb fun(client: vim.lsp.Client, initialize_result: lsp.InitializeResult)
--- @alias vim.lsp.client.on_attach_cb fun(client: vim.lsp.Client, bufnr: integer)
--- @alias vim.lsp.client.on_exit_cb fun(code: integer, signal: integer, client_id: integer)
--- @alias vim.lsp.client.before_init_cb fun(params: lsp.InitializeParams, config: vim.lsp.ClientConfig)

--- @class vim.lsp.ClientConfig
--- command string[] that launches the language
--- server (treated as in |jobstart()|, must be absolute or on `$PATH`, shell constructs like
--- "~" are not expanded), or function that creates an RPC client. Function receives
--- a `dispatchers` table and returns a table with member functions `request`, `notify`,
--- `is_closing` and `terminate`.
--- See |vim.lsp.rpc.request()|, |vim.lsp.rpc.notify()|.
---  For TCP there is a builtin RPC client factory: |vim.lsp.rpc.connect()|
--- @field cmd string[]|fun(dispatchers: vim.lsp.rpc.Dispatchers): vim.lsp.rpc.PublicClient?
---
--- Directory to launch the `cmd` process. Not related to `root_dir`.
--- (default: cwd)
--- @field cmd_cwd? string
---
--- Environment flags to pass to the LSP on spawn.
--- Must be specified using a table.
--- Non-string values are coerced to string.
--- Example:
--- ```lua
--- { PORT = 8080; HOST = "0.0.0.0"; }
--- ```
--- @field cmd_env? table
---
--- Daemonize the server process so that it runs in a separate process group from Nvim.
--- Nvim will shutdown the process on exit, but if Nvim fails to exit cleanly this could leave
--- behind orphaned server processes.
--- (default: true)
--- @field detached? boolean
---
--- List of workspace folders passed to the language server.
--- For backwards compatibility rootUri and rootPath will be derived from the first workspace
--- folder in this list. See `workspaceFolders` in the LSP spec.
--- @field workspace_folders? lsp.WorkspaceFolder[]
---
--- Map overriding the default capabilities defined by |vim.lsp.protocol.make_client_capabilities()|,
--- passed to the language server on initialization. Hint: use make_client_capabilities() and modify
--- its result.
--- - Note: To send an empty dictionary use |vim.empty_dict()|, else it will be encoded as an
---   array.
--- @field capabilities? lsp.ClientCapabilities
---
--- Map of language server method names to |lsp-handler|
--- @field handlers? table<string,function>
---
--- Map with language server specific settings. These are returned to the language server if
--- requested via `workspace/configuration`. Keys are case-sensitive.
--- @field settings? table
---
--- Table that maps string of clientside commands to user-defined functions.
--- Commands passed to start_client take precedence over the global command registry. Each key
--- must be a unique command name, and the value is a function which is called if any LSP action
--- (code action, code lenses, ...) triggers the command.
--- @field commands? table<string,fun(command: lsp.Command, ctx: table)>
---
--- Values to pass in the initialization request as `initializationOptions`. See `initialize` in
--- the LSP spec.
--- @field init_options? table
---
--- Name in log messages.
--- (default: client-id)
--- @field name? string
---
--- Language ID as string. Defaults to the filetype.
--- @field get_language_id? fun(bufnr: integer, filetype: string): string
---
--- The encoding that the LSP server expects. Client does not verify this is correct.
--- @field offset_encoding? 'utf-8'|'utf-16'|'utf-32'
---
--- Callback invoked when the client operation throws an error. `code` is a number describing the error.
--- Other arguments may be passed depending on the error kind.  See `vim.lsp.rpc.client_errors`
--- for possible errors. Use `vim.lsp.rpc.client_errors[code]` to get human-friendly name.
--- @field on_error? fun(code: integer, err: string)
---
--- Callback invoked before the LSP "initialize" phase, where `params` contains the parameters
--- being sent to the server and `config` is the config that was passed to |vim.lsp.start_client()|.
--- You can use this to modify parameters before they are sent.
--- @field before_init? vim.lsp.client.before_init_cb
---
--- Callback invoked after LSP "initialize", where `result` is a table of `capabilities`
--- and anything else the server may send. For example, clangd sends
--- `initialize_result.offsetEncoding` if `capabilities.offsetEncoding` was sent to it.
--- You can only modify the `client.offset_encoding` here before any notifications are sent.
--- @field on_init? elem_or_list<vim.lsp.client.on_init_cb>
---
--- Callback invoked on client exit.
---   - code: exit code of the process
---   - signal: number describing the signal used to terminate (if any)
---   - client_id: client handle
--- @field on_exit? elem_or_list<vim.lsp.client.on_exit_cb>
---
--- Callback invoked when client attaches to a buffer.
--- @field on_attach? elem_or_list<vim.lsp.client.on_attach_cb>
---
--- Passed directly to the language server in the initialize request. Invalid/empty values will
--- (default: "off")
--- @field trace? 'off'|'messages'|'verbose'
---
--- A table with flags for the client. The current (experimental) flags are:
--- - allow_incremental_sync (bool, default true): Allow using incremental sync for buffer edits
--- - debounce_text_changes (number, default 150): Debounce didChange
---   notifications to the server by the given number in milliseconds. No debounce
---   occurs if nil
--- - exit_timeout (number|boolean, default false): Milliseconds to wait for server to
---   exit cleanly after sending the "shutdown" request before sending kill -15.
---   If set to false, nvim exits immediately after sending the "shutdown" request to the server.
--- @field flags? table
---
--- Directory where the LSP server will base its workspaceFolders, rootUri, and rootPath on initialization.
--- @field root_dir? string

--- @class vim.lsp.Client.Progress: vim.Ringbuf<{token: integer|string, value: any}>
--- @field pending table<lsp.ProgressToken,lsp.LSPAny>

--- @class vim.lsp.Client
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
--- @field config vim.lsp.ClientConfig
---
--- Response from the server sent on
--- initialize` describing the server's capabilities.
--- @field server_capabilities lsp.ServerCapabilities?
---
--- A ring buffer (|vim.ringbuf()|) containing progress messages
--- sent by the server.
--- @field progress vim.lsp.Client.Progress
---
--- @field initialized true?
---
--- The workspace folders configured in the client when the server starts.
--- This property is only available if the client supports workspace folders.
--- It can be `null` if the client supports workspace folders but none are
--- configured.
--- @field workspace_folders lsp.WorkspaceFolder[]?
--- @field root_dir string
---
--- @field attached_buffers table<integer,true>
--- @field private _log_prefix string
---
--- Track this so that we can escalate automatically if we've already tried a
--- graceful shutdown
--- @field private _graceful_shutdown_failed true?
---
--- The initial trace setting. If omitted trace is disabled ("off").
--- trace = "off" | "messages" | "verbose";
--- @field private _trace 'off'|'messages'|'verbose'
---
--- Table of command name to function which is called if any LSP action
--- (code action, code lenses, ...) triggers the command.
--- Client commands take precedence over the global command registry.
--- @field commands table<string,fun(command: lsp.Command, ctx: table)>
---
--- @field settings table
--- @field flags table
--- @field get_language_id fun(bufnr: integer, filetype: string): string
---
--- The capabilities provided by the client (editor or tool)
--- @field capabilities lsp.ClientCapabilities
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
--- @field private _before_init_cb? vim.lsp.client.before_init_cb
--- @field private _on_attach_cbs vim.lsp.client.on_attach_cb[]
--- @field private _on_init_cbs vim.lsp.client.on_init_cb[]
--- @field private _on_exit_cbs vim.lsp.client.on_exit_cb[]
--- @field private _on_error_cb? fun(code: integer, err: string)
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

local client_index = 0

--- Checks whether a given path is a directory.
--- @param filename (string) path to check
--- @return boolean # true if {filename} exists and is a directory, false otherwise
local function is_dir(filename)
  validate({ filename = { filename, 's' } })
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

local valid_encodings = {
  ['utf-8'] = 'utf-8',
  ['utf-16'] = 'utf-16',
  ['utf-32'] = 'utf-32',
  ['utf8'] = 'utf-8',
  ['utf16'] = 'utf-16',
  ['utf32'] = 'utf-32',
  UTF8 = 'utf-8',
  UTF16 = 'utf-16',
  UTF32 = 'utf-32',
}

--- Normalizes {encoding} to valid LSP encoding names.
--- @param encoding string? Encoding to normalize
--- @return string # normalized encoding name
local function validate_encoding(encoding)
  validate({
    encoding = { encoding, 's', true },
  })
  if not encoding then
    return valid_encodings.UTF16
  end
  return valid_encodings[encoding:lower()]
    or error(
      string.format(
        "Invalid offset encoding %q. Must be one of: 'utf-8', 'utf-16', 'utf-32'",
        encoding
      )
    )
end

--- Augments a validator function with support for optional (nil) values.
--- @param fn (fun(v): boolean) The original validator function; should return a
--- bool.
--- @return fun(v): boolean # The augmented function. Also returns true if {v} is
--- `nil`.
local function optional_validator(fn)
  return function(v)
    return v == nil or fn(v)
  end
end

--- By default, get_language_id just returns the exact filetype it is passed.
--- It is possible to pass in something that will calculate a different filetype,
--- to be sent by the client.
--- @param _bufnr integer
--- @param filetype string
local function default_get_language_id(_bufnr, filetype)
  return filetype
end

--- Validates a client configuration as given to |vim.lsp.start_client()|.
--- @param config vim.lsp.ClientConfig
local function validate_config(config)
  validate({
    config = { config, 't' },
  })
  validate({
    handlers = { config.handlers, 't', true },
    capabilities = { config.capabilities, 't', true },
    cmd_cwd = { config.cmd_cwd, optional_validator(is_dir), 'directory' },
    cmd_env = { config.cmd_env, 't', true },
    detached = { config.detached, 'b', true },
    name = { config.name, 's', true },
    on_error = { config.on_error, 'f', true },
    on_exit = { config.on_exit, { 'f', 't' }, true },
    on_init = { config.on_init, { 'f', 't' }, true },
    on_attach = { config.on_attach, { 'f', 't' }, true },
    settings = { config.settings, 't', true },
    commands = { config.commands, 't', true },
    before_init = { config.before_init, { 'f', 't' }, true },
    offset_encoding = { config.offset_encoding, 's', true },
    flags = { config.flags, 't', true },
    get_language_id = { config.get_language_id, 'f', true },
  })

  assert(
    (
      not config.flags
      or not config.flags.debounce_text_changes
      or type(config.flags.debounce_text_changes) == 'number'
    ),
    'flags.debounce_text_changes must be a number with the debounce time in milliseconds'
  )
end

--- @param trace string
--- @return 'off'|'messages'|'verbose'
local function get_trace(trace)
  local valid_traces = {
    off = 'off',
    messages = 'messages',
    verbose = 'verbose',
  }
  return trace and valid_traces[trace] or 'off'
end

--- @param id integer
--- @param config vim.lsp.ClientConfig
--- @return string
local function get_name(id, config)
  local name = config.name
  if name then
    return name
  end

  if type(config.cmd) == 'table' and config.cmd[1] then
    return assert(vim.fs.basename(config.cmd[1]))
  end

  return tostring(id)
end

--- @param workspace_folders lsp.WorkspaceFolder[]?
--- @param root_dir string?
--- @return lsp.WorkspaceFolder[]?
local function get_workspace_folders(workspace_folders, root_dir)
  if workspace_folders then
    return workspace_folders
  end
  if root_dir then
    return {
      {
        uri = vim.uri_from_fname(root_dir),
        name = string.format('%s', root_dir),
      },
    }
  end
end

--- @generic T
--- @param x elem_or_list<T>?
--- @return T[]
local function ensure_list(x)
  if type(x) == 'table' then
    return x
  end
  return { x }
end

--- @package
--- @param config vim.lsp.ClientConfig
--- @return vim.lsp.Client?
function Client.create(config)
  validate_config(config)

  client_index = client_index + 1
  local id = client_index
  local name = get_name(id, config)

  --- @class vim.lsp.Client
  local self = {
    id = id,
    config = config,
    handlers = config.handlers or {},
    offset_encoding = validate_encoding(config.offset_encoding),
    name = name,
    _log_prefix = string.format('LSP[%s]', name),
    requests = {},
    attached_buffers = {},
    server_capabilities = {},
    dynamic_capabilities = lsp._dynamic.new(id),
    commands = config.commands or {},
    settings = config.settings or {},
    flags = config.flags or {},
    get_language_id = config.get_language_id or default_get_language_id,
    capabilities = config.capabilities or lsp.protocol.make_client_capabilities(),
    workspace_folders = get_workspace_folders(config.workspace_folders, config.root_dir),
    root_dir = config.root_dir,
    _before_init_cb = config.before_init,
    _on_init_cbs = ensure_list(config.on_init),
    _on_exit_cbs = ensure_list(config.on_exit),
    _on_attach_cbs = ensure_list(config.on_attach),
    _on_error_cb = config.on_error,
    _root_dir = config.root_dir,
    _trace = get_trace(config.trace),

    --- Contains $/progress report messages.
    --- They have the format {token: integer|string, value: any}
    --- For "work done progress", value will be one of:
    --- - lsp.WorkDoneProgressBegin,
    --- - lsp.WorkDoneProgressReport (extended with title from Begin)
    --- - lsp.WorkDoneProgressEnd    (extended with title from Begin)
    progress = vim.ringbuf(50) --[[@as vim.lsp.Client.Progress]],

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

  --- @type table<string|integer, string> title of unfinished progress sequences by token
  self.progress.pending = {}

  --- @type vim.lsp.rpc.Dispatchers
  local dispatchers = {
    notification = method_wrapper(self, Client._notification),
    server_request = method_wrapper(self, Client._server_request),
    on_error = method_wrapper(self, Client._on_error),
    on_exit = method_wrapper(self, Client._on_exit),
  }

  -- Start the RPC client.
  local rpc --- @type vim.lsp.rpc.PublicClient?
  local config_cmd = config.cmd
  if type(config_cmd) == 'function' then
    rpc = config_cmd(dispatchers)
  else
    rpc = lsp.rpc.start(config_cmd, dispatchers, {
      cwd = config.cmd_cwd,
      env = config.cmd_env,
      detached = config.detached,
    })
  end

  -- Return nil if the rpc client fails to start
  if not rpc then
    return
  end

  self.rpc = rpc

  setmetatable(self, Client)

  return self
end

--- @private
--- @param cbs function[]
--- @param error_id integer
--- @param ... any
function Client:_run_callbacks(cbs, error_id, ...)
  for _, cb in pairs(cbs) do
    --- @type boolean, string?
    local status, err = pcall(cb, ...)
    if not status then
      self:write_error(error_id, err)
    end
  end
end

--- @package
function Client:initialize()
  local config = self.config

  local root_uri --- @type string?
  local root_path --- @type string?
  if self.workspace_folders then
    root_uri = self.workspace_folders[1].uri
    root_path = vim.uri_to_fname(root_uri)
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
    workspaceFolders = self.workspace_folders or vim.NIL,
    -- User provided initialization options.
    initializationOptions = config.init_options,
    capabilities = self.capabilities,
    trace = self._trace,
  }

  self:_run_callbacks(
    { self._before_init_cb },
    lsp.client_errors.BEFORE_INIT_CALLBACK_ERROR,
    initialize_params,
    config
  )

  log.trace(self._log_prefix, 'initialize_params', initialize_params)

  local rpc = self.rpc

  rpc.request('initialize', initialize_params, function(init_err, result)
    assert(not init_err, tostring(init_err))
    assert(result, 'server sent empty result')
    rpc.notify('initialized', vim.empty_dict())
    self.initialized = true

    -- These are the cleaned up capabilities we use for dynamically deciding
    -- when to send certain events to clients.
    self.server_capabilities =
      assert(result.capabilities, "initialize result doesn't contain capabilities")
    self.server_capabilities = assert(lsp.protocol.resolve_capabilities(self.server_capabilities))

    if self.server_capabilities.positionEncoding then
      self.offset_encoding = self.server_capabilities.positionEncoding
    end

    if next(self.settings) then
      self:_notify(ms.workspace_didChangeConfiguration, { settings = self.settings })
    end

    self:_run_callbacks(self._on_init_cbs, lsp.client_errors.ON_INIT_CALLBACK_ERROR, self, result)

    log.info(
      self._log_prefix,
      'server_capabilities',
      { server_capabilities = self.server_capabilities }
    )
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
  validate({ bufnr = { bufnr, 'n', true } })
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

--- Concatenates and writes a list of strings to the Vim error buffer.
---
--- @param ... string List to write to the buffer
local function err_message(...)
  local message = table.concat(vim.tbl_flatten({ ... }))
  if vim.in_fast_event() then
    vim.schedule(function()
      api.nvim_err_writeln(message)
      api.nvim_command('redraw')
    end)
  else
    api.nvim_err_writeln(message)
    api.nvim_command('redraw')
  end
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
  validate({ id = { id, 'n' } })
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

--- @private
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
    vim.lsp._watchfiles.cancel(self.id)
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

--- @package
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
      languageId = self.get_language_id(bufnr, filetype),
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
      local namespace = lsp.diagnostic.get_namespace(self.id)
      vim.diagnostic.show(namespace, bufnr)
    end
  end)
end

--- @package
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

  self:_run_callbacks(self._on_attach_cbs, lsp.client_errors.ON_ATTACH_ERROR, self, bufnr)

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
  local client_error = lsp.client_errors[code] --- @type string|integer
  log.error(self._log_prefix, 'on_error', { code = client_error, err = err })
  err_message(self._log_prefix, ': Error ', client_error, ': ', vim.inspect(err))
end

--- @private
--- @param method string
--- @param opts? {bufnr: integer?}
function Client:_supports_method(method, opts)
  local required_capability = lsp._request_name_to_capability[method]
  -- if we don't know about the method, assume that the client supports it.
  if not required_capability then
    return true
  end
  if vim.tbl_get(self.server_capabilities, unpack(required_capability)) then
    return true
  end
  if self.dynamic_capabilities:supports_registration(method) then
    return self.dynamic_capabilities:supports(method, opts)
  end
  return false
end

--- @private
--- Handles a notification sent by an LSP server by invoking the
--- corresponding handler.
---
--- @param method string LSP method name
--- @param params table The parameters for that method.
function Client:_notification(method, params)
  log.trace('notification', method, params)
  local handler = self:_resolve_handler(method)
  if handler then
    -- Method name is provided here for convenience.
    handler(nil, params, { method = method, client_id = self.id })
  end
end

--- @private
--- Handles a request from an LSP server by invoking the corresponding handler.
---
--- @param method (string) LSP method name
--- @param params (table) The parameters for that method
--- @return any result
--- @return lsp.ResponseError error code and message set in case an exception happens during the request.
function Client:_server_request(method, params)
  log.trace('server_request', method, params)
  local handler = self:_resolve_handler(method)
  if handler then
    log.trace('server_request: found handler for', method)
    return handler(nil, params, { method = method, client_id = self.id })
  end
  log.warn('server_request: no handler found for', method)
  return nil, lsp.rpc_response_error(lsp.protocol.ErrorCodes.MethodNotFound)
end

--- @private
--- Invoked when the client operation throws an error.
---
--- @param code integer Error code
--- @param err any Other arguments may be passed depending on the error kind
--- @see vim.lsp.rpc.client_errors for possible errors. Use
--- `vim.lsp.rpc.client_errors[code]` to get a human-friendly name.
function Client:_on_error(code, err)
  self:write_error(code, err)
  if self._on_error_cb then
    --- @type boolean, string
    local status, usererr = pcall(self._on_error_cb, code, err)
    if not status then
      log.error(self._log_prefix, 'user on_error failed', { err = usererr })
      err_message(self._log_prefix, ' user on_error failed: ', tostring(usererr))
    end
  end
end

--- @private
--- Invoked on client exit.
---
--- @param code integer) exit code of the process
--- @param signal integer the signal used to terminate (if any)
function Client:_on_exit(code, signal)
  self:_run_callbacks(
    self._on_exit_cbs,
    lsp.client_errors.ON_EXIT_CALLBACK_ERROR,
    code,
    signal,
    self.id
  )
end

return Client
