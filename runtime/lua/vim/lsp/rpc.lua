local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local lsp_transport = require('vim.lsp._transport')
local validate, schedule_wrap = vim.validate, vim.schedule_wrap

--- Embeds the given string into a table and correctly computes `Content-Length`.
---
--- @param message string
--- @return string message with `Content-Length` attribute
local function format_message_with_content_length(message)
  return table.concat({
    'Content-Length: ',
    tostring(#message),
    '\r\n\r\n',
    message,
  })
end

--- Extract content-length from the header
---
--- @param header string The header to parse
--- @return integer
local function get_content_length(header)
  for line in header:gmatch('(.-)\r\n') do
    if line == '' then
      break
    end
    local key, value = line:match('^%s*(%S+)%s*:%s*(%d+)%s*$')
    if key and key:lower() == 'content-length' then
      return assert(tonumber(value))
    end
  end
  error('Content-Length not found in header: ' .. header)
end

local M = {}

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

--- @type table<string,integer> | table<integer,string>
--- @nodoc
M.client_errors = vim.deepcopy(client_errors)
for k, v in pairs(client_errors) do
  M.client_errors[v] = k
end

--- Constructs an error message from an LSP error object.
---
---@param err table The error object
---@return string error_message The formatted error message
function M.format_rpc_error(err)
  validate('err', err, 'table')

  -- There is ErrorCodes in the LSP specification,
  -- but in ResponseError.code it is not used and the actual type is number.
  local code --- @type string
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

--- Creates an RPC response table `error` to be sent to the LSP response.
---
---@param code integer RPC error code defined, see `vim.lsp.protocol.ErrorCodes`
---@param message? string arbitrary message to send to server
---@param data? any arbitrary data to send to server
---
---@see lsp.ErrorCodes See `vim.lsp.protocol.ErrorCodes`
---@return lsp.ResponseError
function M.rpc_response_error(code, message, data)
  -- TODO should this error or just pick a sane error (like InternalError)?
  ---@type string
  local code_name = assert(protocol.ErrorCodes[code], 'Invalid RPC error code')
  return setmetatable({
    code = code,
    message = message or code_name,
    data = data,
  }, {
    __tostring = M.format_rpc_error,
  })
end

--- Dispatchers for LSP message types.
--- @class vim.lsp.rpc.Dispatchers
--- @inlinedoc
--- @field notification fun(method: string, params: table)
--- @field server_request fun(method: string, params: table): any?, lsp.ResponseError?
--- @field on_exit fun(code: integer, signal: integer)
--- @field on_error fun(code: integer, err: any)

--- @type vim.lsp.rpc.Dispatchers
local default_dispatchers = {
  --- Default dispatcher for notifications sent to an LSP server.
  ---
  ---@param method string The invoked LSP method
  ---@param params table Parameters for the invoked LSP method
  notification = function(method, params)
    log.debug('notification', method, params)
  end,

  --- Default dispatcher for requests sent to an LSP server.
  ---
  ---@param method string The invoked LSP method
  ---@param params table Parameters for the invoked LSP method
  ---@return any result (always nil for the default dispatchers)
  ---@return lsp.ResponseError error `vim.lsp.protocol.ErrorCodes.MethodNotFound`
  server_request = function(method, params)
    log.debug('server_request', method, params)
    return nil, M.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
  end,

  --- Default dispatcher for when a client exits.
  ---
  ---@param code integer Exit code
  ---@param signal integer Number describing the signal used to terminate (if any)
  on_exit = function(code, signal)
    log.info('client_exit', { code = code, signal = signal })
  end,

  --- Default dispatcher for client errors.
  ---
  ---@param code integer Error code
  ---@param err any Details about the error
  on_error = function(code, err)
    log.error('client_error:', M.client_errors[code], err)
  end,
}

local strbuffer = require('vim._stringbuffer')

local function request_parser_loop()
  local buf = strbuffer.new()
  while true do
    local msg = buf:tostring()
    local header_end = msg:find('\r\n\r\n', 1, true)
    if header_end then
      local header = buf:get(header_end + 1)
      buf:skip(2) -- skip past header boundary
      local content_length = get_content_length(header)
      while strbuffer.len(buf) < content_length do
        buf:put(coroutine.yield())
      end
      local body = buf:get(content_length)
      buf:put(coroutine.yield(body))
    else
      buf:put(coroutine.yield())
    end
  end
end

--- @private
--- @param handle_body fun(body: string)
--- @param on_exit? fun()
--- @param on_error fun(err: any)
function M.create_read_loop(handle_body, on_exit, on_error)
  local parse_chunk = coroutine.wrap(request_parser_loop) --[[@as fun(chunk: string?): string]]
  parse_chunk()
  return function(err, chunk)
    if err then
      on_error(err)
      return
    end

    if not chunk then
      if on_exit then
        on_exit()
      end
      return
    end

    while true do
      local body = parse_chunk(chunk)
      if body then
        handle_body(body)
        chunk = ''
      else
        break
      end
    end
  end
end

---@class (private) vim.lsp.rpc.Client
---@field message_index integer
---@field message_callbacks table<integer, function> dict of message_id to callback
---@field notify_reply_callbacks table<integer, function> dict of message_id to callback
---@field transport vim.lsp.rpc.Transport
---@field dispatchers vim.lsp.rpc.Dispatchers
local Client = {}

---@private
function Client:encode_and_send(payload)
  log.debug('rpc.send', payload)
  if self.transport:is_closing() then
    return false
  end
  local jsonstr = vim.json.encode(payload)

  self.transport:write(format_message_with_content_length(jsonstr))
  return true
end

---@package
--- Sends a notification to the LSP server.
---@param method string The invoked LSP method
---@param params any Parameters for the invoked LSP method
---@return boolean `true` if notification could be sent, `false` if not
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

---@package
--- Sends a request to the LSP server and runs {callback} upon response. |vim.lsp.rpc.request()|
---
---@param method string The invoked LSP method
---@param params table? Parameters for the invoked LSP method
---@param callback fun(err?: lsp.ResponseError, result: any) Callback to invoke
---@param notify_reply_callback? fun(message_id: integer) Callback to invoke as soon as a request is no longer pending
---@return boolean success `true` if request could be sent, `false` if not
---@return integer? message_id if request could be sent, `nil` if not
function Client:request(method, params, callback, notify_reply_callback)
  validate('callback', callback, 'function')
  validate('notify_reply_callback', notify_reply_callback, 'function', true)
  self.message_index = self.message_index + 1
  local message_id = self.message_index
  local result = self:encode_and_send({
    id = message_id,
    jsonrpc = '2.0',
    method = method,
    params = params,
  })

  if not result then
    return false
  end

  self.message_callbacks[message_id] = schedule_wrap(callback)
  if notify_reply_callback then
    self.notify_reply_callbacks[message_id] = schedule_wrap(notify_reply_callback)
  end
  return result, message_id
end

---@package
---@param errkind integer
---@param ... any
function Client:on_error(errkind, ...)
  assert(M.client_errors[errkind])
  -- TODO what to do if this fails?
  pcall(self.dispatchers.on_error, errkind, ...)
end

---@private
---@param errkind integer
---@param status boolean
---@param head any
---@param ... any
---@return boolean status
---@return any head
---@return any? ...
function Client:pcall_handler(errkind, status, head, ...)
  if not status then
    self:on_error(errkind, head, ...)
    return status, head
  end
  return status, head, ...
end

---@private
---@param errkind integer
---@param fn function
---@param ... any
---@return boolean status
---@return any head
---@return any? ...
function Client:try_call(errkind, fn, ...)
  return self:pcall_handler(errkind, pcall(fn, ...))
end

-- TODO periodically check message_callbacks for old requests past a certain
-- time and log them. This would require storing the timestamp. I could call
-- them with an error then, perhaps.

--- @package
--- @param body string
function Client:handle_body(body)
  local ok, decoded = pcall(vim.json.decode, body, { luanil = { object = true } })
  if not ok then
    self:on_error(M.client_errors.INVALID_SERVER_JSON, decoded)
    return
  end
  log.debug('rpc.receive', decoded)

  if type(decoded) ~= 'table' then
    self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, decoded)
  elseif type(decoded.method) == 'string' and decoded.id then
    local err --- @type lsp.ResponseError?
    -- Schedule here so that the users functions don't trigger an error and
    -- we can still use the result.
    vim.schedule(coroutine.wrap(function()
      local status, result
      status, result, err = self:try_call(
        M.client_errors.SERVER_REQUEST_HANDLER_ERROR,
        self.dispatchers.server_request,
        decoded.method,
        decoded.params
      )
      log.debug('server_request: callback result', { status = status, result = result, err = err })
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
          ---@cast err lsp.ResponseError
          assert(
            type(err) == 'table',
            'err must be a table. Use rpc_response_error to help format errors.'
          )
          ---@type string
          local code_name = assert(
            protocol.ErrorCodes[err.code],
            'Errors must use protocol.ErrorCodes. Use rpc_response_error to help format errors.'
          )
          err.message = err.message or code_name
        end
      else
        -- On an exception, result will contain the error message.
        err = M.rpc_response_error(protocol.ErrorCodes.InternalError, result)
        result = nil
      end
      self:send_response(decoded.id, err, result)
    end))
    -- This works because we are expecting vim.NIL here
  elseif decoded.id and (decoded.result ~= vim.NIL or decoded.error ~= vim.NIL) then
    -- We sent a number, so we expect a number.
    local result_id = assert(tonumber(decoded.id), 'response id must be a number')

    -- Notify the user that a response was received for the request
    local notify_reply_callback = self.notify_reply_callbacks[result_id]
    if notify_reply_callback then
      validate('notify_reply_callback', notify_reply_callback, 'function')
      notify_reply_callback(result_id)
      self.notify_reply_callbacks[result_id] = nil
    end

    -- Do not surface RequestCancelled to users, it is RPC-internal.
    if decoded.error then
      assert(type(decoded.error) == 'table')
      if decoded.error.code == protocol.ErrorCodes.RequestCancelled then
        log.debug('Received cancellation ack', decoded)
        -- Clear any callback since this is cancelled now.
        -- This is safe to do assuming that these conditions hold:
        -- - The server will not send a result callback after this cancellation.
        -- - If the server sent this cancellation ACK after sending the result, the user of this RPC
        -- client will ignore the result themselves.
        if result_id then
          self.message_callbacks[result_id] = nil
        end
        return
      end
    end

    local callback = self.message_callbacks[result_id]
    if callback then
      self.message_callbacks[result_id] = nil
      validate('callback', callback, 'function')
      if decoded.error then
        setmetatable(decoded.error, { __tostring = M.format_rpc_error })
      end
      self:try_call(
        M.client_errors.SERVER_RESULT_CALLBACK_ERROR,
        callback,
        decoded.error,
        decoded.result
      )
    else
      self:on_error(M.client_errors.NO_RESULT_CALLBACK_FOUND, decoded)
      log.error('No callback found for server response id ' .. result_id)
    end
  elseif type(decoded.method) == 'string' then
    -- Notification
    self:try_call(
      M.client_errors.NOTIFICATION_HANDLER_ERROR,
      self.dispatchers.notification,
      decoded.method,
      decoded.params
    )
  else
    -- Invalid server message
    self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, decoded)
  end
end

---@param dispatchers vim.lsp.rpc.Dispatchers
---@param transport vim.lsp.rpc.Transport
---@return vim.lsp.rpc.Client
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

--- Client RPC object
--- @class vim.lsp.rpc.PublicClient
---
--- See [vim.lsp.rpc.request()]
--- @field request fun(method: string, params: table?, callback: fun(err?: lsp.ResponseError, result: any), notify_reply_callback?: fun(message_id: integer)):boolean,integer?
---
--- See [vim.lsp.rpc.notify()]
--- @field notify fun(method: string, params: any): boolean
---
--- Indicates if the RPC is closing.
--- @field is_closing fun(): boolean
---
--- Terminates the RPC client.
--- @field terminate fun()

---@param client vim.lsp.rpc.Client
---@return vim.lsp.rpc.PublicClient
local function public_client(client)
  ---@type vim.lsp.rpc.PublicClient
  ---@diagnostic disable-next-line: missing-fields
  local result = {}

  ---@private
  function result.is_closing()
    return client.transport:is_closing()
  end

  ---@private
  function result.terminate()
    client.transport:terminate()
  end

  --- Sends a request to the LSP server and runs {callback} upon response.
  ---
  ---@param method (vim.lsp.protocol.Method.ClientToServer.Request) The invoked LSP method
  ---@param params (table?) Parameters for the invoked LSP method
  ---@param callback fun(err: lsp.ResponseError?, result: any) Callback to invoke
  ---@param notify_reply_callback? fun(message_id: integer) Callback to invoke as soon as a request is no longer pending
  ---@return boolean success `true` if request could be sent, `false` if not
  ---@return integer? message_id if request could be sent, `nil` if not
  function result.request(method, params, callback, notify_reply_callback)
    return client:request(method, params, callback, notify_reply_callback)
  end

  --- Sends a notification to the LSP server.
  ---@param method (vim.lsp.protocol.Method.ClientToServer.Notification) The invoked LSP method
  ---@param params (table?) Parameters for the invoked LSP method
  ---@return boolean `true` if notification could be sent, `false` if not
  function result.notify(method, params)
    return client:notify(method, params)
  end

  return result
end

---@param dispatchers vim.lsp.rpc.Dispatchers?
---@return vim.lsp.rpc.Dispatchers
local function merge_dispatchers(dispatchers)
  if not dispatchers then
    return default_dispatchers
  end
  ---@diagnostic disable-next-line: no-unknown
  for name, fn in pairs(dispatchers) do
    if type(fn) ~= 'function' then
      error(string.format('dispatcher.%s must be a function', name))
    end
  end
  ---@type vim.lsp.rpc.Dispatchers
  local merged = {
    notification = (
      dispatchers.notification and vim.schedule_wrap(dispatchers.notification)
      or default_dispatchers.notification
    ),
    on_error = (
      dispatchers.on_error and vim.schedule_wrap(dispatchers.on_error)
      or default_dispatchers.on_error
    ),
    on_exit = dispatchers.on_exit or default_dispatchers.on_exit,
    server_request = dispatchers.server_request or default_dispatchers.server_request,
  }
  return merged
end

--- @param client vim.lsp.rpc.Client
--- @param on_exit? fun()
local function create_client_read_loop(client, on_exit)
  --- @param body string
  local function handle_body(body)
    client:handle_body(body)
  end

  local function on_error(err)
    client:on_error(M.client_errors.READ_ERROR, err)
  end

  return M.create_read_loop(handle_body, on_exit, on_error)
end

--- Create a LSP RPC client factory that connects to either:
---
---  - a named pipe (windows)
---  - a domain socket (unix)
---  - a host and port via TCP
---
--- Return a function that can be passed to the `cmd` field for
--- |vim.lsp.start()|.
---
---@param host_or_path string host to connect to or path to a pipe/domain socket
---@param port integer? TCP port to connect to. If absent the first argument must be a pipe
---@return fun(dispatchers: vim.lsp.rpc.Dispatchers): vim.lsp.rpc.PublicClient
function M.connect(host_or_path, port)
  validate('host_or_path', host_or_path, 'string')
  validate('port', port, 'number', true)

  return function(dispatchers)
    validate('dispatchers', dispatchers, 'table', true)

    dispatchers = merge_dispatchers(dispatchers)

    local transport = lsp_transport.TransportConnect.new()
    local client = new_client(dispatchers, transport)
    local on_read = create_client_read_loop(client, function()
      transport:terminate()
    end)
    transport:connect(host_or_path, port, on_read, dispatchers.on_exit)

    return public_client(client)
  end
end

--- Additional context for the LSP server process.
--- @class vim.lsp.rpc.ExtraSpawnParams
--- @inlinedoc
--- @field cwd? string Working directory for the LSP server process
--- @field detached? boolean Detach the LSP server process from the current process
--- @field env? table<string,string> Additional environment variables for LSP server process. See |vim.system()|

--- Starts an LSP server process and create an LSP RPC client object to
--- interact with it. Communication with the spawned process happens via stdio. For
--- communication via TCP, spawn a process manually and use |vim.lsp.rpc.connect()|
---
--- @param cmd string[] Command to start the LSP server.
--- @param dispatchers? vim.lsp.rpc.Dispatchers
--- @param extra_spawn_params? vim.lsp.rpc.ExtraSpawnParams
--- @return vim.lsp.rpc.PublicClient
function M.start(cmd, dispatchers, extra_spawn_params)
  log.info('Starting RPC client', { cmd = cmd, extra = extra_spawn_params })

  validate('cmd', cmd, 'table')
  validate('dispatchers', dispatchers, 'table', true)

  dispatchers = merge_dispatchers(dispatchers)

  local transport = lsp_transport.TransportRun.new()
  local client = new_client(dispatchers, transport)
  local on_read = create_client_read_loop(client)
  transport:run(cmd, extra_spawn_params, on_read, dispatchers.on_exit)

  return public_client(client)
end

return M
