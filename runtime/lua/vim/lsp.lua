local builtin_default_server_callbacks = require 'vim.lsp.builtin_callbacks'
local log = require 'vim.lsp.log'
local lsp_rpc = require 'vim.lsp.rpc'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'

local nvim_err_writeln, nvim_buf_get_lines, nvim_command, nvim_buf_get_option
  = vim.api.nvim_err_writeln, vim.api.nvim_buf_get_lines, vim.api.nvim_command, vim.api.nvim_buf_get_option

local lsp = {
  protocol = protocol;
}

-- TODO consider whether 'eol' or 'fixeol' should change the nvim_buf_get_lines that send.

local function resolve_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function set_timeout(ms, fn)
  local timer = vim.loop.new_timer()
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
      error(string.format(" Client %d has already shut down.", client_id))
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

--- Start a client and initialize it.
-- conf = {
--   cmd = string;
--   cmd_args = table;
--   cmd_cwd = string | nil;
--   cmd_end = table | nil;
--   offset_encoding = 'utf-8' | 'utf-16' | 'utf-32' | string;
--   name = string | nil;
--   trace = 'off' | 'messages' | 'verbose' | nil
--   default_server_callbacks = table | nil;
--   on_init = function | nil;
--   init_options = table | nil;
-- }
--
-- - `name` here is only used for logging/debugging.
-- - `trace` will be forwarded to the client.
-- - `default_server_callbacks` should be a table of functions which
-- defines:
--   - The handlers for notifications. These should be `function(params)`
--   - A default callback to use for `vim.lsp.buf_request` if one is not
--   provided at the time of calling `vim.lsp.buf_request`. These should be
--   `function(err, result)`
--   - By default, the functions from the module `vim.lsp.builtin_callbacks`
--   will be used. This parameter can override or extend it those builtin
--   callbacks.
--
-- You can use |vim.lsp.get_client_by_id()| to get the actual client.
--
-- NOTE: The client is only available *after* it has been initialized, which
-- may happen after a small delay (or never if there is an error).
-- For this reason, you may want to use `on_init` to do any actions once the
-- client has been initialized.
--
-- @return client_id
function lsp.start_client(conf)
  assert(type(conf.cmd) == 'string', "conf.cmd must be a string")
  assert(type(conf.cmd_args) == 'table', "conf.cmd_args must be a table")
  local offset_encoding = validate_encoding(conf.offset_encoding)
  -- TODO should I be using this for both notifications and request callbacks
  -- or separate those?
  local default_server_callbacks
  if conf.default_server_callbacks then
    assert(type(conf.default_server_callbacks) == 'table', "conf.default_server_callbacks must be a table")
    default_server_callbacks = vim.tbl_extend("keep", conf.default_server_callbacks, builtin_default_server_callbacks)
  else
    default_server_callbacks = builtin_default_server_callbacks
  end
  -- TODO keep vim.schedule here?
  for k, v in pairs(default_server_callbacks) do
    default_server_callbacks[k] = vim.schedule_wrap(v)
  end
  local capabilities = conf.capabilities or {}
  assert(type(capabilities) == 'table', "conf.capabilities must be a table")

  -- There are things sent by the server in the initialize response which
  -- contains capabilities that would be useful for completion engines, such as
  -- the character code triggers for completion and code action, so I'll expose this
  -- for now.
  if conf.on_init then
    assert(type(conf.on_init) == 'function', "conf.on_init must be a function")
  end
  if conf.on_exit then
    assert(type(conf.on_exit) == 'function', "conf.on_exit must be a function")
  end
  if conf.on_error then
    assert(type(conf.on_error) == 'function', "conf.on_error must be a function")
  end
  if conf.cmd_env then
    assert(type(conf.cmd_env) == 'table', "conf.cmd_env must be a table")
  end
  if conf.cmd_cwd then
    assert(type(conf.cmd_cwd) == 'string', "conf.cmd_cwd must be a string")
    local stat = vim.loop.fs_stat(conf.cmd_cwd)
    assert(stat and stat.type == 'directory', "conf.cmd_cwd must be a directory")
  end

  local client_id = next_client_id()

  local handlers = {}

  function handlers.notification(method, params)
    _ = log.debug() and log.debug('notification', method, params)
    local callback = default_server_callbacks[method]
    if callback then
      -- Method name is provided here for convenience.
      callback(params, method)
    end
  end

  function handlers.server_request(method, params)
    _ = log.debug() and log.debug('server_request', method, params)
    local request_callback = default_server_callbacks[method]
    if request_callback then
      return request_callback(params, method)
    end
    return nil, lsp_rpc.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
  end

  local name = conf.name or tostring(client_id)
  assert(type(name) == 'string', "conf.name must be a string")
  local log_prefix = string.format("LSP[%s]", name)

  function handlers.on_error(code, err)
    _ = log.error() and log.error(log_prefix, "on_error", { code = error_codes[code], err = err })
    nvim_err_writeln(string.format('%s: Error %s: %q', log_prefix, error_codes[code], vim.inspect(err)))
    if conf.on_error then
      local status, usererr = pcall(conf.on_error, code, err)
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
    if conf.on_exit then pcall(conf.on_exit, client_id) end
  end

  local rpc = lsp_rpc.start(conf.cmd, conf.cmd_args, handlers, {
    cwd = conf.cmd_cwd;
    env = conf.cmd_env;
  })

  local client = {
    id = client_id;
    name = name;
    rpc = rpc;
    offset_encoding = offset_encoding;
    default_server_callbacks = default_server_callbacks;
    config = conf;
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
      processId = vim.loop.getpid();
      -- The rootPath of the workspace. Is null if no folder is open.
      --
      -- @deprecated in favour of rootUri.
      rootPath = nil;
      -- The rootUri of the workspace. Is null if no folder is open. If both
      -- `rootPath` and `rootUri` are set `rootUri` wins.
      rootUri = vim.uri_from_fname(vim.loop.cwd()); -- TODO which path to use?
--      rootUri = vim.uri_from_fname(vim.fn.expand("%:p:h"));
      -- User provided initialization options.
      initializationOptions = conf.init_options;
      -- The capabilities provided by the client (editor or tool)
      capabilities = vim.tbl_deep_merge(protocol.make_client_capabilities(), capabilities);
      -- The initial trace setting. If omitted trace is disabled ('off').
      -- trace = 'off' | 'messages' | 'verbose';
      trace = valid_traces[conf.trace] or 'off';
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
      if conf.on_init then
        local status, err = pcall(conf.on_init, client, result)
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
    vim.api.nvim_err_writeln(msg)
    return lsp_rpc.rpc_response_error(protocol.ErrorCodes.MethodNotFound, msg)
  end

  --- Checks capabilities before rpc.request-ing.
  function client.request(method, params, callback)
    _ = log.debug() and log.debug(log_prefix, "client.request", client_id, method, params, callback)
    -- TODO keep these checks or just let it go anyway?
    if (not client.resolved_capabilities.hover and method == 'textDocument/hover')
      or (not client.resolved_capabilities.signature_help and method == 'textDocument/signatureHelp')
      or (not client.resolved_capabilities.goto_definition and method == 'textDocument/definition')
      or (not client.resolved_capabilities.implementation and method == 'textDocument/implementation')
    then
      callback(unsupported_method(method))
      return
    end
    return rpc.request(method, params, callback)
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
    -- TODO The old implementation did this but didn't explain why.
    -- if new_lastline > firstline then
    --  table.insert(lines, '')
    -- end
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

function lsp.add_config(config)
  assert(type(config) == 'table', 'argument must be a table')
  assert(config.filetype, "config must have 'filetype' key")
  assert(config.cmd, "config must have 'cmd' key")
  assert(type(config.name) == 'string', "config.name must be a string")
  if LSP_CONFIGS[config.name] then
    -- If the client exists, then it is likely that they are doing some kind of
    -- reload flow, so let's not throw an error here.
    if LSP_CONFIGS[config.name].client_id then
      -- TODO log here? It might be unnecessarily annoying.
      return
    end
    error(string.format('A configuration with the name %q already exists. They must be unique', config.name))
  end
  local capabilities = config.capabilities or {}
  assert(type(capabilities) == 'table', "config.capabilities must be a table")

  local filetypes
  if type(config.filetype) == 'string' then
    filetypes = { config.filetype }
  elseif type(config.filetype) == 'table' then
    filetypes = config.filetype
  else
    error("config.filetype must be a string or a list of strings")
  end

  local offset_encoding = config.offset_encoding and validate_encoding(config.offset_encoding) or VALID_ENCODINGS.UTF16

  local cmd, cmd_args
  if type(config.cmd) == 'string' then
    -- Use a shell to execute the command if it is a string.
    cmd = vim.api.nvim_get_option('shell')
    cmd_args = {vim.api.nvim_get_option('shellcmdflag'), config.cmd}
  elseif vim.tbl_islist(config.cmd) then
    cmd = config.cmd[1]
    cmd_args = {}
    -- Don't mutate our input.
    for i, v in ipairs(config.cmd) do
      assert(type(v) == 'string', "config.cmd arguments must be strings")
      if i > 1 then
        table.insert(cmd_args, v)
      end
    end
  else
    error("cmd type must be string or list.")
  end

  LSP_CONFIGS[config.name] = {
    user_config = config;
    name = config.name;
    offset_encoding = offset_encoding;
    filetypes = filetypes;
    cmd = cmd;
    cmd_args = cmd_args;
    cmd_env = config.cmd_env;
    cmd_cwd = config.cmd_cwd;
    capabilities = capabilities;
    init_options = config.init_options;
    on_init = config.on_init;
  }

  nvim_command(string.format(
    "autocmd FileType %s ++once silent lua vim.lsp._start_client_by_name(%q)",
    table.concat(filetypes, ','),
    config.name))
end

function lsp._start_client_by_name(name)
  local config = LSP_CONFIGS[name]
  -- If it exists and is running, don't make it again.
  if config.client_id and LSP_CLIENTS[config.client_id] then
    -- TODO log here?
    return
  end
  config.client_id = lsp.start_client(config)
  vim.lsp.attach_to_buffer(0, config.client_id)

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
    local request_callback = callback
    if not request_callback then
      request_callback = client.default_server_callbacks[method]
        or error(string.format("buf_request callback is empty and no default client was found for client %s", client.name))
    end
    local request_success, request_id = client.request(method, params, function(err, result)
      -- TODO pass client here?
      request_callback(err, result, client_id)
    end)

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

--- Send a request to a server, but don't wait for the response
-- @param method [string]: Name of the request method
-- @param params [string]: Arguments to send to the server
-- @param cb [function|string] (optional): Either a function to call or a string to call in vim
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The table of request id
function lsp.buf_request_sync(bufnr, method, params, timeout_ms)
  local request_results = {}
  local result_count = 0
  local function callback(err, result, client_id)
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
  local timeout = (timeout_ms or 100) + vim.loop.now()
  -- TODO is there a better way to sync this?
  while result_count < expected_result_count do
    _ = log.trace() and log.trace("results", result_count, request_results)
    if vim.loop.now() >= timeout then
      cancel()
      return nil, "TIMEOUT"
    end
    -- TODO this really needs to be further looked at.
    nvim_command "sleep 10m"
    -- vim.loop.sleep(10)
    vim.loop.update_time()
  end
  vim.loop.update_time()
  _ = log.trace() and log.trace("results", result_count, request_results)
  return request_results
end

--- Send a notification to a server
-- @param method [string]: Name of the request method
-- @param params [string]: Arguments to send to the server
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The notification message id
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
  vim.api.nvim_out_write(vim.inspect(lsp.get_buffer_clients(bufnr)))
  vim.api.nvim_out_write("\n")
end

-- TODO keep?
function lsp.print_debug_info()
  vim.api.nvim_out_write(vim.inspect(LSP_CLIENTS))
  vim.api.nvim_out_write("\n")
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
