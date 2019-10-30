local uv = vim.loop
local logger = require('vim.lsp.logger')
local autocmd = require('vim.lsp.autocmd')
-- local create_message = require('vim.lsp.message').create_message
local call_callback = require('vim.lsp.callbacks').call_callback
local protocol = require('vim.lsp.protocol')

local read_state = {
  init = 0,
  header = 1,
  body = 2,
}

local error_level = {
  critical = 0,
  reset_state = 1,
  info = 2,
}

local Client = {}
Client.__index = Client

Client.new = function(server_name, filetype, cmd, offset_encoding)
  local client = setmetatable({
    server_name = server_name,
    filetype = filetype,
    cmd = cmd,
    client_capabilities = {},
    server_capabilities = {},
    offset_encoding = offset_encoding,
    attached_buf_list = {},

    -- State for handling messages
    _read_state = read_state.init,
    _read_data = '',
    _read_length = 0,

    -- Results & Callback handling
    --  Callbacks must take two arguments:
    --      1 - success: true if successful, false if error
    --      2 - data: corresponding data for the message
    _callbacks = {},
    _responses = {},
    _stopped = false,

    _stdin = nil,
    _stdout = nil,
    _stderr = nil,
    _handle = nil,
  }, Client)

  logger.info(string.format("Starting new client. server_name: %s, cmd: %s, offset_encoding: %s", server_name, vim.inspect(cmd, {newline=''}), offset_encoding))

  return client
end

Client.start = function(self)
  assert(
    vim.fn.executable(self.cmd.execute_path) == 1,
    string.format("Language server config error: The given command %q is not executable.", self.cmd.execute_path)
  )

  self._stdin = uv.new_pipe(false)
  self._stdout = uv.new_pipe(false)
  self._stderr = uv.new_pipe(false)

  local function on_exit()
    logger.info(string.format("filetype: %s, exit: ", self.filetype, self.cmd.execute_path))
  end

  local stdio = { self._stdin, self._stdout, self._stderr }

  self._handle, self.pid = uv.spawn(
    self.cmd.execute_path,
    { args = self.cmd.execute_opts, stdio = stdio },
    on_exit
  )

  uv.read_start(self._stdout, function (err, chunk)
    if not err then
      self:_on_stdout(chunk)
    end
  end)

  uv.read_start(self._stderr, function (err, chunk)
    if err and chunk then
      logger.error('stderr: '..err..', data: '..chunk)
    end
  end)

  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_get_option(buf, "ft") == self.filetype then
      self:set_buf_change_handler(buf)
    end
  end

  autocmd.register_text_document_autocmd(self.filetype, self.server_name)
end

Client.stop = function(self)
  if self:is_stopped() then
    return
  end

  autocmd.unregister_autocmd(self.filetype, self.server_name)

  print(string.format("shutting down filetype: %s, server_name: %s", self.filetype, self.server_name))
  self:request('shutdown', nil, function()end)

  print(string.format("exit filetype: %s, server_name: %s", self.filetype, self.server_name))
  self:notify('exit', nil)

  uv.shutdown(self._stdin, function()
    uv.close(self._stdout)
    uv.close(self._stderr)
    uv.close(self._stdin)
    uv.close(self._handle)
  end)
  uv.kill(self.pid, 'sigterm')

  self._stopped = true
end

Client.is_running = function(self)
  return not self._stopped
end

Client.is_stopped = function(self)
  return self._stopped
end

Client.initialize = function(self)
  local request_id = self:request_async('initialize', protocol.InitializeParams(self), function(_, result)
    self:notify('initialized', protocol.InitializedParams())
    self:notify('textDocument/didOpen', protocol.DidOpenTextDocumentParams())
    self:set_server_capabilities(result.capabilities)
    return result.capabilities
  end, nil)

  logger.info(string.format(
    "filetype: %s, server_name: %s, offset_encoding: %s, client_capabilities: %s, server_capabilities: %s",
    self.filetype, self.server_name, self.offset_encoding, vim.inspect(self.client_capabilities, {newline=''}), vim.inspect(self.server_capabilities, {newline=''})
  ))

  return request_id
end

Client.set_client_capabilities = function(self, capabilities)
  self.client_capabilities = capabilities
end

Client.set_server_capabilities = function(self, capabilities)
  if type(capabilities.offsetEncoding) == 'string' and
    vim.tbl_contains({'utf-8', 'utf-16', 'utf-32'}, capabilities.offsetEncoding) then
    self.offset_encoding = capabilities.offsetEncoding
  end

  self.server_capabilities = capabilities
end


Client.set_buf_change_handler = function(self, bufnr)
  if not self.attached_buf_list[bufnr] then
    self.attached_buf_list[bufnr] = true
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(...) self:handle_text_document_did_change(...) end,
      utf_sizes = (Client.offset_encoding == 'utf-16' or (Client.offset_encoding == 'utf-32'))
    })
  end
end



Client.handle_text_document_did_change = function(self, _, bufnr, changedtick, firstline, lastline, new_lastline, old_bytes, _, units)
  if self:is_stopped() then return true end
  local uri = vim.uri_from_bufnr(bufnr)
  local version = changedtick

  protocol.update_document_version(version, uri)
  local textDocument = { uri = uri, version = version }
  local lines = vim.api.nvim_buf_get_lines(bufnr, firstline, new_lastline, true)
  local text = table.concat(lines, "\n") .. ((new_lastline > firstline) and "\n" or "")
  local range = {
    start = {
      line = firstline,
      character = 0
    },
    ["end"] = {
      line = lastline,
      character = 0
    }
  }
  local length = (self.offset_encoding == 'utf-8' and old_bytes) or units
  local edit = { range = range, text = text, rangeLength = length }
  self:notify("textDocument/didChange", { textDocument = textDocument, contentChanges = { edit } })
end

--- Make a request to the server
-- @param method: Name of the LSP method
-- @param params: the parameters to send

-- @return response (table): The language server response
Client.request = function(self, method, params, bufnr)
  local request_id =  self:_request('request', method, params, 'skip', bufnr)

  local timeout = os.time() + 10

  while (os.time() < timeout) and (self._responses[request_id] == nil) do
    vim.api.nvim_command('sleep 10m')
  end

  if self._responses[request_id] == nil then
    return nil
  end

  local response = self._responses[request_id]

  -- Clear results
  self._responses[request_id] = nil

  return response
end

--- Sends an async request to the client.
-- If a callback is passed,
--  it will be registered to run when the response is received.
--
-- @param method (string|table) : The identifier for the type of message that is being requested
-- @param params (table)        : Optional parameters to pass to override default parameters for a request
-- @param cb     (function)     : An optional function pointer to call once the request has been completed
--                                  If a string is passed, it will execute a VimL funciton of that name
--                                  To disable handling the request, pass "false"

-- @return message id (number)
Client.request_async = function(self, method, params, cb, bufnr)
  return self:_request('request_async', method, params, cb, bufnr)
end

--- Send a notification to the server
-- @param method (string): Name of the LSP method
-- @param params (table): the parameters to send

-- @return message id (number)
Client.notify = function(self, method, params)
  return self:_request('notification', method, params)
end

-- TODO replace with local version for each client.
local MESSAGE_IDS = {}
local function get_next_message_id(client)
	MESSAGE_IDS[client] = (MESSAGE_IDS[client] or 0) + 1
	return MESSAGE_IDS[client]
end

local function format_message_with_content_length(encoded_message)
	return table.concat {
		'Content-Length: '; tostring(#encoded_message); '\r\n\r\n';
		encoded_message;
	}
end

local json_encode = vim.fn.json_encode

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

Client._request = function(self, message_type, method, params, cb, bufnr)
  if self:is_stopped() then
    local msg = 'Language server client is not running. '..self.server_name
    logger.info(msg)
    error(msg)
  end

  if not method then
    error("No request method supplied")
  end

	-- TODO improve check capabilities
	if not check_language_server_capabilities(self, method) then
		if message_type == 'notification' then
			logger.debug(string.format('Notification Method %q is not supported by server %s', method, self.name))
			logger.client.debug(string.format('Notification Method %q is not supported by server %s', method, self.name))
			return nil
		else
			logger.debug(string.format('[LSP:Request] Method %q is not supported by server %s', method, self.name))
			error("[LSP:Request] Method "..method.." is not supported by server "..self.name)
		end
	end

	params = params or {}
	assert(type(method) == 'string', "method must be a string")
	assert(type(params) == 'table', "params must be a table")

	local encoded_message, message_id
	if message_type == 'notification' then
		-- TODO use something faster than vim.fn?
		encoded_message = json_encode {
			jsonrpc = "2.0";
			method = method;
			params = params;
		}
	else
		message_id = get_next_message_id(self)
		-- TODO use something faster than vim.fn?
		encoded_message = json_encode {
			id = message_id;
			jsonrpc = "2.0";
			method = method;
			params = params;
		}
		assert(encoded_message, "Failed to encode request message")
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		-- After handling callback semantics, store it to call on reply.
		self._callbacks[message_id] = {
			cb = cb,
			method = method,
			bufnr = bufnr,
			message_type = message_type,
		}
	end
	encoded_message = format_message_with_content_length(encoded_message)

  uv.write(self._stdin, encoded_message)
  logger.debug(string.format("Send %s --- %s, %s --->: [[%s]]", message_type, self.filetype, self.server_name, encoded_message))

  return message_id
end

--- Parse an LSP Message's header
-- @param header: The header to parse.
local function parse_header(header)
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

Client._on_stdout = function(self, data)
  if not data then
    self:_on_error(error_level.info, '_on_read error: no chunk')
    return
  end

  -- Concatenate the data that we have read previously onto the data that we just read
  self._read_data = self._read_data..data..'\n'

  while true do
    if self._read_state == read_state.init then
      self._read_length = 0
      self._read_state = read_state.header
    elseif self._read_state == read_state.header then
      local eol = self._read_data:find('\r\n', 1, true)

      -- If we haven't seen the end of the line, then we haven't reached the entire messag yet.
      if not eol then
        return
      end

      local line = self._read_data:sub(1, eol - 1)
      self._read_data = self._read_data:sub(eol + 2)

      if #line == 0 then
        self._read_state = read_state.body
      else
        local parsed = parse_header(line)

        if (not parsed.content_length) and (not self._read_length) then
          self:_on_error(error_level.reset_state,
            string.format('_on_read error: bad header\n\t%s\n\t%s',
              line,
              vim.inspect(parsed, {newline=''}))
            )
          return
        end

        if parsed.content_length then
          self._read_length = parsed.content_length

          if type(self._read_length) ~= 'number' then
            self:_on_error(
              error_level.reset_state,
              string.format('_on_read error: bad content length (%s)', self._read_length)
            )
            return
          end
        end
      end
    elseif self._read_state == read_state.body then
      -- Quit for now if we don't have enough of the message
      if #self._read_data < self._read_length then
        return
      end

      -- Parse the message
      local body = self._read_data:sub(1, self._read_length)
      self._read_data = self._read_data:sub(self._read_length + 1)

      vim.schedule(function() self:_on_message(body) end)
      self._read_state = read_state.init
    end
  end
end

local json_decode = vim.fn.json_decode

Client._on_message = function(self, body)
  local ok, json_message = pcall(json_decode, body)

  if not ok then
    logger.error('Not a valid message. Calling self:_on_error')
    self:_on_error(
      error_level.reset_state, string.format('_on_read error: bad json_message (%s)', body)
    )
    return
  end
  -- Handle notifications
  if json_message.method and json_message.params then
    logger.debug(string.format("Receive notification <---: { method: %s, params: %s }", json_message.method, vim.inspect(json_message.params, {newline=''})))
    call_callback(json_message.method, true, json_message.params, nil)

    return
  -- Handle responses
  elseif not json_message.method and json_message.id then
    local cb, message_type

    if self._callbacks[json_message.id] and self._callbacks[json_message.id].cb then
      cb = self._callbacks[json_message.id].cb
      message_type = self._callbacks[json_message.id].message_type
    end

    local method = self._callbacks[json_message.id].method
    local is_success = not json_message['error']
    local result = json_message.result or {}
    if is_success then
      logger.debug(string.format("Receive response <--- %s, %s ---: %s", self.filetype, self.server_name, vim.inspect(json_message, {newline=''})))
    else
      logger.error(string.format("Receive response <--- %s, %s ---: %s", self.filetype, self.server_name, vim.inspect(json_message, {newline=''})))
    end

    if cb ~= 'skip' then
      -- If no callback is passed with request, use the registered callback.
      if cb then
        cb(is_success, result)
      else
        call_callback(method, is_success, result, self.filetype)
      end
    end

    -- Clear called callback
    self._callbacks[json_message.id] = nil

    -- Cache the response temporary for request.
    if message_type == 'request' then
      self._responses[json_message.id] = json_message
    end
  end
end

Client._on_error = function(self, level, err_message)
  if type(level) ~= 'number' then
    print('It seems to have a not number', level)
    self:_reset_state()
    return
  end

  if level <= error_level.critical then
    error('Critical error occured: ' .. vim.inspect(err_message, {newline=''}))
  end

  if level <= error_level.reset_state then
    self:_reset_state()
  end

  if level <= error_level.info then
    logger.warn(err_message)
  end
end

Client._reset_state = function(self)
  self._read_state = read_state.init
  self._read_data = ''
end

return Client
