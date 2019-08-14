local Client = require('lsp.client')
local callbacks = require('lsp.callbacks')
local server_config = require('lsp.server_config')

local log = require('lsp.log')
local util = require('lsp.util')

local plugin = { client_map = {} }

--- Start a server and create a client
-- @param cmd [string]: Command to start the server
-- @param arguments [string]: Arguments to send to the server
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: A client object that has been initialized
plugin.start_client = function(cmd, filetype, bufnr)
  filetype = filetype or util.get_filetype(bufnr)
  cmd = cmd or server_config.get_command(filetype)

  local name = server_config.get_name(filetype)

  -- Start the client
  log.debug('[LSP.plugin] Starting client...', name, '/', filetype, '/', cmd)
  local client = Client.new(name, filetype, cmd)

  if client == nil then
    log.error('client was nil with arguments: ', cmd)
    return nil
  end
  client:initialize()

  -- Store the client in our map
  plugin.client_map[filetype] = client

  return client
end

--- Get the client associated with a filetype
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: Client Object or nil
plugin.get_client = function(filetype)
  -- TODO: Throw error if no client started?
  return plugin.client_map[filetype]
end

--- Send a request to a server and return the response
-- @param method (string): Name of the request method
-- @param arguments [string]: Arguments to send to the server
-- @param cb [function|string]: Either a function to call or a string to call in vim
-- @param filetype [string]: The filetype associated with the server
--
-- @returns: The result of the request
plugin.request = function(method, arguments, filetype, cb, bufnr)
  filetype = filetype or util.get_filetype(bufnr)
  if filetype == nil or filetype == '' then
    return
  end

  local current_client = plugin.get_client(filetype)

  if current_client == nil then
    log.warn('request() failed', 'No client available for:', filetype)
    return
  end

  return current_client:request(method, arguments, cb, bufnr)
end

--- Send a request to a server, but don't wait for the response
plugin.request_async = function(method, arguments, filetype, cb, bufnr)
  filetype = filetype or util.get_filetype(bufnr)
  if filetype == nil or filetype == '' then
    return
  end

  local current_client = plugin.get_client(filetype)

  if current_client == nil then
    log.warn('async_request() failed', 'No client available for: ', filetype, ' with method: ', method)
    return
  end

  current_client:request_async(method, arguments, cb, bufnr)
end

plugin.request_autocmd = function(method, arguments, cb, filetype)
  if not plugin.has_started(filetype) then
    return
  end

  plugin.request(method, arguments, cb, filetype)

  return true
end

plugin.wait_request = function(request_id, filetype)
  if plugin.get_client(filetype) == nil then
    return
  end

  return plugin.get_client(filetype)._results[request_id]
end

--- Send a notification to a server
plugin.notify = function(method, arguments, filetype, bufnr)
  filetype = filetype or util.get_filetype(bufnr)
  if filetype == nil or filetype == '' then
    return
  end

  local current_client = plugin.get_client(filetype)

  if current_client == nil then
    log.warn('notify() failed', 'No client available for: ', filetype, ' with method: ', method)
    return
  end

  current_client:notify(method, arguments)
end

plugin.client_has_started = function(filetype)
  return plugin.get_client(filetype) ~= nil
end

plugin.handle = function(filetype, method, data, default_only)
  return callbacks.call_callbacks_for_method(method, true, data, default_only, filetype)
end

plugin.client_job_stdout = function(id, data)
  Client.job_stdout(id, data)
end

plugin.client_job_exit = function(id, data)
  Client.job_exit(id, data)
end

return plugin
