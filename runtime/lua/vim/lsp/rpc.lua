local uv = vim.loop
local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')

-- TODO use something faster than vim.fn?
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
  for line in vim.gsplit(header, '\\r\\n', true) do
    if line == '' then
      break
    end
    local key, value = line:match("^%s*(%S+)%s*:%s*(%S+)%s*$")
    if key then
      key = key:lower():gsub('%-', '_')
      headers[key] = value
    else
      _ = log.error() and log.error("invalid header line %q", line)
      error(string.format("invalid header line %q", line))
    end
  end
  headers.content_length = tonumber(headers.content_length)
  assert(headers.content_length, "Content-Length not found in headers.")
  return headers
end

local function request_parser_loop()
  local buffer = ''
  while true do
    -- A message can only be complete if it has a double CRLF and also the full
    -- payload, so first let's check for the CRLFs
    local start, finish = buffer:find('\r\n\r\n', 1, true)
    -- Start parsing the headers
    if start then
      local headers = parse_headers(buffer:sub(1, start-1))
      buffer = buffer:sub(finish+1)
      local content_length = headers.content_length
      -- Keep waiting for data until we have enough.
      while #buffer < content_length do
        buffer = buffer..assert(coroutine.yield(), ":( body") -- TODO hmm.
      end
      local body = buffer:sub(1, content_length)
      buffer = buffer:sub(content_length + 1)
      -- Yield our data.
      buffer = buffer..assert(coroutine.yield(headers, body), ':( cont') -- TODO hmm.
    else
      -- Get more data since we don't have enough.
      buffer = buffer..assert(coroutine.yield(), ":( header") -- TODO hmm.
    end
  end
end

local CLIENT_ERRORS = vim.tbl_add_reverse_lookup {
  INVALID_SERVER_MESSAGE       = 1;
  INVALID_SERVER_JSON          = 2;
  NO_RESULT_CALLBACK_FOUND     = 3;
  READ_ERROR                   = 4;
  NOTIFICATION_HANDLER_ERROR   = 5;
  SERVER_REQUEST_HANDLER_ERROR = 6;
  SERVER_RESULT_CALLBACK_ERROR = 7;
}

local function rpc_response_error(code, message, data)
  -- TODO should this error or just pick a sane error?
  local code_name = assert(protocol.ErrorCodes[code], 'Invalid rpc error code')
  return {
    code = code;
    message = message or code_name;
    data = data;
  }
end

local default_handlers = {}
function default_handlers.notification(method, params)
  _ = log.info() and log.info('notification', method, params)
end
function default_handlers.server_request(method, params)
  _ = log.info() and log.info('server_request', method, params)
  return nil, rpc_response_error(protocol.ErrorCodes.MethodNotFound)
end
function default_handlers.on_exit() end
-- TODO use protocol.ErrorCodes instead?
function default_handlers.on_error(code, err)
  _ = log.info() and log.info('client_error:', CLIENT_ERRORS[code], err)
end

--- Create and start an RPC client.
local function create_and_start_client(cmd, cmd_args, handlers, extra_spawn_params)
  _ = log.info() and log.info("starting client", {cmd, cmd_args})
  assert(type(cmd) == 'string', "cmd must be a string")
  assert(type(cmd_args) == 'table', "cmd_args must be a table")

  -- TODO make sure this is always correct.
  if not (vim.fn.executable(cmd) == 1) then
    error(string.format("The given command %q is not executable.", cmd))
  end
  handlers = vim.tbl_extend("keep", handlers or {}, default_handlers)

  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle, pid
  do
    local function onexit(code, signal)
      stdin:close()
      stdout:close()
      stderr:close()
      handle:close()
      handlers.on_exit()
    end
    local spawn_params = {
      args = cmd_args;
      stdio = {stdin, stdout, stderr};
    }
    -- TODO add stuff like cwd and env.
    -- if extra_spawn_params then
    -- end
    handle, pid = uv.spawn(cmd, spawn_params, onexit)
  end

  local message_index = 0
  local message_callbacks = {}

  local function encode_and_send(payload)
    _ = log.debug() and log.debug("payload", payload)
    if handle:is_closing() then return false end
    local encoded = assert(json_encode(payload))
    stdin:write(format_message_with_content_length(encoded))
    return true
  end

  local function send_notification(method, params)
    _ = log.info() and log.info('notify', method, params)
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
    message_index = message_index + 1
    local message_id = message_index
    -- TODO check the result here and assert it went correctly.
    local result = encode_and_send {
      id = message_id;
      jsonrpc = "2.0";
      method = method;
      params = params;
    }
    if result then
      -- TODO vim.schedule here?
      -- TODO vim.schedule here?
      -- TODO vim.schedule here?
      -- TODO vim.schedule here?
      message_callbacks[message_id] = vim.schedule_wrap(callback)
--      message_callbacks[message_id] = callback
      return result, message_id
    else
      return false
    end
  end

  -- TODO delete
  -- TODO delete
  -- TODO delete
  local stderroutput = io.open("/home/ashkan/lsp.log", "w")
  stderroutput:setvbuf("no")
  stderr:read_start(function(err, chunk)
    if chunk then
      stderroutput:write(chunk)
    end
  end)

  local function on_error(errkind, ...)
    assert(CLIENT_ERRORS[errkind])
    -- TODO what to do if this fails?
    pcall(handlers.on_error, errkind, ...)
  end
  local function pcall_handler(errkind, status, head, ...)
    if not status then
      on_error(errkind, ...)
      return status, head
    end
    return status, head, ...
  end
  local function try_call(errkind, fn, ...)
    return pcall_handler(errkind, pcall(fn, ...))
  end

  local function handle_body(body)
    -- TODO handle invalid decoding.
    local decoded, err = json_decode(body)
    if not decoded then
      on_error(CLIENT_ERRORS.INVALID_SERVER_JSON, err)
    end
    _ = log.debug() and log.debug("decoded", decoded)

    if type(decoded.method) == 'string' and decoded.id then
      -- Server Request
      local status, result
      -- TODO make sure that these won't block anything. use vim.loop.send_async or schedule_wrap?
      status, result, err = try_call(CLIENT_ERRORS.SERVER_REQUEST_HANDLER_ERROR,
          handlers.server_request, decoded.method, decoded.params)
      if status then
        -- TODO what to do here? Fatal error?
        assert(result or err, "either a result or an error must be sent to the server in response")
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
    elseif decoded.id then
      -- Server Result

      -- TODO this condition (result or error) will fail if result is null in
      -- the success case. such as for textDocument/completion.
      --      elseif decoded.id and (decoded.result or decoded.error) then

      -- TODO verify decoded.id is a string or number?
      local result_id = tonumber(decoded.id)
      local callback = message_callbacks[result_id]
      if callback then
        message_callbacks[result_id] = nil
        assert(type(callback) == 'function', "callback must be a function")
        try_call(CLIENT_ERRORS.SERVER_RESULT_CALLBACK_ERROR,
            callback, decoded.error, decoded.result)
      else
        on_error(CLIENT_ERRORS.NO_RESULT_CALLBACK_FOUND, decoded)
        _ = log.error() and log.error("No callback found for server response id "..result_id)
      end
    elseif type(decoded.method) == 'string' then
      -- Notification
      try_call(CLIENT_ERRORS.NOTIFICATION_HANDLER_ERROR,
          handlers.notification, decoded.method, decoded.params)
    else
      -- Invalid server message
      on_error(CLIENT_ERRORS.INVALID_SERVER_MESSAGE, decoded)
    end
  end

  local request_parser = coroutine.wrap(request_parser_loop)
  request_parser()
  stdout:read_start(function(err, chunk)
    if err then
      -- TODO better handling. Can these be intermittent errors?
      on_error(CLIENT_ERRORS.READ_ERROR, err)
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
  ERRORS = CLIENT_ERRORS;
}
-- vim:sw=2 ts=2 et
