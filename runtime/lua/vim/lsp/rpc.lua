local uv = vim.loop
local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local validate, schedule, schedule_wrap = vim.validate, vim.schedule, vim.schedule_wrap

-- TODO replace with a better implementation.
local function json_encode(data)
  local status, result = pcall(vim.fn.json_encode, data)
  if status then
    return result
  else
    return nil, result
  end
end
local function json_decode(data)
  local status, result = pcall(vim.fn.json_decode, data)
  if status then
    return result
  else
    return nil, result
  end
end

local function is_dir(filename)
  local stat = vim.loop.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

local NIL = vim.NIL
local function convert_NIL(v)
  if v == NIL then return nil end
  return v
end

-- If a dictionary is passed in, turn it into a list of string of "k=v"
-- Accepts a table which can be composed of k=v strings or map-like
-- specification, such as:
--
-- ```
-- {
--   "PRODUCTION=false";
--   "PATH=/usr/bin/";
--   PORT = 123;
--   HOST = "0.0.0.0";
-- }
-- ```
--
-- Non-string values will be cast with `tostring`
local function force_env_list(final_env)
  if final_env then
    local env = final_env
    final_env = {}
    for k,v in pairs(env) do
      -- If it's passed in as a dict, then convert to list of "k=v"
      if type(k) == "string" then
        table.insert(final_env, k..'='..tostring(v))
      elseif type(v) == 'string' then
        table.insert(final_env, v)
      else
        -- TODO is this right or should I exception here?
        -- Try to coerce other values to string.
        table.insert(final_env, tostring(v))
      end
    end
    return final_env
  end
end

local function format_message_with_content_length(encoded_message)
  return table.concat {
    'Content-Length: '; tostring(#encoded_message); '\r\n\r\n';
    encoded_message;
  }
end

--- Parse an LSP Message's header
-- @param header: The header to parse.
local function parse_headers(header)
  if type(header) ~= 'string' then
    return nil
  end
  local headers = {}
  for line in vim.gsplit(header, '\r\n', true) do
    if line == '' then
      break
    end
    local key, value = line:match("^%s*(%S+)%s*:%s*(.+)%s*$")
    if key then
      key = key:lower():gsub('%-', '_')
      headers[key] = value
    else
      local _ = log.error() and log.error("invalid header line %q", line)
      error(string.format("invalid header line %q", line))
    end
  end
  headers.content_length = tonumber(headers.content_length)
      or error(string.format("Content-Length not found in headers. %q", header))
  return headers
end

-- This is the start of any possible header patterns. The gsub converts it to a
-- case insensitive pattern.
local header_start_pattern = ("content"):gsub("%w", function(c) return "["..c..c:upper().."]" end)

local function request_parser_loop()
  local buffer = ''
  while true do
    -- A message can only be complete if it has a double CRLF and also the full
    -- payload, so first let's check for the CRLFs
    local start, finish = buffer:find('\r\n\r\n', 1, true)
    -- Start parsing the headers
    if start then
      -- This is a workaround for servers sending initial garbage before
      -- sending headers, such as if a bash script sends stdout. It assumes
      -- that we know all of the headers ahead of time. At this moment, the
      -- only valid headers start with "Content-*", so that's the thing we will
      -- be searching for.
      -- TODO(ashkan) I'd like to remove this, but it seems permanent :(
      local buffer_start = buffer:find(header_start_pattern)
      local headers = parse_headers(buffer:sub(buffer_start, start-1))
      buffer = buffer:sub(finish+1)
      local content_length = headers.content_length
      -- Keep waiting for data until we have enough.
      while #buffer < content_length do
        buffer = buffer..(coroutine.yield()
            or error("Expected more data for the body. The server may have died.")) -- TODO hmm.
      end
      local body = buffer:sub(1, content_length)
      buffer = buffer:sub(content_length + 1)
      -- Yield our data.
      buffer = buffer..(coroutine.yield(headers, body)
          or error("Expected more data for the body. The server may have died.")) -- TODO hmm.
    else
      -- Get more data since we don't have enough.
      buffer = buffer..(coroutine.yield()
          or error("Expected more data for the header. The server may have died.")) -- TODO hmm.
    end
  end
end

local client_errors = vim.tbl_add_reverse_lookup {
  INVALID_SERVER_MESSAGE       = 1;
  INVALID_SERVER_JSON          = 2;
  NO_RESULT_CALLBACK_FOUND     = 3;
  READ_ERROR                   = 4;
  NOTIFICATION_HANDLER_ERROR   = 5;
  SERVER_REQUEST_HANDLER_ERROR = 6;
  SERVER_RESULT_CALLBACK_ERROR = 7;
}

local function format_rpc_error(err)
  validate {
    err = { err, 't' };
  }
  local code_name = assert(protocol.ErrorCodes[err.code], "err.code is invalid")
  local message_parts = {"RPC", code_name}
  if err.message then
    table.insert(message_parts, "message = ")
    table.insert(message_parts, string.format("%q", err.message))
  end
  if err.data then
    table.insert(message_parts, "data = ")
    table.insert(message_parts, vim.inspect(err.data))
  end
  return table.concat(message_parts, ' ')
end

local function rpc_response_error(code, message, data)
  -- TODO should this error or just pick a sane error (like InternalError)?
  local code_name = assert(protocol.ErrorCodes[code], 'Invalid rpc error code')
  return setmetatable({
    code = code;
    message = message or code_name;
    data = data;
  }, {
    __tostring = format_rpc_error;
  })
end

local default_handlers = {}
function default_handlers.notification(method, params)
  local _ = log.debug() and log.debug('notification', method, params)
end
function default_handlers.server_request(method, params)
  local _ = log.debug() and log.debug('server_request', method, params)
  return nil, rpc_response_error(protocol.ErrorCodes.MethodNotFound)
end
function default_handlers.on_exit(code, signal)
  local _ = log.info() and log.info("client exit", { code = code, signal = signal })
end
function default_handlers.on_error(code, err)
  local _ = log.error() and log.error('client_error:', client_errors[code], err)
end

--- Create and start an RPC client.
-- @param cmd [
local function create_and_start_client(cmd, cmd_args, handlers, extra_spawn_params)
  local _ = log.info() and log.info("Starting RPC client", {cmd = cmd, args = cmd_args, extra = extra_spawn_params})
  validate {
    cmd = { cmd, 's' };
    cmd_args = { cmd_args, 't' };
    handlers = { handlers, 't', true };
  }

  if not (vim.fn.executable(cmd) == 1) then
    error(string.format("The given command %q is not executable.", cmd))
  end
  if handlers then
    local user_handlers = handlers
    handlers = {}
    for handle_name, default_handler in pairs(default_handlers) do
      local user_handler = user_handlers[handle_name]
      if user_handler then
        if type(user_handler) ~= 'function' then
          error(string.format("handler.%s must be a function", handle_name))
        end
        -- server_request is wrapped elsewhere.
        if not (handle_name == 'server_request'
          or handle_name == 'on_exit') -- TODO this blocks the loop exiting for some reason.
        then
          user_handler = schedule_wrap(user_handler)
        end
        handlers[handle_name] = user_handler
      else
        handlers[handle_name] = default_handler
      end
    end
  else
    handlers = default_handlers
  end

  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local message_index = 0
  local message_callbacks = {}

  local handle, pid
  do
    local function onexit(code, signal)
      stdin:close()
      stdout:close()
      stderr:close()
      handle:close()
      -- Make sure that message_callbacks can be gc'd.
      message_callbacks = nil
      handlers.on_exit(code, signal)
    end
    local spawn_params = {
      args = cmd_args;
      stdio = {stdin, stdout, stderr};
    }
    if extra_spawn_params then
      spawn_params.cwd = extra_spawn_params.cwd
      if spawn_params.cwd then
        assert(is_dir(spawn_params.cwd), "cwd must be a directory")
      end
      spawn_params.env = force_env_list(extra_spawn_params.env)
    end
    handle, pid = uv.spawn(cmd, spawn_params, onexit)
  end

  local function encode_and_send(payload)
    local _ = log.debug() and log.debug("rpc.send.payload", payload)
    if handle:is_closing() then return false end
    -- TODO(ashkan) remove this once we have a Lua json_encode
    schedule(function()
      local encoded = assert(json_encode(payload))
      stdin:write(format_message_with_content_length(encoded))
    end)
    return true
  end

  local function send_notification(method, params)
    local _ = log.debug() and log.debug("rpc.notify", method, params)
    return encode_and_send {
      jsonrpc = "2.0";
      method = method;
      params = params;
    }
  end

  local function send_response(request_id, err, result)
    return encode_and_send {
      id = request_id;
      jsonrpc = "2.0";
      error = err;
      result = result;
    }
  end

  local function send_request(method, params, callback)
    validate {
      callback = { callback, 'f' };
    }
    message_index = message_index + 1
    local message_id = message_index
    local result = encode_and_send {
      id = message_id;
      jsonrpc = "2.0";
      method = method;
      params = params;
    }
    if result then
      message_callbacks[message_id] = schedule_wrap(callback)
      return result, message_id
    else
      return false
    end
  end

  stderr:read_start(function(_err, chunk)
    if chunk then
      local _ = log.error() and log.error("rpc", cmd, "stderr", chunk)
    end
  end)

  local function on_error(errkind, ...)
    assert(client_errors[errkind])
    -- TODO what to do if this fails?
    pcall(handlers.on_error, errkind, ...)
  end
  local function pcall_handler(errkind, status, head, ...)
    if not status then
      on_error(errkind, head, ...)
      return status, head
    end
    return status, head, ...
  end
  local function try_call(errkind, fn, ...)
    return pcall_handler(errkind, pcall(fn, ...))
  end

  -- TODO periodically check message_callbacks for old requests past a certain
  -- time and log them. This would require storing the timestamp. I could call
  -- them with an error then, perhaps.

  local function handle_body(body)
    local decoded, err = json_decode(body)
    if not decoded then
      on_error(client_errors.INVALID_SERVER_JSON, err)
    end
    local _ = log.debug() and log.debug("decoded", decoded)

    if type(decoded.method) == 'string' and decoded.id then
      -- Server Request
      decoded.params = convert_NIL(decoded.params)
      -- Schedule here so that the users functions don't trigger an error and
      -- we can still use the result.
      schedule(function()
        local status, result
        status, result, err = try_call(client_errors.SERVER_REQUEST_HANDLER_ERROR,
            handlers.server_request, decoded.method, decoded.params)
        local _ = log.debug() and log.debug("server_request: callback result", { status = status, result = result, err = err })
        if status then
          if not (result or err) then
            -- TODO this can be a problem if `null` is sent for result. needs vim.NIL
            error(string.format("method %q: either a result or an error must be sent to the server in response", decoded.method))
          end
          if err then
            assert(type(err) == 'table', "err must be a table. Use rpc_response_error to help format errors.")
            local code_name = assert(protocol.ErrorCodes[err.code], "Errors must use protocol.ErrorCodes. Use rpc_response_error to help format errors.")
            err.message = err.message or code_name
          end
        else
          -- On an exception, result will contain the error message.
          err = rpc_response_error(protocol.ErrorCodes.InternalError, result)
          result = nil
        end
        send_response(decoded.id, err, result)
      end)
    -- This works because we are expecting vim.NIL here
    elseif decoded.id and (decoded.result or decoded.error) then
      -- Server Result
      decoded.error = convert_NIL(decoded.error)
      decoded.result = convert_NIL(decoded.result)

      -- We sent a number, so we expect a number.
      local result_id = tonumber(decoded.id)
      local callback = message_callbacks[result_id]
      if callback then
        message_callbacks[result_id] = nil
        validate {
          callback = { callback, 'f' };
        }
        if decoded.error then
          decoded.error = setmetatable(decoded.error, {
            __tostring = format_rpc_error;
          })
        end
        try_call(client_errors.SERVER_RESULT_CALLBACK_ERROR,
            callback, decoded.error, decoded.result)
      else
        on_error(client_errors.NO_RESULT_CALLBACK_FOUND, decoded)
        local _ = log.error() and log.error("No callback found for server response id "..result_id)
      end
    elseif type(decoded.method) == 'string' then
      -- Notification
      decoded.params = convert_NIL(decoded.params)
      try_call(client_errors.NOTIFICATION_HANDLER_ERROR,
          handlers.notification, decoded.method, decoded.params)
    else
      -- Invalid server message
      on_error(client_errors.INVALID_SERVER_MESSAGE, decoded)
    end
  end
  -- TODO(ashkan) remove this once we have a Lua json_decode
  handle_body = schedule_wrap(handle_body)

  local request_parser = coroutine.wrap(request_parser_loop)
  request_parser()
  stdout:read_start(function(err, chunk)
    if err then
      -- TODO better handling. Can these be intermittent errors?
      on_error(client_errors.READ_ERROR, err)
      return
    end
    -- This should signal that we are done reading from the client.
    if not chunk then return end
    -- Flush anything in the parser by looping until we don't get a result
    -- anymore.
    while true do
      local headers, body = request_parser(chunk)
      -- If we successfully parsed, then handle the response.
      if headers then
        handle_body(body)
        -- Set chunk to empty so that we can call request_parser to get
        -- anything existing in the parser to flush.
        chunk = ''
      else
        break
      end
    end
  end)

  return {
    pid = pid;
    handle = handle;
    request = send_request;
    notify = send_notification;
  }
end

return {
  start = create_and_start_client;
  rpc_response_error = rpc_response_error;
  format_rpc_error = format_rpc_error;
  client_errors = client_errors;
}
-- vim:sw=2 ts=2 et
