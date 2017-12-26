-- TODO:
--  Do the decoding from the message class?

local json = require('lsp.json')
local util = require('neovim.util')

local log = require('neovim.log')
local get_request_function = require('runtime.lua.lsp.request').get_request_function

local Message = {
  jsonrpc = "2.0"
}

local message_id = {}

local get_id = function(name)
  local temp_id = message_id[name] or 0
  message_id[name] = temp_id + 1
  return temp_id
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

  log.debug(
    string.format('Creating new request method with: %s, %s, (default) %s',
      util.tostring(client), util.tostring(method), util.tostring(params)
    )
  )

  local request_func = get_request_function(method)
  local request_params
  if request_func and type(request_func) == 'function' then
    request_params = request_func(client, params)
    log.debug(string.format('Request function: %s returned params: %s',
      util.tostring(request_func), util.tostring(request_params)
    ))
  else
    log.info(string.format('No request function found for: %s', util.tostring(method)))
    request_params = params
  end

  local object = {
    id = get_id(client),
    method = method,
    params = request_params
  }

  setmetatable(object, request_mt)
  return object
end

function RequestMessage:json()
  return json.encode({
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

function NotificationMessage:new(client, message, params)
  local o = Message:new{client=client, message=message, params=params}
  self.__index = self
  return o
end

return {
  Message = Message,
  RequestMessage = RequestMessage,
  ResponseMessage = ResponseMessage,
  ResponseError = ResponseError,
  NotificationMessage = NotificationMessage,
}
