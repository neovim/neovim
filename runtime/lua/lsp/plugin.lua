-- luacheck: globals vim

local ClientObject = require ('lsp.client')

local log = require('lsp.log')
local lsp_util = require('lsp.util')

local client_map = {}

local plugin = {
  client = {},
  server = {},
  helpers = {},
}

--- Add a configuration for a language server
-- @param filetype (string): The filetype associated with the server
-- @param configuration (table): See |lsp#server#add()| for more information
plugin.server.add = function(filetype, configuration)
  vim.api.nvim_call_function('lsp#server#add', {filetype, configuration})
end

--- Get the configuration for a language server
-- @param filetype (string): The filetype associated with the server
--
-- @returns: The configuration for a language server
plugin.server.get_configuration = function(filetype)
  return vim.api.nvim_call_function('lsp#server#get_configuration', {filetype})
end

--- Get the command for starting a server associated with filetype
-- @param cmd [string]: Command to start the server
-- @param filetype [string]: The filetype associated with the server
plugin.helpers.get_command = function(cmd, filetype)
  if cmd ~= nil then
    return cmd
  end

  filetype = lsp_util.get_filetype(filetype)
  return plugin.server.get_configuration(filetype).command
end

--- Get the arguments for starting a server associated with filetype
-- @param arguments [string]: Arguments to send to the server
-- @param filetype [string]: The filetype associated with the server
plugin.helpers.get_arguments = function(arguments, filetype)
  if arguments ~= nil then
    return arguments
  end

  filetype = lsp_util.get_filetype(filetype)
  return plugin.server.get_configuration(filetype).arguments
end

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
plugin.client.start = function(cmd, arguments, filetype)
  filetype = lsp_util.get_filetype(filetype)
  cmd = plugin.helpers.get_command(cmd, filetype)
  arguments = plugin.helpers.get_arguments(arguments, filetype)

  local name = plugin.server.get_configuration(filetype).name

  -- Start the client
  log.debug('[LSP.plugin] Starting client...')
  local client = ClientObject.new(name, filetype, cmd, arguments)
  if client == nil then
    log.error('client was nil with arguments: ', cmd, ' ', arguments)
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
  local current_client = plugin.client.get(filetype)

  if current_client == nil then
    log.warn('request() failed', 'No client available for:', filetype)
    return
  end

  return current_client:request(method, arguments, cb)
end

--- Send a request to a server, but don't wait for the response
plugin.client.request_async = function(method, arguments, cb, filetype)
  local current_client = plugin.client.get(filetype)

  if current_client == nil then
    log.warn('async_request() failed', 'No client available for:', filetype)
    return
  end

  current_client:request_async(method, arguments, cb)
end

plugin.client.wait_request = function(request_id, filetype)
  if plugin.client.get(filetype) == nil then
    return
  end

  return plugin.client.get(filetype)._results[request_id]
end

plugin.client.get_callback = function(method, cb)
  if cb then
    return cb
  end

  return require('lsp.callbacks').get_callback_function(method)
end

plugin.client.has_started = function(filetype)
  return plugin.client.get(filetype) ~= nil
end

-- Non-client commands
-- Determines if a request is supported or not
plugin.is_supported_request = function(method)
  return plugin.client.get_callback(method) ~= nil
end

return plugin
