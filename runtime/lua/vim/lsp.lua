-- luacheck: globals vim

local lsp = {
  server_config = require('lsp.server_config'),
  config = require('lsp.config'),
  structures = require('lsp.structures'),
  checks = require('lsp.checks'),
  util = require('lsp.util'),
}

local Client = require('lsp.client')
local callbacks = require('lsp.callbacks')
local server_config = require('lsp.server_config')

local log = require('lsp.log')
local util = require('lsp.util')

local clients = {}

--- Get the client associated with a filetype
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: Client Object or nil
local get_client = function(filetype)
  -- TODO: Throw error if no client started?
  return clients[filetype]
end

--- Start a server and create a client
-- @param cmd [string]: Command to start the server
-- @param arguments [string]: Arguments to send to the server
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: A client object that has been initialized
lsp.start_client = function(cmd, filetype, bufnr)
  filetype = filetype or util.get_filetype(bufnr)

  if get_client(filetype) then
    error(string.format('%s for %s has already started', cmd, filetype))
  end

  cmd = cmd or server_config.get_command(filetype)

  local name = server_config.get_name(filetype)

  -- Start the client
  log.debug('[LSP.lsp] Starting client...', name, '/', filetype, '/', cmd)
  local client = Client.new(name, filetype, cmd)
  client:start()

  if client == nil then
    log.error('client was nil with arguments: ', cmd)
    return nil
  end
  client:initialize()

  -- Store the client in our map
  clients[filetype] = client

  return client
end

lsp.stop_client = function(filetype)
  local client = get_client(filetype)
  if not (client == nil) then
    client:stop()
  end
end

--- Send a request to a server and return the response
-- @param method (string): Name of the request method
-- @param arguments [string]: Arguments to send to the server
-- @param cb [function|string]: Either a function to call or a string to call in vim
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: The result of the request
lsp.request = function(method, arguments, filetype, cb, bufnr)
  filetype = filetype or util.get_filetype(bufnr)
  if filetype == nil or filetype == '' then
    return
  end

  local current_client = get_client(filetype)

  if current_client == nil then
    log.warn('request() failed', 'No client available for:', filetype)
    return
  end

  return current_client:request(method, arguments, cb, bufnr)
end

--- Send a request to a server, but don't wait for the response
lsp.request_async = function(method, arguments, filetype, cb, bufnr)
  filetype = filetype or util.get_filetype(bufnr)
  if filetype == nil or filetype == '' then
    return
  end

  local current_client = get_client(filetype)

  if current_client == nil then
    log.warn('async_request() failed', 'No client available for: ', filetype, ' with method: ', method)
    return
  end

  current_client:request_async(method, arguments, cb, bufnr)
end

--- Send a notification to a server
lsp.notify = function(method, arguments, filetype, bufnr)
  filetype = filetype or util.get_filetype(bufnr)
  if filetype == nil or filetype == '' then
    return
  end

  local current_client = get_client(filetype)

  if current_client == nil then
    log.warn('notify() failed', 'No client available for: ', filetype, ' with method: ', method)
    return
  end

  current_client:notify(method, arguments)
end

lsp.handle = function(filetype, method, data, default_only)
  return callbacks.call_callbacks_for_method(method, true, data, default_only, filetype)
end

lsp.client_has_started = function(filetype)
  return get_client(filetype) ~= nil
end

return lsp
