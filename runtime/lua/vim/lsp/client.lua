local uv = vim.loop
local util = require('vim.lsp.util')
local logger = require('vim.lsp.logger')
local autocmd = require('vim.lsp.autocmd')
local create_message = require('vim.lsp.message').create_message
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
  local obj = setmetatable({
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

  logger.info('Starting new client. server_name: '..server_name..', cmd: '..vim.inspect(cmd, {newline=''})..', offset_encoding: '..offset_encoding)

  return obj
end

Client.start = function(self)
  self._stdin = uv.new_pipe(false)
  self._stdout = uv.new_pipe(false)
  self._stderr = uv.new_pipe(false)

  local function on_exit()
    logger.info('filetype: '..self.filetype..', exit: '..self.cmd_tostring)
  end

  local stdio = { self._stdin, self._stdout, self._stderr }
  local cmd_with_opts, execute_path, opts

  if type(self.cmd) == 'string' then
    cmd_with_opts = vim.split(self.cmd, ' ', true)
    execute_path = table.remove(cmd_with_opts, 1)
    opts = { args = cmd_with_opts, stdio = stdio }
  elseif vim.tbl_islist(self.cmd) then
    cmd_with_opts = self.cmd
    execute_path = table.remove(cmd_with_opts, 1)
    opts = { args = cmd_with_opts, stdio = stdio }
  else
    error("cmd type must be string or table.", 2)
  end

  self._handle, self.pid = uv.spawn(execute_path, opts, on_exit)

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

  vim.api.nvim_command("echo 'shutting down filetype: "..self.filetype..", server_name: "..self.server_name.."'")
  self:request('shutdown', nil, function()end)

  vim.api.nvim_command("echo 'exit filetype: "..self.filetype..", server_name: "..self.server_name.."'")
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

Client.cmd_tostring = function(self)
  if type(self.cmd) == 'table' then
    return table.concat(self.cmd)
  end
  return self.cmd
end

Client.initialize = function(self)
  local request_id = self:request_async('initialize', protocol.InitializeParams(self), function(_, result)
    self:notify('initialized', protocol.InitializedParams())
    self:notify('textDocument/didOpen', protocol.DidOpenTextDocumentParams())
    self:set_server_capabilities(result.capabilities)
    return result.capabilities
  end, nil)

  logger.info(
    "filetype: "..self.filetype..", server_name: "..self.server_name..", offset_encoding: "..self.offset_encoding..
    ", client_capabilities: "..vim.inspect(self.client_capabilities, {newline=''})..
    ", server_capabilities: "..vim.inspect(self.server_capabilities, {newline=''})
  )

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

Client._request = function(self, message_type, method, params, cb, bufnr)
  if self:is_stopped() then
    local msg = 'Language server client is not running. '..self.server_name
    logger.info(msg)
    error(msg, 2)
  end

  if not method then
    error("No request method supplied", 2)
  end

  local message = create_message(self, message_type, method, params)
  if message == nil then return nil end

  if message_type == 'request' or message_type == 'request_async' then
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    -- After handling callback semantics, store it to call on reply.
    self._callbacks[message.id] = {
      cb = cb,
      method = message.method,
      bufnr = bufnr,
      message_type = message_type,
    }
  end

  uv.write(self._stdin, message:data())
  logger.write('debug', "Send "..message_type.." --- "..self.filetype..", "..self.server_name.." --->: [[ "..message:data().." ]]", 'client')

  return message.id
end

--- Parse an LSP Message's header
-- @param header: The header to parse.
Client._parse_header = function(header)
  if type(header) ~= 'string' then
    return nil, nil
  end

  local lines = vim.split(header, '\\r\\n', true)

  local split_lines = {}

  for _, line in pairs(lines) do
    if line ~= '' then
      local temp_lines = vim.split(line, ':', true)
      for t_index, t_line in pairs(temp_lines) do
        temp_lines[t_index] = vim.trim(t_line)
      end

      split_lines[temp_lines[1]:lower():gsub('-', '_')] = temp_lines[2]
    end
  end

  if split_lines.content_length then
    split_lines.content_length = tonumber(split_lines.content_length)
  end

  return split_lines, nil
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
      local eol = self._read_data:find('\r\n')

      -- If we haven't seen the end of the line, then we haven't reached the entire messag yet.
      if not eol then
        return
      end

      local line = self._read_data:sub(1, eol - 1)
      self._read_data = self._read_data:sub(eol + 2)

      if #line == 0 then
        self._read_state = read_state.body
      else
        local parsed = self._parse_header(line)

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
            self:_on_error(error_level.reset_state,
              string.format('_on_read error: bad content length (%s)',
                self._read_length)
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

Client._on_message = function(self, body)
  local ok, json_message = pcall(util.decode_json, body)

  if not ok then
    logger.error('Not a valid message. Calling self:_on_error')
    self:_on_error(
      error_level.reset_state,
      string.format('_on_read error: bad json_message (%s)', body)--self._read_data)
    )
    return
  end
  -- Handle notifications
  if json_message.method and json_message.params then
    logger.write('debug', "Receive notification <---: [[ method: "..json_message.method..", params: "..vim.inspect(json_message.params, {newline=''}).." ]]", 'server')
    call_callback(json_message.method, true, json_message.params, nil)

    return
  -- Handle responses
  elseif not json_message.method and json_message.id then
    local cb, message_type

    if self._callbacks[json_message.id] and self._callbacks[json_message.id].cb then
      cb = self._callbacks[json_message.id].cb
      message_type = self._callbacks[json_message.id].message_type
    end

    local id = json_message.id
    local method = self._callbacks[json_message.id].method
    local is_success = not json_message['error']
    local result = json_message.result or {}
    if is_success then
      logger.write('debug', "Receive response <--- "..self.filetype..", "..self.server_name.." ---: [[ id: "..id..", method: "..method..", result: "..vim.inspect(result, {newline=''}).." ]]", 'server')
    else
      logger.write('error', "Receive response <--- "..self.filetype..", "..self.server_name.." ---: [[ id: "..id..", method: "..method..", error: "..vim.inspect(result, {newline=''}).." ]]", 'server')
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
