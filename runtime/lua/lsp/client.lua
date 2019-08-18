local json = require('lsp.json')
local util = require('nvim.util')
local shared = require('vim.shared')

local Enum = require('nvim.meta').Enum
local EmptyDictionary = require('nvim.meta').EmptyDictionary

local message = require('lsp.message')
local call_callbacks_for_method = require('lsp.callbacks').call_callbacks_for_method
local should_send_message = require('lsp.checks').should_send

local log = require('lsp.log')

local read_state = Enum:new({
  init = 0,
  header = 1,
  body = 2,
})

local error_level = Enum:new({
  critical = 0,
  reset_state = 1,
  info = 2,
})

local ActiveJobs = {}

ActiveJobs.add = function(job_id, obj)
  ActiveJobs[job_id] = obj
end

ActiveJobs.remove = function(job_id)
  ActiveJobs[job_id] = nil
end

local client = {}
client.__index = client

client.job_stdout = function(job_id, data)
  if ActiveJobs[job_id] == nil then
    return
  end

  ActiveJobs[job_id]:on_stdout(data)
end

client.job_exit = function(job_id, data)
  if ActiveJobs[job_id] == nil then
    return
  end

  ActiveJobs[job_id]:on_exit(data)
end

client.start_job = function(cmd)
  local job_id = vim.api.nvim_call_function('jobstart', {
      cmd, {
        on_stdout = 'lsp#_on_event',
        on_stderr = 'lsp#_on_event',
        on_exit = 'lsp#_on_event',
      }
    })
  if job_id == 0 then
    error('Failed to starting language server job')
  elseif job_id == -1 then
    error(string.format('Failed to starting language server job. "%s" is not executable', cmd))
  end

  return job_id
end

client.new = function(name, ft, cmd)
  log.debug('Starting new client: ', name, cmd)

  local job_id = client.start_job(cmd)

  assert(job_id)
  assert(job_id > 0)

  log.debug('Client id: ', job_id)

  local self = setmetatable({
    job_id = job_id,

    name = name,
    ft = ft,
    cmd = cmd,

    -- State for handling messages
    _read_state = read_state.init,
    _read_data = '',
    _current_header = {},

    -- Capabilities sent by server
    capabilities = EmptyDictionary:new(),

    -- Results & Callback handling
    --  Callbacks must take two arguments:
    --      1 - success: true if successful, false if error
    --      2 - data: corresponding data for the message
    _callbacks = {},
    _results = {},

    -- Data fields, to be used internally
    __data__ = {},
  }, client)

  ActiveJobs.add(job_id, self)

  return self
end

client.initialize = function(self)
  local result = self:request_async('initialize', nil, function(_, data)
    self:notify('initialized')
    self:notify('textDocument/didOpen')
    self.capabilities =  EmptyDictionary:new(data.capabilities)
    return data.capabilities
  end, nil)

  return result
end

client.close = function(self)
  if self._closed then
    return
  end

  self._closed = true
  vim.api.nvim_call_function('jobclose', {self.job_id})
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

  -- local later = os.time() + require('lsp.conf').request.timeout
  local later = os.time() + 10

  while (os.time() < later) and (self._results[request_id]  == nil) do
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

  if self.job_id == nil then
    log.warn('Client does not have valid job_id: ', self.name)
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

  if should_send_message(self, req) then
    log.debug("Send request --->: [["..req:data().."]]")
    log.client.debug("Send request --->: [["..req:data().."]]")
    vim.api.nvim_call_function('chansend', {self.job_id, req:data()})
  else
    log.debug(string.format('Request "%s" was cancelled with params %s', method, util.tostring(params)))
  end

  return req.id
end

--- Send a notification to the server
-- @param method: Name of the LSP method
-- @param params: the parameters to send
client.notify = function(self, method, params)
  if self.job_id == nil then
    log.warn('Client does not have valid job_id: ', self.name)
    return nil
  end

  local notification = message.NotificationMessage:new(self, method, params)

  if notification == nil then
    return nil
  end

  if should_send_message(self, notification) then
    log.debug("Send notification --->: [["..notification:data().."]]")
    log.client.debug("Send notification --->: [["..notification:data().."]]")
    vim.api.nvim_call_function('chansend', {self.job_id, notification:data()})
  else
    log.debug(string.format('Notification "%s" was cancelled with params %s', method, util.tostring(params)))
  end
end

--- Parse an LSP Message's header
-- @param header: The header to parse.
client._parse_header = function(header)
  if type(header) ~= 'string' then
    return nil, nil
  end

  local lines = shared.split(header, '\\r\\n', true)

  local split_lines = {}

  for _, line in pairs(lines) do
    if line ~= '' then
      local temp_lines = shared.split(line, ':', true)
      for t_index, t_line in pairs(temp_lines) do
        temp_lines[t_index] = shared.trim(t_line)
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
  self._read_data = self._read_data .. table.concat(data, '\n')
  --self:on_error(error_level.info,'[['..self._read_data..']]')

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
              util.tostring(parsed))
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
      -- TODO: Figure out why he uses a null value here
      local body = self._read_data:sub(1, self._read_length)
      self._read_data = self._read_data:sub(self._read_length + 1)

      local ok, json_message = pcall(json.decode, body)

      if not ok then
        log.info('Not a valid message. Calling self:on_error')
        -- TODO(KillTheMule): Is self.__read_data the thing to print here?
        self:on_error(
          error_level.reset_state,
          string.format('_on_read error: bad json_message (%s)', body)--self._read_data)
        )
        return
      end

      self:on_message(json_message)
      self._read_state = read_state.init
    end
  end
end

client.on_message = function(self, json_message)
  -- Handle notifications
  if json_message.method and json_message.params then
    log.debug("Receive notification <---: [[ method: "..json_message.method..", params: "..util.tostring(json_message.params))
    log.server.debug("Receive notification <---: [[ method: "..json_message.method..", params: "..util.tostring(json_message.params))
    call_callbacks_for_method(json_message.method, true, json_message.params, nil)

    return
  -- Handle responses
  elseif not json_message.method and json_message.id then
    local cb

    if self._callbacks[json_message.id] and self._callbacks[json_message.id].cb then
      cb = self._callbacks[json_message.id].cb
    end

    local id = json_message.id
    local method = self._callbacks[json_message.id].method
    local success = not json_message['error']
    local data = json_message['error'] or json_message.result or {}
    if success then
      log.debug("Receive response <---: [[ id: "..id..", method: "..method..", result: "..util.tostring(data))
      log.server.debug("Receive response <---: [[ id: "..id..", method: "..method..", result: "..util.tostring(data))
    else
      log.debug("Receive response <---: [[ id: "..id..", method: "..method..", error: "..util.tostring(data))
      log.server.debug("Receive response <---: [[ id: "..id..", method: "..method..", error: "..util.tostring(data))
    end

    local result
    if cb then
      result = { cb(success, data) }
    else
      result = { call_callbacks_for_method(method, success, data, nil) }
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
    print('we seem to have a not number', level)
    self:reset_state()
    return
  end

  if level <= error_level.critical then
    error('Critical error occured: ' .. util.tostring(err_message))
  end

  if level <= error_level.reset_state then
    self:reset_state()
  end

  if level <= error_level.info then
    log.warn(err_message)
  end
end

client.on_exit = function(self, data)
  log.info('Exiting job id: ', self.job_id, 'with data:', data)

  ActiveJobs.remove(self.job_id)
end

client.reset_state = function(self)
  self._read_state = read_state.init
  self._read_data = ''
end

return client
