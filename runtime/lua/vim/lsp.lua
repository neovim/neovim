local lsp = {
  server_config = require('vim.lsp.server_config'),
  config = require('vim.lsp.config'),
  protocol = require('vim.lsp.protocol'),
}

local Client = require('vim.lsp.client')
local callbacks = require('vim.lsp.callbacks')
local logger = require('vim.lsp.logger')
local text_document_handler = require('vim.lsp.handler').text_document

local function get_filetype(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_option(bufnr, 'filetype')
end

--- Dictionary of [filetype][server_name]
local CLIENTS = {}

--- Get the client list associated with a filetype
-- @param filetype    [string]
--
-- @returns: list of Client Object
function lsp.get_clients(filetype)
  return CLIENTS[filetype]
end

--- Get the client
-- @param filetype    [string]
-- @param server_name [string]
--
-- @returns: Client Object or nil
function lsp.get_client(filetype, server_name)
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
function lsp.start_client(filetype, server_name, bufnr)
  filetype = filetype or get_filetype(bufnr)
  if not server_name then server_name = filetype end

  assert(not lsp.get_client(filetype, server_name), string.format("Language server for filetype: %s, server_name: %s has already started.", filetype, server_name))

  local config = lsp.server_config.get_server(filetype, server_name)
  local cmd = config.cmd
  local offset_encoding = config.offset_encoding

  -- Start the client
  logger.debug(string.format("Starting client... %s/%s/%s", server_name, filetype, vim.inspect(cmd)))

  local client = Client.new(server_name, filetype, cmd, offset_encoding)
  client:start()
  client:initialize()

  if not CLIENTS[filetype] then CLIENTS[filetype] = {} end
  CLIENTS[filetype][server_name] = client

  return client
end

function lsp.stop_client(filetype, server_name)
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
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The table of responses of the request
function lsp.request(method, arguments, bufnr, filetype, server_name)
  filetype = filetype or get_filetype(bufnr)
  if not filetype or filetype == '' then
    return
  end

  if server_name then
    local client = lsp.get_client(filetype, server_name)

    if client == nil then
      local msg = string.format("request() failed. No client is available for filetype: %s, server_name: %s", filetype, server_name)
      logger.warn(msg)
      error(msg)
    end

    return client:request(method, arguments, bufnr)
  else
    local filetype_clients = lsp.get_clients(filetype)
    local responses = {}

    for _, client in pairs(filetype_clients) do
      table.insert(responses, client:request(method, arguments, bufnr))
    end

    return responses
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
-- @returns: The table of request id
function lsp.request_async(method, arguments, cb, bufnr, filetype, server_name)
  filetype = filetype or get_filetype(bufnr)
  if not filetype or filetype == '' then
    return
  end

  if server_name then
    local client = lsp.get_client(filetype, server_name)

    if client == nil then
      local msg = string.format("request_async() failed. No client is available for filetype: %s, server_name: %s", filetype, server_name)
      logger.warn(msg)
      error(msg)
    end

    return { client:request_async(method, arguments, cb, bufnr) }
  else
    local filetype_clients = lsp.get_clients(filetype)
    local request_ids = {}

    for _, client in pairs(filetype_clients) do
      table.insert(request_ids, client:request_async(method, arguments, cb, bufnr))
    end

    return request_ids
  end
end

--- Send a notification to a server
-- @param method [string]: Name of the request method
-- @param arguments [string]: Arguments to send to the server
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The notification message id
function lsp.notify(method, arguments, bufnr, filetype, server_name)
  filetype = filetype or get_filetype(bufnr)
  if not filetype or filetype == '' then
    return
  end

  if server_name then
    local client = lsp.get_client(filetype, server_name)

    if client == nil then
      local msg = string.format("notify() failed. No client is available for filetype: %s, server_name: %s", filetype, server_name)
      logger.warn(msg)
      error(msg)
    end

    return { client:notify(method, arguments) }
  else
    local filetype_clients = lsp.get_clients(filetype)
    local notification_ids = {}

    for _, client in pairs(filetype_clients) do
      table.insert(notification_ids, client:notify(method, arguments))
    end

    return notification_ids
  end
end

function lsp.handle(filetype, method, result, default_only)
  return callbacks.call_callback(method, true, result, default_only, filetype)
end

function lsp.client_has_started(filetype, server_name)
  assert(filetype, "filetype is required.")

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
      for _, client in ipairs(filetype_clients) do
				if client:is_running() then
					return true
				end
      end
    end

    return false
  end
end

function lsp.client_info(filetype, server_name)
  assert(filetype and filetype ~= '', "The filetype argument must be non empty string")

  if not server_name then
    server_name = filetype
  end

  local client =  lsp.get_client(filetype, server_name)
  if client then
    return vim.inspect(client)
  else
    return 'No client is available for filetype: '..filetype..', server_name: '..server_name..'.'
  end
end

function lsp.status()
  local status = ''
  for _, filetype_clients in pairs(CLIENTS) do
    for _, client in pairs(filetype_clients) do
      status = status..'filetype: '..client.filetype..', server_name: '..client.server_name..', command: '..client.cmd.execute_path..'\n'
    end
  end

  return status
end

local function get_current_line_to_cursor()
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = assert(vim.api.nvim_buf_get_lines(0, pos[1]-1, pos[1], false)[1])
	return line:sub(pos[2]+1)
end

function lsp.omnifunc(findstart, base)
  logger.debug(string.format("omnifunc findstart: %s, base: %s", findstart, base))

  if not lsp.client_has_started(get_filetype()) then
    return findstart and -1 or {}
  end

  if findstart == 1 then
    return vim.fn.col('.')
  elseif findstart == 0 then
		local pos = vim.api.nvim_win_get_cursor(0)
		local line = assert(vim.api.nvim_buf_get_lines(0, pos[1]-1, pos[1], false)[1])
		local line_to_cursor = line:sub(pos[2]+1)
		local params = {
			textDocument = {
				uri = vim.uri_from_bufnr(0);
			};
			position = {
				-- 0-indexed for both line and character
				line = pos[1] - 1,
				character = pos[2],
			};
			-- The completion context. This is only available if the client specifies
			-- to send this using `ClientCapabilities.textDocument.completion.contextSupport === true`
			-- context = nil or {
			-- 	triggerKind = protocol.CompletionTriggerKind.Invoked;
			-- 	triggerCharacter = nil or "";
			-- };
		}
    local responses = vim.lsp.request('textDocument/completion', params)
    local matches = {}
    for _, response in ipairs(responses) do
			-- TODO handle errors?
      if not response.error then
				local data = response.result
				local completion_items = text_document_handler.completion_list_to_complete_items(data or {}, line_to_cursor)
				for _, match in ipairs(completion_items) do
					table.insert(matches, match)
				end
				-- logger.debug('callback:textDocument/completion(omnifunc)', data, ' ', self)
      end
    end

    return matches
  end
end

return lsp
