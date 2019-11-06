local builtin_callbacks = require 'vim.lsp.builtin_callbacks'
local log = require 'vim.lsp.log'
local lsp_rpc = require 'vim.lsp.rpc'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'

local nvim_err_writeln, nvim_buf_get_lines, nvim_command, nvim_buf_get_option
  = vim.api.nvim_err_writeln, vim.api.nvim_buf_get_lines, vim.api.nvim_command, vim.api.nvim_buf_get_option
local uv = vim.loop

local lsp = {
  protocol = protocol;
  rpc_response_error = lsp_rpc.rpc_response_error;
}

-- TODO consider whether 'eol' or 'fixeol' should change the nvim_buf_get_lines that send.

local function resolve_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function set_timeout(ms, fn)
  local timer = uv.new_timer()
  timer:start(ms, 0, function()
    pcall(fn)
    timer:close()
  end)
  return timer
end

local VALID_ENCODINGS = {
  ["utf-8"] = 'utf-8'; ["utf-16"] = 'utf-16'; ["utf-32"] = 'utf-32';
  ["utf8"]  = 'utf-8'; ["utf16"]  = 'utf-16'; ["utf32"]  = 'utf-32';
  UTF8      = 'utf-8'; UTF16      = 'utf-16'; UTF32      = 'utf-32';
}

local CLIENT_INDEX = 0
local function next_client_id()
  CLIENT_INDEX = CLIENT_INDEX + 1
  return CLIENT_INDEX
end
-- Tracks all clients created via lsp.start_client
local LSP_CLIENTS = {}
local BUFFER_CLIENT_IDS = {}

local function for_each_buffer_client(bufnr, callback)
  assert(type(callback) == 'function', "callback must be a function")
  bufnr = resolve_bufnr(bufnr)
  assert(type(bufnr) == 'number', "bufnr must be a number")
  local client_ids = BUFFER_CLIENT_IDS[bufnr]
  if not client_ids or vim.tbl_isempty(client_ids) then
    return
  end
  for client_id in pairs(client_ids) do
    local client = LSP_CLIENTS[client_id]
    -- This is unlikely to happen. Could only potentially happen in a race
    -- condition between literally a single statement.
    -- We could skip this error, but let's error for now.
    if not client then
      error(string.format("Client %d has already shut down.", client_id))
    end
    callback(client, client_id)
  end
end

local function validate_encoding(encoding)
  assert(type(encoding) == 'string', "encoding must be a string")
  return VALID_ENCODINGS[encoding:lower()] or error(string.format("Invalid offset encoding %q. Must be one of: 'utf-8', 'utf-16', 'utf-32'", encoding))
end

local maxerrn = table.maxn(lsp_rpc.ERRORS)
local error_codes = vim.tbl_extend("error", lsp_rpc.ERRORS, vim.tbl_add_reverse_lookup {
  ON_INIT_CALLBACK_ERROR = maxerrn + 1;
})

-- Error codes to be used with `on_error` from |vim.lsp.start_client|.
-- Can be used to look up the string from a the number or the number
-- from the string.
lsp.ERRORS = error_codes

local function is_dir(filename)
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
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

local function validate_client_config(config)
  assert(type(config) == 'table', 'argument must be a table')
  assert(config.cmd, "config must have 'cmd' key")
  local cmd, cmd_args = validate_command(config.cmd)
  assert(type(config.root_dir) == 'string', "config.root_dir must be a string")
  assert(is_dir(config.root_dir), "config.root_dir must be a directory")
  local offset_encoding = VALID_ENCODINGS.UTF16
  if config.offset_encoding then
    offset_encoding = validate_encoding(config.offset_encoding)
  end
  if config.callbacks then
    assert(type(config.callbacks) == 'table', "config.callbacks must be a table")
  end
  if config.capabilities then
    assert(type(config.capabilities) == 'table', "config.capabilities must be a table")
  end

  -- There are things sent by the server in the initialize response which
  -- contains capabilities that would be useful for completion engines, such as
  -- the character code triggers for completion and code action, so I'll expose this
  -- for now.
  if config.on_init then
    assert(type(config.on_init) == 'function', "config.on_init must be a function")
  end
  if config.on_exit then
    assert(type(config.on_exit) == 'function', "config.on_exit must be a function")
  end
  if config.on_error then
    assert(type(config.on_error) == 'function', "config.on_error must be a function")
  end
  if config.cmd_env then
    assert(type(config.cmd_env) == 'table', "config.cmd_env must be a table")
  end
  if config.cmd_cwd then
    assert(type(config.cmd_cwd) == 'string', "config.cmd_cwd must be a string")
    assert(is_dir(config.cmd_cwd), "config.cmd_cwd must be a directory")
  end
  if config.name then
    assert(type(config.name) == 'string', "config.name must be a string")
  end
  return {
    cmd = cmd; cmd_args = cmd_args;
    offset_encoding = offset_encoding;
  }
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
-- capabilities: A {table} which will be merged using |vim.deep_merge| with
-- neovim's default capabilities and passed to the language server on
-- initialization.
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
-- on_error: A `function(code, ...)` for handling errors thrown by client
-- operation. {code} is a number describing the error. Other arguments
-- may be passed depending on the error kind.  @see |vim.lsp.ERRORS| for
-- possible errors. `vim.lsp.ERRORS[code]` can be used to retrieve a human
-- understandable string.
--
-- on_init: A `function(client, initialize_result)` which is called after the
-- request `initialize` is completed. `initialize_result` contains
-- `capabilities` and anything else the server may send. For example, `clangd`
-- sends `result.offsetEncoding` if `capabilities.offsetEncoding` was sent to
-- it.
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

  local callbacks = vim.tbl_extend("keep", config.callbacks or {}, builtin_callbacks)
  local capabilities = config.capabilities or {}
  local name = config.name or tostring(client_id)
  local log_prefix = string.format("LSP[%s]", name)

  local handlers = {}

  function handlers.notification(method, params)
    _ = log.debug() and log.debug('notification', method, params)
    local callback = callbacks[method]
    if callback then
      -- Method name is provided here for convenience.
      callback(nil, method, params, client_id)
    end
  end

  function handlers.server_request(method, params)
    _ = log.debug() and log.debug('server_request', method, params)
    local callback = callbacks[method]
    if callback then
      _ = log.debug() and log.debug("server_request: found callback for", method)
      return callback(nil, method, params, client_id)
    end
    _ = log.debug() and log.debug("server_request: no callback found for", method)
    return nil, lsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
  end

  function handlers.on_error(code, err)
    _ = log.error() and log.error(log_prefix, "on_error", { code = error_codes[code], err = err })
    nvim_err_writeln(string.format('%s: Error %s: %q', log_prefix, error_codes[code], vim.inspect(err)))
    if config.on_error then
      local status, usererr = pcall(config.on_error, code, err)
      if not status then
        _ = log.error() and log.error(log_prefix, "user on_error failed", { err = usererr })
        nvim_err_writeln(log_prefix.." user on_error failed: "..tostring(usererr))
      end
    end
  end

  -- This is used because if there are outstanding timers (like for stop())
  -- they will block neovim exiting.
  local timers = {}
  function handlers.on_exit()
    for _, h in ipairs(timers) do
      h:stop()
      h:close()
    end
    LSP_CLIENTS[client_id] = nil
    for bufnr, client_ids in pairs(BUFFER_CLIENT_IDS) do
      client_ids[client_id] = nil
    end
    if config.on_exit then
      pcall(config.on_exit, client_id)
    end
  end

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
      capabilities = vim.tbl_deep_merge(protocol.make_client_capabilities(), capabilities);
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
    _ = log.debug() and log.debug(log_prefix, "initialize_params", initialize_params)
    rpc.request('initialize', initialize_params, function(err, result)
      assert(not err, err)
      rpc.notify('initialized', {})
      client.initialized = true
      client.server_capabilities = assert(result.capabilities, "initialize result doesn't contain capabilities")
      client.resolved_capabilities = protocol.resolve_capabilities(client.server_capabilities)
      if config.on_init then
        local status, err = pcall(config.on_init, client, result)
        if not status then
          pcall(handlers.on_error, error_codes.ON_INIT_CALLBACK_ERROR, err)
        end
      end
      _ = log.debug() and log.debug(log_prefix, "server_capabilities", client.server_capabilities)
      _ = log.info() and log.info(log_prefix, "initialized", { resolved_capabilities = client.resolved_capabilities })

      -- Only assign after initialized?
      LSP_CLIENTS[client_id] = client
      -- If we had been registered before we start, then send didOpen This can
      -- happen if we attach to buffers before initialize finishes or if
      -- someone restarts a client.
      for bufnr, client_ids in pairs(BUFFER_CLIENT_IDS) do
        if client_ids[client_id] then
          client.text_document_did_open(bufnr)
        end
      end
    end)
  end

  local function unsupported_method(method)
    local msg = "server doesn't support "..method
    _ = log.warn() and log.warn(msg)
    nvim_err_writeln(msg)
    return lsp.rpc_response_error(protocol.ErrorCodes.MethodNotFound, msg)
  end

  --- Checks capabilities before rpc.request-ing.
  function client.request(method, params, callback)
    if not callback then
      callback = client.callbacks[method]
        or error(string.format("request callback is empty and no default was found for client %s", client.name))
    end
    _ = log.debug() and log.debug(log_prefix, "client.request", client_id, method, params, callback)
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

  -- TODO Make sure these timeouts are ok or make configurable?
  function client.stop(force)
    local handle = rpc.handle
    if handle:is_closing() then
      return
    end
    if force then
      -- kill after 1s as a last resort.
      table.insert(timers, set_timeout(1e3, function() handle:kill(9) end))
      handle:kill(15)
      return
    end
    -- term after 100ms as a fallback
    table.insert(timers, set_timeout(1e2, function() handle:kill(15) end))
    -- kill after 1s as a last resort.
    table.insert(timers, set_timeout(1e3, function() handle:kill(9) end))
    -- Sending a signal after a process has exited is acceptable.
    rpc.request('shutdown', nil, function(err, result)
      if err == nil then
        rpc.notify('exit')
      else
        -- If there was an error in the shutdown request, then term to be safe.
        handle:kill(15)
      end
    end)
  end

  function client.text_document_did_open(bufnr)
    if not client.resolved_capabilities.text_document_open_close then
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
    rpc.notify('textDocument/didOpen', params)
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

local ENCODING_INDEX = { ["utf-8"] = 1; ["utf-16"] = 2; ["utf-32"] = 3; }
local function text_document_did_change_handler(_, bufnr, changedtick, firstline, lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size)
  _ = log.debug() and log.debug("on_lines", bufnr, changedtick, firstline, lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size)
  -- Don't do anything if there are no clients attached.
  if vim.tbl_isempty(BUFFER_CLIENT_IDS[bufnr] or {}) then
    return
  end
  local incremental_changes = once(function(client)
    -- TODO make sure this is correct. Sometimes this sends firstline = lastline and text = ""
    local size_index = ENCODING_INDEX[client.offset_encoding]
    local lines = nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
    -- This is necessary for some reason (from testing with clangd). This seems
    -- to imply that the protocol requires that all lines be terminated with a
    -- newline.
    if new_lastline > firstline then
     table.insert(lines, '')
    end
    return {
      range = {
        start = { line = firstline, character = 0 };
        ["end"] = { line = lastline, character = 0 };
      };
      rangeLength = select(size_index, old_byte_size, old_utf16_size, old_utf32_size);
      text = table.concat(lines, '\n');
    };
  end)
  local full_changes = once(function()
    return {
      text = table.concat(nvim_buf_get_lines(bufnr, 0, -1, false), "\n");
    };
  end)
  local uri = vim.uri_from_bufnr(bufnr)
  for_each_buffer_client(bufnr, function(client, client_id)
    local text_document_did_change = client.resolved_capabilities.text_document_did_change
    local changes
    if text_document_did_change == protocol.TextDocumentSyncKind.None then
      return
    elseif text_document_did_change == protocol.TextDocumentSyncKind.Incremental then
      changes = incremental_changes(client)
    elseif text_document_did_change == protocol.TextDocumentSyncKind.Full then
      changes = full_changes(client)
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

-- Implements the textDocument/did* notifications required to track a buffer
-- for any language server.
--
-- This function could be implemented outside of the client function, since
-- it stands out alone as the only function which contains protocol
-- implementation details, but it's definitely easier to implement here.
function lsp.attach_to_buffer(bufnr, client_id)
  assert(type(client_id) == 'number', "client_id must be a number")
  bufnr = resolve_bufnr(bufnr)
  local buffer_client_ids = BUFFER_CLIENT_IDS[bufnr]
  -- This is our first time attaching to this buffer.
  if not buffer_client_ids then
    buffer_client_ids = {}
    BUFFER_CLIENT_IDS[bufnr] = buffer_client_ids

    nvim_command(string.format("autocmd BufWritePost <buffer=%d> lua vim.lsp._text_document_did_save_handler(%d)", bufnr, bufnr))
    local uri = vim.uri_from_bufnr(bufnr)

    -- First time, so attach and set up stuff.
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = text_document_did_change_handler;
      -- TODO this could be abstracted if on_detach passes the bufnr, but since
      -- there's no documentation, I have no idea if that happens.
      on_detach = function()
        local params = {
          textDocument = {
            uri = uri;
          }
        }
        for_each_buffer_client(bufnr, function(client, client_id)
          if client.resolved_capabilities.text_document_open_close then
            client.notify('textDocument/didClose', params)
          end
        end)
        BUFFER_CLIENT_IDS[bufnr] = nil
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

  local client = LSP_CLIENTS[client_id]
  -- Send didOpen for the client if it is initialized. If it isn't initialized
  -- then it will send didOpen on initialize.
  if client then
    client.text_document_did_open(bufnr)
  end
end

local LSP_CONFIGS = {}

-- Easy configuration option for common LSP use-cases.
-- This will lazy initialize the client when the filetypes specified are
-- encountered and attach to those buffers.
--
-- The configuration options are the same as |vim.lsp.start_client()|, but
-- with a few additions and distinctions:
--
-- Additional parameters:
-- - filetype: {string} or {list} of filetypes to attach to.
-- - name: A unique string among all other functions configured with
-- |vim.lsp.add_config|.
--
-- Differences:
-- - root_dir: will default to |getcwd()|
--
function lsp.add_config(config)
  -- Additional defaults.
  -- Keep a copy of the user's input for debugging reasons.
  local user_config = config
  config = vim.tbl_extend("force", {}, user_config)
  config.root_dir = config.root_dir or uv.cwd()
  -- Validate config.
  validate_client_config(config)
  assert(config.filetype, "config must have 'filetype' key")
  assert(type(config.name) == 'string', "config.name must be a string")

  local filetypes
  if type(config.filetype) == 'string' then
    filetypes = { config.filetype }
  elseif type(config.filetype) == 'table' then
    filetypes = config.filetype
  else
    error("config.filetype must be a string or a list of strings")
  end

  if LSP_CONFIGS[config.name] then
    -- If the client exists, then it is likely that they are doing some kind of
    -- reload flow, so let's not throw an error here.
    if LSP_CONFIGS[config.name].client_id then
      -- TODO log here? It might be unnecessarily annoying.
      return
    end
    error(string.format('A configuration with the name %q already exists. They must be unique', config.name))
  end

  LSP_CONFIGS[config.name] = vim.tbl_extend("keep", config, {
    client_id = nil;
    filetypes = filetypes;
    user_config = user_config;
  })

  nvim_command(string.format(
    "autocmd FileType %s ++once silent lua vim.lsp._start_client_by_name(%q)",
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
function lsp.copy_config(existing_name, new_config)
  local config = LSP_CONFIGS[existing_name] or error(string.format("Configuration with name %q doesn't exist", existing_name))
  config = vim.tbl_extend("force", config, new_config or {})
  config.client_id = nil
  config.original_config_name = existing_name

  if config.name == existing_name then
    -- Create a new, unique name.
    local duplicate_count = 0
    for _, conf in pairs(LSP_CONFIGS) do
      if conf.original_config_name == existing_name then
        duplicate_count = duplicate_count + 1
      end
    end
    config.name = string.format("%s-%d", existing_name, duplicate_count + 1)
  end
  lsp.add_config(config)
end

function lsp._start_client_by_name(name)
  local config = LSP_CONFIGS[name]
  -- If it exists and is running, don't make it again.
  if config.client_id and LSP_CLIENTS[config.client_id] then
    -- TODO log here?
    return
  end
  config.client_id = lsp.start_client(config)
  lsp.attach_to_buffer(0, config.client_id)

  nvim_command(string.format(
    "autocmd FileType %s silent lua vim.lsp.attach_to_buffer(0, %d)",
    table.concat(config.filetypes, ','),
    config.client_id))
  return config.client_id
end

nvim_command("autocmd VimLeavePre * lua vim.lsp.stop_all_clients()")

function lsp.get_client_by_id(client_id)
  return LSP_CLIENTS[client_id]
end

function lsp.get_client_by_name(name)
  local config = LSP_CONFIGS[name]
  if config.client_id then
    return LSP_CLIENTS[config.client_id]
  end
end

function lsp.stop_client(client_id, force)
  local client = LSP_CLIENTS[client_id]
  if client then
    client.stop(force)
  end
end

function lsp.stop_all_clients(force)
  for client_id, client in pairs(LSP_CLIENTS) do
    client.stop(force)
  end
end

--- Send a request to a server and return the response
-- @param method [string]: Name of the request method
-- @param params [table] (optional): Arguments to send to the server
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: success?, request_id, cancel_fn
function lsp.buf_request(bufnr, method, params, callback)
  if callback then
    assert(type(callback) == 'function', "buf_request callback must be a function")
  end
  local client_request_ids = {}
  for_each_buffer_client(bufnr, function(client, client_id)
    local request_success, request_id = client.request(method, params, callback)

    -- This could only fail if the client shut down in the time since we looked
    -- it up and we did the request, which should be rare.
    if request_success then
      client_request_ids[client_id] = request_id
    end
  end)

  local function cancel_request()
    for client_id, request_id in pairs(client_request_ids) do
      local client = LSP_CLIENTS[client_id]
      client.rpc.notify('$/cancelRequest', { id = request_id })
    end
  end

  return client_request_ids, cancel_request
end

--- Send a request to a server and wait for the response.
-- @param bufnr [number] (optional): The number of the buffer
-- @param method [string]: Name of the request method
-- @param params [string]: Arguments to send to the server
-- @param timeout_ms=100 [number] (optional): maximum ms to wait for a result.
--
-- @returns: The table of {[client_id] = request_result}
function lsp.buf_request_sync(bufnr, method, params, timeout_ms)
  local request_results = {}
  local result_count = 0
  local function callback(err, method, result, client_id)
    _ = log.trace() and log.trace("callback", err, result, client_id)
    request_results[client_id] = { error = err, result = result }
    result_count = result_count + 1
  end
  local client_request_ids, cancel = lsp.buf_request(bufnr, method, params, callback)
  _ = log.trace() and log.trace("client_request_ids", client_request_ids)

  local expected_result_count = 0
  for _ in pairs(client_request_ids) do
    expected_result_count = expected_result_count + 1
  end
  _ = log.trace() and log.trace("expected_result_count", expected_result_count)
  local timeout = (timeout_ms or 100) + uv.now()
  -- TODO is there a better way to sync this?
  while result_count < expected_result_count do
    _ = log.trace() and log.trace("results", result_count, request_results)
    if uv.now() >= timeout then
      cancel()
      return nil, "TIMEOUT"
    end
    -- TODO this really needs to be further looked at.
    nvim_command "sleep 10m"
    -- vim.loop.sleep(10)
    uv.update_time()
  end
  uv.update_time()
  _ = log.trace() and log.trace("results", result_count, request_results)
  return request_results
end

--- Send a notification to a server
-- @param bufnr [number] (optional): The number of the buffer
-- @param method [string]: Name of the request method
-- @param params [string]: Arguments to send to the server
--
-- @returns nil
function lsp.buf_notify(bufnr, method, params)
  for_each_buffer_client(bufnr, function(client, client_id)
    client.rpc.notify(method, params)
  end)
end

function lsp._text_document_did_save_handler(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  local text = once(function()
    return table.concat(nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  end)
  for_each_buffer_client(bufnr, function(client, client_id)
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

--- Function which can be called to generate omnifunc compatible completion.
function lsp.omnifunc(findstart, base)
  _ = log.debug() and log.debug("omnifunc.findstart", { findstart = findstart, base = base })

  local bufnr = resolve_bufnr()
  local has_buffer_clients = not vim.tbl_isempty(BUFFER_CLIENT_IDS[bufnr] or {})
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
    _ = log.trace() and log.trace("omnifunc.line", pos, line)
    local line_to_cursor = line:sub(1, pos[2]+1)
    _ = log.trace() and log.trace("omnifunc.line_to_cursor", line_to_cursor)
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
    -- TODO handle timeout error differently?
    local client_responses = lsp.buf_request_sync(bufnr, 'textDocument/completion', params) or {}
    local matches = {}
    for client_id, response in pairs(client_responses) do
      -- TODO how to handle errors?
      if not response.error then
        local data = response.result
        local completion_items = util.text_document_completion_list_to_complete_items(data or {}, line_to_cursor)
        _ = log.trace() and log.trace("omnifunc.completion_items", completion_items)
        vim.list_extend(matches, completion_items)
      end
    end
    return matches
  end
end

-- TODO keep?
function lsp.get_buffer_clients(bufnr)
  bufnr = resolve_bufnr(bufnr)
 local result = {}
 for_each_buffer_client(bufnr, function(client, client_id)
   result[client_id] = client
 end)
 return result
end

-- TODO keep?
function lsp.buf_print_debug_info(bufnr)
  print(vim.inspect(lsp.get_buffer_clients(bufnr)))
end

-- TODO keep?
function lsp.print_debug_info()
  print(vim.inspect({ clients = LSP_CLIENTS, configs = LSP_CONFIGS }))
end

function lsp.set_log_level(level)
  if type(level) == 'string' or type(level) == 'number' then
    log.set_level(level)
  else
    error(string.format("Invalid log level: %q", level))
  end
end

return lsp
-- vim:sw=2 ts=2 et
