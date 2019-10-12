local lsp = {
  server_config = require('vim.lsp.server_config'),
  config = require('vim.lsp.config'),
  protocol = require('vim.lsp.protocol'),
  util = require('vim.lsp.util'),
}

local Client = require('vim.lsp.client')
local callbacks = require('vim.lsp.callbacks')
local logger = require('vim.lsp.logger')
local text_document_handler = require('vim.lsp.handler').text_document

local clients = {}

--- Get the client list associated with a filetype
-- @param filetype    [string]
--
-- @returns: list of Client Object
lsp.get_clients = function(filetype)
  return clients[filetype]
end

--- Get the client
-- @param filetype    [string]
-- @param server_name [string]
--
-- @returns: Client Object or nil
lsp.get_client = function(filetype, server_name)
  local filetype_clients = lsp.get_clients(filetype)
  if not filetype_clients then
    return nil
  else
    return filetype_clients[server_name]
  end
end

--- Start a server and create a client
-- @param filetype [string](optional): A filetype associated with the server
-- @param server_name [string](optional): A language server name associated with the server
-- @param bufnr [number]: A bufnr
--
-- @returns: A client object that has been initialized
lsp.start_client = function(filetype, server_name, bufnr)
  filetype = filetype or lsp.util.get_filetype(bufnr)
  if not server_name then server_name = filetype end

  assert(not lsp.get_client(filetype, server_name), string.format('Language server for filetype: %s, server_name: %s has already started', filetype, server_name))

  local cmd = lsp.server_config.get_server_cmd(filetype, server_name)
  local offset_encoding = lsp.server_config.get_server_offset_encoding(filetype, server_name)

  -- Start the client
  logger.debug('[LSP.lsp] Starting client...', server_name, '/', filetype, '/', cmd)

  local client = Client.new(server_name, filetype, cmd, offset_encoding)
  client:start()
  client:initialize()

  if not clients[filetype] then clients[filetype] = {} end
  clients[filetype][server_name] = client

  return client
end

lsp.stop_client = function(filetype, server_name)
  assert(filetype, 'filetype is required.')

  if not server_name then server_name = filetype end

  local client = lsp.get_client(filetype, server_name)
  if client then
    client:stop()
  end
end

--- Send a request to a server and return the response
-- @param method [string]: Name of the request method
-- @param arguments [string]: Arguments to send to the server
-- @param cb [function|string] (optional): Either a function to call or a string to call in vim
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The result of the request
lsp.request = function(method, arguments, cb, bufnr, filetype, server_name)
  filetype = filetype or lsp.util.get_filetype(bufnr)
  if not filetype or filetype == '' then
    return
  end

  if server_name then
    local client = lsp.get_client(filetype, server_name)

    if client == nil then
      logger.warn('request() failed', 'No client is available for filetype: '..filetype..', server_name: '..server_name)
      return
    end

    return client:request(method, arguments, cb, bufnr)
  else
    local filetype_clients = lsp.get_clients(filetype)
    local results = {}

    for _, client in pairs(filetype_clients) do
      table.insert(results, client:request(method, arguments, cb, bufnr))
    end

    return results
  end
end

--- Send a request to a server, but don't wait for the response
-- @param method [string]: Name of the request method
-- @param arguments [string]: Arguments to send to the server
-- @param cb [function|string] (optional): Either a function to call or a string to call in vim
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The result of the request
lsp.request_async = function(method, arguments, cb, bufnr, filetype, server_name)
  filetype = filetype or lsp.util.get_filetype(bufnr)
  if not filetype or filetype == '' then
    return
  end

  if server_name then
    local client = lsp.get_client(filetype, server_name)

    if client == nil then
      logger.warn('request() failed', 'No client is available for filetype: '..filetype..', server_name: '..server_name)
      return
    end

    return client:request_async(method, arguments, cb, bufnr)
  else
    local filetype_clients = lsp.get_clients(filetype)
    local results = {}

    for _, client in pairs(filetype_clients) do
      table.insert(results, client:request_async(method, arguments, cb, bufnr))
    end

    return results
  end
end

--- Send a notification to a server
-- @param method [string]: Name of the request method
-- @param arguments [string]: Arguments to send to the server
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The result of the request
lsp.notify = function(method, arguments, bufnr, filetype, server_name)
  filetype = filetype or lsp.util.get_filetype(bufnr)
  if not filetype or filetype == '' then
    return
  end

  if server_name then
    local client = lsp.get_client(filetype, server_name)

    if client == nil then
      logger.warn('request() failed', 'No client is available for filetype: '..filetype..', server_name: '..server_name)
      return
    end

    client:notify(method, arguments)
  else
    local filetype_clients = lsp.get_clients(filetype)

    for _, client in pairs(filetype_clients) do
      client:notify(method, arguments)
    end
  end
end

lsp.handle = function(filetype, method, data, default_only)
  return callbacks.call_callback(method, true, data, default_only, filetype)
end

lsp.client_has_started = function(filetype, server_name)
  assert(filetype, 'filetype is required.')

  if server_name then
    local client = lsp.get_client(filetype, server_name)
    if client and client:is_running() then
      return true
    else
      return false
    end
  else
    local filetype_clients = lsp.get_clients(filetype)
    if filetype_clients ~= nil then
      for _, client in pairs(filetype_clients) do
        if client:is_running() then return true end
      end
    end

    return false
  end
end

lsp.client_info = function(filetype, server_name)
  if not filetype or filetype == '' then
    return
  end

  if not server_name then
    server_name = filetype
  end

  local client =  lsp.get_client(filetype, server_name)
  if client then
    return vim.inspect(client)
  else
    return 'No client is available for filetype: '..filetype..', server_name: '..server_name
  end
end

lsp.status = function()
  local status = ''
  for _, filetype_clients in pairs(clients) do
    for _, client in pairs(filetype_clients) do
      status = status..'filetype: '..client.filetype..', server_name: '..client.server_name..', command: '..client:cmd_tostring()..'\n'
    end
  end

  return status
end

local build_completion_items = function(self, data)
  logger.debug('callback:textDocument/completion(omnifunc)', data, ' ', self)

  if not data or vim.tbl_isempty(data) then
    return {}
  end
  return text_document_handler.CompletionList_to_matches(data)
end

lsp.omnifunc = function(findstart, base)
  logger.debug('omnifunc findstart: '..findstart..', base: '..base)

  if not lsp.client_has_started(lsp.util.get_filetype()) then
    return findstart and -1 or {}
  end

  if findstart == 1 then
    return vim.api.nvim_call_function('col', {'.'})
  elseif findstart == 0 then
    local params = lsp.protocol.CompletionParams()
    local results = vim.lsp.request('textDocument/completion', params, build_completion_items)[1]
    local matches = {}
    for _, result in pairs(results) do
      matches = vim.tbl_extend('force', matches, result)
    end
    return matches
  end
end

return lsp
