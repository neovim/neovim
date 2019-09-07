local util = require('vim.lsp.util')
local logger = require('vim.lsp.logger')

local Message = {
  jsonrpc = "2.0"
}

local message_id = {}

local get_id = function(name)
  local temp_id = message_id[name] or 0
  message_id[name] = temp_id + 1
  return temp_id
end

local check_language_server_capabilities = function(client, method)
  local method_table
  if type(method) == 'string' then
    method_table = vim.split(method, '/', true)
  elseif type(method) == 'table' then
    method_table = method
  else
    return true
  end

  -- TODO: This should be a better implementation.
  -- Most methods are named like 'subject_name/opetation_name'.
  -- Most capability properties are named like 'operation_nameProvider'.
  -- And some language server has custom methods.
  -- So if client.server_capabilities[method_table[2]..'Provider'] is nil, return true for now.
  if method_table[2] and client.server_capabilities[method_table[2]..'Provider'] == false then
    return false
  else
    return true
  end
end

function Message:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Message:data()
  local data = self:json()

  return 'Content-Length: ' ..  tostring(data:len()) ..  '\r\n\r\n' ..  data
end

local RequestMessage = {}
local request_mt = { __index = RequestMessage }
setmetatable(RequestMessage, { __index = Message })

function RequestMessage:new(client, method, params)
  assert(self)

  if check_language_server_capabilities(client, method) == false then
    logger.debug(string.format('[LSP:Request] Method "%s" is not supported by server %s', method, client.name))
    return nil
  end

  local object = {
    id = get_id(client),
    method = method,
    params = params
  }

  setmetatable(object, request_mt)
  return object
end

function RequestMessage:json()
  return util.encode_json({
    jsonrpc = self.jsonrpc,
    id = self.id,
    method = self.method,
    params = self.params,
  })
end


local ResponseMessage = {}
local response_mt = { __index = ResponseMessage }
setmetatable(ResponseMessage, { __index = Message })

function ResponseMessage:new(client, result, err)
  assert(self)

  result = result or nil
  err = err or {}

  local object = {
    id = get_id(client),
    result = result,
    ['error'] = err
  }

  setmetatable(object, response_mt)
  return object
end

local ResponseError = {}
local response_err_mt = { __index = ResponseError }
setmetatable(ResponseError, response_err_mt)

function ResponseError:new()
  assert(self)

  return {}
end

local NotificationMessage = {}
local notification_mt = { __index = NotificationMessage }
setmetatable(NotificationMessage, { __index = Message })
function NotificationMessage:new(client, method, params)
  assert(self)

  if check_language_server_capabilities(client, method) == false then
    logger.debug(string.format('Notification Method "%s" is not supported by server %s', method, client.name))
    logger.client.debug(string.format('Notification Method "%s" is not supported by server %s', method, client.name))
    return nil
  end

  local object = {
    method = method,
    params = params
  }

  setmetatable(object, notification_mt)
  return object
end

function NotificationMessage:json()
  return util.encode_json({
    jsonrpc = self.jsonrpc,
    method = self.method,
    params = self.params,
  })
end

return {
  Message = Message,
  RequestMessage = RequestMessage,
  ResponseMessage = ResponseMessage,
  ResponseError = ResponseError,
  NotificationMessage = NotificationMessage,
}
