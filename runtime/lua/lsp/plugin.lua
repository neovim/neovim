-- luacheck: globals vim

local ClientObject = require('lsp.client')
local callbacks = require('lsp.callbacks')
local server_config = require('lsp.server')

local log = require('lsp.log')
local lsp_util = require('lsp.util')

local client_map = {}

local plugin = {
  client = {},
}


--- Get the client associated with a filetype
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: Client Object or nil
plugin.client.get = function(filetype)
  filetype = lsp_util.get_filetype(filetype)

  -- TODO: Throw error if no client started?
  return client_map[filetype]
end

--- Start a server and create a client
-- @param cmd [string]: Command to start the server
-- @param arguments [string]: Arguments to send to the server
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: A client object that has been initialized
plugin.client.start = function(cmd, filetype)
  filetype = lsp_util.get_filetype(filetype)
  cmd = server_config.get_command(cmd, filetype)

  local name = server_config.get_name(filetype)

  -- Start the client
  log.debug('[LSP.plugin] Starting client...', name, '/', filetype, '/', cmd)
  local client = ClientObject.new(name, filetype, cmd)

  if client == nil then
    log.error('client was nil with arguments: ', cmd)
    return nil
  end
  client:initialize()

  -- Store the client in our map
  client_map[filetype] = client

  return client
end

--- Send a request to a server and return the response
-- @param method (string): Name of the request method
-- @param arguments [string]: Arguments to send to the server
-- @param cb [function|string]: Either a function to call or a string to call in vim
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: The result of the request
plugin.client.request = function(method, arguments, cb, filetype)
  filetype = lsp_util.get_filetype(filetype)
  if filetype == nil or filetype == '' then
    return
  end

  local current_client = plugin.client.get(filetype)

  if current_client == nil then
    log.warn('request() failed', 'No client available for:', filetype)
    return
  end

  return current_client:request(method, arguments, cb)
end

--- Send a request to a server, but don't wait for the response
plugin.client.request_async = function(method, arguments, cb, filetype)
  filetype = lsp_util.get_filetype(filetype)
  if filetype == nil or filetype == '' then
    return
  end

  local current_client = plugin.client.get(filetype)

  if current_client == nil then
    log.warn('async_request() failed', 'No client available for: ', filetype, ' with method: ', method)
    return
  end

  current_client:request_async(method, arguments, cb)
end

plugin.client.request_autocmd = function(method, arguments, cb, filetype)
  if not plugin.client.has_started(filetype) then
    return
  end

  plugin.client.request(method, arguments, cb, filetype)

  return true
end

plugin.client.wait_request = function(request_id, filetype)
  if plugin.client.get(filetype) == nil then
    return
  end

  return plugin.client.get(filetype)._results[request_id]
end

plugin.client.has_started = function(filetype)
  return plugin.client.get(filetype) ~= nil
end
plugin.client.handle = function(filetype, method, data, default_only)
  return callbacks.call_callbacks_for_method(method, true, data, default_only, filetype)
end

return plugin
