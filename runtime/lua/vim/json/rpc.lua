local net_transport = require('vim.net._transport')
local validate = vim.validate

--- The error codes from and including -32768 to -32000 are reserved for pre-defined errors.
--- Any code within this range, but not defined explicitly below is reserved for future use.
--- The error codes are nearly the same as those suggested for XML-RPC at the
--- following url: http://xmlrpc-epi.sourceforge.net/specs/rfc.fault_codes.php
---@enum vim.json.rpc.error.Code
local error_code = {
  lower_bound = -32768,
  upper_bound = -32000,
  -- Invalid JSON was received by the server.
  -- An error occurred on the server while parsing the JSON text.
  parse_error = -32700,
  -- The JSON sent is not a valid Request object.
  invalid_request = -32600,
  -- The method does not exist / is not available.
  method_not_found = -32601,
  -- Invalid method parameter(s).
  invalid_params = -32602,
  -- Internal JSON-RPC error.
  internal_error = -32603,
}

local M = {}

--- Mapping of error codes used by the client
--- @enum vim.json.rpc.ClientErrors
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

--- Dispatchers for incoming JSON-RPC messages.
---
---@class vim.json.rpc.Dispatchers
---
--- Invoked on notifications received from the other endpoint.
---
--- - Parameters:
---    - {method}: (`string`) The invoked JSON-RPC method
---    - {params}: (`table?`) Parameters for the invoked method
---@field on_notify fun(method: string, params?: table)
---
--- Invoked on requests received from the other endpoint.
---
--- - Parameters:
---   - {method}: (`string`) The invoked JSON-RPC method
---   - {params}: (`table?`) Parameters for the invoked method
--- - Return (multiple):
---   - {result}: (`any?`) Always nil for the default dispatchers
---   - {err}: (`vim.json.rpc.Error?`)
---
--- Note that:
---   - {result} is required on success and
---     must not exist if there was an error invoking the method.
---   - {error} is required on error and
---     must not exist if there was no error triggered during invocation.
---@field on_request fun(method: string, params?: table): any?, vim.json.rpc.Error?
---
--- Invoked when the connection exits.
---
--- - Parameters:
---   - {code}: (`integer`) Exit code
---   - {signal}: (`integer`) Number describing the signal used to terminate (if any)
---@field on_exit fun(code: integer, signal: integer)
---
--- Invoked when the connection errors.
---
--- - Parameters:
---   - {code}: (`integer`) Error code
---   - {err}: (`any`) Details about the error
---@field on_error fun(code: integer, err: any)

--- Represents one side of a JSON-RPC connection.
---
--- Unlike a strict client or server, it can both initiate and receive requests.
---
--- @class vim.json.rpc.Connection
---
--- Increments automatically after each request is sent, use as the request ID.
--- @field private request_count integer
---
--- Callbacks that is invoked when the sent request is responded to.
---
--- Index in the form of request_id -> callback
--- @field private request_callbacks table<integer, fun(err?: vim.json.rpc.Error, result: any, request_id: integer)?>
---
--- @field private transport vim.net.Transport
--- @field private message_stream vim.net.MessageStream
--- @field private dispatchers vim.json.rpc.Dispatchers
--- @field private log vim.Log
local Connection = {}

---@package
---@param transport vim.net.Transport
---@param dispatchers vim.json.rpc.Dispatchers
---@param log vim.Log
---@param decode fun(buf: vim._core.stringbuffer): string?
---@param encode fun(msg: string): string
---@return vim.json.rpc.Connection
function Connection.new(transport, dispatchers, log, decode, encode)
  local self = setmetatable({
    request_count = 0,
    request_callbacks = {},
    transport = transport,
    dispatchers = dispatchers,
    log = log,
  }, { __index = Connection })

  local message_stream = net_transport.MessageStream.new(decode, encode, function(err, data)
    if err then
      self:on_error(M.client_errors.READ_ERROR, err)
    elseif data then
      local ok, message = pcall(vim.json.decode, data)
      if not ok then
        self:on_error(M.client_errors.INVALID_SERVER_JSON, message)
        return
      elseif type(message) ~= 'table' then
        self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, message)
        return
      end ---@cast message vim.json.rpc.Message

      self:on_receive(message)
    else
      self:terminate()
    end
  end, function(err)
    self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, err)
    self:terminate()
  end)
  self.message_stream = message_stream

  transport:listen(function(err, data)
    message_stream:feed(err, data)
  end, dispatchers.on_exit)
  return self
end

--- Indicates if this JSON-RPC connection is closing.
function Connection:is_closing()
  return self.transport:is_closing()
end

--- Terminates this JSON-RPC connection.
function Connection:terminate()
  return self.transport:terminate()
end

--- Encodes a Lua Object to stringfied JSON and sends it to the other endpoint.
---
---@private
---@param message vim.json.rpc.Message
function Connection:send(message)
  self.log.debug('rpc.send', message)
  if self.transport:is_closing() then
    return false
  end

  local json = vim.json.encode(message)
  self.transport:write(self.message_stream.encode(json))
  return true
end

--- Sends a notification to the other endpoint.
---
---@param method string The invoked JSON-RPC method
---@param params? table Parameters for the invoked method
---@return boolean `true` if notification could be sent, `false` if not
function Connection:notify(method, params)
  return self:send(
    ---@type vim.json.rpc.Notification
    {
      jsonrpc = '2.0',
      method = method,
      params = params,
    }
  )
end

--- Sends a response to the other endpoint.
---
---@private
---@param request_id vim.json.rpc.Request.Id
---@param err? vim.json.rpc.Error
---@param result? any
function Connection:respond(request_id, err, result)
  return self:send(
    ---@type vim.json.rpc.Response
    {
      id = request_id,
      jsonrpc = '2.0',
      error = err,
      result = result,
    }
  )
end

--- Sends a request to the other endpoint and runs {callback} upon response.
---
---@param method string The invoked JSON-RPC method
---@param params? table Parameters for the invoked method
---@param callback fun(err?: vim.json.rpc.Error, result: any, request_id: integer) Callback to invoke
---@return boolean success `true` if request could be sent, `false` if not
---@return integer? request_id if request could be sent, `nil` if not
function Connection:request(method, params, callback)
  validate('callback', callback, 'function')
  self.request_count = self.request_count + 1
  local request_id = self.request_count
  local result = self:send(
    ---@type vim.json.rpc.Request
    {
      id = request_id,
      jsonrpc = '2.0',
      method = method,
      params = params,
    }
  )

  if not result then
    return false
  end

  self.request_callbacks[request_id] = vim.schedule_wrap(callback)
  return result, request_id
end

---@package
---@param errkind vim.json.rpc.ClientErrors
---@param err any
function Connection:on_error(errkind, err)
  assert(M.client_errors[errkind])
  -- TODO what to do if this fails?
  pcall(self.dispatchers.on_error, errkind, err)
end

-- TODO periodically check request_callbacks for old requests past a certain
-- time and log them. This would require storing the timestamp. I could call
-- them with an error then, perhaps.

--- @package
--- @param message vim.json.rpc.Message
function Connection:on_receive(message)
  self.log.debug('rpc.receive', message)

  if
    -- Received a request.
    type(message.method) == 'string' and message.id
  then
    ---@cast message vim.json.rpc.Request
    if type(message.id) ~= 'number' and type(message.id) ~= 'string' and message.id ~= vim.NIL then
      self.log.error(
        'Server request id must be a number or string, got ' .. type(message.id),
        message.method,
        message.id
      )
      self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, message)
      return
    end

    -- Schedule here so that the users functions don't trigger an error and
    -- we can still use the result.
    vim.schedule(coroutine.wrap(function()
      xpcall(function()
        --- @type any, vim.json.rpc.Error?
        local result, err = self.dispatchers.on_request(message.method, message.params)
        self.log.debug('remote_request: callback result', { result = result, err = err })
        if result == nil and err == nil then
          error(
            string.format(
              'method %q: either a result or an error must be sent to the server in response',
              message.method
            )
          )
        end
        if err then
          validate('result', result, 'nil')
          validate('err', err, 'table')
          validate('err.code', err.code, 'number')
          validate('err.message', err.message, 'string')
          assert(
            err.code < error_code.lower_bound or error_code.upper_bound < err.code,
            string.format(
              'method %q: error code %d is reserved by the JSON-RPC specification for pre-defined errors',
              message.method,
              err.code
            )
          )
        end
        self:respond(message.id, err, result)
      end, function(err)
        self:on_error(M.client_errors.SERVER_REQUEST_HANDLER_ERROR, err)
        self:respond(message.id, { code = error_code.internal_error, message = err }, nil)
      end)
    end))
  elseif
    -- Received a response to a request we sent.
    message.id
  then
    ---@cast message vim.json.rpc.Response
    -- If there was an error in detecting the id in the Request object
    -- (e.g. Parse error/Invalid Request), it must be Null.
    if message.id == vim.NIL then
      self.log.warn('Server sent response with null id', message)
      self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, message)
      return
    end
    -- Proceed only if exactly one of 'result' or 'error' is present,
    -- as required by the JSON-RPC spec:
    -- * If 'error' is nil, then 'result' must be present.
    -- * If 'result' is nil, then 'error' must be present (and not vim.NIL).
    if (message.error == nil or message.error == vim.NIL) and message.result == nil then
      self.log.error('Server respond empty result and error', message)
      self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, message)
      return
    end

    -- We sent a number, so we expect a number.
    local result_id = vim._assert_integer(message.id)

    local callback = self.request_callbacks[result_id]
    if callback then
      self.request_callbacks[result_id] = nil

      xpcall(function()
        callback(message.error, message.result ~= vim.NIL and message.result or nil, result_id)
      end, function(err)
        self:on_error(M.client_errors.SERVER_RESULT_CALLBACK_ERROR, err)
      end)
    else
      -- This may happen if the server sends a response
      -- with an id we already received a response for.
      self:on_error(M.client_errors.NO_RESULT_CALLBACK_FOUND, message)
      self.log.error('No callback found for server response id ' .. result_id)
    end
  elseif
    -- Received a notification.
    type(message.method) == 'string'
  then
    xpcall(function()
      assert(
        self.dispatchers.on_notify(message.method, message.params) == nil,
        'notification handlers should not return a value'
      )
    end, function(err)
      self:on_error(M.client_errors.NOTIFICATION_HANDLER_ERROR, err)
    end)
  else
    -- Invalid server message
    self:on_error(M.client_errors.INVALID_SERVER_MESSAGE, message)
  end
end

---@class vim.json.rpc.Opts
---@inlinedoc
---@field log vim.Log
---@field dispatchers vim.json.rpc.Dispatchers
---@field decode fun(buf: string.buffer): string?
---@field encode fun(msg: string): string

--- Create a JSON-RPC connection that connects to either:
---
---  - a named pipe (windows)
---  - a domain socket (unix)
---  - a host and port via TCP
---
---@param host_or_path string host to connect to or path to a pipe/domain socket
---@param port integer? TCP port to connect to. If absent the first argument must be a pipe
---@param opts vim.json.rpc.Opts
---@return vim.json.rpc.Connection
function M.connect(host_or_path, port, opts)
  validate('host_or_path', host_or_path, 'string')
  validate('port', port, 'number', true)
  validate('opts', opts, 'table')
  validate('opts.log', opts.log, 'table')
  validate('opts.dispatchers', opts.dispatchers, 'table')
  validate('opts.decode', opts.decode, 'function')
  validate('opts.encode', opts.encode, 'function')

  local log = opts.log
  log.info('Establishing JSON-RPC connection', { host_or_path = host_or_path, port = port })
  local transport = net_transport.TransportConnect.new(host_or_path, port, log)
  return Connection.new(transport, opts.dispatchers, log, opts.decode, opts.encode)
end

--- Additional context for the spawned process.
---
---@class vim.net.transport.ExtraSpawnParams
---@inlinedoc
---@field cwd? string Working directory for the spawned process
---@field detached? boolean Detach the spawned process from the current process
---@field env? table<string,string> Additional environment variables for spawned process. See |vim.system()|

--- Starts a process and creates a JSON-RPC connection to interact with it.
--- Communication with the spawned process happens via stdio. For communication via
--- TCP, create a process manually and use |vim.json.rpc.connect()|.
---
---@param cmd string[] Command to start the process connects to.
---@param extra_spawn_params? vim.net.transport.ExtraSpawnParams
---@param opts vim.json.rpc.Opts
---@return vim.json.rpc.Connection
function M.run(cmd, extra_spawn_params, opts)
  validate('cmd', cmd, 'table')
  validate('extra_spawn_params', extra_spawn_params, 'table', true)
  validate('opts', opts, 'table')
  validate('opts.log', opts.log, 'table')
  validate('opts.dispatchers', opts.dispatchers, 'table')
  validate('opts.decode', opts.decode, 'function')
  validate('opts.encode', opts.encode, 'function')

  local log = opts.log
  log.info('Starting JSON-RPC connection', { cmd = cmd, extra = extra_spawn_params })
  local transport = net_transport.TransportRun.new(cmd, extra_spawn_params, log)
  return Connection.new(transport, opts.dispatchers, log, opts.decode, opts.encode)
end

return M
