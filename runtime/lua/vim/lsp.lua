local builtin_callbacks = require 'vim.lsp.builtin_callbacks'
local log = require 'vim.lsp.log'
local lsp_rpc = require 'vim.lsp.rpc'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'

local nvim_err_writeln, nvim_buf_get_lines, nvim_command, nvim_buf_get_option
  = vim.api.nvim_err_writeln, vim.api.nvim_buf_get_lines, vim.api.nvim_command, vim.api.nvim_buf_get_option
local uv = vim.loop
local tbl_isempty, tbl_extend = vim.tbl_isempty, vim.tbl_extend
local validate = vim.validate

local lsp = {
  protocol = protocol;
  builtin_callbacks = builtin_callbacks;
  util = util;
  -- Allow raw RPC access.
  rpc = lsp_rpc;
  -- Export these directly from rpc.
  rpc_response_error = lsp_rpc.rpc_response_error;
  -- You probably won't need this directly, since __tostring is set for errors
  -- by the RPC.
  -- format_rpc_error = lsp_rpc.format_rpc_error;
}

-- TODO consider whether 'eol' or 'fixeol' should change the nvim_buf_get_lines that send.
-- TODO improve handling of scratch buffers with LSP attached.

local function resolve_bufnr(bufnr)
  validate { bufnr = { bufnr, 'n', true } }
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function is_dir(filename)
  validate{filename={filename,'s'}}
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

-- TODO Use vim.wait when that is available, but provide an alternative for now.
local wait = vim.wait or function(timeout_ms, condition, interval)
  validate {
    timeout_ms = { timeout_ms, 'n' };
    condition = { condition, 'f' };
    interval = { interval, 'n', true };
  }
  assert(timeout_ms > 0, "timeout_ms must be > 0")
  local _ = log.debug() and log.debug("wait.fallback", timeout_ms)
  interval = interval or 200
  local interval_cmd = "sleep "..interval.."m"
  local timeout = timeout_ms + uv.now()
  -- TODO is there a better way to sync this?
  while true do
    uv.update_time()
    if condition() then
      return 0
    end
    if uv.now() >= timeout then
      return -1
    end
    nvim_command(interval_cmd)
    -- vim.loop.sleep(10)
  end
end
local wait_result_reason = { [-1] = "timeout"; [-2] = "interrupted"; [-3] = "error" }

local valid_encodings = {
  ["utf-8"] = 'utf-8'; ["utf-16"] = 'utf-16'; ["utf-32"] = 'utf-32';
  ["utf8"]  = 'utf-8'; ["utf16"]  = 'utf-16'; ["utf32"]  = 'utf-32';
  UTF8      = 'utf-8'; UTF16      = 'utf-16'; UTF32      = 'utf-32';
}

local client_index = 0
local function next_client_id()
  client_index = client_index + 1
  return client_index
end
-- Tracks all clients created via lsp.start_client
local active_clients = {}
local all_buffer_active_clients = {}
local uninitialized_clients = {}

local function for_each_buffer_client(bufnr, callback)
  validate {
    callback = { callback, 'f' };
  }
  bufnr = resolve_bufnr(bufnr)
  local client_ids = all_buffer_active_clients[bufnr]
  if not client_ids or tbl_isempty(client_ids) then
    return
  end
  for client_id in pairs(client_ids) do
    -- This is unlikely to happen. Could only potentially happen in a race
    -- condition between literally a single statement.
    -- We could skip this error, but let's error for now.
    local client = active_clients[client_id]
        -- or error(string.format("Client %d has already shut down.", client_id))
    if client then
      callback(client, client_id)
    end
  end
end

-- Error codes to be used with `on_error` from |vim.lsp.start_client|.
-- Can be used to look up the string from a the number or the number
-- from the string.
lsp.client_errors = tbl_extend("error", lsp_rpc.client_errors, vim.tbl_add_reverse_lookup {
  ON_INIT_CALLBACK_ERROR = table.maxn(lsp_rpc.client_errors) + 1;
})

local function validate_encoding(encoding)
  validate {
    encoding = { encoding, 's' };
  }
  return valid_encodings[encoding:lower()]
      or error(string.format("Invalid offset encoding %q. Must be one of: 'utf-8', 'utf-16', 'utf-32'", encoding))
end

local function validate_command(input)
  local cmd, cmd_args
  if type(input) == 'string' then
    -- Use a shell to execute the command if it is a string.
    cmd = vim.api.nvim_get_option('shell')
    cmd_args = {vim.api.nvim_get_option('shellcmdflag'), input}
  elseif vim.tbl_islist(input) then
    cmd = input[1]
    cmd_args = {}
    -- Don't mutate our input.
    for i, v in ipairs(input) do
      assert(type(v) == 'string', "input arguments must be strings")
      if i > 1 then
        table.insert(cmd_args, v)
      end
    end
  else
    error("cmd type must be string or list.")
  end
  return cmd, cmd_args
end

local function optional_validator(fn)
  return function(v)
    return v == nil or fn(v)
  end
end

local function validate_client_config(config)
  validate {
    config = { config, 't' };
  }
  validate {
    root_dir        = { config.root_dir, is_dir, "directory" };
    callbacks       = { config.callbacks, "t", true };
    capabilities    = { config.capabilities, "t", true };
    -- cmd             = { config.cmd, "s", false };
    cmd_cwd         = { config.cmd_cwd, optional_validator(is_dir), "directory" };
    cmd_env         = { config.cmd_env, "f", true };
    name            = { config.name, 's', true };
    on_error        = { config.on_error, "f", true };
    on_exit         = { config.on_exit, "f", true };
    on_init         = { config.on_init, "f", true };
    offset_encoding = { config.offset_encoding, "s", true };
  }
  local cmd, cmd_args = validate_command(config.cmd)
  local offset_encoding = valid_encodings.UTF16
  if config.offset_encoding then
    offset_encoding = validate_encoding(config.offset_encoding)
  end
  return {
    cmd = cmd; cmd_args = cmd_args;
    offset_encoding = offset_encoding;
  }
end

local function text_document_did_open_handler(bufnr, client)
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
      text = table.concat(nvim_buf_get_lines(bufnr, 0, -1, false), '\n');
    }
  }
  client.notify('textDocument/didOpen', params)
end


--- Start a client and initialize it.
-- Its arguments are passed via a configuration object.
--
-- Mandatory parameters:
--
-- root_dir: {string} specifying the directory where the LSP server will base
-- as its rootUri on initialization.
--
-- cmd: {string} or {list} which is the base command to execute for the LSP. A
-- string will be run using |'shell'| and a list will be interpreted as a bare
-- command with arguments passed. This is the same as |jobstart()|.
--
-- Optional parameters:

-- cmd_cwd: {string} specifying the directory to launch the `cmd` process. This
-- is not related to `root_dir`. By default, |getcwd()| is used.
--
-- cmd_env: {table} specifying the environment flags to pass to the LSP on
-- spawn.  This can be specified using keys like a map or as a list with `k=v`
-- pairs or both. Non-string values are coerced to a string.
-- For example: `{ "PRODUCTION=true"; "TEST=123"; PORT = 8080; HOST = "0.0.0.0"; }`.
--
-- capabilities: A {table} which will be used instead of
-- `vim.lsp.protocol.make_client_capabilities()` which contains neovim's
-- default capabilities and passed to the language server on initialization.
-- You'll probably want to use make_client_capabilities() and modify the
-- result.
-- NOTE:
--   To send an empty dictionary, you should use
--   `{[vim.type_idx]=vim.types.dictionary}` Otherwise, it will be encoded as
--   an array.
--
-- callbacks: A {table} of whose keys are language server method names and the
-- values are `function(err, method, params, client_id)`.
-- This will be called for:
-- - notifications from the server, where `err` will always be `nil`
-- - requests initiated by the server. For these, you can respond by returning
-- two values: `result, err`. The err must be in the format of an RPC error,
-- which is `{ code, message, data? }`. You can use |vim.lsp.rpc_response_error()|
-- to help with this.
-- - as a callback for requests initiated by the client if the request doesn't
-- explicitly specify a callback.
--
-- init_options: A {table} of values to pass in the initialization request
-- as `initializationOptions`. See the `initialize` in the LSP spec.
--
-- name: A {string} used in log messages. Defaults to {client_id}
--
-- offset_encoding: One of 'utf-8', 'utf-16', or 'utf-32' which is the
-- encoding that the LSP server expects. By default, it is 'utf-16' as
-- specified in the LSP specification. The client does not verify this
-- is correct.
--
-- on_error(code, ...): A function for handling errors thrown by client
-- operation. {code} is a number describing the error. Other arguments may be
-- passed depending on the error kind.  @see |vim.lsp.client_errors| for
-- possible errors. `vim.lsp.client_errors[code]` can be used to retrieve a
-- human understandable string.
--
-- on_init(client, initialize_result): A function which is called after the
-- request `initialize` is completed. `initialize_result` contains
-- `capabilities` and anything else the server may send. For example, `clangd`
-- sends `result.offsetEncoding` if `capabilities.offsetEncoding` was sent to
-- it.
--
-- on_exit(code, signal, client_id): A function which is called after the
-- client has exited. code is the exit code of the process, and signal is a
-- number describing the signal used to terminate (if any).
--
-- on_attach(client, bufnr): A function which is called after the client is
-- attached to a buffer.
--
-- trace:  'off' | 'messages' | 'verbose' | nil passed directly to the language
-- server in the initialize request. Invalid/empty values will default to 'off'
--
-- @returns client_id You can use |vim.lsp.get_client_by_id()| to get the
-- actual client.
--
-- NOTE: The client is only available *after* it has been initialized, which
-- may happen after a small delay (or never if there is an error).
-- For this reason, you may want to use `on_init` to do any actions once the
-- client has been initialized.
function lsp.start_client(config)
  local cleaned_config = validate_client_config(config)
  local cmd, cmd_args, offset_encoding = cleaned_config.cmd, cleaned_config.cmd_args, cleaned_config.offset_encoding

  local client_id = next_client_id()

  local callbacks = tbl_extend("keep", config.callbacks or {}, builtin_callbacks)
  -- Copy metatable if it has one.
  if config.callbacks and config.callbacks.__metatable then
    setmetatable(callbacks, getmetatable(config.callbacks))
  end
  local name = config.name or tostring(client_id)
  local log_prefix = string.format("LSP[%s]", name)

  local handlers = {}

  function handlers.notification(method, params)
    local _ = log.debug() and log.debug('notification', method, params)
    local callback = callbacks[method]
    if callback then
      -- Method name is provided here for convenience.
      callback(nil, method, params, client_id)
    end
  end

  function handlers.server_request(method, params)
    local _ = log.debug() and log.debug('server_request', method, params)
    local callback = callbacks[method]
    if callback then
      local _ = log.debug() and log.debug("server_request: found callback for", method)
      return callback(nil, method, params, client_id)
    end
    local _ = log.debug() and log.debug("server_request: no callback found for", method)
    return nil, lsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
  end

  function handlers.on_error(code, err)
    local _ = log.error() and log.error(log_prefix, "on_error", { code = lsp.client_errors[code], err = err })
    nvim_err_writeln(string.format('%s: Error %s: %q', log_prefix, lsp.client_errors[code], vim.inspect(err)))
    if config.on_error then
      local status, usererr = pcall(config.on_error, code, err)
      if not status then
        local _ = log.error() and log.error(log_prefix, "user on_error failed", { err = usererr })
        nvim_err_writeln(log_prefix.." user on_error failed: "..tostring(usererr))
      end
    end
  end

  function handlers.on_exit(code, signal)
    active_clients[client_id] = nil
    uninitialized_clients[client_id] = nil
    for _, client_ids in pairs(all_buffer_active_clients) do
      client_ids[client_id] = nil
    end
    if config.on_exit then
      pcall(config.on_exit, code, signal, client_id)
    end
  end

  -- Start the RPC client.
  local rpc = lsp_rpc.start(cmd, cmd_args, handlers, {
    cwd = config.cmd_cwd;
    env = config.cmd_env;
  })

  local client = {
    id = client_id;
    name = name;
    rpc = rpc;
    offset_encoding = offset_encoding;
    callbacks = callbacks;
    config = config;
  }

  -- Store the uninitialized_clients for cleanup in case we exit before
  -- initialize finishes.
  uninitialized_clients[client_id] = client;

  local function initialize()
    local valid_traces = {
      off = 'off'; messages = 'messages'; verbose = 'verbose';
    }
    local initialize_params = {
      -- The process Id of the parent process that started the server. Is null if
      -- the process has not been started by another process.  If the parent
      -- process is not alive then the server should exit (see exit notification)
      -- its process.
      processId = uv.getpid();
      -- The rootPath of the workspace. Is null if no folder is open.
      --
      -- @deprecated in favour of rootUri.
      rootPath = nil;
      -- The rootUri of the workspace. Is null if no folder is open. If both
      -- `rootPath` and `rootUri` are set `rootUri` wins.
      rootUri = vim.uri_from_fname(config.root_dir);
--      rootUri = vim.uri_from_fname(vim.fn.expand("%:p:h"));
      -- User provided initialization options.
      initializationOptions = config.init_options;
      -- The capabilities provided by the client (editor or tool)
      capabilities = config.capabilities or protocol.make_client_capabilities();
      -- The initial trace setting. If omitted trace is disabled ('off').
      -- trace = 'off' | 'messages' | 'verbose';
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
      workspaceFolders = nil;
    }
    local _ = log.debug() and log.debug(log_prefix, "initialize_params", initialize_params)
    rpc.request('initialize', initialize_params, function(init_err, result)
      assert(not init_err, tostring(init_err))
      assert(result, "server sent empty result")
      rpc.notify('initialized', {})
      client.initialized = true
      uninitialized_clients[client_id] = nil
      client.server_capabilities = assert(result.capabilities, "initialize result doesn't contain capabilities")
      -- These are the cleaned up capabilities we use for dynamically deciding
      -- when to send certain events to clients.
      client.resolved_capabilities = protocol.resolve_capabilities(client.server_capabilities)
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

  local function unsupported_method(method)
    local msg = "server doesn't support "..method
    local _ = log.warn() and log.warn(msg)
    nvim_err_writeln(msg)
    return lsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound, msg)
  end

  --- Checks capabilities before rpc.request-ing.
  function client.request(method, params, callback)
    if not callback then
      callback = client.callbacks[method]
        or error(string.format("request callback is empty and no default was found for client %s", client.name))
    end
    local _ = log.debug() and log.debug(log_prefix, "client.request", client_id, method, params, callback)
    -- TODO keep these checks or just let it go anyway?
    if (not client.resolved_capabilities.hover and method == 'textDocument/hover')
      or (not client.resolved_capabilities.signature_help and method == 'textDocument/signatureHelp')
      or (not client.resolved_capabilities.goto_definition and method == 'textDocument/definition')
      or (not client.resolved_capabilities.implementation and method == 'textDocument/implementation')
    then
      callback(unsupported_method(method), method, nil, client_id)
      return
    end
    return rpc.request(method, params, function(err, result)
      callback(err, method, result, client_id)
    end)
  end

  function client.notify(...)
    return rpc.notify(...)
  end

  function client.cancel_request(id)
    validate{id = {id, 'n'}}
    return rpc.notify("$/cancelRequest", { id = id })
  end

  -- Track this so that we can escalate automatically if we've alredy tried a
  -- graceful shutdown
  local tried_graceful_shutdown = false
  function client.stop(force)
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

  function client.is_stopped()
    return rpc.handle:is_closing()
  end

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

local function once(fn)
  local value
  return function(...)
    if not value then value = fn(...) end
    return value
  end
end

local text_document_did_change_handler
do
  local encoding_index = { ["utf-8"] = 1; ["utf-16"] = 2; ["utf-32"] = 3; }
  text_document_did_change_handler = function(_, bufnr, changedtick,
      firstline, lastline, new_lastline, old_byte_size, old_utf32_size,
      old_utf16_size)
    local _ = log.debug() and log.debug("on_lines", bufnr, changedtick, firstline,
    lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size, nvim_buf_get_lines(bufnr, firstline, new_lastline, true))
    if old_byte_size == 0 then
      return
    end
    -- Don't do anything if there are no clients attached.
    if tbl_isempty(all_buffer_active_clients[bufnr] or {}) then
      return
    end
    -- Lazy initialize these because clients may not even need them.
    local incremental_changes = once(function(client)
      local size_index = encoding_index[client.offset_encoding]
      local length = select(size_index, old_byte_size, old_utf16_size, old_utf32_size)
      local lines = nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
      -- This is necessary because we are specifying the full line including the
      -- newline in range. Therefore, we must replace the newline as well.
      if #lines > 0 then
       table.insert(lines, '')
      end
      return {
        range = {
          start = { line = firstline, character = 0 };
          ["end"] = { line = lastline, character = 0 };
        };
        rangeLength = length;
        text = table.concat(lines, '\n');
      };
    end)
    local full_changes = once(function()
      return {
        text = table.concat(nvim_buf_get_lines(bufnr, 0, -1, false), "\n");
      };
    end)
    local uri = vim.uri_from_bufnr(bufnr)
    for_each_buffer_client(bufnr, function(client, _client_id)
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
      elseif true or text_document_did_change == protocol.TextDocumentSyncKind.Full then
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
  local text = once(function()
    return table.concat(nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  end)
  for_each_buffer_client(bufnr, function(client, _client_id)
    if client.resolved_capabilities.text_document_save then
      local included_text
      if client.resolved_capabilities.text_document_save_include_text then
        included_text = text()
      end
      client.notify('textDocument/didSave', {
        textDocument = {
          uri = uri;
          text = included_text;
        }
      })
    end
  end)
end

-- Implements the textDocument/did* notifications required to track a buffer
-- for any language server.
-- @param bufnr [number] buffer handle or 0 for current
-- @param client_id [number] the client id
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
        for_each_buffer_client(bufnr, function(client, _client_id)
          if client.resolved_capabilities.text_document_open_close then
            client.notify('textDocument/didClose', params)
          end
        end)
        all_buffer_active_clients[bufnr] = nil
      end;
      -- TODO if we know all of the potential clients ahead of time, then we
      -- could conditionally set this.
      --      utf_sizes = size_index > 1;
      utf_sizes = true;
    })
  end
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

-- Check if a buffer is attached for a particular client.
-- @param bufnr [number] buffer handle or 0 for current
-- @param client_id [number] the client id
function lsp.buf_is_attached(bufnr, client_id)
  return (all_buffer_active_clients[bufnr] or {})[client_id] == true
end

-- Look up an active client by its id, returns nil if it is not yet initialized
-- or is not a valid id.
-- @param client_id number the client id.
function lsp.get_client_by_id(client_id)
  return active_clients[client_id]
end

-- Stop a client by its id, optionally with force.
-- You can also use the `stop()` function on a client if you already have
-- access to it.
-- By default, it will just ask the server to shutdown without force.
-- If you request to stop a client which has previously been requested to shutdown,
-- it will automatically force shutdown.
-- @param client_id number the client id.
-- @param force boolean (optional) whether to use force or request shutdown
function lsp.stop_client(client_id, force)
  local client
  client = active_clients[client_id]
  if client then
    client.stop(force)
    return
  end
  client = uninitialized_clients[client_id]
  if client then
    client.stop(true)
  end
end

-- Returns a list of all the active clients.
function lsp.get_active_clients()
  return vim.tbl_values(active_clients)
end

-- Stop all the clients, optionally with force.
-- You can also use the `stop()` function on a client if you already have
-- access to it.
-- By default, it will just ask the server to shutdown without force.
-- If you request to stop a client which has previously been requested to shutdown,
-- it will automatically force shutdown.
-- @param force boolean (optional) whether to use force or request shutdown
function lsp.stop_all_clients(force)
  for _, client in pairs(uninitialized_clients) do
    client.stop(true)
  end
  for _, client in pairs(active_clients) do
    client.stop(force)
  end
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
  local wait_result = wait(500, function() return tbl_isempty(active_clients) end, 50)
  if wait_result ~= 0 then
    for _, client in pairs(active_clients) do
      client.stop(true)
    end
  end
end

nvim_command("autocmd VimLeavePre * lua vim.lsp._vim_exit_handler()")

---
--- Buffer level client functions.
---

--- Send a request to a server and return the response
-- @param bufnr [number] Buffer handle or 0 for current.
-- @param method [string] Request method name
-- @param params [table|nil] Parameters to send to the server
-- @param callback [function|nil] Request callback (or uses the client's callbacks)
--
-- @returns: client_request_ids, cancel_all_requests
function lsp.buf_request(bufnr, method, params, callback)
  validate {
    bufnr    = { bufnr, 'n', true };
    method   = { method, 's' };
    callback = { callback, 'f', true };
  }
  local client_request_ids = {}
  for_each_buffer_client(bufnr, function(client, client_id)
    local request_success, request_id = client.request(method, params, callback)

    -- This could only fail if the client shut down in the time since we looked
    -- it up and we did the request, which should be rare.
    if request_success then
      client_request_ids[client_id] = request_id
    end
  end)

  local function cancel_all_requests()
    for client_id, request_id in pairs(client_request_ids) do
      local client = active_clients[client_id]
      client.cancel_request(request_id)
    end
  end

  return client_request_ids, cancel_all_requests
end

--- Send a request to a server and wait for the response.
-- @param bufnr [number] Buffer handle or 0 for current.
-- @param method [string] Request method name
-- @param params [string] Parameters to send to the server
-- @param timeout_ms [number|100] Maximum ms to wait for a result
--
-- @returns: The table of {[client_id] = request_result}
function lsp.buf_request_sync(bufnr, method, params, timeout_ms)
  local request_results = {}
  local result_count = 0
  local function callback(err, _method, result, client_id)
    request_results[client_id] = { error = err, result = result }
    result_count = result_count + 1
  end
  local client_request_ids, cancel = lsp.buf_request(bufnr, method, params, callback)
  local expected_result_count = 0
  for _ in pairs(client_request_ids) do
    expected_result_count = expected_result_count + 1
  end
  local wait_result = wait(timeout_ms or 100, function()
    return result_count >= expected_result_count
  end, 10)
  if wait_result ~= 0 then
    cancel()
    return nil, wait_result_reason[wait_result]
  end
  return request_results
end

--- Send a notification to a server
-- @param bufnr [number] (optional): The number of the buffer
-- @param method [string]: Name of the request method
-- @param params [string]: Arguments to send to the server
--
-- @returns nil
function lsp.buf_notify(bufnr, method, params)
  validate {
    bufnr    = { bufnr, 'n', true };
    method   = { method, 's' };
  }
  for_each_buffer_client(bufnr, function(client, _client_id)
    client.rpc.notify(method, params)
  end)
end

--- Function which can be called to generate omnifunc compatible completion.
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

  if findstart == 1 then
    return vim.fn.col('.')
  else
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = assert(nvim_buf_get_lines(bufnr, pos[1]-1, pos[1], false)[1])
    local _ = log.trace() and log.trace("omnifunc.line", pos, line)
    local line_to_cursor = line:sub(1, pos[2]+1)
    local _ = log.trace() and log.trace("omnifunc.line_to_cursor", line_to_cursor)
    local params = {
      textDocument = {
        uri = vim.uri_from_bufnr(bufnr);
      };
      position = {
        -- 0-indexed for both line and character
        line = pos[1] - 1,
        character = pos[2],
      };
      -- The completion context. This is only available if the client specifies
      -- to send this using `ClientCapabilities.textDocument.completion.contextSupport === true`
      -- context = nil or {
      --  triggerKind = protocol.CompletionTriggerKind.Invoked;
      --  triggerCharacter = nil or "";
      -- };
    }
    -- TODO handle timeout error differently? Like via an error?
    local client_responses = lsp.buf_request_sync(bufnr, 'textDocument/completion', params) or {}
    local matches = {}
    for _, response in pairs(client_responses) do
      -- TODO how to handle errors?
      if not response.error then
        local data = response.result
        local completion_items = util.text_document_completion_list_to_complete_items(data or {}, line_to_cursor)
        local _ = log.trace() and log.trace("omnifunc.completion_items", completion_items)
        vim.list_extend(matches, completion_items)
      end
    end
    return matches
  end
end

---
--- FileType based configuration utility
---

local all_filetype_configs = {}

-- Lookup a filetype config client by its name.
function lsp.get_filetype_client_by_name(name)
  local config = all_filetype_configs[name]
  if config.client_id then
    return active_clients[config.client_id]
  end
end

local function start_filetype_config(config)
  config.client_id = lsp.start_client(config)
  nvim_command(string.format(
    "autocmd FileType %s silent lua vim.lsp.buf_attach_client(0, %d)",
    table.concat(config.filetypes, ','),
    config.client_id))
  return config.client_id
end

-- Easy configuration option for common LSP use-cases.
-- This will lazy initialize the client when the filetypes specified are
-- encountered and attach to those buffers.
--
-- The configuration options are the same as |vim.lsp.start_client()|, but
-- with a few additions and distinctions:
--
-- Additional parameters:
-- - filetype: {string} or {list} of filetypes to attach to.
-- - name: A unique string among all other servers configured with
-- |vim.lsp.add_filetype_config|.
--
-- Differences:
-- - root_dir: will default to |getcwd()|
--
function lsp.add_filetype_config(config)
  -- Additional defaults.
  -- Keep a copy of the user's input for debugging reasons.
  local user_config = config
  config = tbl_extend("force", {}, user_config)
  config.root_dir = config.root_dir or uv.cwd()
  -- Validate config.
  validate_client_config(config)
  validate {
    name = { config.name, 's' };
  }
  assert(config.filetype, "config must have 'filetype' key")

  local filetypes
  if type(config.filetype) == 'string' then
    filetypes = { config.filetype }
  elseif type(config.filetype) == 'table' then
    filetypes = config.filetype
    assert(not tbl_isempty(filetypes), "config.filetype must not be an empty table")
  else
    error("config.filetype must be a string or a list of strings")
  end

  if all_filetype_configs[config.name] then
    -- If the client exists, then it is likely that they are doing some kind of
    -- reload flow, so let's not throw an error here.
    if all_filetype_configs[config.name].client_id then
      -- TODO log here? It might be unnecessarily annoying.
      return
    end
    error(string.format('A configuration with the name %q already exists. They must be unique', config.name))
  end

  all_filetype_configs[config.name] = tbl_extend("keep", config, {
    client_id = nil;
    filetypes = filetypes;
    user_config = user_config;
  })

  nvim_command(string.format(
    "autocmd FileType %s ++once silent lua vim.lsp._start_filetype_config_client(%q)",
    table.concat(filetypes, ','),
    config.name))
end

-- Create a copy of an existing configuration, and override config with values
-- from new_config.
-- This is useful if you wish you create multiple LSPs with different root_dirs
-- or other use cases.
--
-- You can specify a new unique name, but if you do not, a unique name will be
-- created like `name-dup_count`.
--
-- existing_name: the name of the existing config to copy.
-- new_config: the new configuration options. @see |vim.lsp.start_client()|.
-- @returns string the new name.
function lsp.copy_filetype_config(existing_name, new_config)
  local config = all_filetype_configs[existing_name]
      or error(string.format("Configuration with name %q doesn't exist", existing_name))
  config = tbl_extend("force", config, new_config or {})
  config.client_id = nil
  config.original_config_name = existing_name

  -- If the user didn't rename it, we will.
  if config.name == existing_name then
    -- Create a new, unique name.
    local duplicate_count = 0
    for _, conf in pairs(all_filetype_configs) do
      if conf.original_config_name == existing_name then
        duplicate_count = duplicate_count + 1
      end
    end
    config.name = string.format("%s-%d", existing_name, duplicate_count + 1)
  end
  print("New config name:", config.name)
  lsp.add_filetype_config(config)
  return config.name
end

-- Autocmd handler to actually start the client when an applicable filetype is
-- encountered.
function lsp._start_filetype_config_client(name)
  local config = all_filetype_configs[name]
  -- If it exists and is running, don't make it again.
  if config.client_id and active_clients[config.client_id] then
    -- TODO log here?
    return
  end
  lsp.buf_attach_client(0, start_filetype_config(config))
  return config.client_id
end

---
--- Miscellaneous utilities.
---

-- Retrieve a map from client_id to client of all active buffer clients.
-- @param bufnr [number] (optional): buffer handle or 0 for current
function lsp.buf_get_clients(bufnr)
  bufnr = resolve_bufnr(bufnr)
 local result = {}
 for_each_buffer_client(bufnr, function(client, client_id)
   result[client_id] = client
 end)
 return result
end

-- Print some debug information about the current buffer clients.
-- The output of this function should not be relied upon and may change.
function lsp.buf_print_debug_info(bufnr)
  print(vim.inspect(lsp.buf_get_clients(bufnr)))
end

-- Print some debug information about all LSP related things.
-- The output of this function should not be relied upon and may change.
function lsp.print_debug_info()
  print(vim.inspect({ clients = active_clients, filetype_configs = all_filetype_configs }))
end

-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the
-- name from the number.
-- Levels by name: 'trace', 'debug', 'info', 'warn', 'error'
-- Level numbers begin with 'trace' at 0
lsp.log_levels = log.levels

-- Set the log level for lsp logging.
-- Levels by name: 'trace', 'debug', 'info', 'warn', 'error'
-- Level numbers begin with 'trace' at 0
-- @param level [number|string] the case insensitive level name or number @see |vim.lsp.log_levels|
function lsp.set_log_level(level)
  if type(level) == 'string' or type(level) == 'number' then
    log.set_level(level)
  else
    error(string.format("Invalid log level: %q", level))
  end
end

-- Return the path of the logfile used by the LSP client.
function lsp.get_log_path()
  return log.get_filename()
end

return lsp
-- vim:sw=2 ts=2 et
