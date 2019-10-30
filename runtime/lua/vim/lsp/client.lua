local uv = vim.loop
local logger = require('vim.lsp.logger')

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

-- Client.initialize = function(self)
--   local request_id = self:request_async('initialize', protocol.InitializeParams(self), function(_, result)
--     self:notify('initialized', protocol.InitializedParams())
--     self:notify('textDocument/didOpen', protocol.DidOpenTextDocumentParams())
--     self:set_server_capabilities(result.capabilities)
--     return result.capabilities
--   end, nil)
--   logger.info(string.format(
--     "filetype: %s, server_name: %s, offset_encoding: %s, client_capabilities: %s, server_capabilities: %s",
--     self.filetype, self.server_name, self.offset_encoding, vim.inspect(self.client_capabilities, {newline=''}), vim.inspect(self.server_capabilities, {newline=''})
--   ))
--   return request_id
-- end

-- Client.set_client_capabilities = function(self, capabilities)
--   self.client_capabilities = capabilities
-- end

-- Client.set_server_capabilities = function(self, capabilities)
--   if type(capabilities.offsetEncoding) == 'string' and
--     vim.tbl_contains({'utf-8', 'utf-16', 'utf-32'}, capabilities.offsetEncoding) then
--     self.offset_encoding = capabilities.offsetEncoding
--   end
--   self.server_capabilities = capabilities
-- end

local function format_message_with_content_length(encoded_message)
	return table.concat {
		'Content-Length: '; tostring(#encoded_message); '\r\n\r\n';
		encoded_message;
	}
end

-- TODO use something faster than vim.fn?
local function json_encode(data)
	local status, result = pcall(vim.fn.json_encode, data)
	if status then
		return result
	else
		return nil, result
	end
end
local function json_decode(data)
	local status, result = pcall(vim.fn.json_decode, data)
	if status then
		return result
	else
		return nil, result
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

--- Parse an LSP Message's header
-- @param header: The header to parse.
local function parse_headers(header)
  if type(header) ~= 'string' then
    return nil
  end
  local headers = {}
  for line in vim.gsplit(header, '\\r\\n', true) do
    if line == '' then
			break
		end
		local key, value = line:match("^%s*(%S+)%s*:%s*(%S+)%s*$")
		if key then
			key = key:lower():gsub('%-', '_')
			headers[key] = value
		else
			logger.error("invalid header line %q", line)
			error(string.format("invalid header line %q", line))
		end
  end
	headers.content_length = tonumber(headers.content_length)
	assert(headers.content_length, "Content-Length not found in headers.")
  return headers
end

local function text_document_did_change_params(size_index, _, bufnr, changedtick, firstline, lastline, new_lastline, old_byte_size, old_utf32_size, old_utf16_size)
  local lines = vim.api.nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
	-- Add an extra line. TODO why?
	if new_lastline > firstline then
		table.insert(lines, '')
	end
	return {
		textDocument = {
			uri = vim.uri_from_bufnr(bufnr);
			version = changedtick;
		};
		contentChanges = {
			-- TODO make sure this is correct. Sometimes this sends firstline = lastline and text = ""
			{
				range = {
					start = { line = firstline, character = 0 };
					["end"] = { line = lastline, character = 0 };
				};
				text = table.concat(lines, "\n");
				rangeLength = select(size_index, old_byte_size, old_utf16_size, old_utf32_size);
			};
		}
	}
end

local function request_parser_loop()
	local buffer = ''
	while true do
		-- A message can only be complete if it has a double CRLF and also the full
		-- payload, so first let's check for the CRLFs
		local start, finish = buffer:find('\r\n\r\n', 1, true)
		-- Start parsing the headers
		if start then
			local headers = parse_headers(buffer:sub(1, start-1))
			buffer = buffer:sub(finish+1)
			local content_length = headers.content_length
			-- Keep waiting for data until we have enough.
			while #buffer < content_length do
				buffer = buffer..assert(coroutine.yield(), ":( body") -- TODO hmm.
			end
			local body = buffer:sub(1, content_length)
			buffer = buffer:sub(content_length + 1)
			-- Yield our data.
			buffer = buffer..assert(coroutine.yield(headers, body), ':( cont') -- TODO hmm.
		else
			-- Get more data since we don't have enough.
			buffer = buffer..assert(coroutine.yield(), ":( header") -- TODO hmm.
		end
	end
end

local function add_reverse_lookup(o)
	local keys = {}
	for k in pairs(o) do table.insert(keys, k) end
	for _, k in ipairs(keys) do o[o[k]] = k end
	-- for k, v in pairs(o) do o[v] = k end
	return o
end
local CLIENT_ERRORS = add_reverse_lookup {
	INVALID_SERVER_MESSAGE = 1;
	NO_RESULT_CALLBACK_FOUND = 2;
}

local CLIENT_INDEX = 0
local function next_client_id()
	CLIENT_INDEX = CLIENT_INDEX + 1
	return CLIENT_INDEX
end

local LSP_CLIENTS = {}

local function text_document_did_save_handler(client_id, bufnr)
	local client = LSP_CLIENTS[client_id]
	if not client then
		-- TODO error here?
		error(string.format("text_document_did_save_handler called with client_id that's not found: %d", client_id))
	end
	local params = {
		textDocument = {
			uri = vim.uri_from_bufnr(bufnr or 0);
			-- TODO make sure I'm handling this correctly.
			-- Optional the content when saved. Depends on the includeText value
			-- when the save notification was requested.
			text = nil;
		}
	}
	client.notify('textDocument/didSave', params)
end

local function set_timeout(ms, fn)
	local timer = uv.new_timer()
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
local ENCODING_INDEX = { ["utf-8"] = 1; ["utf-16"] = 2; ["utf-32"] = 3; }

local function create_and_start_client(conf)
	logger.info("starting client", conf)
	assert(type(conf.name) == 'string', "conf.name must be a string")
	local offset_encoding = VALID_ENCODINGS[conf.offset_encoding]
	if not offset_encoding then
		error(string.format("Invalid offset_encoding: %q", conf.offset_encoding))
	end
	assert(type(conf.cmd) == 'string', "conf.cmd must be a string")
	assert(type(conf.cmd_args) == 'table', "conf.cmd_args must be a table")
	local cmd, cmd_args, name = conf.cmd, conf.cmd_args, conf.name

	-- TODO make sure this is always correct.
	if not (vim.fn.executable(cmd) == 1) then
    error(string.format("The given command %q is not executable.", cmd))
	end

	-- TODO hmmm.
	local notification_handler = conf.notification_handler or function(...) logger.info('notification', ...) end
	assert(type(notification_handler) == 'function', "notification_handler must be a function")

	-- TODO hmmm.
	local server_request_handler = conf.server_request_handler or function(...) logger.info('server_request', ...) return nil, 'nil' end
	assert(type(server_request_handler) == 'function', "server_request_handler must be a function")

	-- TODO hmmm.
	local error_handler = conf.error_handler or function(kind, ...) logger.info('client_error:', CLIENT_ERRORS[kind], ...) end
	assert(type(error_handler) == 'function', "error_handler must be a function")

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

	local client_id = next_client_id()

  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

	local timers = {}

  local handle, pid
	do
		local function onexit(code, signal)
			stdin:close()
			stdout:close()
			stderr:close()
			handle:close()
			for _, h in ipairs(timers) do
				h:stop()
				h:close()
			end
			LSP_CLIENTS[client_id] = nil
		end
		local spawn_params = {
			args = cmd_args;
			stdio = {stdin, stdout, stderr};
		}
		handle, pid = uv.spawn(cmd, spawn_params, onexit)
	end

	local message_index = 0
	local message_callbacks = {}

	local function encode_and_send(payload)
		if handle:is_closing() then return false end
		-- TODO keep these?
		assert(type(payload.jsonrpc) == 'string', "payload.jsonrpc must be a string")
		local encoded = assert(json_encode(payload))
		stdin:write(format_message_with_content_length(encoded))
		return true
	end

	local function send_notification(method, params)
		logger.info('notify', method, params)
		return encode_and_send {
			jsonrpc = "2.0";
			method = method;
			params = params;
		}
	end

	local attached_buffers = {}
	local function attach_to_buffer(bufnr)
		if bufnr == nil or bufnr == 0 then
			bufnr = vim.api.nvim_get_current_buf()
		end
		assert(type(bufnr) == 'number', "bufnr must be a number")
		if attached_buffers[bufnr] then return false end
		attached_buffers[bufnr] = true

		do
			local params = {
				textDocument = {
					uri = vim.uri_from_bufnr(bufnr);
					text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n');
					version = 0;
					languageId = vim.api.nvim_buf_get_option(bufnr, 'filetype');
				}
			}
			send_notification('textDocument/didOpen', params)
		end
		-- TODO change this to vim.lsp._text_document_did_save_handler.
		vim.api.nvim_command(string.format("autocmd BufWritePost <buffer=%d> lua require'vim.lsp.client'.text_document_did_save_handler(%d, %d)", bufnr, client_id, bufnr))

		local size_index = ENCODING_INDEX[offset_encoding]
		vim.api.nvim_buf_attach(bufnr, false, {
			on_lines = function(...)
				local params = text_document_did_change_params(size_index, ...)
				logger.info('params=', params)
				if not send_notification("textDocument/didChange", params) then
					-- attached_buffers[bufnr] = nil
					return true
				end
			end;
			on_detach = function()
				attached_buffers[bufnr] = nil
				local params = {
					textDocument = {
						uri = vim.uri_from_bufnr(bufnr);
					}
				}
				send_notification('textDocument/didClose', params)
			end;
			utf_sizes = size_index > 1;
		})
		return true
	end

	local function send_response(request_id, error, result)
		return encode_and_send {
			id = request_id;
			jsonrpc = "2.0";
			error = error;
			result = result;
		}
	end

	-- TODO implement cancel by returning a function
	local function send_request(method, params, callback)
		message_index = message_index + 1
		local message_id = message_index
		-- TODO check the result here and assert it went correctly.
		local result = encode_and_send {
			id = message_id;
			jsonrpc = "2.0";
			method = method;
			params = params;
		}
		if result then
			message_callbacks[message_id] = callback
			return result, message_id, function() send_notification('$/cancelRequest', { id = message_id }) end
		else
			return false
		end
	end

	-- local function send_request_sync(method, params)
	-- 	local co = coroutine.running()
	-- 	send_request(method, params, function(...) coroutine.resume(co, ...) end)
	-- 	return coroutine.yield()
	-- end

	-- TODO hmmm.
	local function stop(force)
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
		send_request('shutdown', nil, function(err, result)
			if err == nil then
				send_notification('exit')
			else
				-- If there was an error in the shutdown request, then term to be safe.
				handle:kill(15)
			end
		end)
	end

	local request_parser = coroutine.wrap(request_parser_loop)
	request_parser()
	stdout:read_start(function(err, chunk)
		if err then
			-- TODO better handling. Can these be intermittent errors?
			error(err)
			return
		end
		if not chunk then
			return
		end
		local headers, body = request_parser(chunk)
		-- If we successfully parsed, then handle the response.
		if headers then
			-- TODO handle invalid decoding.
			local decoded
			decoded, err = json_decode(body)
			if not decoded then
				-- TODO should I specify invalid json?
				pcall(error_handler, CLIENT_ERRORS.INVALID_SERVER_MESSAGE, err)
			end

			-- assert(type(decoded) == 'table', "Server sent an invalid response")
			if type(decoded.method) == 'string' and decoded.id then
				-- Server Request
				local status, result
				status, result, err = pcall(server_request_handler, decoded.method, decoded.params)
				-- TODO what to do here? Fatal error?
				assert(result or err, "either a result or an error must be sent to the server in response")
				if not status then
					err = result
					result = nil
				end
				-- TODO make sure that these won't block anything.
				send_response(decoded.id, err, result)
			elseif decoded.id then
				-- TODO this will fail if result is null in the success case. such as for shutdown.
				--			elseif decoded.id and (decoded.result or decoded.error) then
				-- Server Result
				-- TODO verify decoded.id is a string or number?
				local result_id = tonumber(decoded.id)
				local callback = message_callbacks[result_id]
				if callback then
					message_callbacks[result_id] = nil
					assert(type(callback) == 'function', "callback must be a function")
					-- TODO log errors from user.
					pcall(callback, decoded.error, decoded.result)
				else
					-- TODO handle us not having a callback
					pcall(error_handler, CLIENT_ERRORS.NO_RESULT_CALLBACK_FOUND, decoded)
					logger.error("No callback found for server response id "..result_id)
				end
			elseif type(decoded.method) == 'string' then
				-- Notification
				pcall(notification_handler, decoded.method, decoded.params)
			else
				-- Invalid server message
				pcall(error_handler, CLIENT_ERRORS.INVALID_SERVER_MESSAGE, decoded)
			end
		end
	end)

	local client = {
		id = client_id;
		pid = pid;
		request = send_request;
		-- request_sync = send_request_sync;
		notify = send_notification;
		stop = stop;
		attach_to_buffer = attach_to_buffer;
	}
	LSP_CLIENTS[client_id] = client
	return client
end

return {
	create_and_start_client = create_and_start_client;
	text_document_did_save_handler = text_document_did_save_handler;
	get_client_by_id = function(client_id)
		return LSP_CLIENTS[client_id]
	end;
}
