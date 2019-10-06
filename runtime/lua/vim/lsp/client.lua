local autocmd = require('vim.lsp.autocmd')
local uv = vim.loop

local util = require('vim.lsp.util')

local logger = require('vim.lsp.logger')
local message = require('vim.lsp.message')
local call_callback = require('vim.lsp.callbacks').call_callback
local InitializeParams = require('vim.lsp.protocol').InitializeParams
local DidOpenTextDocumentParams = require('vim.lsp.protocol').DidOpenTextDocumentParams
local update_document_version = require('vim.lsp.protocol').update_document_version


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

local client = {}
client.__index = client

client.new = function(server_name, filetype, cmd, offset_encoding)
  local obj = setmetatable({
    server_name = server_name,
    filetype = filetype,
    cmd = cmd,

    -- State for handling messages
    _read_state = read_state.init,
    _read_data = '',
    _current_header = {},

    client_capabilities = {},
    -- Capabilities sent by server
    server_capabilities = {},

    -- Results & Callback handling
    --  Callbacks must take two arguments:
    --      1 - success: true if successful, false if error
    --      2 - data: corresponding data for the message
    _callbacks = {},
    _results = {},
    _stopped = false,

    -- Data fields, to be used internally
    __data__ = {},
    attached_buf_list = {},
    offset_encoding = offset_encoding,
    stdin = nil,
    stdout = nil,
    stderr = nil,
    handle = nil,
  }, client)

  logger.info('Starting new client. server_name: '..server_name..', cmd: '..vim.tbl_tostring(cmd)..', offset_encoding: '..offset_encoding)

  return obj
end

client.start = function(self)
  self.stdin = uv.new_pipe(false)
  self.stdout = uv.new_pipe(false)
  self.stderr = uv.new_pipe(false)

  local function on_exit()
    logger.info('filetype: '..self.filetype..', exit: '..self.cmd_tostring)
  end

  local stdio = { self.stdin, self.stdout, self.stderr }

  if type(self.cmd) == 'string' then
    local cmd_with_opts = vim.split(self.cmd, ' ', true)
    local execute_path = table.remove(cmd_with_opts, 1)
    local opts = { args = cmd_with_opts, stdio = stdio }
    self.handle, self.pid = uv.spawn(execute_path, opts, on_exit)
  elseif vim.tbl_islist(self.cmd) then
    local cmd_with_opts = self.cmd
    local execute_path = table.remove(cmd_with_opts, 1)
    local opts = { args = cmd_with_opts, stdio = stdio }
    self.handle, self.pid = uv.spawn(execute_path, opts, on_exit)
  else
    error("cmd type must be string or table.", 2)
  end

  uv.read_start(self.stdout, function (err, chunk)
    if not err then
      self:on_stdout(chunk)
    end
  end)

  uv.read_start(self.stderr, function (err, chunk)
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

client.stop = function(self)
  if self._stopped then
    return
  end

  autocmd.unregister_autocmd(self.filetype, self.server_name)


  vim.api.nvim_command("echo 'shutting down filetype: "..self.filetype..", server_name: "..self.server_name.."'")
  self:request('shutdown', nil, function()end)

  vim.api.nvim_command("echo 'exit filetype: "..self.filetype..", server_name: "..self.server_name.."'")
  self:notify('exit', nil)

  uv.shutdown(self.stdin, function()
    uv.close(self.stdout)
    uv.close(self.stderr)
    uv.close(self.stdin)
    uv.close(self.handle)
  end)
  uv.kill(self.pid, 'sigterm')

  self._stopped = true
end

client.cmd_tostring = function(self)
  if type(self.cmd) == 'table' then
    return table.concat(self.cmd)
  end
  return self.cmd
end

client.initialize = function(self)
  local result = self:request_async('initialize', InitializeParams(self), function(_, data)
    self:notify('initialized', {})
    self:notify('textDocument/didOpen', DidOpenTextDocumentParams())
    self:set_server_capabilities(data.capabilities)
    return data.capabilities
  end, nil)

  logger.info(
    "filetype: "..self.filetype..", server_name: "..self.server_name..", offset_encoding: "..self.offset_encoding..", client_capabilities: "..vim.tbl_tostring(self.client_capabilities)..", server_capabilities: "..vim.tbl_tostring(self.server_capabilities)
  )

  return result
end

client.set_client_capabilities = function(self, capabilities)
  self.client_capabilities = capabilities
end

client.set_server_capabilities = function(self, capabilities)
  if type(capabilities.offsetEncoding) == 'string' and
    vim.tbl_contains({'utf-8', 'utf-16', 'utf-32'}, capabilities.offsetEncoding) then
    self.offset_encoding = capabilities.offsetEncoding
  end

  self.server_capabilities = capabilities
end


client.set_buf_change_handler = function(self, bufnr)
  if not self.attached_buf_list[bufnr] then
    self.attached_buf_list[bufnr] = true
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(...) self:handle_text_document_did_change(...) end,
      utf_sizes = (client.offset_encoding == 'utf-16' or (client.offset_encoding == 'utf-32'))
    })
  end
end



client.handle_text_document_did_change = function(self, _, bufnr, changedtick, firstline, lastline, new_lastline, old_bytes, _, units)
  if self._stopped then return true end
  local uri = vim.uri_from_bufnr(bufnr)
  local version = changedtick

  update_document_version(version, uri)
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
-- @param cb (optional): If sent, will call this when it's done
--                          otherwise it'll wait til the client is done
client.request = function(self, method, params, cb, bufnr)
  if not method then
    error("No request method supplied", 2)
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local request_id = self:request_async(method, params, cb, bufnr)

  local later = os.time() + 10

  while (os.time() < later) and (self._results[request_id] == nil) do
    vim.api.nvim_command('sleep 100m')
  end

  if self._results[request_id] == nil then
    return nil
  end

  return self._results[request_id].result[1]
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
client.request_async = function(self, method, params, cb, bufnr)
  if not method then
    error("No request method supplied", 2)
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if self._stopped then
    logger.info('Client closed. ', self.server_name)
    return nil
  end

  local req = message.RequestMessage:new(self, method, params)

  if req == nil then
    return nil
  end

  -- After handling callback semantics, store it to call on reply.
  self._callbacks[req.id] = {
    cb = cb,
    method = req.method,
    bufnr = bufnr,
  }

  uv.write(self.stdin, req:data())
  local log_msg = "Send request --- "..self.filetype..", "..self.server_name.." --->: [["..req:data().."]]"
  logger.debug(log_msg)
  logger.client.debug(log_msg)

  return req.id
end

--- Send a notification to the server
-- @param method: Name of the LSP method
-- @param params: the parameters to send
client.notify = function(self, method, params)
  if self._stopped then
    logger.info('Client closed. '..self.filetype..', '..self.server_name)
    return nil
  end

  local notification = message.NotificationMessage:new(self, method, params)

  if notification == nil then
    return nil
  end

  uv.write(self.stdin, notification:data())
  local log_msg = "Send request --- "..self.filetype..", "..self.server_name.." --->: [["..notification:data().."]]"
  logger.debug(log_msg)
  logger.client.debug(log_msg)
end

--- Parse an LSP Message's header
-- @param header: The header to parse.
client._parse_header = function(header)
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

client.on_stdout = function(self, data)
  if not data then
    self:on_error(error_level.info, '_on_read error: no chunk')
    return
  end

  -- Concatenate the data that we have read previously onto the data that we just read
  self._read_data = self._read_data..data..'\n'

  while true do
    if self._read_state == read_state.init then
      self._read_length = 0
      self._read_state = read_state.header
      self._current_header = {}
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
          self:on_error(error_level.reset_state,
            string.format('_on_read error: bad header\n\t%s\n\t%s',
              line,
              vim.tbl_tostring(parsed))
            )
          return
        end

        if parsed.content_length then
          self._read_length = parsed.content_length

          if type(self._read_length) ~= 'number' then
            self:on_error(error_level.reset_state,
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

      vim.schedule(function() self:on_message(body) end)
      self._read_state = read_state.init
    end
  end
end

client.on_message = function(self, body)
  local ok, json_message = pcall(util.decode_json, body)

  if not ok then
    logger.error('Not a valid message. Calling self:on_error')
    self:on_error(
      error_level.reset_state,
      string.format('_on_read error: bad json_message (%s)', body)--self._read_data)
    )
    return
  end
  -- Handle notifications
  if json_message.method and json_message.params then
    logger.debug("Receive notification <---: [[ method: "..json_message.method..", params: "..vim.tbl_tostring(json_message.params))
    logger.server.debug("Receive notification <---: [[ method: "..json_message.method..", params: "..vim.tbl_tostring(json_message.params))
    call_callback(json_message.method, true, json_message.params, nil)

    return
  -- Handle responses
  elseif not json_message.method and json_message.id then
    local cb

    if self._callbacks[json_message.id] and self._callbacks[json_message.id].cb then
      cb = self._callbacks[json_message.id].cb
    end

    local id = json_message.id
    local method = self._callbacks[json_message.id].method
    local is_success = not json_message['error']
    local data = json_message['error'] or json_message.result or {}
    if is_success then
      local log_msg = "Receive response <--- "..self.filetype..", "..self.server_name.." ---: [[ id: "..id..", method: "..method..", result: "..vim.tbl_tostring(data)
      logger.debug(log_msg)
      logger.server.debug(log_msg)
    else
      local log_msg = "Receive response <--- "..self.filetype..", "..self.server_name.." ---: [[ id: "..id..", method: "..method..", error: "..vim.tbl_tostring(data)
      logger.error(log_msg)
      logger.server.error(log_msg)
    end

    -- If no callback is passed with request, use the registered callback.
    local result
    if cb then
      result = { cb(is_success, data) }
    else
      result = { call_callback(method, is_success, data, self.filetype) }
    end

    -- Clear the old callback
    self._callbacks[json_message.id] = nil

    self._results[json_message.id] = {
      complete = true,
      was_error = json_message['error'],
      result = result,
    }
  end
end

client.on_error = function(self, level, err_message)
  if type(level) ~= 'number' then
    print('It seems to have a not number', level)
    self:reset_state()
    return
  end

  if level <= error_level.critical then
    error('Critical error occured: ' .. vim.tbl_tostring(err_message))
  end

  if level <= error_level.reset_state then
    self:reset_state()
  end

  if level <= error_level.info then
    logger.warn(err_message)
  end
end

client.on_exit = function(data)
  logger.info('Exiting with data:', data)
end

client.reset_state = function(self)
  self._read_state = read_state.init
  self._read_data = ''
end

return client
