-- local server_config = require('vim.lsp.server_config')
-- local config = require('vim.lsp.config')

local lsp = {}

local protocol = require('vim.lsp.protocol')
lsp.protocol = protocol
local lsp_rpc = require('vim.lsp.rpc')
-- local callbacks = require('vim.lsp.callbacks')
local default_request_callbacks = require('vim.lsp.builtin_callbacks')
local logger = require('vim.lsp.logger')
local text_document_handler = require('vim.lsp.handler').text_document

-- local LOG_LEVELS = {
-- 	TRACE = 0;
-- 	DEBUG = 1;
-- 	INFO  = 2;
-- 	WARN  = 3;
-- 	ERROR = 4;
-- 	-- FATAL = 4;
-- }
-- local LOG_LEVEL = LOG_LEVELS.ERROR
-- function lsp.set_log_level(level)
-- 	if type(level) == 'string' then
-- 		LOG_LEVEL = assert(LOG_LEVEL[level:upper()], string.format("Invalid log level: %q", level))
-- 	else
-- 		assert(type(level) == 'number', "level must be a number")
-- 		LOG_LEVEL = assert(LOG_LEVEL[level], string.format("Invalid log level: %d", level))
-- 	end
-- end

-- Usage:
-- ```
-- coroutine.wrap(function()
--   local resumer = maker_resumer()
--   client.request(method, params, resumer)
--   local request_result = coroutine.yield()
-- end)
-- ```
local function make_resumer()
	local co = coroutine.running()
	return function(...) coroutine.resume(co, ...) end
end

local function get_current_line_to_cursor()
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = assert(vim.api.nvim_buf_get_lines(0, pos[1]-1, pos[1], false)[1])
	return line:sub(pos[2]+1)
end

local function resolve_bufnr(bufnr)
	if bufnr == nil or bufnr == 0 then
		return vim.api.nvim_get_current_buf()
	end
	return bufnr
end

local function set_timeout(ms, fn)
	local timer = vim.loop.new_timer()
	timer:start(ms, 0, function()
		pcall(fn)
		timer:close()
	end)
	return timer
end

-- TODO deduplicate
local VALID_ENCODINGS = {
	["utf-8"] = 'utf-8'; ["utf-16"] = 'utf-16'; ["utf-32"] = 'utf-32';
	["utf8"]  = 'utf-8'; ["utf16"]  = 'utf-16'; ["utf32"]  = 'utf-32';
	UTF8      = 'utf-8'; UTF16      = 'utf-16'; UTF32      = 'utf-32';
}

local CLIENT_INDEX = 0
local function next_client_id()
	CLIENT_INDEX = CLIENT_INDEX + 1
	return CLIENT_INDEX
end
local LSP_CLIENTS = {}
local BUFFER_CLIENT_IDS = {}

local function for_each_buffer_client(bufnr, callback)
	assert(type(callback) == 'function', "callback must be a function")
	bufnr = resolve_bufnr(bufnr)
	assert(type(bufnr) == 'number', "bufnr must be a number")
	local client_ids = BUFFER_CLIENT_IDS[bufnr]
	-- TODO error here?
	if not client_ids or vim.tbl_isempty(client_ids) then
		local msg = string.format("No clients available for buffer %d", bufnr)
		logger.warn(msg)
		error(msg)
	end
	for client_id in pairs(client_ids) do
		local client = LSP_CLIENTS[client_id]
		-- This is unlikely to happen. Could only potentially happen in a race
		-- condition between literally a single statement.
		-- We could skip this error, but let's error for now.
		if not client then
			error(string.format(" Client %d has already shut down.", client_id))
		end
		callback(client, client_id)
	end
end

-------------- TODO TODO TODO ---------------------------
-- -- TODO improve check capabilities
-- if not check_language_server_capabilities(self, method) then
-- 	if message_type == 'notification' then
-- 		logger.debug(string.format('Notification Method %q is not supported by server %s', method, self.name))
-- 		logger.client.debug(string.format('Notification Method %q is not supported by server %s', method, self.name))
-- 		return nil
-- 	else
-- 		logger.debug(string.format('[LSP:Request] Method %q is not supported by server %s', method, self.name))
-- 		error("[LSP:Request] Method "..method.." is not supported by server "..self.name)
-- 	end
-- end

local function attach_to_buffers_by_filetype(client, filetypes)
	assert(type(filetypes) == 'table', "filetypes must be a table")
  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
		local buf_filetype = vim.api.nvim_buf_get_option(buf, "ft")
		if vim.tbl_contains(filetypes, buf_filetype) then
			client.attach_to_buffer(buf)
		end
  end
end

local function check_language_server_capabilities(client, method)
  local method_table
  if type(method) == 'string' then
    method_table = vim.split(method, '/', true)
  elseif type(method) == 'table' then
    method_table = method
  else
    return true
  end
  -- TODO: This should be a better implementation.
  -- Most methods are named like 'subject_name/operation_name'.
  -- Most capability properties are named like 'operation_nameProvider'.
  -- And some language server has custom methods.
  -- So if client.server_capabilities[method_table[2]..'Provider'] is nil, return true for now.
  if method_table[2] then
    local provider_capabilities = client.server_capabilities[method_table[2]..'Provider']
    if provider_capabilities ~= nil and provider_capabilities == false then
      return false
    end
    return true
  else
    return true
  end
end

function lsp.start_client(conf)
	assert(type(conf.cmd) == 'string', "conf.cmd must be a string")
	assert(type(conf.cmd_args) == 'table', "conf.cmd_args must be a table")
	-- TODO do I need name here for logs or something??
	-- assert(type(conf.name) == 'string', "conf.name must be a string")
	local offset_encoding
	if conf.offset_encoding then
		offset_encoding = VALID_ENCODINGS[conf.offset_encoding]
		if not offset_encoding then
			error(string.format("Invalid offset_encoding: %q", conf.offset_encoding))
		end
	else
		-- TODO UTF8 or UTF16?
		offset_encoding = VALID_ENCODINGS.UTF8
	end
	assert(type(conf.request_callbacks or {}) == 'table', "conf.request_callbacks must be a table")
	-- TODO this isn't correct. It should probably be something else.
	-- TODO this isn't correct. It should probably be something else.
	-- TODO this isn't correct. It should probably be something else.
	-- TODO this isn't correct. It should probably be something else.
	-- TODO this isn't correct. It should probably be something else.
	-- TODO this isn't correct. It should probably be something else.
	local request_callbacks = vim.tbl_extend("keep", conf.request_callbacks or {}, default_request_callbacks)
	-- local request_callbacks = conf.request_callbacks or default_request_callbacks
	-- assert(type(request_callbacks) == 'table', "request_callbacks must be a table")

	local client_id = next_client_id()

	local handlers = {}

	function handlers.notification(method, params)
		logger.info('notification', method, params)
	end

	function handlers.server_request(method, params)
		logger.info('server_request', method, params)
		local request_callback = request_callbacks[method]
		if request_callback then
			return request_callback(params)
		end
		return nil, lsp_rpc.rpc_response_error(protocol.ErrorCodes.MethodNotFound)
	end

	-- TODO use protocol.ErrorCodes instead?
	function handlers.on_error(code, err)
		logger.info('client_error:', lsp_rpc.ERRORS[code], err)
	end

	local timers = {}
	function handlers.on_exit()
		for _, h in ipairs(timers) do
			h:stop()
			h:close()
		end
		LSP_CLIENTS[client_id] = nil
		for bufnr, client_ids in pairs(BUFFER_CLIENT_IDS) do
			client_ids[client_id] = nil
		end
	end

	local rpc = lsp_rpc.start(conf.cmd, conf.cmd_args, handlers)

	local client = {
		id = client_id;
		rpc = rpc;
		offset_encoding = offset_encoding;
	}

	local function initialize()
		local initialize_params = {
			-- The process Id of the parent process that started the server. Is null if
			-- the process has not been started by another process.  If the parent
			-- process is not alive then the server should exit (see exit notification)
			-- its process.
			processId = vim.loop.getpid();
			-- The rootPath of the workspace. Is null if no folder is open.
			--
			-- @deprecated in favour of rootUri.
			rootPath = nil;
			-- The rootUri of the workspace. Is null if no folder is open. If both
			-- `rootPath` and `rootUri` are set `rootUri` wins.
			rootUri = vim.uri_from_fname(vim.fn.expand("%:p:h"));
			-- User provided initialization options.
			initializationOptions = conf.init_options;
			-- The capabilities provided by the client (editor or tool)
			capabilities = protocol.ClientCapabilities();
			-- The initial trace setting. If omitted trace is disabled ('off').
			-- trace = 'off' | 'messages' | 'verbose';
			trace = conf.trace or 'off';
			-- The workspace folders configured in the client when the server starts.
			-- This property is only available if the client supports workspace folders.
			-- It can be `null` if the client supports workspace folders but none are
			-- configured.
			--
			-- Since 3.6.0
			-- workspaceFolders?: WorkspaceFolder[] | null;
			-- export interface WorkspaceFolder {
			-- 	-- The associated URI for this workspace folder.
			-- 	uri
			-- 	-- The name of the workspace folder. Used to refer to this
			-- 	-- workspace folder in the user interface.
			-- 	name
			-- }
			workspaceFolders = nil;
		}
		rpc.request('initialize', initialize_params, function(err, result)
			assert(not err, err)
			rpc.notify('initialized', {})
			client.initialized = true
			client.server_capabilities = assert(result.capabilities, "initialize result doesn't capabilities")
			-- Only assign after initialized?
			LSP_CLIENTS[client_id] = client
			-- If we had been registered before we start, then send didOpen This can
			-- happen if we attach to buffers before initialize finishes or if
			-- someone restarts a client.
			for bufnr, client_ids in pairs(BUFFER_CLIENT_IDS) do
				if client_ids[client_id] then
					client.text_document_did_open(bufnr)
				end
			end
		end)
	end

	--- Checks capabilities before rpc.request-ing.
	function client.request(method, params, callback)
		logger.info("client.request", client_id, method, params, callback)
		-- TODO check server capabilities before doing the request.
		-- TODO check server capabilities before doing the request.
		-- TODO check server capabilities before doing the request.
		-- TODO check server capabilities before doing the request.
		-- TODO check server capabilities before doing the request.
		-- TODO check server capabilities before doing the request.
		-- TODO check server capabilities before doing the request.
		-- error('unimplemented')
		return rpc.request(method, params, callback)
	end

	-- TODO keep this?
	function client.notify(...)
		return rpc.notify(...)
	end

	-- TODO hmmm.
	function client.stop(force)
		local handle = rpc.handle
		if handle:is_closing() then
			return
		end
		if force then
			-- kill after 1s as a last resort.
			table.insert(timers, set_timeout(1e3, function() handle:kill(9) end))
			handle:kill(15)
			return
		end
		-- term after 100ms as a fallback
		table.insert(timers, set_timeout(1e2, function() handle:kill(15) end))
		-- kill after 1s as a last resort.
		table.insert(timers, set_timeout(1e3, function() handle:kill(9) end))
		-- Sending a signal after a process has exited is acceptable.
		rpc.request('shutdown', nil, function(err, result)
			if err == nil then
				rpc.notify('exit')
			else
				-- If there was an error in the shutdown request, then term to be safe.
				handle:kill(15)
			end
		end)
	end

	function client.text_document_did_open(bufnr)
		local params = {
			textDocument = {
				version = 0;
				uri = vim.uri_from_bufnr(bufnr);
				-- TODO make sure this is correct.
				languageId = vim.api.nvim_buf_get_option(bufnr, 'filetype');
				text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n');
			}
		}
		rpc.notify('textDocument/didOpen', params)
	end

	initialize()

	return client_id
end

local ENCODING_INDEX = { ["utf-8"] = 1; ["utf-16"] = 2; ["utf-32"] = 3; }
local function text_document_did_change_handler(_, bufnr, changedtick, firstline, lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size)
	logger.debug("on_lines", bufnr, changedtick, firstline, lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size)
	-- Don't do anything if there are no clients attached.
	if vim.tbl_isempty(BUFFER_CLIENT_IDS[bufnr] or {}) then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
--	local lines = vim.api.nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
	-- Add an extra line. TODO why?
	-- if new_lastline > firstline then
	-- 	table.insert(lines, '')
	-- end
	local content_text = table.concat(lines, "\n")
	local uri = vim.uri_from_bufnr(bufnr)
	for_each_buffer_client(bufnr, function(client, client_id)
		local size_index = ENCODING_INDEX[client.offset_encoding]
		-- TODO make sure this is correct. Sometimes this sends firstline = lastline and text = ""
		client.notify("textDocument/didChange", {
			textDocument = {
				uri = uri;
				version = changedtick;
			};
			contentChanges = {
				-- TODO make sure this is correct. Sometimes this sends firstline = lastline and text = ""
				{
					-- range = {
					-- 	start = { line = firstline, character = 0 };
					-- 	["end"] = { line = lastline, character = 0 };
					-- };
					-- rangeLength = select(size_index, old_byte_size, old_utf16_size, old_utf32_size);
					text = content_text;
				};
			}
		})
	end)
end

-- Implements the textDocument/did* notifications required to track a buffer
-- for any language server.
--
-- This function could be implemented outside of the client function, since
-- it stands out alone as the only function which contains protocol
-- implementation details, but it's definitely easier to implement here.
function lsp.attach_to_buffer(bufnr, client_id)
	bufnr = resolve_bufnr(bufnr)
	local buffer_client_ids = BUFFER_CLIENT_IDS[bufnr]
	-- This is our first time attaching to this buffer.
	if not buffer_client_ids then
		buffer_client_ids = {}
		BUFFER_CLIENT_IDS[bufnr] = buffer_client_ids

		vim.api.nvim_command(string.format("autocmd BufWritePost <buffer=%d> lua vim.lsp._text_document_did_save_handler(%d)", bufnr, bufnr))
		local uri = vim.uri_from_bufnr(bufnr)

		-- First time, so attach and set up stuff.
		vim.api.nvim_buf_attach(bufnr, false, {
			on_lines = text_document_did_change_handler;
			-- TODO this could be abstracted if on_detach passes the bufnr, but since
			-- there's no documentation, I have no idea if that happens.
			on_detach = function()
				local params = {
					textDocument = {
						uri = uri;
					}
				}
				for_each_buffer_client(bufnr, function(client, client_id)
					client.notify('textDocument/didClose', params)
				end)
				BUFFER_CLIENT_IDS[bufnr] = nil
			end;
			-- TODO if we know all of the potential clients ahead of time, then we
			-- could conditionally set this.
			--			utf_sizes = size_index > 1;
			utf_sizes = true;
		})
	end
	if buffer_client_ids[client_id] then return end
	-- This is our first time attaching this client to this buffer.
	buffer_client_ids[client_id] = true

	local client = LSP_CLIENTS[client_id]
	-- Send didOpen for the client if it is initialized. If it isn't initialized
	-- then it will send didOpen on initialize.
	if client then
		client.text_document_did_open(bufnr)
	end
end

local LSP_CONFIGS = {}

function lsp.add_config(config)
  assert(type(config) == 'table', 'argument must be a table')
  assert(config.filetype, "config must have 'filetype' key")
  assert(config.cmd, "config must have 'cmd' key")
	assert(type(config.name) == 'string', "config.name must be a string")
	if LSP_CONFIGS[config.name] then
		-- If the client exists, then it is likely that they are doing some kind of
		-- reload flow, so let's not throw an error here.
		if LSP_CONFIGS[config.name].client_id then
			-- TODO log?
			return
		end
		error(string.format('A configuration with the name %q already exists. They must be unique', config.name))
	end
	local capabilities = config.capabilities or {}
	assert(type(capabilities) == 'table', "config.capabilities must be a table")

  local filetypes
  if type(config.filetype) == 'string' then
    filetypes = { config.filetype }
  elseif type(config.filetype) == 'table' then
    filetypes = config.filetype
  else
    error("config.filetype must be a string or a list of strings")
  end

	local offset_encoding = VALID_ENCODINGS.UTF8
--	local offset_encoding = VALID_ENCODINGS.UTF16
  if config.offset_encoding then
    assert(type(config.offset_encoding) == 'string', "config.offset_encoding must be a string")
		-- Ignore case here.
		offset_encoding = VALID_ENCODINGS[config.offset_encoding:lower()]
    assert(offset_encoding, "config.offset_encoding must be one of 'utf-8', 'utf-16', or 'utf32'")
  end

	local cmd, cmd_args
	if type(config.cmd) == 'string' then
		-- Use a shell to execute the command if it is a string.
		cmd = vim.api.nvim_get_option('shell')
		cmd_args = {vim.api.nvim_get_option('shellcmdflag'), config.cmd}
	elseif vim.tbl_islist(config.cmd) then
		cmd = config.cmd[1]
		cmd_args = {}
		-- Don't mutate our input.
		for i, v in ipairs(config.cmd) do
			assert(type(v) == 'string', "config.cmd arguments must be strings")
			if i > 1 then
				table.insert(cmd_args, v)
			end
		end
	else
		error("cmd type must be string or list.")
	end

	LSP_CONFIGS[config.name] = {
		user_config = config;
		name = config.name;
		offset_encoding = offset_encoding;
		filetypes = filetypes;
		cmd = cmd;
		cmd_args = cmd_args;
		capabilities = {};
	}

	vim.api.nvim_command(string.format(
		"autocmd FileType %s ++once silent lua vim.lsp._start_client_by_name(%q)",
		table.concat(filetypes, ','),
		config.name))
end

function lsp._start_client_by_name(name)
	local config = LSP_CONFIGS[name]
	-- If it exists and is running, don't make it again.
	if config.client_id and LSP_CLIENTS[config.client_id] then
		-- TODO log?
		return
	end
	config.client_id = lsp.start_client(config)
	vim.lsp.attach_to_buffer(0, config.client_id)

	vim.api.nvim_command(string.format(
		"autocmd FileType %s silent lua vim.lsp.attach_to_buffer(0, %d)",
		table.concat(config.filetypes, ','),
		config.client_id))
end

vim.api.nvim_command("autocmd VimLeavePre * lua vim.lsp.stop_all_clients()")

function lsp.get_client(client_id)
	return LSP_CLIENTS[client_id]
end

function lsp.stop_client(client_id, force)
  local client = LSP_CLIENTS[client_id]
  if client then
    client.stop(force)
  end
end

function lsp.stop_all_clients(force)
	for client_id, client in pairs(LSP_CLIENTS) do
		client.stop(force)
	end
end

--- Send a request to a server and return the response
-- @param method [string]: Name of the request method
-- @param params [table] (optional): Arguments to send to the server
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: success?, request_id, cancel_fn
function lsp.buf_request(bufnr, method, params, callback)
	if not callback then
		-- TODO
		callback = default_request_callbacks[method]
--		callback = LSP_CONFIGS[
	end
	assert(type(callback) == 'function', "callback must be a function")

	local client_request_ids = {}
	for_each_buffer_client(bufnr, function(client, client_id)
		local request_success, request_id = client.request(method, params, function(err, result)
			callback(err, result, client_id)
		end)

		-- This could only fail if the client shut down in the time since we looked
		-- it up and we did the request, which should be rare.
		if request_success then
			client_request_ids[client_id] = request_id
		end
	end)

	local function cancel_request()
		for client_id, request_id in pairs(client_request_ids) do
			local client = LSP_CLIENTS[client_id]
			client.rpc.notify('$/cancelRequest', { id = request_id })
		end
	end

	return client_request_ids, cancel_request
end

--- Send a request to a server, but don't wait for the response
-- @param method [string]: Name of the request method
-- @param params [string]: Arguments to send to the server
-- @param cb [function|string] (optional): Either a function to call or a string to call in vim
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The table of request id
function lsp.buf_request_sync(bufnr, method, params, timeout_ms)
	local request_results = {}
	local result_count = 0
	local function callback(err, result, client_id)
		logger.info("callback", err, result, client_id)
		request_results[client_id] = { error = err, result = result }
		result_count = result_count + 1
	end
	local client_request_ids, cancel = lsp.buf_request(bufnr, method, params, callback)
	logger.info("client_request_ids", client_request_ids)

	local expected_result_count = 0
	for _ in pairs(client_request_ids) do
		expected_result_count = expected_result_count + 1
	end
	logger.info("expected_result_count", expected_result_count)
	local timeout = (timeout_ms or 100) + vim.loop.now()
	-- TODO is there a better way to sync this?
	while result_count < expected_result_count do
		logger.info("results", result_count, request_results)
		if vim.loop.now() >= timeout then
			cancel()
			return nil, "TIMEOUT"
		end
		-- TODO this really needs to be further looked at.
		vim.api.nvim_command "sleep 10m"
		-- vim.loop.sleep(10)
		vim.loop.update_time()
	end
	vim.loop.update_time()
	logger.info("results", result_count, request_results)
	return request_results
end

--- Send a notification to a server
-- @param method [string]: Name of the request method
-- @param params [string]: Arguments to send to the server
-- @param bufnr [number] (optional): The number of the buffer
-- @param filetype [string] (optional): The filetype associated with the server
-- @param server_name [string] (optional)
--
-- @returns: The notification message id
function lsp.buf_notify(bufnr, method, params)
	for_each_buffer_client(bufnr, function(client, client_id)
		client.rpc.notify(method, params)
	end)
end

function lsp._text_document_did_save_handler(bufnr)
	bufnr = resolve_bufnr(bufnr)
	local params = {
		textDocument = {
			uri = vim.uri_from_bufnr(bufnr);
			-- TODO make sure I'm handling this correctly.
			-- Optional the content when saved. Depends on the includeText value
			-- when the save notification was requested.
			text = nil;
		}
	}
	for_each_buffer_client(bufnr, function(client, client_id)
		client.notify('textDocument/didSave', params)
	end)
end

function lsp.omnifunc(findstart, base)
  logger.debug(string.format("omnifunc findstart: %s, base: %s", findstart, base))

	local bufnr = resolve_bufnr()
	local has_buffer_clients = not vim.tbl_isempty(BUFFER_CLIENT_IDS[bufnr] or {})
  if not has_buffer_clients then
		if findstart == 1 then
			return -1
		else
			return {}
		end
  end

  if findstart == 1 then
    return vim.fn.col('.')
	else
		local pos = vim.api.nvim_win_get_cursor(0)
		local line = assert(vim.api.nvim_buf_get_lines(bufnr, pos[1]-1, pos[1], false)[1])
		logger.debug("line", pos, line)
		local line_to_cursor = line:sub(1, pos[2]+1)
		local params = {
			textDocument = {
				uri = vim.uri_from_bufnr(bufnr);
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
		-- TODO handle timeout error differently?
    local client_responses = lsp.buf_request_sync(bufnr, 'textDocument/completion', params) or {}
    local matches = {}
    for client_id, response in pairs(client_responses) do
			-- TODO how to handle errors?
      if not response.error then
				local data = response.result
				local completion_items = text_document_handler.completion_list_to_complete_items(data or {}, line_to_cursor)
				logger.debug("line_to_cursor", line_to_cursor)
				logger.debug("completion_items", completion_items)
				-- TODO use this.
				-- vim.list_extend(matches, completion_items)
				for _, match in ipairs(completion_items) do
					table.insert(matches, match)
				end
				-- logger.debug('callback:textDocument/completion(omnifunc)', data, ' ', self)
      end
    end
    return matches
  end
end

-- -- TODO keep?
-- function lsp.get_buffer_clients(bufnr)
-- 	local result = {}
-- 	for_each_buffer_client(bufnr, function(client, client_id)
-- 		result[client_id] = client
-- 	end)
-- 	return result
-- end

-- function lsp.handle(filetype, method, result, default_only)
--   return callbacks.call_callback(method, true, result, default_only, filetype)
-- end

-- function lsp.client_has_started(filetype, server_name)
--   assert(filetype, "filetype is required.")
--   if server_name then
--     local client = lsp.get_client(filetype, server_name)
--     if client and client:is_running() then
--       return true
--     else
--       return false
--     end
--   else
--     local filetype_clients = lsp.get_clients(filetype)
--     if filetype_clients ~= nil then
--       for _, client in ipairs(filetype_clients) do
-- 				if client:is_running() then
-- 					return true
-- 				end
--       end
--     end
--     return false
--   end
-- end

-- function lsp.client_info(bufnr)
-- 	bufnr = resolve_bufnr(bufnr)
-- 	return BUFFER_CLIENT_IDS[bufnr]
--   assert(filetype and filetype ~= '', "The filetype argument must be non empty string")
--   if not server_name then
--     server_name = filetype
--   end
--   local client =  lsp.get_client(filetype, server_name)
--   if client then
--     return vim.inspect(client)
--   else
--     return 'No client is available for filetype: '..filetype..', server_name: '..server_name..'.'
--   end
-- end

-- function lsp.status()
--   local status = ''
--   for _, filetype_clients in pairs(LSP_CLIENTS) do
--     for _, client in pairs(filetype_clients) do
--       status = status..'filetype: '..client.filetype..', server_name: '..client.server_name..', command: '..client.cmd.execute_path..'\n'
--     end
--   end
--   return status
-- end

return lsp
