-- luacheck: globals vim

local json = require('lsp.json')
local util = require('neovim.util')

local Enum = require('neovim.meta').Enum

local message = require('lsp.message')
local initialize_filetype_autocmds = require('lsp.autocmds').initialize_filetype_autocmds
local lsp_doautocmd = require('lsp.autocmds').lsp_doautocmd
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


local active_jobs = {}

active_jobs.add = function(id, obj)
  active_jobs[id] = obj
end

active_jobs.remove = function(id)
  active_jobs[id] = nil
end

local mt_capabilities = {
  __index = function(self, key)
    if rawget(self, key) ~= nil then
      return rawget(self, key)
    end

    return {}
  end,
}

local client = {}
client.__index = client

client.job_stdout = function(id, data)
  if active_jobs[id] == nil then
    return
  end

  active_jobs[id]:on_stdout(data)
end

client.new = function(name, ft, cmd)
  log.debug('Starting new client: ', name, cmd)

  -- TODO: I'm a little concerned about the milliseconds after starting up the job.
  -- Not sure if we'll register ourselves faster than we will get stdin or out that we want...
  local job_id = vim.api.nvim_call_function('lsp#job#start', { cmd })

  assert(job_id)
  assert(job_id > 0)

  log.trace('Client id: ', job_id)

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
    capabilities = setmetatable({}, mt_capabilities),

    -- Results & Callback handling
    --  Callbacks must take two arguments:
    --      1 - success: true if successful, false if error
    --      2 - data: corresponding data for the message
    _callbacks = {},
    _results = {},

    -- Data fields, to be used internally
    __data__ = {},
  }, client)

  active_jobs.add(job_id, self)

  return self
end

client.initialize = function(self)
  -- Initialize autocmd for filetypes == self.ft
  --    These will create buffer local autocmds in each buffer
  initialize_filetype_autocmds(self.ft)

  local result = self:request_async('initialize', nil, function(_, data)
    self.capabilities = setmetatable(data.capabilities, mt_capabilities)
    return data.capabilities
  end)

  -- Open the document for the language server.
  -- We only send this automatically on starting the server.
  self:request_async('textDocument/didOpen')

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
client.request = function(self, method, params, cb)
  if not method then
    return nil
  end

  local request_id = self:request_async(method, params, cb)

  -- local later = os.time() + require('lsp.conf.request').timeout
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
-- It will also issue autocommands in Vim so that other plugins can do things on LSP actions.
--  For example, when sending the request: 'textDocument/hover',
--  it will send:
--      LSP/textDocument/hover/pre
--      LSP/textDocument/hover/post
--
-- @param method (string|table) : The identifier for the type of message that is being requested
-- @param params (table)        : Optional parameters to pass to override default parameters for a request
-- @param cb     (function)     : An optional function pointer to call once the request has been completed
--                                  If a string is passed, it will execute a VimL funciton of that name
--                                  To disable handling the request, pass "false"
client.request_async = function(self, method, params, cb)
  if self.job_id == nil then
    log.warn('Client does not have valid job_id: ', self.name)
    return nil
  end

  local req = message.RequestMessage:new(self, method, params)

  if req == nil then
    return nil
  end

  -- After handling callback semantics, store it to call on reply.
  if cb ~= false then
    self._callbacks[req.id] = {
      cb = cb,
      method = req.method,
    }
  end


  if should_send_message(self, req) then
    lsp_doautocmd(method, 'pre')
    vim.api.nvim_call_function('chansend', {self.job_id, req:data()})
    lsp_doautocmd(method, 'post')
  else
    log.debug(string.format('Request "%s" was cancelled with params %s', method, util.tostring(params)))
  end

  return req.id
end

--- Send a notification to the server
-- @param method: Name of the LSP method
-- @param params: the parameters to send
client.notify = function(self, method, params)
  self:request_async(method, params)
end

--- Parse an LSP Message's header
-- @param header: The header to parse.
client._parse_header = function(header)
  if type(header) ~= 'string' then
    return nil, nil
  end

  local lines = util.split(header, '\\r\\n')

  local split_lines = {}

  for _, line in pairs(lines) do
    if line ~= '' then
      local temp_lines = util.split(line, ':')
      for t_index, t_line in pairs(temp_lines) do
        temp_lines[t_index] = util.trim(t_line)
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
        self:on_error(
          error_level.reset_state,
          string.format('_on_read error: bad json_message (%s)', self._read_data)
        )
        return
      end

      self:on_message(json_message)
      self._read_state = read_state.init
    end
  end
end

client.on_message = function(self, json_message)
  log.trace('on_message: ', json_message)

  -- Handle notifications
  if json_message.method and json_message.params then
    log.debug('notification: ', json_message.method)
    call_callbacks_for_method(json_message.method, true, json_message.params)
    lsp_doautocmd(json_message.method, 'notification')

    return
  -- Handle responses
  elseif not json_message.method and json_message.id then
    local cb = self._callbacks[json_message.id].cb
    local method = self._callbacks[json_message.id].method
    local success = not json_message['error']
    local data = json_message['error'] or json_message.result or {}

    lsp_doautocmd(method, 'response')
    local result
    if cb then
      result = { cb(success, data) }
    else
      result = { call_callbacks_for_method(method, success, data) }
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

client.reset_state = function(self)
  self._read_state = read_state.init
  self._read_data = ''
end

return client
