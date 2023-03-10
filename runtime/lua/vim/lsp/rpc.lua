local uv = vim.loop
local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local validate, schedule, schedule_wrap = vim.validate, vim.schedule, vim.schedule_wrap

local is_win = uv.os_uname().version:find('Windows')

---@private
--- Checks whether a given path exists and is a directory.
---@param filename (string) path to check
---@returns (bool)
local function is_dir(filename)
  local stat = uv.fs_stat(filename)
  return stat and stat.type == 'directory' or false
end

---@private
--- Merges current process env with the given env and returns the result as
--- a list of "k=v" strings.
---
--- <pre>
--- Example:
---
---  in:    { PRODUCTION="false", PATH="/usr/bin/", PORT=123, HOST="0.0.0.0", }
---  out:   { "PRODUCTION=false", "PATH=/usr/bin/", "PORT=123", "HOST=0.0.0.0", }
--- </pre>
---@param env (table) table of environment variable assignments
---@returns (table) list of `"k=v"` strings
local function env_merge(env)
  if env == nil then
    return env
  end
  -- Merge.
  env = vim.tbl_extend('force', vim.fn.environ(), env)
  local final_env = {}
  for k, v in pairs(env) do
    assert(type(k) == 'string', 'env must be a dict')
    table.insert(final_env, k .. '=' .. tostring(v))
  end
  return final_env
end

---@private
--- Embeds the given string into a table and correctly computes `Content-Length`.
---
---@param encoded_message (string)
---@returns (table) table containing encoded message and `Content-Length` attribute
local function format_message_with_content_length(encoded_message)
  return table.concat({
    'Content-Length: ',
    tostring(#encoded_message),
    '\r\n\r\n',
    encoded_message,
  })
end

---@private
--- Parses an LSP Message's header
---
---@param header string: The header to parse.
---@return table parsed headers
local function parse_headers(header)
  assert(type(header) == 'string', 'header must be a string')
  local headers = {}
  for line in vim.gsplit(header, '\r\n', true) do
    if line == '' then
      break
    end
    local key, value = line:match('^%s*(%S+)%s*:%s*(.+)%s*$')
    if key then
      key = key:lower():gsub('%-', '_')
      headers[key] = value
    else
      local _ = log.error() and log.error('invalid header line %q', line)
      error(string.format('invalid header line %q', line))
    end
  end
  headers.content_length = tonumber(headers.content_length)
    or error(string.format('Content-Length not found in headers. %q', header))
  return headers
end

-- This is the start of any possible header patterns. The gsub converts it to a
-- case insensitive pattern.
local header_start_pattern = ('content'):gsub('%w', function(c)
  return '[' .. c .. c:upper() .. ']'
end)

---@private
--- The actual workhorse.
local function request_parser_loop()
  local buffer = '' -- only for header part
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
      local headers = parse_headers(buffer:sub(buffer_start, start - 1))
      local content_length = headers.content_length
      -- Use table instead of just string to buffer the message. It prevents
      -- a ton of strings allocating.
      -- ref. http://www.lua.org/pil/11.6.html
      local body_chunks = { buffer:sub(finish + 1) }
      local body_length = #body_chunks[1]
      -- Keep waiting for data until we have enough.
      while body_length < content_length do
        local chunk = coroutine.yield()
          or error('Expected more data for the body. The server may have died.') -- TODO hmm.
        table.insert(body_chunks, chunk)
        body_length = body_length + #chunk
      end
      local last_chunk = body_chunks[#body_chunks]

      body_chunks[#body_chunks] = last_chunk:sub(1, content_length - body_length - 1)
      local rest = ''
      if body_length > content_length then
        rest = last_chunk:sub(content_length - body_length)
      end
      local body = table.concat(body_chunks)
      -- Yield our data.
      buffer = rest
        .. (
          coroutine.yield(headers, body)
          or error('Expected more data for the body. The server may have died.')
        ) -- TODO hmm.
    else
      -- Get more data since we don't have enough.
      buffer = buffer
        .. (
          coroutine.yield() or error('Expected more data for the header. The server may have died.')
        ) -- TODO hmm.
    end
  end
end

--- Mapping of error codes used by the client
local client_errors = {
  INVALID_SERVER_MESSAGE = 1,
  INVALID_SERVER_JSON = 2,
  NO_RESULT_CALLBACK_FOUND = 3,
  READ_ERROR = 4,
  NOTIFICATION_HANDLER_ERROR = 5,
  SERVER_REQUEST_HANDLER_ERROR = 6,
  SERVER_RESULT_CALLBACK_ERROR = 7,
}

client_errors = vim.tbl_add_reverse_lookup(client_errors)

--- Constructs an error message from an LSP error object.
---
---@param err (table) The error object
---@returns (string) The formatted error message
local function format_rpc_error(err)
  validate({
    err = { err, 't' },
  })

  -- There is ErrorCodes in the LSP specification,
  -- but in ResponseError.code it is not used and the actual type is number.
  local code
  if protocol.ErrorCodes[err.code] then
    code = string.format('code_name = %s,', protocol.ErrorCodes[err.code])
  else
    code = string.format('code_name = unknown, code = %s,', err.code)
  end

  local message_parts = { 'RPC[Error]', code }
  if err.message then
    table.insert(message_parts, 'message =')
    table.insert(message_parts, string.format('%q', err.message))
  end
  if err.data then
    table.insert(message_parts, 'data =')
    table.insert(message_parts, vim.inspect(err.data))
  end
  return table.concat(message_parts, ' ')
end

--- Creates an RPC response object/table.
---
---@param code integer RPC error code defined in `vim.lsp.protocol.ErrorCodes`
---@param message string|nil arbitrary message to send to server
---@param data any|nil arbitrary data to send to server
local function rpc_response_error(code, message, data)
  -- TODO should this error or just pick a sane error (like InternalError)?
  local code_name = assert(protocol.ErrorCodes[code], 'Invalid RPC error code')
  return setmetatable({
    code = code,
    message = message or code_name,
    data = data,
  }, {
    __tostring = format_rpc_error,
  })
end

local default_dispatchers = {}

---@private
--- Default dispatcher for notifications sent to an LSP server.
---
---@param method (string) The invoked LSP method
---@param params (table): Parameters for the invoked LSP method
function default_dispatchers.notification(method, params)
  local _ = log.debug() and log.debug('notification', method, params)
end
---@private
--- Default dispatcher for requests sent to an LSP server.
---
---@param method (string) The invoked LSP method
---@param params (table): Parameters for the invoked LSP method
---@returns `nil` and `vim.lsp.protocol.ErrorCodes.MethodNotFound`.
function default_dispatchers.server_request(method, params)
  local _ = log.debug() and log.debug('server_request', method, params)
  return nil, rpc_response_error(protocol.ErrorCodes.MethodNotFound)
end
---@private
--- Default dispatcher for when a client exits.
---
---@param code (integer): Exit code
---@param signal (integer): Number describing the signal used to terminate (if
---any)
function default_dispatchers.on_exit(code, signal)
  local _ = log.info() and log.info('client_exit', { code = code, signal = signal })
end
---@private
--- Default dispatcher for client errors.
---
---@param code (integer): Error code
---@param err (any): Details about the error
---any)
function default_dispatchers.on_error(code, err)
  local _ = log.error() and log.error('client_error:', client_errors[code], err)
end

---@private
local function create_read_loop(handle_body, on_no_chunk, on_error)
  local parse_chunk = coroutine.wrap(request_parser_loop)
  parse_chunk()
  return function(err, chunk)
    if err then
      on_error(err)
      return
    end

    if not chunk then
      if on_no_chunk then
        on_no_chunk()
      end
      return
    end

    while true do
      local headers, body = parse_chunk(chunk)
      if headers then
        handle_body(body)
        chunk = ''
      else
        break
      end
    end
  end
end

---@class RpcClient
---@field message_index integer
---@field message_callbacks table
---@field notify_reply_callbacks table
---@field transport table
---@field dispatchers table

---@class RpcClient
local Client = {}

---@private
function Client:encode_and_send(payload)
  local _ = log.debug() and log.debug('rpc.send', payload)
  if self.transport.is_closing() then
    return false
  end
  local encoded = vim.json.encode(payload)
  self.transport.write(format_message_with_content_length(encoded))
  return true
end

---@private
--- Sends a notification to the LSP server.
---@param method (string) The invoked LSP method
---@param params (any): Parameters for the invoked LSP method
---@returns (bool) `true` if notification could be sent, `false` if not
function Client:notify(method, params)
  return self:encode_and_send({
    jsonrpc = '2.0',
    method = method,
    params = params,
  })
end

---@private
--- sends an error object to the remote LSP process.
function Client:send_response(request_id, err, result)
  return self:encode_and_send({
    id = request_id,
    jsonrpc = '2.0',
    error = err,
    result = result,
  })
end

---@private
--- Sends a request to the LSP server and runs {callback} upon response.
---
---@param method (string) The invoked LSP method
---@param params (table|nil) Parameters for the invoked LSP method
---@param callback fun(err: lsp.ResponseError|nil, result: any) Callback to invoke
---@param notify_reply_callback (function|nil) Callback to invoke as soon as a request is no longer pending
---@return boolean success, integer|nil request_id true, request_id if request could be sent, `false` if not
function Client:request(method, params, callback, notify_reply_callback)
  validate({
    callback = { callback, 'f' },
    notify_reply_callback = { notify_reply_callback, 'f', true },
  })
  self.message_index = self.message_index + 1
  local message_id = self.message_index
  local result = self:encode_and_send({
    id = message_id,
    jsonrpc = '2.0',
    method = method,
    params = params,
  })
  local message_callbacks = self.message_callbacks
  local notify_reply_callbacks = self.notify_reply_callbacks
  if result then
    if message_callbacks then
      message_callbacks[message_id] = schedule_wrap(callback)
    else
      return false
    end
    if notify_reply_callback and notify_reply_callbacks then
      notify_reply_callbacks[message_id] = schedule_wrap(notify_reply_callback)
    end
    return result, message_id
  else
    return false
  end
end

---@private
function Client:on_error(errkind, ...)
  assert(client_errors[errkind])
  -- TODO what to do if this fails?
  pcall(self.dispatchers.on_error, errkind, ...)
end

---@private
function Client:pcall_handler(errkind, status, head, ...)
  if not status then
    self:on_error(errkind, head, ...)
    return status, head
  end
  return status, head, ...
end

---@private
function Client:try_call(errkind, fn, ...)
  return self:pcall_handler(errkind, pcall(fn, ...))
end

-- TODO periodically check message_callbacks for old requests past a certain
-- time and log them. This would require storing the timestamp. I could call
-- them with an error then, perhaps.

---@private
function Client:handle_body(body)
  local ok, decoded = pcall(vim.json.decode, body, { luanil = { object = true } })
  if not ok then
    self:on_error(client_errors.INVALID_SERVER_JSON, decoded)
    return
  end
  local _ = log.debug() and log.debug('rpc.receive', decoded)

  if type(decoded.method) == 'string' and decoded.id then
    local err
    -- Schedule here so that the users functions don't trigger an error and
    -- we can still use the result.
    schedule(function()
      coroutine.wrap(function()
        local status, result
        status, result, err = self:try_call(
          client_errors.SERVER_REQUEST_HANDLER_ERROR,
          self.dispatchers.server_request,
          decoded.method,
          decoded.params
        )
        local _ = log.debug()
          and log.debug(
            'server_request: callback result',
            { status = status, result = result, err = err }
          )
        if status then
          if result == nil and err == nil then
            error(
              string.format(
                'method %q: either a result or an error must be sent to the server in response',
                decoded.method
              )
            )
          end
          if err then
            assert(
              type(err) == 'table',
              'err must be a table. Use rpc_response_error to help format errors.'
            )
            local code_name = assert(
              protocol.ErrorCodes[err.code],
              'Errors must use protocol.ErrorCodes. Use rpc_response_error to help format errors.'
            )
            err.message = err.message or code_name
          end
        else
          -- On an exception, result will contain the error message.
          err = rpc_response_error(protocol.ErrorCodes.InternalError, result)
          result = nil
        end
        self:send_response(decoded.id, err, result)
      end)()
    end)
    -- This works because we are expecting vim.NIL here
  elseif decoded.id and (decoded.result ~= vim.NIL or decoded.error ~= vim.NIL) then
    -- We sent a number, so we expect a number.
    local result_id = assert(tonumber(decoded.id), 'response id must be a number')

    -- Notify the user that a response was received for the request
    local notify_reply_callbacks = self.notify_reply_callbacks
    local notify_reply_callback = notify_reply_callbacks and notify_reply_callbacks[result_id]
    if notify_reply_callback then
      validate({
        notify_reply_callback = { notify_reply_callback, 'f' },
      })
      notify_reply_callback(result_id)
      notify_reply_callbacks[result_id] = nil
    end

    local message_callbacks = self.message_callbacks

    -- Do not surface RequestCancelled to users, it is RPC-internal.
    if decoded.error then
      local mute_error = false
      if decoded.error.code == protocol.ErrorCodes.RequestCancelled then
        local _ = log.debug() and log.debug('Received cancellation ack', decoded)
        mute_error = true
      end

      if mute_error then
        -- Clear any callback since this is cancelled now.
        -- This is safe to do assuming that these conditions hold:
        -- - The server will not send a result callback after this cancellation.
        -- - If the server sent this cancellation ACK after sending the result, the user of this RPC
        -- client will ignore the result themselves.
        if result_id and message_callbacks then
          message_callbacks[result_id] = nil
        end
        return
      end
    end

    local callback = message_callbacks and message_callbacks[result_id]
    if callback then
      message_callbacks[result_id] = nil
      validate({
        callback = { callback, 'f' },
      })
      if decoded.error then
        decoded.error = setmetatable(decoded.error, {
          __tostring = format_rpc_error,
        })
      end
      self:try_call(
        client_errors.SERVER_RESULT_CALLBACK_ERROR,
        callback,
        decoded.error,
        decoded.result
      )
    else
      self:on_error(client_errors.NO_RESULT_CALLBACK_FOUND, decoded)
      local _ = log.error() and log.error('No callback found for server response id ' .. result_id)
    end
  elseif type(decoded.method) == 'string' then
    -- Notification
    self:try_call(
      client_errors.NOTIFICATION_HANDLER_ERROR,
      self.dispatchers.notification,
      decoded.method,
      decoded.params
    )
  else
    -- Invalid server message
    self:on_error(client_errors.INVALID_SERVER_MESSAGE, decoded)
  end
end

---@private
---@return RpcClient
local function new_client(dispatchers, transport)
  local state = {
    message_index = 0,
    message_callbacks = {},
    notify_reply_callbacks = {},
    transport = transport,
    dispatchers = dispatchers,
  }
  return setmetatable(state, { __index = Client })
end

---@private
---@param client RpcClient
local function public_client(client)
  local result = {}

  ---@private
  function result.is_closing()
    return client.transport.is_closing()
  end

  ---@private
  function result.terminate()
    client.transport.terminate()
  end

  --- Sends a request to the LSP server and runs {callback} upon response.
  ---
  ---@param method (string) The invoked LSP method
  ---@param params (table|nil) Parameters for the invoked LSP method
  ---@param callback fun(err: lsp.ResponseError | nil, result: any) Callback to invoke
  ---@param notify_reply_callback (function|nil) Callback to invoke as soon as a request is no longer pending
  ---@return boolean success, integer|nil request_id true, message_id if request could be sent, `false` if not
  function result.request(method, params, callback, notify_reply_callback)
    return client:request(method, params, callback, notify_reply_callback)
  end

  --- Sends a notification to the LSP server.
  ---@param method (string) The invoked LSP method
  ---@param params (table|nil): Parameters for the invoked LSP method
  ---@returns (bool) `true` if notification could be sent, `false` if not
  function result.notify(method, params)
    return client:notify(method, params)
  end

  return result
end

---@private
local function merge_dispatchers(dispatchers)
  if dispatchers then
    local user_dispatchers = dispatchers
    dispatchers = {}
    for dispatch_name, default_dispatch in pairs(default_dispatchers) do
      local user_dispatcher = user_dispatchers[dispatch_name]
      if user_dispatcher then
        if type(user_dispatcher) ~= 'function' then
          error(string.format('dispatcher.%s must be a function', dispatch_name))
        end
        -- server_request is wrapped elsewhere.
        if
          not (dispatch_name == 'server_request' or dispatch_name == 'on_exit') -- TODO this blocks the loop exiting for some reason.
        then
          user_dispatcher = schedule_wrap(user_dispatcher)
        end
        dispatchers[dispatch_name] = user_dispatcher
      else
        dispatchers[dispatch_name] = default_dispatch
      end
    end
  else
    dispatchers = default_dispatchers
  end
  return dispatchers
end

--- Create a LSP RPC client factory that connects via TCP to the given host
--- and port
---
---@param host string
---@param port integer
---@return function
local function connect(host, port)
  return function(dispatchers)
    dispatchers = merge_dispatchers(dispatchers)
    local tcp = uv.new_tcp()
    local closing = false
    local transport = {
      write = function(msg)
        tcp:write(msg)
      end,
      is_closing = function()
        return closing
      end,
      terminate = function()
        if not closing then
          closing = true
          tcp:shutdown()
          tcp:close()
          dispatchers.on_exit(0, 0)
        end
      end,
    }
    local client = new_client(dispatchers, transport)
    tcp:connect(host, port, function(err)
      if err then
        vim.schedule(function()
          vim.notify(
            string.format('Could not connect to %s:%s, reason: %s', host, port, vim.inspect(err)),
            vim.log.levels.WARN
          )
        end)
        return
      end
      local handle_body = function(body)
        client:handle_body(body)
      end
      tcp:read_start(create_read_loop(handle_body, transport.terminate, function(read_err)
        client:on_error(client_errors.READ_ERROR, read_err)
      end))
    end)

    return public_client(client)
  end
end

--- Starts an LSP server process and create an LSP RPC client object to
--- interact with it. Communication with the spawned process happens via stdio. For
--- communication via TCP, spawn a process manually and use |vim.lsp.rpc.connect()|
---
---@param cmd (string) Command to start the LSP server.
---@param cmd_args (table) List of additional string arguments to pass to {cmd}.
---@param dispatchers table|nil Dispatchers for LSP message types. Valid
---dispatcher names are:
--- - `"notification"`
--- - `"server_request"`
--- - `"on_error"`
--- - `"on_exit"`
---@param extra_spawn_params table|nil Additional context for the LSP
--- server process. May contain:
--- - {cwd} (string) Working directory for the LSP server process
--- - {env} (table) Additional environment variables for LSP server process
---@returns Client RPC object.
---
---@returns Methods:
--- - `notify()` |vim.lsp.rpc.notify()|
--- - `request()` |vim.lsp.rpc.request()|
--- - `is_closing()` returns a boolean indicating if the RPC is closing.
--- - `terminate()` terminates the RPC client.
local function start(cmd, cmd_args, dispatchers, extra_spawn_params)
  local _ = log.info()
    and log.info('Starting RPC client', { cmd = cmd, args = cmd_args, extra = extra_spawn_params })
  validate({
    cmd = { cmd, 's' },
    cmd_args = { cmd_args, 't' },
    dispatchers = { dispatchers, 't', true },
  })

  if extra_spawn_params and extra_spawn_params.cwd then
    assert(is_dir(extra_spawn_params.cwd), 'cwd must be a directory')
  end

  dispatchers = merge_dispatchers(dispatchers)
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local handle, pid

  local client = new_client(dispatchers, {
    write = function(msg)
      stdin:write(msg)
    end,
    is_closing = function()
      return handle == nil or handle:is_closing()
    end,
    terminate = function()
      if handle then
        handle:kill(15)
      end
    end,
  })

  ---@private
  --- Callback for |vim.loop.spawn()| Closes all streams and runs the `on_exit` dispatcher.
  ---@param code (integer) Exit code
  ---@param signal (integer) Signal that was used to terminate (if any)
  local function onexit(code, signal)
    stdin:close()
    stdout:close()
    stderr:close()
    handle:close()
    dispatchers.on_exit(code, signal)
  end
  local spawn_params = {
    args = cmd_args,
    stdio = { stdin, stdout, stderr },
    detached = not is_win,
  }
  if extra_spawn_params then
    spawn_params.cwd = extra_spawn_params.cwd
    spawn_params.env = env_merge(extra_spawn_params.env)
    if extra_spawn_params.detached ~= nil then
      spawn_params.detached = extra_spawn_params.detached
    end
  end
  handle, pid = uv.spawn(cmd, spawn_params, onexit)
  if handle == nil then
    stdin:close()
    stdout:close()
    stderr:close()
    local msg = string.format('Spawning language server with cmd: `%s` failed', cmd)
    if string.match(pid, 'ENOENT') then
      msg = msg
        .. '. The language server is either not installed, missing from PATH, or not executable.'
    else
      msg = msg .. string.format(' with error message: %s', pid)
    end
    vim.notify(msg, vim.log.levels.WARN)
    return
  end

  stderr:read_start(function(_, chunk)
    if chunk then
      local _ = log.error() and log.error('rpc', cmd, 'stderr', chunk)
    end
  end)

  local handle_body = function(body)
    client:handle_body(body)
  end
  stdout:read_start(create_read_loop(handle_body, nil, function(err)
    client:on_error(client_errors.READ_ERROR, err)
  end))

  return public_client(client)
end

return {
  start = start,
  connect = connect,
  rpc_response_error = rpc_response_error,
  format_rpc_error = format_rpc_error,
  client_errors = client_errors,
  create_read_loop = create_read_loop,
}
-- vim:sw=2 ts=2 et
