local if_nil = vim.F.if_nil

local default_handlers = require 'vim.lsp.handlers'
local log = require 'vim.lsp.log'
local lsp_rpc = require 'vim.lsp.rpc'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'

local vim = vim
local nvim_err_writeln, nvim_buf_get_lines, nvim_command, nvim_buf_get_option
  = vim.api.nvim_err_writeln, vim.api.nvim_buf_get_lines, vim.api.nvim_command, vim.api.nvim_buf_get_option
local uv = vim.loop
local tbl_isempty, tbl_extend = vim.tbl_isempty, vim.tbl_extend
local validate = vim.validate

local lsp = {
  protocol = protocol;

  handlers = default_handlers;

  buf = require'vim.lsp.buf';
  diagnostic = require'vim.lsp.diagnostic';
  util = util;

  -- Allow raw RPC access.
  rpc = lsp_rpc;

  -- Export these directly from rpc.
  rpc_response_error = lsp_rpc.rpc_response_error;
}

-- maps request name to the required resolved_capability in the client.
lsp._request_name_to_capability = {
  ['textDocument/hover'] = 'hover';
  ['textDocument/signatureHelp'] = 'signature_help';
  ['textDocument/definition'] = 'goto_definition';
  ['textDocument/implementation'] = 'implementation';
  ['textDocument/declaration'] = 'declaration';
  ['textDocument/typeDefinition'] = 'type_definition';
  ['textDocument/documentSymbol'] = 'document_symbol';
  ['textDocument/workspaceSymbol'] = 'workspace_symbol';
  ['textDocument/prepareCallHierarchy'] = 'call_hierarchy';
  ['textDocument/rename'] = 'rename';
  ['textDocument/codeAction'] = 'code_action';
  ['workspace/executeCommand'] = 'execute_command';
  ['textDocument/references'] = 'find_references';
  ['textDocument/rangeFormatting'] = 'document_range_formatting';
  ['textDocument/formatting'] = 'document_formatting';
  ['textDocument/completion'] = 'completion';
  ['textDocument/documentHighlight'] = 'document_highlight';
}

-- TODO improve handling of scratch buffers with LSP attached.

--@private
--- Concatenates and writes a list of strings to the Vim error buffer.
---
--@param {...} (List of strings) List to write to the buffer
local function err_message(...)
  nvim_err_writeln(table.concat(vim.tbl_flatten{...}))
  nvim_command("redraw")
end

--@private
--- Returns the buffer number for the given {bufnr}.
---
--@param bufnr (number) Buffer number to resolve. Defaults to the current
---buffer if not given.
--@returns bufnr (number) Number of requested buffer
local function resolve_bufnr(bufnr)
  validate { bufnr = { bufnr, 'n', true } }
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

--@private
--- Called by the client when trying to call a method that's not
--- supported in any of the servers registered for the current buffer.
--@param method (string) name of the method
function lsp._unsupported_method(method)
  local msg = string.format("method %s is not supported by any of the servers registered for the current buffer", method)
  log.warn(msg)
  return lsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound, msg)
end

--@private
--- Checks whether a given path is a directory.
---
--@param filename (string) path to check
--@returns true if {filename} exists and is a directory, false otherwise
local function is_dir(filename)
  validate{filename={filename,'s'}}
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

local wait_result_reason = { [-1] = "timeout"; [-2] = "interrupted"; [-3] = "error" }

local valid_encodings = {
  ["utf-8"] = 'utf-8'; ["utf-16"] = 'utf-16'; ["utf-32"] = 'utf-32';
  ["utf8"]  = 'utf-8'; ["utf16"]  = 'utf-16'; ["utf32"]  = 'utf-32';
  UTF8      = 'utf-8'; UTF16      = 'utf-16'; UTF32      = 'utf-32';
}

local client_index = 0
--@private
--- Returns a new, unused client id.
---
--@returns (number) client id
local function next_client_id()
  client_index = client_index + 1
  return client_index
end
-- Tracks all clients created via lsp.start_client
local active_clients = {}
local all_buffer_active_clients = {}
local uninitialized_clients = {}

-- Tracks all buffers attached to a client.
local all_client_active_buffers = {}

--@private
--- Invokes a function for each LSP client attached to the buffer {bufnr}.
---
--@param bufnr (Number) of buffer
--@param fn (function({client}, {client_id}, {bufnr}) Function to run on
---each client attached to that buffer.
local function for_each_buffer_client(bufnr, fn)
  validate {
    fn = { fn, 'f' };
  }
  bufnr = resolve_bufnr(bufnr)
  local client_ids = all_buffer_active_clients[bufnr]
  if not client_ids or tbl_isempty(client_ids) then
    return
  end
  for client_id in pairs(client_ids) do
    local client = active_clients[client_id]
    if client then
      fn(client, client_id, bufnr)
    end
  end
end

-- Error codes to be used with `on_error` from |vim.lsp.start_client|.
-- Can be used to look up the string from a the number or the number
-- from the string.
lsp.client_errors = tbl_extend("error", lsp_rpc.client_errors, vim.tbl_add_reverse_lookup {
  ON_INIT_CALLBACK_ERROR = table.maxn(lsp_rpc.client_errors) + 1;
})

--@private
--- Normalizes {encoding} to valid LSP encoding names.
---
--@param encoding (string) Encoding to normalize
--@returns (string) normalized encoding name
local function validate_encoding(encoding)
  validate {
    encoding = { encoding, 's' };
  }
  return valid_encodings[encoding:lower()]
      or error(string.format("Invalid offset encoding %q. Must be one of: 'utf-8', 'utf-16', 'utf-32'", encoding))
end

--@internal
--- Parses a command invocation into the command itself and its args. If there
--- are no arguments, an empty table is returned as the second argument.
---
--@param input (List)
--@returns (string) the command
--@returns (list of strings) its arguments
function lsp._cmd_parts(input)
  vim.validate{cmd={
    input,
    function() return vim.tbl_islist(input) end,
    "list"}}

  local cmd = input[1]
  local cmd_args = {}
  -- Don't mutate our input.
  for i, v in ipairs(input) do
    vim.validate{["cmd argument"]={v, "s"}}
    if i > 1 then
      table.insert(cmd_args, v)
    end
  end
  return cmd, cmd_args
end

--@private
--- Augments a validator function with support for optional (nil) values.
---
--@param fn (function(v)) The original validator function; should return a
---bool.
--@returns (function(v)) The augmented function. Also returns true if {v} is
---`nil`.
local function optional_validator(fn)
  return function(v)
    return v == nil or fn(v)
  end
end

--@private
--- Validates a client configuration as given to |vim.lsp.start_client()|.
---
--@param config (table)
--@returns (table) "Cleaned" config, containing only the command, its
---arguments, and a valid encoding.
---
--@see |vim.lsp.start_client()|
local function validate_client_config(config)
  validate {
    config = { config, 't' };
  }
  validate {
    root_dir        = { config.root_dir, is_dir, "directory" };
    handlers        = { config.handlers, "t", true };
    capabilities    = { config.capabilities, "t", true };
    cmd_cwd         = { config.cmd_cwd, optional_validator(is_dir), "directory" };
    cmd_env         = { config.cmd_env, "t", true };
    name            = { config.name, 's', true };
    on_error        = { config.on_error, "f", true };
    on_exit         = { config.on_exit, "f", true };
    on_init         = { config.on_init, "f", true };
    settings        = { config.settings, "t", true };
    before_init     = { config.before_init, "f", true };
    offset_encoding = { config.offset_encoding, "s", true };
    flags           = { config.flags, "t", true };
  }

  local cmd, cmd_args = lsp._cmd_parts(config.cmd)
  local offset_encoding = valid_encodings.UTF16
  if config.offset_encoding then
    offset_encoding = validate_encoding(config.offset_encoding)
  end

  return {
    cmd = cmd;
    cmd_args = cmd_args;
    offset_encoding = offset_encoding;
  }
end

--@private
--- Returns full text of buffer {bufnr} as a string.
---
--@param bufnr (number) Buffer handle, or 0 for current.
--@returns Buffer text as string.
local function buf_get_full_text(bufnr)
  local text = table.concat(nvim_buf_get_lines(bufnr, 0, -1, true), '\n')
  if nvim_buf_get_option(bufnr, 'eol') then
    text = text .. '\n'
  end
  return text
end

--@private
--- Default handler for the 'textDocument/didOpen' LSP notification.
---
--@param bufnr (Number) Number of the buffer, or 0 for current
--@param client Client object
local function text_document_did_open_handler(bufnr, client)
  local allow_incremental_sync = if_nil(client.config.flags.allow_incremental_sync, false)
  if allow_incremental_sync then
    if not client._cached_buffers then
      client._cached_buffers = {}
    end
    client._cached_buffers[bufnr] = nvim_buf_get_lines(bufnr, 0, -1, true)
  end
  if not client.resolved_capabilities.text_document_open_close then
    return
  end
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local params = {
    textDocument = {
      version = 0;
      uri = vim.uri_from_bufnr(bufnr);
      -- TODO make sure our filetypes are compatible with languageId names.
      languageId = nvim_buf_get_option(bufnr, 'filetype');
      text = buf_get_full_text(bufnr);
    }
  }
  client.notify('textDocument/didOpen', params)
  util.buf_versions[bufnr] = params.textDocument.version
end

-- FIXME: DOC: Shouldn't need to use a dummy function
--
--- LSP client object. You can get an active client object via
--- |vim.lsp.get_client_by_id()| or |vim.lsp.get_active_clients()|.
---
--- - Methods:
---
---  - request(method, params, [handler], bufnr)
---     Sends a request to the server.
---     This is a thin wrapper around {client.rpc.request} with some additional
---     checking.
---     If {handler} is not specified,  If one is not found there, then an error will occur.
---     Returns: {status}, {[client_id]}. {status} is a boolean indicating if
---     the notification was successful. If it is `false`, then it will always
---     be `false` (the client has shutdown).
---     If {status} is `true`, the function returns {request_id} as the second
---     result. You can use this with `client.cancel_request(request_id)`
---     to cancel the request.
---
---  - notify(method, params)
---     Sends a notification to an LSP server.
---     Returns: a boolean to indicate if the notification was successful. If
---     it is false, then it will always be false (the client has shutdown).
---
---  - cancel_request(id)
---     Cancels a request with a given request id.
---     Returns: same as `notify()`.
---
---  - stop([force])
---     Stops a client, optionally with force.
---     By default, it will just ask the server to shutdown without force.
---     If you request to stop a client which has previously been requested to
---     shutdown, it will automatically escalate and force shutdown.
---
---  - is_stopped()
---     Checks whether a client is stopped.
---     Returns: true if the client is fully stopped.
---
---  - on_attach(client, bufnr)
---     Runs the on_attach function from the client's config if it was defined.
---     Useful for buffer-local setup.
---
--- - Members
---  - {id} (number): The id allocated to the client.
---
---  - {name} (string): If a name is specified on creation, that will be
---    used. Otherwise it is just the client id. This is used for
---    logs and messages.
---
---  - {rpc} (table): RPC client object, for low level interaction with the
---    client. See |vim.lsp.rpc.start()|.
---
---  - {offset_encoding} (string): The encoding used for communicating
---    with the server. You can modify this in the `config`'s `on_init` method
---    before text is sent to the server.
---
---  - {handlers} (table): The handlers used by the client as described in |lsp-handler|.
---
---  - {config} (table): copy of the table that was passed by the user
---    to |vim.lsp.start_client()|.
---
---  - {server_capabilities} (table): Response from the server sent on
---    `initialize` describing the server's capabilities.
---
---  - {resolved_capabilities} (table): Normalized table of
---    capabilities that we have detected based on the initialize
---    response from the server in `server_capabilities`.
function lsp.client()
  error()
end

-- FIXME: DOC: Currently all methods on the `vim.lsp.client` object are
-- documented twice: Here, and on the methods themselves (e.g.
-- `client.request()`). This is a workaround for the vimdoc generator script
-- not handling method names correctly. If you change the documentation on
-- either, please make sure to update the other as well.
--
--- Starts and initializes a client with the given configuration.
---
--- Parameters `cmd` and `root_dir` are required.
---
--- The following parameters describe fields in the {config} table.
---
--@param root_dir: (required, string) Directory where the LSP server will base
--- its rootUri on initialization.
---
--@param cmd: (required, string or list treated like |jobstart()|) Base command
--- that initiates the LSP client.
---
--@param cmd_cwd: (string, default=|getcwd()|) Directory to launch
--- the `cmd` process. Not related to `root_dir`.
---
--@param cmd_env: (table) Environment flags to pass to the LSP on
--- spawn.  Can be specified using keys like a map or as a list with `k=v`
--- pairs or both. Non-string values are coerced to string.
--- Example:
--- <pre>
--- { "PRODUCTION=true"; "TEST=123"; PORT = 8080; HOST = "0.0.0.0"; }
--- </pre>
---
--@param capabilities Map overriding the default capabilities defined by
--- |vim.lsp.protocol.make_client_capabilities()|, passed to the language
--- server on initialization. Hint: use make_client_capabilities() and modify
--- its result.
--- - Note: To send an empty dictionary use
---   `{[vim.type_idx]=vim.types.dictionary}`, else it will be encoded as an
---   array.
---
--@param handlers Map of language server method names to |lsp-handler|
---
--@param settings Map with language server specific settings. These are
--- returned to the language server if requested via `workspace/configuration`.
--- Keys are case-sensitive.
---
--@param init_options Values to pass in the initialization request
--- as `initializationOptions`. See `initialize` in the LSP spec.
---
--@param name (string, default=client-id) Name in log messages.
---
--@param offset_encoding (default="utf-16") One of "utf-8", "utf-16",
--- or "utf-32" which is the encoding that the LSP server expects. Client does
--- not verify this is correct.
---
--@param on_error Callback with parameters (code, ...), invoked
--- when the client operation throws an error. `code` is a number describing
--- the error. Other arguments may be passed depending on the error kind.  See
--- |vim.lsp.client_errors| for possible errors.
--- Use `vim.lsp.client_errors[code]` to get human-friendly name.
---
--@param before_init Callback with parameters (initialize_params, config)
--- invoked before the LSP "initialize" phase, where `params` contains the
--- parameters being sent to the server and `config` is the config that was
--- passed to |vim.lsp.start_client()|. You can use this to modify parameters before
--- they are sent.
---
--@param on_init Callback (client, initialize_result) invoked after LSP
--- "initialize", where `result` is a table of `capabilities` and anything else
--- the server may send. For example, clangd sends
--- `initialize_result.offsetEncoding` if `capabilities.offsetEncoding` was
--- sent to it. You can only modify the `client.offset_encoding` here before
--- any notifications are sent. Most language servers expect to be sent client specified settings after
--- initialization. Neovim does not make this assumption. A
--- `workspace/didChangeConfiguration` notification should be sent
---  to the server during on_init.
---
--@param on_exit Callback (code, signal, client_id) invoked on client
--- exit.
--- - code: exit code of the process
--- - signal: number describing the signal used to terminate (if any)
--- - client_id: client handle
---
--@param on_attach Callback (client, bufnr) invoked when client
--- attaches to a buffer.
---
--@param trace:  "off" | "messages" | "verbose" | nil passed directly to the language
--- server in the initialize request. Invalid/empty values will default to "off"
--@param flags: A table with flags for the client. The current (experimental) flags are:
--- - allow_incremental_sync (bool, default false): Allow using on_line callbacks for lsp
---
--- <pre>
--- -- In attach function for the client, you can do:
--- local custom_attach = function(client)
---   if client.config.flags then
---     client.config.flags.allow_incremental_sync = true
---   end
--- end
--- </pre>
---
--@returns Client id. |vim.lsp.get_client_by_id()| Note: client may not be
--- fully initialized. Use `on_init` to do any actions once
--- the client has been initialized.
function lsp.start_client(config)
  local cleaned_config = validate_client_config(config)
  local cmd, cmd_args, offset_encoding = cleaned_config.cmd, cleaned_config.cmd_args, cleaned_config.offset_encoding

  config.flags = config.flags or {}
  config.settings = config.settings or {}

  local client_id = next_client_id()

  local handlers = config.handlers or {}
  local name = config.name or tostring(client_id)
  local log_prefix = string.format("LSP[%s]", name)

  local dispatch = {}

  --@private
  --- Returns the handler associated with an LSP method.
  --- Returns the default handler if the user hasn't set a custom one.
  ---
  --@param method (string) LSP method name
  --@returns (fn) The handler for the given method, if defined, or the default from |vim.lsp.handlers|
  local function resolve_handler(method)
    return handlers[method] or default_handlers[method]
  end

  --@private
  --- Handles a notification sent by an LSP server by invoking the
  --- corresponding handler.
  ---
  --@param method (string) LSP method name
  --@param params (table) The parameters for that method.
  function dispatch.notification(method, params)
    local _ = log.debug() and log.debug('notification', method, params)
    local handler = resolve_handler(method)
    if handler then
      -- Method name is provided here for convenience.
      handler(nil, method, params, client_id)
    end
  end

  --@private
  --- Handles a request from an LSP server by invoking the corresponding handler.
  ---
  --@param method (string) LSP method name
  --@param params (table) The parameters for that method
  function dispatch.server_request(method, params)
    local _ = log.debug() and log.debug('server_request', method, params)
    local handler = resolve_handler(method)
    if handler then
      local _ = log.debug() and log.debug("server_request: found handler for", method)
      return handler(nil, method, params, client_id)
    end
    local _ = log.debug() and log.debug("server_request: no handler found for", method)
    return nil, lsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
  end

  --@private
  --- Invoked when the client operation throws an error.
  ---
  --@param code (number) Error code
  --@param err (...) Other arguments may be passed depending on the error kind
  --@see |vim.lsp.client_errors| for possible errors. Use
  ---`vim.lsp.client_errors[code]` to get a human-friendly name.
  function dispatch.on_error(code, err)
    local _ = log.error() and log.error(log_prefix, "on_error", { code = lsp.client_errors[code], err = err })
    err_message(log_prefix, ': Error ', lsp.client_errors[code], ': ', vim.inspect(err))
    if config.on_error then
      local status, usererr = pcall(config.on_error, code, err)
      if not status then
        local _ = log.error() and log.error(log_prefix, "user on_error failed", { err = usererr })
        err_message(log_prefix, ' user on_error failed: ', tostring(usererr))
      end
    end
  end

  --@private
  --- Invoked on client exit.
  ---
  --@param code (number) exit code of the process
  --@param signal (number) the signal used to terminate (if any)
  function dispatch.on_exit(code, signal)
    active_clients[client_id] = nil
    uninitialized_clients[client_id] = nil

    lsp.diagnostic.reset(client_id, all_buffer_active_clients)
    all_client_active_buffers[client_id] = nil
    for _, client_ids in pairs(all_buffer_active_clients) do
      client_ids[client_id] = nil
    end

    if code ~= 0 or (signal ~= 0 and signal ~= 15) then
      local msg = string.format("Client %s quit with exit code %s and signal %s", client_id, code, signal)
      vim.schedule(function()
        vim.notify(msg, vim.log.levels.WARN)
      end)
    end

    if config.on_exit then
      pcall(config.on_exit, code, signal, client_id)
    end
  end

  -- Start the RPC client.
  local rpc = lsp_rpc.start(cmd, cmd_args, dispatch, {
    cwd = config.cmd_cwd;
    env = config.cmd_env;
  })

  local client = {
    id = client_id;
    name = name;
    rpc = rpc;
    offset_encoding = offset_encoding;
    config = config;

    handlers = handlers;
    -- for $/progress report
    messages = { name = name, messages = {}, progress = {}, status = {} }
  }

  -- Store the uninitialized_clients for cleanup in case we exit before initialize finishes.
  uninitialized_clients[client_id] = client;

  --@private
  local function initialize()
    local valid_traces = {
      off = 'off'; messages = 'messages'; verbose = 'verbose';
    }
    local version = vim.version()
    local initialize_params = {
      -- The process Id of the parent process that started the server. Is null if
      -- the process has not been started by another process.  If the parent
      -- process is not alive then the server should exit (see exit notification)
      -- its process.
      processId = uv.getpid();
      -- Information about the client
      -- since 3.15.0
      clientInfo = {
        name = "Neovim",
        version = string.format("%s.%s.%s", version.major, version.minor, version.patch)
      };
      -- The rootPath of the workspace. Is null if no folder is open.
      --
      -- @deprecated in favour of rootUri.
      rootPath = config.root_dir;
      -- The rootUri of the workspace. Is null if no folder is open. If both
      -- `rootPath` and `rootUri` are set `rootUri` wins.
      rootUri = vim.uri_from_fname(config.root_dir);
      -- User provided initialization options.
      initializationOptions = config.init_options;
      -- The capabilities provided by the client (editor or tool)
      capabilities = config.capabilities or protocol.make_client_capabilities();
      -- The initial trace setting. If omitted trace is disabled ("off").
      -- trace = "off" | "messages" | "verbose";
      trace = valid_traces[config.trace] or 'off';
      -- The workspace folders configured in the client when the server starts.
      -- This property is only available if the client supports workspace folders.
      -- It can be `null` if the client supports workspace folders but none are
      -- configured.
      --
      -- Since 3.6.0
      -- workspaceFolders?: WorkspaceFolder[] | null;
      -- export interface WorkspaceFolder {
      --  -- The associated URI for this workspace folder.
      --  uri
      --  -- The name of the workspace folder. Used to refer to this
      --  -- workspace folder in the user interface.
      --  name
      -- }
      workspaceFolders = {{
        uri = vim.uri_from_fname(config.root_dir);
        name = string.format("%s", config.root_dir);
      }};
    }
    if config.before_init then
      -- TODO(ashkan) handle errors here.
      pcall(config.before_init, initialize_params, config)
    end
    local _ = log.debug() and log.debug(log_prefix, "initialize_params", initialize_params)
    rpc.request('initialize', initialize_params, function(init_err, result)
      assert(not init_err, tostring(init_err))
      assert(result, "server sent empty result")
      rpc.notify('initialized', {[vim.type_idx]=vim.types.dictionary})
      client.initialized = true
      uninitialized_clients[client_id] = nil
      client.workspaceFolders = initialize_params.workspaceFolders
      client.server_capabilities = assert(result.capabilities, "initialize result doesn't contain capabilities")
      -- These are the cleaned up capabilities we use for dynamically deciding
      -- when to send certain events to clients.
      client.resolved_capabilities = protocol.resolve_capabilities(client.server_capabilities)
      client.supports_method = function(method)
        local required_capability = lsp._request_name_to_capability[method]
        -- if we don't know about the method, assume that the client supports it.
        if not required_capability then
          return true
        end

        return client.resolved_capabilities[required_capability]
      end
      if config.on_init then
        local status, err = pcall(config.on_init, client, result)
        if not status then
          pcall(handlers.on_error, lsp.client_errors.ON_INIT_CALLBACK_ERROR, err)
        end
      end
      local _ = log.debug() and log.debug(log_prefix, "server_capabilities", client.server_capabilities)
      local _ = log.info() and log.info(log_prefix, "initialized", { resolved_capabilities = client.resolved_capabilities })

      -- Only assign after initialized.
      active_clients[client_id] = client
      -- If we had been registered before we start, then send didOpen This can
      -- happen if we attach to buffers before initialize finishes or if
      -- someone restarts a client.
      for bufnr, client_ids in pairs(all_buffer_active_clients) do
        if client_ids[client_id] then
          client._on_attach(bufnr)
        end
      end
    end)
  end

  --@private
  --- Sends a request to the server.
  ---
  --- This is a thin wrapper around {client.rpc.request} with some additional
  --- checks for capabilities and handler availability.
  ---
  --@param method (string) LSP method name.
  --@param params (table) LSP request params.
  --@param handler (function, optional) Response |lsp-handler| for this method.
  --@param bufnr (number) Buffer handle (0 for current).
  --@returns ({status}, [request_id]): {status} is a bool indicating
  ---whether the request was successful. If it is `false`, then it will
  ---always be `false` (the client has shutdown). If it was
  ---successful, then it will return {request_id} as the
  ---second result. You can use this with `client.cancel_request(request_id)`
  ---to cancel the-request.
  --@see |vim.lsp.buf_request()|
  function client.request(method, params, handler, bufnr)
    if not handler then
      handler = resolve_handler(method)
        or error(string.format("not found: %q request handler for client %q.", method, client.name))
    end
    local _ = log.debug() and log.debug(log_prefix, "client.request", client_id, method, params, handler, bufnr)
    return rpc.request(method, params, function(err, result)
      handler(err, method, result, client_id, bufnr)
    end)
  end

  --@private
  --- Sends a notification to an LSP server.
  ---
  --@param method (string) LSP method name.
  --@param params (optional, table) LSP request params.
  --@param bufnr (number) Buffer handle, or 0 for current.
  --@returns {status} (bool) true if the notification was successful.
  ---If it is false, then it will always be false
  ---(the client has shutdown).
  function client.notify(...)
    return rpc.notify(...)
  end

  --@private
  --- Cancels a request with a given request id.
  ---
  --@param id (number) id of request to cancel
  --@returns true if any client returns true; false otherwise
  --@see |vim.lsp.client.notify()|
  function client.cancel_request(id)
    validate{id = {id, 'n'}}
    return rpc.notify("$/cancelRequest", { id = id })
  end

  -- Track this so that we can escalate automatically if we've alredy tried a
  -- graceful shutdown
  local tried_graceful_shutdown = false
  --@private
  --- Stops a client, optionally with force.
  ---
  ---By default, it will just ask the - server to shutdown without force. If
  --- you request to stop a client which has previously been requested to
  --- shutdown, it will automatically escalate and force shutdown.
  ---
  --@param force (bool, optional)
  function client.stop(force)

    lsp.diagnostic.reset(client_id, all_buffer_active_clients)
    all_client_active_buffers[client_id] = nil
    for _, client_ids in pairs(all_buffer_active_clients) do
      client_ids[client_id] = nil
    end

    local handle = rpc.handle
    if handle:is_closing() then
      return
    end
    if force or (not client.initialized) or tried_graceful_shutdown then
      handle:kill(15)
      return
    end
    tried_graceful_shutdown = true
    -- Sending a signal after a process has exited is acceptable.
    rpc.request('shutdown', nil, function(err, _)
      if err == nil then
        rpc.notify('exit')
      else
        -- If there was an error in the shutdown request, then term to be safe.
        handle:kill(15)
      end
    end)
  end

  --@private
  --- Checks whether a client is stopped.
  ---
  --@returns (bool) true if client is stopped or in the process of being
  ---stopped; false otherwise
  function client.is_stopped()
    return rpc.handle:is_closing()
  end

  --@private
  --- Runs the on_attach function from the client's config if it was defined.
  --@param bufnr (number) Buffer number
  function client._on_attach(bufnr)
    text_document_did_open_handler(bufnr, client)
    if config.on_attach then
      -- TODO(ashkan) handle errors.
      pcall(config.on_attach, client, bufnr)
    end
  end

  initialize()

  return client_id
end

--@private
--- Memoizes a function. On first run, the function return value is saved and
--- immediately returned on subsequent runs.
---
--@param fn (function) Function to run
--@returns (function) Memoized function
local function once(fn)
  local value
  return function(...)
    if not value then value = fn(...) end
    return value
  end
end

--@private
--@fn text_document_did_change_handler(_, bufnr, changedtick, firstline, lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size)
--- Notify all attached clients that a buffer has changed.
local text_document_did_change_handler
do
  text_document_did_change_handler = function(_, bufnr, changedtick,
      firstline, lastline, new_lastline, old_byte_size, old_utf32_size,
      old_utf16_size)

    local _ = log.debug() and log.debug(
      string.format("on_lines bufnr: %s, changedtick: %s, firstline: %s, lastline: %s, new_lastline: %s, old_byte_size: %s, old_utf32_size: %s, old_utf16_size: %s",
      bufnr, changedtick, firstline, lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size),
      nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
    )

    -- Don't do anything if there are no clients attached.
    if tbl_isempty(all_buffer_active_clients[bufnr] or {}) then
      return
    end

    util.buf_versions[bufnr] = changedtick
    -- Lazy initialize these because clients may not even need them.
    local incremental_changes = once(function(client)
      local lines = nvim_buf_get_lines(bufnr, 0, -1, true)
      local startline =  math.min(firstline + 1, math.min(#client._cached_buffers[bufnr], #lines))
      local endline =  math.min(-(#lines - new_lastline), 0)
      local incremental_change = vim.lsp.util.compute_diff(client._cached_buffers[bufnr], lines, startline, endline)
      client._cached_buffers[bufnr] = lines
      return incremental_change
    end)
    local full_changes = once(function()
      return {
        text = buf_get_full_text(bufnr);
      };
    end)
    local uri = vim.uri_from_bufnr(bufnr)
    for_each_buffer_client(bufnr, function(client, _client_id)
      local allow_incremental_sync = if_nil(client.config.flags.allow_incremental_sync, false)

      local text_document_did_change = client.resolved_capabilities.text_document_did_change
      local changes
      if text_document_did_change == protocol.TextDocumentSyncKind.None then
        return
      --[=[ TODO(ashkan) there seem to be problems with the byte_sizes sent by
      -- neovim right now so only send the full content for now. In general, we
      -- can assume that servers *will* support both versions anyway, as there
      -- is no way to specify the sync capability by the client.
      -- See https://github.com/palantir/python-language-server/commit/cfd6675bc10d5e8dbc50fc50f90e4a37b7178821#diff-f68667852a14e9f761f6ebf07ba02fc8 for an example of pyls handling both.
      --]=]
      elseif not allow_incremental_sync or text_document_did_change == protocol.TextDocumentSyncKind.Full then
        changes = full_changes(client)
      elseif text_document_did_change == protocol.TextDocumentSyncKind.Incremental then
        changes = incremental_changes(client)
      end
      client.notify("textDocument/didChange", {
        textDocument = {
          uri = uri;
          version = changedtick;
        };
        contentChanges = { changes; }
      })
    end)
  end
end

-- Buffer lifecycle handler for textDocument/didSave
function lsp._text_document_did_save_handler(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  local text = once(buf_get_full_text)
  for_each_buffer_client(bufnr, function(client, _client_id)
    if client.resolved_capabilities.text_document_save then
      local included_text
      if client.resolved_capabilities.text_document_save_include_text then
        included_text = text()
      end
      client.notify('textDocument/didSave', {
        textDocument = {
          uri = uri;
        };
        text = included_text;
      })
    end
  end)
end

--- Implements the `textDocument/did…` notifications required to track a buffer
--- for any language server.
---
--- Without calling this, the server won't be notified of changes to a buffer.
---
--- @param bufnr (number) Buffer handle, or 0 for current
--- @param client_id (number) Client id
function lsp.buf_attach_client(bufnr, client_id)
  validate {
    bufnr     = {bufnr, 'n', true};
    client_id = {client_id, 'n'};
  }
  bufnr = resolve_bufnr(bufnr)
  local buffer_client_ids = all_buffer_active_clients[bufnr]
  -- This is our first time attaching to this buffer.
  if not buffer_client_ids then
    buffer_client_ids = {}
    all_buffer_active_clients[bufnr] = buffer_client_ids

    local uri = vim.uri_from_bufnr(bufnr)
    nvim_command(string.format("autocmd BufWritePost <buffer=%d> lua vim.lsp._text_document_did_save_handler(0)", bufnr))
    -- First time, so attach and set up stuff.
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = text_document_did_change_handler;
      on_detach = function()
        local params = { textDocument = { uri = uri; } }
        for_each_buffer_client(bufnr, function(client, _)
          if client.resolved_capabilities.text_document_open_close then
            client.notify('textDocument/didClose', params)
          end
          if client._cached_buffers then
            client._cached_buffers[bufnr] = nil
          end
        end)
        util.buf_versions[bufnr] = nil
        all_buffer_active_clients[bufnr] = nil
      end;
      -- TODO if we know all of the potential clients ahead of time, then we
      -- could conditionally set this.
      --      utf_sizes = size_index > 1;
      utf_sizes = true;
    })
  end

  if not all_client_active_buffers[client_id] then
    all_client_active_buffers[client_id] = {}
  end

  table.insert(all_client_active_buffers[client_id], bufnr)

  if buffer_client_ids[client_id] then return end
  -- This is our first time attaching this client to this buffer.
  buffer_client_ids[client_id] = true

  local client = active_clients[client_id]
  -- Send didOpen for the client if it is initialized. If it isn't initialized
  -- then it will send didOpen on initialize.
  if client then
    client._on_attach(bufnr)
  end
  return true
end

--- Checks if a buffer is attached for a particular client.
---
---@param bufnr (number) Buffer handle, or 0 for current
---@param client_id (number) the client id
function lsp.buf_is_attached(bufnr, client_id)
  return (all_buffer_active_clients[bufnr] or {})[client_id] == true
end

--- Gets a client by id, or nil if the id is invalid.
--- The returned client may not yet be fully initialized.
--
--@param client_id client id number
---
--@returns |vim.lsp.client| object, or nil
function lsp.get_client_by_id(client_id)
  return active_clients[client_id] or uninitialized_clients[client_id]
end

--- Returns list of buffers attached to client_id.
--
--@param client_id client id
--@returns list of buffer ids
function lsp.get_buffers_by_client_id(client_id)
  local active_client_buffers = all_client_active_buffers[client_id]
  if active_client_buffers then
    return active_client_buffers
  else
    return {}
  end
end

--- Stops a client(s).
---
--- You can also use the `stop()` function on a |vim.lsp.client| object.
--- To stop all clients:
---
--- <pre>
--- vim.lsp.stop_client(vim.lsp.get_active_clients())
--- </pre>
---
--- By default asks the server to shutdown, unless stop was requested
--- already for this client, then force-shutdown is attempted.
---
--@param client_id client id or |vim.lsp.client| object, or list thereof
--@param force boolean (optional) shutdown forcefully
function lsp.stop_client(client_id, force)
  local ids = type(client_id) == 'table' and client_id or {client_id}
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

--- Gets all active clients.
---
--@returns Table of |vim.lsp.client| objects
function lsp.get_active_clients()
  return vim.tbl_values(active_clients)
end

function lsp._vim_exit_handler()
  log.info("exit_handler", active_clients)
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

  if not vim.wait(500, function() return tbl_isempty(active_clients) end, 50) then
    for _, client in pairs(active_clients) do
      client.stop(true)
    end
  end
end

nvim_command("autocmd VimLeavePre * lua vim.lsp._vim_exit_handler()")


--- Sends an async request for all active clients attached to the
--- buffer.
---
--@param bufnr (number) Buffer handle, or 0 for current.
--@param method (string) LSP method name
--@param params (optional, table) Parameters to send to the server
--@param handler (optional, function) See |lsp-handler|
--  If nil, follows resolution strategy defined in |lsp-handler-configuration|
--
--@returns 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function lsp.buf_request(bufnr, method, params, handler)
  validate {
    bufnr    = { bufnr, 'n', true };
    method   = { method, 's' };
    handler  = { handler, 'f', true };
  }
  local client_request_ids = {}

  local method_supported = false
  for_each_buffer_client(bufnr, function(client, client_id, resolved_bufnr)
    if client.supports_method(method) then
      method_supported = true
      local request_success, request_id = client.request(method, params, handler, resolved_bufnr)

      -- This could only fail if the client shut down in the time since we looked
      -- it up and we did the request, which should be rare.
      if request_success then
        client_request_ids[client_id] = request_id
      end
    end
  end)

  -- if has client but no clients support the given method, call the callback with the proper
  -- error message.
  if not tbl_isempty(all_buffer_active_clients[resolve_bufnr(bufnr)] or {}) and not method_supported then
    local unsupported_err = lsp._unsupported_method(method)
    handler = handler or lsp.handlers[method]
    if handler then
      handler(unsupported_err, method, bufnr)
    end
    return
  end

  local function _cancel_all_requests()
    for client_id, request_id in pairs(client_request_ids) do
      local client = active_clients[client_id]
      client.cancel_request(request_id)
    end
  end

  return client_request_ids, _cancel_all_requests
end

--- Sends a request to a server and waits for the response.
---
--- Calls |vim.lsp.buf_request()| but blocks Nvim while awaiting the result.
--- Parameters are the same as |vim.lsp.buf_request()| but the return result is
--- different. Wait maximum of {timeout_ms} (default 100) ms.
---
--@param bufnr (number) Buffer handle, or 0 for current.
--@param method (string) LSP method name
--@param params (optional, table) Parameters to send to the server
--@param timeout_ms (optional, number, default=100) Maximum time in
---      milliseconds to wait for a result.
---
--@returns Map of client_id:request_result. On timeout, cancel or error,
---        returns `(nil, err)` where `err` is a string describing the failure
---        reason.
function lsp.buf_request_sync(bufnr, method, params, timeout_ms)
  local request_results = {}
  local result_count = 0
  local function _sync_handler(err, _, result, client_id)
    request_results[client_id] = { error = err, result = result }
    result_count = result_count + 1
  end
  local client_request_ids, cancel = lsp.buf_request(bufnr, method, params, _sync_handler)
  local expected_result_count = 0
  for _ in pairs(client_request_ids) do
    expected_result_count = expected_result_count + 1
  end

  local wait_result, reason = vim.wait(timeout_ms or 100, function()
    return result_count >= expected_result_count
  end, 10)

  if not wait_result then
    cancel()
    return nil, wait_result_reason[reason]
  end
  return request_results
end

--- Send a notification to a server
--@param bufnr [number] (optional): The number of the buffer
--@param method [string]: Name of the request method
--@param params [string]: Arguments to send to the server
---
--@returns true if any client returns true; false otherwise
function lsp.buf_notify(bufnr, method, params)
  validate {
    bufnr    = { bufnr, 'n', true };
    method   = { method, 's' };
  }
  local resp = false
  for_each_buffer_client(bufnr, function(client, _client_id, _resolved_bufnr)
    if client.rpc.notify(method, params) then resp = true end
  end)
  return resp
end

--- Implements 'omnifunc' compatible LSP completion.
---
--@see |complete-functions|
--@see |complete-items|
--@see |CompleteDone|
---
--@param findstart 0 or 1, decides behavior
--@param base If findstart=0, text to match against
---
--@returns (number) Decided by `findstart`:
--- - findstart=0: column where the completion starts, or -2 or -3
--- - findstart=1: list of matches (actually just calls |complete()|)
function lsp.omnifunc(findstart, base)
  local _ = log.debug() and log.debug("omnifunc.findstart", { findstart = findstart, base = base })

  local bufnr = resolve_bufnr()
  local has_buffer_clients = not tbl_isempty(all_buffer_active_clients[bufnr] or {})
  if not has_buffer_clients then
    if findstart == 1 then
      return -1
    else
      return {}
    end
  end

  -- Then, perform standard completion request
  local _ = log.info() and log.info("base ", base)

  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])
  local _ = log.trace() and log.trace("omnifunc.line", pos, line)

  -- Get the start position of the current keyword
  local textMatch = vim.fn.match(line_to_cursor, '\\k*$')
  local prefix = line_to_cursor:sub(textMatch+1)

  local params = util.make_position_params()

  local items = {}
  lsp.buf_request(bufnr, 'textDocument/completion', params, function(err, _, result)
    if err or not result then return end
    local matches = util.text_document_completion_list_to_complete_items(result, prefix)
    -- TODO(ashkan): is this the best way to do this?
    vim.list_extend(items, matches)
    vim.fn.complete(textMatch+1, items)
  end)

  -- Return -2 to signal that we should continue completion so that we can
  -- async complete.
  return -2
end

---Checks whether a client is stopped.
---
--@param client_id (Number)
--@returns true if client is stopped, false otherwise.
function lsp.client_is_stopped(client_id)
  return active_clients[client_id] == nil
end

--- Gets a map of client_id:client pairs for the given buffer, where each value
--- is a |vim.lsp.client| object.
---
--@param bufnr (optional, number): Buffer handle, or 0 for current
function lsp.buf_get_clients(bufnr)
  bufnr = resolve_bufnr(bufnr)
 local result = {}
 for_each_buffer_client(bufnr, function(client, client_id)
   result[client_id] = client
 end)
 return result
end

-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the
-- name from the number.
-- Levels by name: "trace", "debug", "info", "warn", "error"
-- Level numbers begin with "trace" at 0
lsp.log_levels = log.levels

--- Sets the global log level for LSP logging.
---
--- Levels by name: "trace", "debug", "info", "warn", "error"
--- Level numbers begin with "trace" at 0
---
--- Use `lsp.log_levels` for reverse lookup.
---
--@see |vim.lsp.log_levels|
---
--@param level [number|string] the case insensitive level name or number
function lsp.set_log_level(level)
  if type(level) == 'string' or type(level) == 'number' then
    log.set_level(level)
  else
    error(string.format("Invalid log level: %q", level))
  end
end

--- Gets the path of the logfile used by the LSP client.
--@returns (String) Path to logfile.
function lsp.get_log_path()
  return log.get_filename()
end

--- Call {fn} for every client attached to {bufnr}
function lsp.for_each_buffer_client(bufnr, fn)
  return for_each_buffer_client(bufnr, fn)
end

--- Function to manage overriding defaults for LSP handlers.
--@param handler (function) See |lsp-handler|
--@param override_config (table) Table containing the keys to override behavior of the {handler}
function lsp.with(handler, override_config)
  return function(err, method, params, client_id, bufnr, config)
    return handler(err, method, params, client_id, bufnr, vim.tbl_deep_extend("force", config or {}, override_config))
  end
end

--- Helper function to use when implementing a handler.
--- This will check that all of the keys in the user configuration
--- are valid keys and make sense to include for this handler.
---
--- Will error on invalid keys (i.e. keys that do not exist in the options)
function lsp._with_extend(name, options, user_config)
  user_config = user_config or {}

  local resulting_config = {}
  for k, v in pairs(user_config) do
    if options[k] == nil then
      error(debug.traceback(string.format(
        "Invalid option for `%s`: %s. Valid options are:\n%s",
        name,
        k,
        vim.inspect(vim.tbl_keys(options))
      )))
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

-- Define the LspDiagnostics signs if they're not defined already.
require('vim.lsp.diagnostic')._define_default_signs_and_highlights()

return lsp
-- vim:sw=2 ts=2 et
