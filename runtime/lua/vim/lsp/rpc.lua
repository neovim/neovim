local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local json_rpc = require('vim.json.rpc')
local net_transport = require('vim.net._transport')
local strbuffer = require('vim._core.stringbuffer')
local validate = vim.validate

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

--- Extract `content-length` from the header.
---
--- The structure of header fields conforms to [HTTP semantics](https://tools.ietf.org/html/rfc7230#section-3.2),
--- i.e., `header-field = field-name : OWS field-value OWS`. OWS means optional whitespace (space/horizontal tabs).
---
--- We ignore lines ending with `\n` that don't contain `content-length`, since some servers
--- write log to standard output and there's no way to avoid it.
--- See https://github.com/neovim/neovim/pull/35743#pullrequestreview-3379705828
--- @param ptr vim._core.stringbuffer.ptr The ptr to buffer to parse
--- @param start integer The starting index of the buffer to parse, 0-based
--- @param len integer The length of the header to parse
--- @return integer
local function get_content_length(ptr, start, len)
  local state = 'name'
  local i, end_ = start, start + len
  local j, name = 1, 'content-length'
  local buf = strbuffer.new()
  local digit = true
  while i < end_ do
    local c = ptr[i]
    if state == 'name' then
      if c >= 65 and c <= 90 then -- lower case
        c = c + 32
      end
      if (c == 32 or c == 9) and j == 1 then -- luacheck: ignore 542
        -- skip OWS for compatibility only
      elseif c == name:byte(j) then
        j = j + 1
      elseif c == 58 and j == 15 then
        state = 'colon'
      else
        state = 'invalid'
      end
    elseif state == 'colon' then
      if c ~= 32 and c ~= 9 then -- skip OWS normally
        state = 'value'
        i = i - 1
      end
    elseif state == 'value' then
      if c == 13 and ptr[i + 1] == 10 then -- must end with \r\n
        local value = buf:get()
        if digit then
          return vim._assert_integer(value)
        end
        error('value of Content-Length is not number: ' .. value)
      else
        buf:put(string.char(c))
      end
      if c < 48 and c ~= 32 and c ~= 9 or c > 57 then
        digit = false
      end
    elseif state == 'invalid' then
      if c == 10 then -- reset for next line
        state, j = 'name', 1
      end
    end
    i = i + 1
  end
  local header = strbuffer.new()
  for k = start, end_ - 1 do
    header:put(string.char(ptr[k]))
  end
  error('Content-Length not found in header: ' .. header:tostring())
end

local M = {}

--- Mapping of error codes used by the client
--- @enum vim.lsp.rpc.ClientErrors
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
  return {
    code = code,
    message = message or code_name,
    data = data,
  }
end

--- Dispatchers for LSP message types.
--- @class vim.lsp.rpc.Dispatchers
--- @inlinedoc
--- @field notification fun(method: vim.lsp.protocol.Method.ServerToClient.Notification, params: table)
--- @field server_request fun(method: vim.lsp.protocol.Method.ServerToClient.Request, params: table): any?, lsp.ResponseError?
--- @field on_exit fun(code: integer, signal: integer)
--- @field on_error fun(code: integer, err: any)

--- @type vim.lsp.rpc.Dispatchers
local default_dispatchers = {
  --- Default dispatcher for notifications sent to an LSP server.
  ---
  ---@param method vim.lsp.protocol.Method.ServerToClient The invoked LSP method
  ---@param params table Parameters for the invoked LSP method
  notification = function(method, params)
    log.debug('notification', method, params)
  end,

  --- Default dispatcher for requests sent to an LSP server.
  ---
  ---@param method vim.lsp.protocol.Method.ServerToClient The invoked LSP method
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

--- Parse one `Content-Length` framed message from `strbuf`.
---
--- Returns a body after consuming one full frame, returns nil if more bytes are needed.
--- Raises an error if the buffered data is not a valid frame.
---
---@param strbuf vim._core.stringbuffer
---@return string?
local function message_decoder(strbuf)
  local header_len ---@type integer?
  local ptr, len = strbuf:ref()
  for i = 0, len - 4 do
    -- Find the header boundary "\r\n\r\n"
    -- (compare bytes instead of string.find(), to avoid a string alloc).
    if ptr[i] == 13 and ptr[i + 1] == 10 and ptr[i + 2] == 13 and ptr[i + 3] == 10 then
      header_len = i + 2
      break
    end
  end

  if not header_len then
    return nil
  end

  local content_length = get_content_length(ptr, 0, header_len)
  if strbuffer.len(strbuf) < header_len + 2 + content_length then
    return nil
  end

  strbuf:skip(header_len + 2) -- skip past header boundary
  return strbuf:get(content_length)
end

--- @private
--- @param handle_body fun(body: string)
--- @param on_exit? fun()
--- @param on_error? fun(err: any, errkind: vim.json.rpc.ClientErrors)
function M.create_read_loop(handle_body, on_exit, on_error)
  on_exit = on_exit or function() end
  on_error = on_error or function() end
  local message_stream = net_transport.MessageStream.new(
    message_decoder,
    format_message_with_content_length,
    function(err, chunk)
      if err then
        on_error(err, M.client_errors.READ_ERROR)
      elseif chunk then
        handle_body(chunk)
      else
        on_exit()
      end
    end,
    function(err)
      on_error(err, M.client_errors.INVALID_SERVER_MESSAGE)
    end
  )

  return function(err, chunk)
    message_stream:feed(err, chunk)
  end
end

--- Client RPC object
--- @class vim.lsp.rpc.Client
---
--- See [vim.lsp.rpc.request()]
--- @field request fun(method: vim.lsp.protocol.Method.ClientToServer.Request, params: table?, callback: fun(err?: lsp.ResponseError, result: any, request_id: integer), notify_reply_callback?: fun(message_id: integer)):boolean,integer?
---
--- See [vim.lsp.rpc.notify()]
--- @field notify fun(method: vim.lsp.protocol.Method.ClientToServer.Notification, params: any): boolean
---
--- Indicates if the RPC is closing.
--- @field is_closing fun(): boolean
---
--- Terminates the RPC client.
--- @field terminate fun()

--- Preserve the legacy `vim.lsp.rpc` dot-call API.
---@param connection vim.json.rpc.Connection
local function to_lsp_rpc(connection)
  ---@type vim.lsp.rpc.Client
  ---@diagnostic disable-next-line: missing-fields
  local result = {}

  ---@private
  function result.is_closing()
    return connection:is_closing()
  end

  ---@private
  function result.terminate()
    connection:terminate()
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
    local success, request_id ---@type boolean, integer?
    success, request_id = connection:request(method, params, function(...)
      local err = select(1, ...) ---@type lsp.ResponseError
      if notify_reply_callback then
        validate('notify_reply_callback', notify_reply_callback, 'function')
        notify_reply_callback(assert(request_id))
      end

      -- Do not surface RequestCancelled to users, it is RPC-internal.
      if err then
        if err.code == vim.lsp.protocol.ErrorCodes.RequestCancelled then
          log.debug('Received cancellation ack', err)
          -- Clear any callback since this is cancelled now.
          -- This is safe to do assuming that these conditions hold:
          -- - The server will not send a result callback after this cancellation.
          -- - If the server sent this cancellation ACK after sending the result, the user of this RPC
          -- client will ignore the result themselves.
          return
        end
      end

      callback(...)
    end)
    return success, request_id
  end

  --- Sends a notification to the LSP server.
  ---@param method (vim.lsp.protocol.Method.ClientToServer.Notification) The invoked LSP method
  ---@param params (table?) Parameters for the invoked LSP method
  ---@return boolean `true` if notification could be sent, `false` if not
  function result.notify(method, params)
    return connection:notify(method, params)
  end

  return result
end

---@param dispatchers vim.lsp.rpc.Dispatchers?
---@return vim.json.rpc.Dispatchers
local function merge_dispatchers(dispatchers)
  dispatchers = dispatchers or {}
  ---@diagnostic disable-next-line: no-unknown
  for name, fn in pairs(dispatchers) do
    if type(fn) ~= 'function' then
      error(string.format('dispatcher.%s must be a function', name))
    end
  end
  ---@type vim.json.rpc.Dispatchers
  local merged = {
    on_notify = (
      dispatchers.notification and vim.schedule_wrap(dispatchers.notification)
      or default_dispatchers.notification
    ),
    on_error = (
      dispatchers.on_error and vim.schedule_wrap(dispatchers.on_error)
      or default_dispatchers.on_error
    ),
    on_exit = dispatchers.on_exit or default_dispatchers.on_exit,
    on_request = dispatchers.server_request or default_dispatchers.server_request,
  }
  return merged
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
---@return fun(dispatchers: vim.lsp.rpc.Dispatchers): vim.lsp.rpc.Client
function M.connect(host_or_path, port)
  return function(dispatchers)
    return to_lsp_rpc(json_rpc.connect(host_or_path, port, {
      log = log._self,
      dispatchers = merge_dispatchers(dispatchers),
      decode = message_decoder,
      encode = format_message_with_content_length,
    }))
  end
end

--- Additional context for the LSP server process.
--- @class vim.lsp.rpc.ExtraSpawnParams : vim.net.transport.ExtraSpawnParams
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
--- @return vim.lsp.rpc.Client
function M.start(cmd, dispatchers, extra_spawn_params)
  return to_lsp_rpc(json_rpc.run(cmd, extra_spawn_params, {
    log = log._self,
    dispatchers = merge_dispatchers(dispatchers),
    decode = message_decoder,
    encode = format_message_with_content_length,
  }))
end

return M
