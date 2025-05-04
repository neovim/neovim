local uv = vim.uv
local api = vim.api
local lsp = vim.lsp
local log = lsp.log
local ms = lsp.protocol.Methods
local changetracking = lsp._changetracking
local validate = vim.validate

--- @alias vim.lsp.client.on_init_cb fun(client: vim.lsp.Client, init_result: lsp.InitializeResult)
--- @alias vim.lsp.client.on_attach_cb fun(client: vim.lsp.Client, bufnr: integer)
--- @alias vim.lsp.client.on_exit_cb fun(code: integer, signal: integer, client_id: integer)
--- @alias vim.lsp.client.before_init_cb fun(params: lsp.InitializeParams, config: vim.lsp.ClientConfig)

--- @class vim.lsp.Client.Flags
--- @inlinedoc
---
--- Allow using incremental sync for buffer edits
--- (default: `true`)
--- @field allow_incremental_sync? boolean
---
--- Debounce `didChange` notifications to the server by the given number in milliseconds.
--- No debounce occurs if `nil`.
--- (default: `150`)
--- @field debounce_text_changes integer
---
--- Milliseconds to wait for server to exit cleanly after sending the
--- "shutdown" request before sending kill -15. If set to false, nvim exits
--- immediately after sending the "shutdown" request to the server.
--- (default: `false`)
--- @field exit_timeout integer|false

--- @class vim.lsp.ClientConfig
---
--- Callback invoked before the LSP "initialize" phase, where `params` contains the parameters
--- being sent to the server and `config` is the config that was passed to |vim.lsp.start()|.
--- You can use this to modify parameters before they are sent.
--- @field before_init? fun(params: lsp.InitializeParams, config: vim.lsp.ClientConfig)
---
--- Map overriding the default capabilities defined by |vim.lsp.protocol.make_client_capabilities()|,
--- passed to the language server on initialization. Hint: use make_client_capabilities() and modify
--- its result.
--- - Note: To send an empty dictionary use |vim.empty_dict()|, else it will be encoded as an
---   array.
--- @field capabilities? lsp.ClientCapabilities
---
--- command string[] that launches the language
--- server (treated as in |jobstart()|, must be absolute or on `$PATH`, shell constructs like
--- "~" are not expanded), or function that creates an RPC client. Function receives
--- a `dispatchers` table and returns a table with member functions `request`, `notify`,
--- `is_closing` and `terminate`.
--- See |vim.lsp.rpc.request()|, |vim.lsp.rpc.notify()|.
---  For TCP there is a builtin RPC client factory: |vim.lsp.rpc.connect()|
--- @field cmd string[]|fun(dispatchers: vim.lsp.rpc.Dispatchers): vim.lsp.rpc.PublicClient
---
--- Directory to launch the `cmd` process. Not related to `root_dir`.
--- (default: cwd)
--- @field cmd_cwd? string
---
--- Environment variables passed to the LSP process on spawn. Non-string values are coerced to
--- string.
--- Example:
--- ```lua
--- { PORT = 8080; HOST = '0.0.0.0'; }
--- ```
--- @field cmd_env? table
---
--- Client commands. Map of command names to user-defined functions. Commands passed to `start()`
--- take precedence over the global command registry. Each key must be a unique command name, and
--- the value is a function which is called if any LSP action (code action, code lenses, …) triggers
--- the command.
--- @field commands? table<string,fun(command: lsp.Command, ctx: table)>
---
--- Daemonize the server process so that it runs in a separate process group from Nvim.
--- Nvim will shutdown the process on exit, but if Nvim fails to exit cleanly this could leave
--- behind orphaned server processes.
--- (default: true)
--- @field detached? boolean
---
--- A table with flags for the client. The current (experimental) flags are:
--- @field flags? vim.lsp.Client.Flags
---
--- Language ID as string. Defaults to the buffer filetype.
--- @field get_language_id? fun(bufnr: integer, filetype: string): string
---
--- Map of LSP method names to |lsp-handler|s.
--- @field handlers? table<string,function>
---
--- Values to pass in the initialization request as `initializationOptions`. See `initialize` in
--- the LSP spec.
--- @field init_options? lsp.LSPObject
---
--- (default: client-id) Name in logs and user messages.
--- @field name? string
---
--- Called "position encoding" in LSP spec. The encoding that the LSP server expects, used for
--- communication. Not validated. Can be modified in `on_init` before text is sent to the server.
--- @field offset_encoding? 'utf-8'|'utf-16'|'utf-32'
---
--- Callback invoked when client attaches to a buffer.
--- @field on_attach? elem_or_list<fun(client: vim.lsp.Client, bufnr: integer)>
---
--- Callback invoked when the client operation throws an error. `code` is a number describing the error.
--- Other arguments may be passed depending on the error kind.  See `vim.lsp.rpc.client_errors`
--- for possible errors. Use `vim.lsp.rpc.client_errors[code]` to get human-friendly name.
--- @field on_error? fun(code: integer, err: string)
---
--- Callback invoked on client exit.
---   - code: exit code of the process
---   - signal: number describing the signal used to terminate (if any)
---   - client_id: client handle
--- @field on_exit? elem_or_list<fun(code: integer, signal: integer, client_id: integer)>
---
--- Callback invoked after LSP "initialize", where `result` is a table of `capabilities` and
--- anything else the server may send. For example, clangd sends `init_result.offsetEncoding` if
--- `capabilities.offsetEncoding` was sent to it. You can only modify the `client.offset_encoding`
--- here before any notifications are sent.
--- @field on_init? elem_or_list<fun(client: vim.lsp.Client, init_result: lsp.InitializeResult)>
---
--- Directory where the LSP server will base its workspaceFolders, rootUri, and rootPath on initialization.
--- @field root_dir? string
---
--- Map of language server-specific settings, decided by the client. Sent to the LS if requested via
--- `workspace/configuration`. Keys are case-sensitive.
--- @field settings? lsp.LSPObject
---
--- Passed directly to the language server in the initialize request. Invalid/empty values will
--- (default: "off")
--- @field trace? 'off'|'messages'|'verbose'
---
--- List of workspace folders passed to the language server. For backwards compatibility rootUri and
--- rootPath are derived from the first workspace folder in this list. Can be `null` if the client
--- supports workspace folders but none are configured. See `workspaceFolders` in LSP spec.
--- @field workspace_folders? lsp.WorkspaceFolder[]
---
--- (default false) Server requires a workspace (no "single file" support). Note: Without
--- a workspace, cross-file features (navigation, hover) may or may not work depending on the
--- language server, even if the server doesn't require a workspace.
--- @field workspace_required? boolean

--- @class vim.lsp.Client.Progress: vim.Ringbuf<{token: integer|string, value: any}>
--- @field pending table<lsp.ProgressToken,lsp.LSPAny>

--- @class vim.lsp.Client
---
--- @field attached_buffers table<integer,true>
---
--- Capabilities provided by the client (editor or tool), at startup.
--- @field capabilities lsp.ClientCapabilities
---
--- Client commands. See [vim.lsp.ClientConfig].
--- @field commands table<string,fun(command: lsp.Command, ctx: table)>
---
--- Copy of the config passed to |vim.lsp.start()|.
--- @field config vim.lsp.ClientConfig
---
--- Capabilities provided at runtime (after startup).
--- @field dynamic_capabilities lsp.DynamicCapabilities
---
--- A table with flags for the client. The current (experimental) flags are:
--- @field flags vim.lsp.Client.Flags
---
--- See [vim.lsp.ClientConfig].
--- @field get_language_id fun(bufnr: integer, filetype: string): string
---
--- See [vim.lsp.ClientConfig].
--- @field handlers table<string,lsp.Handler>
---
--- The id allocated to the client.
--- @field id integer
---
--- @field initialized true?
---
--- See [vim.lsp.ClientConfig].
--- @field name string
---
--- See [vim.lsp.ClientConfig].
--- @field offset_encoding string
---
--- A ring buffer (|vim.ringbuf()|) containing progress messages
--- sent by the server.
--- @field progress vim.lsp.Client.Progress
---
--- The current pending requests in flight to the server. Entries are key-value
--- pairs with the key being the request id while the value is a table with
--- `type`, `bufnr`, and `method` key-value pairs. `type` is either "pending"
--- for an active request, or "cancel" for a cancel request. It will be
--- "complete" ephemerally while executing |LspRequest| autocmds when replies
--- are received from the server.
--- @field requests table<integer,{ type: string, bufnr: integer, method: string}?>
---
--- See [vim.lsp.ClientConfig].
--- @field root_dir string?
---
--- RPC client object, for low level interaction with the client.
--- See |vim.lsp.rpc.start()|.
--- @field rpc vim.lsp.rpc.PublicClient
---
--- Response from the server sent on `initialize` describing the server's capabilities.
--- @field server_capabilities lsp.ServerCapabilities?
---
--- Response from the server sent on `initialize` describing server information (e.g. version).
--- @field server_info lsp.ServerInfo?
---
--- See [vim.lsp.ClientConfig].
--- @field settings lsp.LSPObject
---
--- See [vim.lsp.ClientConfig].
--- @field workspace_folders lsp.WorkspaceFolder[]?
---
---
--- Track this so that we can escalate automatically if we've already tried a
--- graceful shutdown
--- @field private _graceful_shutdown_failed true?
---
--- The initial trace setting. If omitted trace is disabled ("off").
--- trace = "off" | "messages" | "verbose";
--- @field private _trace 'off'|'messages'|'verbose'
---
--- @field private registrations table<string,lsp.Registration[]>
--- @field private _log_prefix string
--- @field private _before_init_cb? vim.lsp.client.before_init_cb
--- @field private _on_attach_cbs vim.lsp.client.on_attach_cb[]
--- @field private _on_init_cbs vim.lsp.client.on_init_cb[]
--- @field private _on_exit_cbs vim.lsp.client.on_exit_cb[]
--- @field private _on_error_cb? fun(code: integer, err: string)
local Client = {}
Client.__index = Client

--- @param obj table<string,any>
--- @param cls table<string,function>
--- @param name string
local function method_wrapper(obj, cls, name)
  local meth = assert(cls[name])
  obj[name] = function(...)
    local arg = select(1, ...)
    if arg and getmetatable(arg) == cls then
      -- First argument is self, call meth directly
      return meth(...)
    end
    vim.deprecate('client.' .. name, 'client:' .. name, '0.13')
    -- First argument is not self, insert it
    return meth(obj, ...)
  end
end

local client_index = 0

--- Checks whether a given path is a directory.
--- @param filename (string) path to check
--- @return boolean # true if {filename} exists and is a directory, false otherwise
local function is_dir(filename)
  validate('filename', filename, 'string')
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
}

--- Normalizes {encoding} to valid LSP encoding names.
--- @param encoding string? Encoding to normalize
--- @return string # normalized encoding name
local function validate_encoding(encoding)
  validate('encoding', encoding, 'string', true)
  if not encoding then
    return valid_encodings.utf16
  end
  return valid_encodings[encoding:lower()]
    or error(
      string.format(
        "Invalid position encoding %q. Must be one of: 'utf-8', 'utf-16', 'utf-32'",
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

--- Validates a client configuration as given to |vim.lsp.start()|.
--- @param config vim.lsp.ClientConfig
local function validate_config(config)
  validate('config', config, 'table')
  validate('handlers', config.handlers, 'table', true)
  validate('capabilities', config.capabilities, 'table', true)
  validate('cmd_cwd', config.cmd_cwd, optional_validator(is_dir), 'directory')
  validate('cmd_env', config.cmd_env, 'table', true)
  validate('detached', config.detached, 'boolean', true)
  validate('name', config.name, 'string', true)
  validate('on_error', config.on_error, 'function', true)
  validate('on_exit', config.on_exit, { 'function', 'table' }, true)
  validate('on_init', config.on_init, { 'function', 'table' }, true)
  validate('on_attach', config.on_attach, { 'function', 'table' }, true)
  validate('settings', config.settings, 'table', true)
  validate('commands', config.commands, 'table', true)
  validate('before_init', config.before_init, { 'function', 'table' }, true)
  validate('offset_encoding', config.offset_encoding, 'string', true)
  validate('flags', config.flags, 'table', true)
  validate('get_language_id', config.get_language_id, 'function', true)

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

--- @nodoc
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
    registrations = {},
    commands = config.commands or {},
    settings = config.settings or {},
    flags = config.flags or {},
    get_language_id = config.get_language_id or default_get_language_id,
    capabilities = config.capabilities,
    workspace_folders = lsp._get_workspace_folders(config.workspace_folders or config.root_dir),
    root_dir = config.root_dir,
    _is_stopping = false,
    _before_init_cb = config.before_init,
    _on_init_cbs = vim._ensure_list(config.on_init),
    _on_exit_cbs = vim._ensure_list(config.on_exit),
    _on_attach_cbs = vim._ensure_list(config.on_attach),
    _on_error_cb = config.on_error,
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

  self.capabilities =
    vim.tbl_deep_extend('force', lsp.protocol.make_client_capabilities(), self.capabilities or {})

  --- @class lsp.DynamicCapabilities
  --- @nodoc
  self.dynamic_capabilities = {
    capabilities = self.registrations,
    client_id = id,
    register = function(_, registrations)
      return self:_register_dynamic(registrations)
    end,
    unregister = function(_, unregistrations)
      return self:_unregister_dynamic(unregistrations)
    end,
    get = function(_, method, opts)
      return self:_get_registration(method, opts and opts.bufnr)
    end,
    supports_registration = function(_, method)
      return self:_supports_registration(method)
    end,
    supports = function(_, method, opts)
      return self:_get_registration(method, opts and opts.bufnr) ~= nil
    end,
  }

  --- @type table<string|integer, string> title of unfinished progress sequences by token
  self.progress.pending = {}

  --- @type vim.lsp.rpc.Dispatchers
  local dispatchers = {
    notification = function(...)
      return self:_notification(...)
    end,
    server_request = function(...)
      return self:_server_request(...)
    end,
    on_error = function(...)
      return self:_on_error(...)
    end,
    on_exit = function(...)
      return self:_on_exit(...)
    end,
  }

  -- Start the RPC client.
  local config_cmd = config.cmd
  if type(config_cmd) == 'function' then
    self.rpc = config_cmd(dispatchers)
  else
    self.rpc = lsp.rpc.start(config_cmd, dispatchers, {
      cwd = config.cmd_cwd,
      env = config.cmd_env,
      detached = config.detached,
    })
  end

  setmetatable(self, Client)

  method_wrapper(self, Client, 'request')
  method_wrapper(self, Client, 'request_sync')
  method_wrapper(self, Client, 'notify')
  method_wrapper(self, Client, 'cancel_request')
  method_wrapper(self, Client, 'stop')
  method_wrapper(self, Client, 'is_stopped')
  method_wrapper(self, Client, 'on_attach')
  method_wrapper(self, Client, 'supports_method')

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

--- @nodoc
function Client:initialize()
  local config = self.config

  local root_uri --- @type string?
  local root_path --- @type string?
  if self.workspace_folders then
    root_uri = self.workspace_folders[1].uri
    root_path = vim.uri_to_fname(root_uri)
  end

  local init_params = {
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
    workDoneToken = '1',
  }

  self:_run_callbacks(
    { self._before_init_cb },
    lsp.client_errors.BEFORE_INIT_CALLBACK_ERROR,
    init_params,
    config
  )

  log.trace(self._log_prefix, 'init_params', init_params)

  local rpc = self.rpc

  rpc.request('initialize', init_params, function(init_err, result)
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

    self.server_info = result.serverInfo

    if next(self.settings) then
      self:notify(ms.workspace_didChangeConfiguration, { settings = self.settings })
    end

    -- If server is being restarted, make sure to re-attach to any previously attached buffers.
    -- Save which buffers before on_init in case new buffers are attached.
    local reattach_bufs = vim.deepcopy(self.attached_buffers)

    self:_run_callbacks(self._on_init_cbs, lsp.client_errors.ON_INIT_CALLBACK_ERROR, self, result)

    for buf in pairs(reattach_bufs) do
      -- The buffer may have been detached in the on_init callback.
      if self.attached_buffers[buf] then
        self:on_attach(buf)
      end
    end

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
--- @return lsp.Handler? handler for the given method, if defined, or the default from |vim.lsp.handlers|
function Client:_resolve_handler(method)
  return self.handlers[method] or lsp.handlers[method]
end

--- @private
--- @param id integer
--- @param req_type 'pending'|'complete'|'cancel'|
--- @param bufnr? integer (only required for req_type='pending')
--- @param method? string (only required for req_type='pending')
function Client:_process_request(id, req_type, bufnr, method)
  local pending = req_type == 'pending'

  validate('id', id, 'number')
  if pending then
    validate('bufnr', bufnr, 'number')
    validate('method', method, 'string')
  end

  local cur_request = self.requests[id]

  if pending and cur_request then
    log.error(
      self._log_prefix,
      ('Cannot create request with id %d as one already exists'):format(id)
    )
    return
  elseif not pending and not cur_request then
    log.error(
      self._log_prefix,
      ('Cannot find request with id %d whilst attempting to %s'):format(id, req_type)
    )
    return
  end

  if cur_request then
    bufnr = cur_request.bufnr
    method = cur_request.method
  end

  assert(bufnr and method)

  local request = { type = req_type, bufnr = bufnr, method = method }

  -- Clear 'complete' requests
  -- Note 'pending' and 'cancelled' requests are cleared when the server sends a response
  -- which is processed via the notify_reply_callback argument to rpc.request.
  self.requests[id] = req_type ~= 'complete' and request or nil

  api.nvim_exec_autocmds('LspRequest', {
    buffer = api.nvim_buf_is_valid(bufnr) and bufnr or nil,
    modeline = false,
    data = { client_id = self.id, request_id = id, request = request },
  })
end

--- Sends a request to the server.
---
--- This is a thin wrapper around {client.rpc.request} with some additional
--- checks for capabilities and handler availability.
---
--- @param method string LSP method name.
--- @param params? table LSP request params.
--- @param handler? lsp.Handler Response |lsp-handler| for this method.
--- @param bufnr? integer (default: 0) Buffer handle, or 0 for current.
--- @return boolean status indicates whether the request was successful.
---     If it is `false`, then it will always be `false` (the client has shutdown).
--- @return integer? request_id Can be used with |Client:cancel_request()|.
---                             `nil` is request failed.
--- to cancel the-request.
--- @see |vim.lsp.buf_request_all()|
function Client:request(method, params, handler, bufnr)
  if not handler then
    handler = assert(
      self:_resolve_handler(method),
      string.format('not found: %q request handler for client %q.', method, self.name)
    )
  end
  -- Ensure pending didChange notifications are sent so that the server doesn't operate on a stale state
  changetracking.flush(self, bufnr)
  bufnr = vim._resolve_bufnr(bufnr)
  local version = lsp.util.buf_versions[bufnr]
  log.debug(self._log_prefix, 'client.request', self.id, method, params, handler, bufnr)

  -- Detect if request resolved synchronously (only possible with in-process servers).
  local already_responded = false
  local request_registered = false

  -- NOTE: rpc.request might call an in-process (Lua) server, thus may be synchronous.
  local success, request_id = self.rpc.request(method, params, function(err, result)
    handler(err, result, {
      method = method,
      client_id = self.id,
      bufnr = bufnr,
      params = params,
      version = version,
    })
  end, function(request_id)
    -- Called when the server sends a response to the request (including cancelled acknowledgment).
    if request_registered then
      self:_process_request(request_id, 'complete')
    end
    already_responded = true
  end)

  if success and request_id and not already_responded then
    self:_process_request(request_id, 'pending', bufnr, method)
    request_registered = true
  end

  return success, request_id
end

-- TODO(lewis6991): duplicated from lsp.lua
local wait_result_reason = { [-1] = 'timeout', [-2] = 'interrupted', [-3] = 'error' }

--- Concatenates and writes a list of strings to the Vim error buffer.
---
--- @param ... string List to write to the buffer
local function err_message(...)
  local chunks = { { table.concat(vim.iter({ ... }):flatten():totable()) } }
  if vim.in_fast_event() then
    vim.schedule(function()
      api.nvim_echo(chunks, true, { err = true })
      api.nvim_command('redraw')
    end)
  else
    api.nvim_echo(chunks, true, { err = true })
    api.nvim_command('redraw')
  end
end

--- Sends a request to the server and synchronously waits for the response.
---
--- This is a wrapper around |Client:request()|
---
--- @param method string LSP method name.
--- @param params table LSP request params.
--- @param timeout_ms integer? Maximum time in milliseconds to wait for
---                                a result. Defaults to 1000
--- @param bufnr? integer (default: 0) Buffer handle, or 0 for current.
--- @return {err: lsp.ResponseError?, result:any}? `result` and `err` from the |lsp-handler|.
---                 `nil` is the request was unsuccessful
--- @return string? err On timeout, cancel or error, where `err` is a
---                 string describing the failure reason.
--- @see |vim.lsp.buf_request_sync()|
function Client:request_sync(method, params, timeout_ms, bufnr)
  local request_result = nil
  local function _sync_handler(err, result)
    request_result = { err = err, result = result }
  end

  local success, request_id = self:request(method, params, _sync_handler, bufnr)
  if not success then
    return nil
  end

  local wait_result, reason = vim.wait(timeout_ms or 1000, function()
    return request_result ~= nil
  end, 10)

  if not wait_result then
    if request_id then
      self:cancel_request(request_id)
    end
    return nil, wait_result_reason[reason]
  end
  return request_result
end

--- Sends a notification to an LSP server.
---
--- @param method string LSP method name.
--- @param params table? LSP request params.
--- @return boolean status indicating if the notification was successful.
---                        If it is false, then the client has shutdown.
function Client:notify(method, params)
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

--- Cancels a request with a given request id.
---
--- @param id integer id of request to cancel
--- @return boolean status indicating if the notification was successful.
--- @see |Client:notify()|
function Client:cancel_request(id)
  self:_process_request(id, 'cancel')
  return self.rpc.notify(ms.dollar_cancelRequest, { id = id })
end

--- Stops a client, optionally with force.
---
--- By default, it will just request the server to shutdown without force. If
--- you request to stop a client which has previously been requested to
--- shutdown, it will automatically escalate and force shutdown.
---
--- @param force? boolean
function Client:stop(force)
  if self:is_stopped() then
    return
  end

  self._is_stopping = true
  local rpc = self.rpc

  vim.lsp._watchfiles.cancel(self.id)

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

--- Get options for a method that is registered dynamically.
--- @param method string
function Client:_supports_registration(method)
  local capability = vim.tbl_get(self.capabilities, unpack(vim.split(method, '/')))
  return type(capability) == 'table' and capability.dynamicRegistration
end

--- @private
--- @param registrations lsp.Registration[]
function Client:_register_dynamic(registrations)
  -- remove duplicates
  self:_unregister_dynamic(registrations)
  for _, reg in ipairs(registrations) do
    local method = reg.method
    if not self.registrations[method] then
      self.registrations[method] = {}
    end
    table.insert(self.registrations[method], reg)
  end
end

--- @param registrations lsp.Registration[]
function Client:_register(registrations)
  self:_register_dynamic(registrations)

  local unsupported = {} --- @type string[]

  for _, reg in ipairs(registrations) do
    local method = reg.method
    if method == ms.workspace_didChangeWatchedFiles then
      vim.lsp._watchfiles.register(reg, self.id)
    elseif not self:_supports_registration(method) then
      unsupported[#unsupported + 1] = method
    end
  end

  if #unsupported > 0 then
    local warning_tpl = 'The language server %s triggers a registerCapability '
      .. 'handler for %s despite dynamicRegistration set to false. '
      .. 'Report upstream, this warning is harmless'
    log.warn(string.format(warning_tpl, self.name, table.concat(unsupported, ', ')))
  end
end

--- @private
--- @param unregistrations lsp.Unregistration[]
function Client:_unregister_dynamic(unregistrations)
  for _, unreg in ipairs(unregistrations) do
    local sreg = self.registrations[unreg.method]
    -- Unegister dynamic capability
    for i, reg in ipairs(sreg or {}) do
      if reg.id == unreg.id then
        table.remove(sreg, i)
        break
      end
    end
  end
end

--- @param unregistrations lsp.Unregistration[]
function Client:_unregister(unregistrations)
  self:_unregister_dynamic(unregistrations)
  for _, unreg in ipairs(unregistrations) do
    if unreg.method == ms.workspace_didChangeWatchedFiles then
      vim.lsp._watchfiles.unregister(unreg, self.id)
    end
  end
end

--- @private
function Client:_get_language_id(bufnr)
  return self.get_language_id(bufnr, vim.bo[bufnr].filetype)
end

--- @param method string
--- @param bufnr? integer
--- @return lsp.Registration?
function Client:_get_registration(method, bufnr)
  bufnr = vim._resolve_bufnr(bufnr)
  for _, reg in ipairs(self.registrations[method] or {}) do
    local regoptions = reg.registerOptions --[[@as {documentSelector:lsp.TextDocumentFilter[]}]]
    if not regoptions or not regoptions.documentSelector then
      return reg
    end
    local documentSelector = regoptions.documentSelector
    local language = self:_get_language_id(bufnr)
    local uri = vim.uri_from_bufnr(bufnr)
    local fname = vim.uri_to_fname(uri)
    for _, filter in ipairs(documentSelector) do
      local flang, fscheme, fpat = filter.language, filter.scheme, filter.pattern
      if
        not (flang and language ~= flang)
        and not (fscheme and not vim.startswith(uri, fscheme .. ':'))
        and not (type(fpat) == 'string' and not vim.glob.to_lpeg(fpat):match(fname))
      then
        return reg
      end
    end
  end
end

--- Checks whether a client is stopped.
---
--- @return boolean # true if client is stopped or in the process of being
--- stopped; false otherwise
function Client:is_stopped()
  return self.rpc.is_closing() or self._is_stopping
end

--- Execute a lsp command, either via client command function (if available)
--- or via workspace/executeCommand (if supported by the server)
---
--- @param command lsp.Command
--- @param context? {bufnr?: integer}
--- @param handler? lsp.Handler only called if a server command
function Client:exec_cmd(command, context, handler)
  context = vim.deepcopy(context or {}, true) --[[@as lsp.HandlerContext]]
  context.bufnr = vim._resolve_bufnr(context.bufnr)
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
  --- @type lsp.ExecuteCommandParams
  local params = {
    command = cmdname,
    arguments = command.arguments,
  }
  self:request(ms.workspace_executeCommand, params, handler, context.bufnr)
end

--- Default handler for the 'textDocument/didOpen' LSP notification.
---
--- @param bufnr integer Number of the buffer, or 0 for current
function Client:_text_document_did_open_handler(bufnr)
  changetracking.init(self, bufnr)
  if not self:supports_method(ms.textDocument_didOpen) then
    return
  end
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  self:notify(ms.textDocument_didOpen, {
    textDocument = {
      version = lsp.util.buf_versions[bufnr],
      uri = vim.uri_from_bufnr(bufnr),
      languageId = self:_get_language_id(bufnr),
      text = lsp._buf_get_full_text(bufnr),
    },
  })

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

--- Runs the on_attach function from the client's config if it was defined.
--- Useful for buffer-local setup.
--- @param bufnr integer Buffer number
function Client:on_attach(bufnr)
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

--- Checks if a client supports a given method.
--- Always returns true for unknown off-spec methods.
---
--- Note: Some language server capabilities can be file specific.
--- @param method string
--- @param bufnr? integer
function Client:supports_method(method, bufnr)
  -- Deprecated form
  if type(bufnr) == 'table' then
    --- @diagnostic disable-next-line:no-unknown
    bufnr = bufnr.bufnr
  end
  local required_capability = lsp.protocol._request_name_to_capability[method]
  -- if we don't know about the method, assume that the client supports it.
  if not required_capability then
    return true
  end
  if vim.tbl_get(self.server_capabilities, unpack(required_capability)) then
    return true
  end

  local rmethod = lsp._resolve_to_request[method]
  if rmethod then
    if self:_supports_registration(rmethod) then
      local reg = self:_get_registration(rmethod, bufnr)
      return vim.tbl_get(reg or {}, 'registerOptions', 'resolveProvider') or false
    end
  else
    if self:_supports_registration(method) then
      return self:_get_registration(method, bufnr) ~= nil
    end
  end
  return false
end

--- Get options for a method that is registered dynamically.
--- @param method string
--- @param bufnr? integer
--- @return lsp.LSPAny?
function Client:_get_registration_options(method, bufnr)
  if not self:_supports_registration(method) then
    return
  end

  local reg = self:_get_registration(method, bufnr)

  if reg then
    return reg.registerOptions
  end
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

--- Add a directory to the workspace folders.
--- @param dir string?
function Client:_add_workspace_folder(dir)
  for _, folder in pairs(self.workspace_folders or {}) do
    if folder.name == dir then
      print(dir, 'is already part of this workspace')
      return
    end
  end

  local wf = assert(lsp._get_workspace_folders(dir))

  self:notify(ms.workspace_didChangeWorkspaceFolders, {
    event = { added = wf, removed = {} },
  })

  if not self.workspace_folders then
    self.workspace_folders = {}
  end
  vim.list_extend(self.workspace_folders, wf)
end

--- Remove a directory to the workspace folders.
--- @param dir string?
function Client:_remove_workspace_folder(dir)
  local wf = assert(lsp._get_workspace_folders(dir))

  self:notify(ms.workspace_didChangeWorkspaceFolders, {
    event = { added = {}, removed = wf },
  })

  for idx, folder in pairs(self.workspace_folders) do
    if folder.name == dir then
      table.remove(self.workspace_folders, idx)
      break
    end
  end
end

return Client
