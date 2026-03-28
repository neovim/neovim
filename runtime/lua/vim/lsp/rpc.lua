local protocol = require('vim.lsp.protocol')
local json_rpc = require('vim.json.rpc')
local validate = vim.validate

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
  return setmetatable({
    code = code,
    message = message or code_name,
    data = data,
  }, {
    __tostring = M.format_rpc_error,
  })
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
---@return fun(dispatchers: vim.json.rpc.Dispatchers): vim.json.rpc.PublicClient
function M.connect(host_or_path, port)
  return json_rpc.connect(host_or_path, port)
end

--- Additional context for the spawned process.
--- @class vim.transport.ExtraSpawnParams
--- @inlinedoc
--- @field cwd? string Working directory for the spawned process
--- @field detached? boolean Detach the spawned process from the current process
--- @field env? table<string,string> Additional environment variables for spawned process. See |vim.system()|

--- Starts an LSP server process and create an LSP RPC client object to
--- interact with it. Communication with the spawned process happens via stdio. For
--- communication via TCP, spawn a process manually and use |vim.lsp.rpc.connect()|
---
--- @param cmd string[] Command to start the LSP server.
--- @param dispatchers? vim.json.rpc.Dispatchers
--- @param extra_spawn_params? vim.transport.ExtraSpawnParams
--- @return vim.json.rpc.PublicClient
function M.start(cmd, dispatchers, extra_spawn_params)
  return json_rpc.start(cmd, dispatchers, extra_spawn_params)
end

return M
