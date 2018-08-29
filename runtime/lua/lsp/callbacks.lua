-- luacheck: globals vim
-- Implements the following default callbacks:
--  textDocument/publishDiagnostics
--  notification: textDocument/didOpen
--  notification: textDocument/willSave
--  TODO: textDocument/willSaveWaitUntil
--  notification: textDocument/didSave
--  notification: textDocument/didClose
--  IN PROGRESS: textDocument/completion
--  textDocument/hover
--  TODO: textDocument/signatureHelp
--  textDocument/references
--  TODO: textDocument/documentHighlight
--  TODO: textDocument/documentSymbol
--  TODO: textDocument/formatting
--  TODO: textDocument/rangeFormatting
--  TODO: textDocument/onTypeFormatting
--  textDocument/definition
--  TODO: textDocument/codeAction
--  TODO: textDocument/codeLens
--  TODO: textDocument/documentLink
--  TODO: textDocument/rename
--
--  TODO: completionItem/resolve
--
--  TODO: codeLens/resolve
--
--  TODO: documentLink/resolve

local log = require('lsp.log')
local util = require('neovim.util')
local lsp_util = require('lsp.util')

local protocol = require('lsp.protocol')
local errorCodes = protocol.errorCodes

local handle_completion = require('lsp.handle.completion')
local handle_workspace = require('lsp.handle.workspace')

local CallbackMapping = setmetatable({}, {})
local CallbackObject = {}

local method_to_callback_object = function(method, create_new)
  if type(method) ~= 'string' then
    return nil
  end

  if CallbackMapping[method] == nil and create_new then
    CallbackMapping[method] = CallbackObject.new(method)
  end

  return CallbackMapping[method]
end


CallbackObject.__index = function(self, key)
  if CallbackObject[key] ~= nil then
    return CallbackObject[key]
  end

  return rawget(self, key)
end

CallbackObject.__call = function(self, success, data, default_only, filetype)
  if self.name ~= 'neovim/error_callback' and not success then
    method_to_callback_object('neovim/error_callback').default(self, data)
  end

  if util.table.is_empty(self.default) then
      log.trace('Request: "', self.method, '" had no registered callbacks')
    return nil
  end

  local callback_list = self:get_list_of_callbacks(default_only, filetype)
  local results = { }

  for _, cb in ipairs(callback_list) do
    local current_result = cb(self, data)

    if current_result ~= nil then
      table.insert(results, current_result)
    end
  end

  return unpack(results)
end

CallbackObject.new = function(method, default_callback, options)
  options = options or {}

  local object = setmetatable({
    method = method,
    options = setmetatable(options, {
      __index = function(_, key)
        error(string.format('Cannot get option (%s) for "%s"', key, method))
      end,

      __newindex = function(_, key, value)
        error(string.format('Cannot set option (%s) for "%s" to value [%s]', key, method, value))
      end,
    }),

    default = {},
    generic = {},
    filetype = {},
  }, CallbackObject)

  if default_callback ~= nil then
    if type(default_callback) == 'string' then
      default_callback = function(self, data)
        return vim.api.nvim_call_function(default_callback, {
          { method = self.method, options = unpack(options) },
          data
        })
      end
    end

    object:set_default_callback(default_callback)
  end

  return object
end

CallbackObject.set_default_callback = function(self, default_callback)
  self.default = { default_callback }
end

CallbackObject.add_callback = function(self, new_callback)
  table.insert(self.generic, new_callback)
end

CallbackObject.add_default_callback = function(self, new_callback)
  table.insert(self.default, new_callback)
end

CallbackObject.add_filetype_callback = function(self, new_callback, filetype)
  if self.filetype[filetype] == nil then
    self.filetype[filetype] = {}
  end

  table.insert(self.filetype[filetype], new_callback)
end

CallbackObject.get_list_of_callbacks = function(self, default_only, filetype)
  local callback_list = {}

  for _, value in ipairs(self.default) do
    table.insert(callback_list, value)
  end

  if default_only then
    return callback_list
  end

  for _, value in ipairs(self.generic) do
    table.insert(callback_list, value)
  end

  if filetype ~= nil then
    if self.filetype[filetype] == nil then
      self.filetype[filetype] = {}
    end

    for _, value in ipairs(self.filetype[filetype]) do
      table.insert(callback_list, value)
    end
  end

  return callback_list
end

-- Callback definition section
local add_default_callback = function(name, callback, options)
  CallbackMapping[name] = CallbackObject.new(name, callback, options)
end

-- 3 neovim/error_callback
add_default_callback('neovim/error_callback', function(original, error_message)
  local message = ''
  if error_message.message ~= nil and type(error_message.message) == 'string' then
    message = error_message.message
  elseif rawget(errorCodes, error_message.code) ~= nil then
    message = string.format('[%s] %s',
      error_message.code, errorCodes[error_message.code]
    )
  end

  vim.api.nvim_err_writeln(string.format('[LSP:%s] Error: %s', original.method, message))

  return
end)

-- 3 textDocument/publishDiagnostics
add_default_callback('textDocument/publishDiagnostics', function(self, data)
  local qflist = {}

  for _, diagnostic in ipairs(data.diagnostics) do
    local range = diagnostic.range
    local severity = diagnostic.severity or protocol.DiagnosticSeverity.Information

    local message_type
    if severity == protocol.DiagnosticSeverity.Error then
      message_type = 'E'
    elseif severity == protocol.DiagnosticSeverity.Warning then
      message_type = 'W'
    else
      message_type = 'I'
    end

    -- local code = diagnostic.code
    local source = diagnostic.source or 'lsp'
    local message = diagnostic.message

    table.insert(qflist, {
      lnum = range.start.line + 1,
      col = range.start.character + 1,
      text = '[' .. source .. ']' .. message,
      filename = lsp_util.get_filename(data.uri),
      ['type'] = message_type,
    })
  end

  vim.api.nvim_call_function('setqflist', {qflist, ' ', 'Language Server Diagnostics'})

  if #qflist == 0  then
    vim.api.nvim_command('cclose')
  elseif self.options.auto_quickfix_list then
    if not util.is_quickfix_open() then
      vim.api.nvim_command('copen')
      vim.api.nvim_command('wincmd p')
    end
  end

  return
end, { auto_quickfix_list = false, })

-- 3 textDocument/completion
add_default_callback('textDocument/completion', function(self, data)
  if data == nil then
    print(self)
    return
  end

  return handle_completion.getLabels(data)
end)

-- 3 textDocument/references
add_default_callback('textDocument/references', function(self, data)
  local locations = data
  local loclist = {}

  for _, loc in ipairs(locations) do
    -- TODO: URL parsing here?
    local start = loc.range.start
    local line = start.line + 1
    local character = start.character + 1

    local path = util.handle_uri(loc["uri"])
    local text = lsp_util.get_line_from_path(path, line)

    table.insert(loclist, {
        filename = path,
        lnum = line,
        col = character,
        text = text,
    })
  end

  local result = vim.api.nvim_call_function('setloclist', {0, loclist, ' ', 'Language Server textDocument/references'})

  if self.options.auto_location_list then
    if loclist ~= {} then
      if not util.is_loclist_open() then
        vim.api.nvim_command('lopen')
        vim.api.nvim_command('wincmd p')
      end
    else
      vim.api.nvim_command('lclose')
    end
  end

  return result
end, { auto_location_list = true })

-- 3 textDocument/rename
add_default_callback('textDocument/rename', function(self, data)
  if data == nil then
    print(self)
    return nil
  end

  vim.api.nvim_set_var('textDocument_rename', data)

  handle_workspace.apply_WorkspaceEdit(data)
end, { })

-- 3 textDocument/hover
add_default_callback('textDocument/hover', function(self, data)
  log.trace('textDocument/hover', data, self)

  if data.range ~= nil then
    -- Doesn't handle multi-line highlights
    local _ = vim.api.nvim_buf_add_highlight(0,
      -1,
      'Error',
      data.range.start.line,
      data.range.start.character,
      data.range['end'].character
    )
  end

  -- TODO: Use floating windows when they become available
  local long_string = ''
  if data.contents ~= nil then
    if util.is_array(data.contents) == true then
      for _, item in ipairs(data.contents) do
        local value
        if type(item) == 'table' then
          value = item.value
        elseif item == nil then
          value = ''
        else
          value = item
        end

        long_string = long_string .. value .. "\n"
      end

      log.debug('Hover: ', long_string)
    elseif type(data.contents) == 'table' then
      long_string = long_string .. (data.contents.value or '')
    else
      long_string = data.contents
    end

    if long_string == '' then
      long_string = 'LSP: No information available'
    end

    vim.api.nvim_out_write(long_string .. '\n')
    return long_string
  end
end)

-- 3 textDocument/definition
add_default_callback('textDocument/definition', function(self, data)
  log.trace('callback:textDocument/definiton', data, self)

  if data == nil or data == {} then
    log.info('No definition found')
    return nil
  end

  local current_file = vim.api.nvim_call_function('expand', {'%'})

  -- We can sometimes get a list of locations,
  -- so set the first value as the only value we want to handle
  if data[1] ~= nil then
    data = data[1]
  end

  if data.uri == nil then
    vim.api.nvim_err_writeln('[LSP] Could not find a valid definition')
    return
  end

  if type(data.uri) ~= 'string' then
    vim.api.nvim_err_writeln('Invalid uri')
    return
  end

  local data_file = lsp_util.get_filename(data.uri)

  if data_file ~= lsp_util.get_uri(current_file) then
    vim.api.nvim_command('silent edit ' .. data_file)
  end

  vim.api.nvim_command(
    string.format('normal! %sG%s|'
      , data.range.start.line + 1
      , data.range.start.character + 1
    )
  )

  return true
end)


-- 2 window
-- 3 window/showMessage
add_default_callback('window/showMessage', function(self, data)
  if data == nil or type(data) ~= 'table' then
    print(self)
    return nil
  end

  local message_type = data['type']
  local message = data['message']

  if message_type == protocol.MessageType.Error then
    -- Might want to not use err_writeln,
    -- but displaying a message with red highlights or something
    vim.api.nvim_err_writeln(message)
  else
    vim.api.nvim_out_write(message .. "\n")
  end

  return data
end, { })

-- 3 window/showMessageRequest
-- TODO: Should probably find some unique way to handle requests from server -> client
add_default_callback('window/showMessageRequest', function(self, data)
  if data == nil or type(data) ~= 'table' then
    print(self)
    return nil
  end

  local message_type = data['type']
  local message = data['message']
  local actions = data['actions']

  print(message_type, message, actions)
end, { })

-- 2 workspace
-- 3 workspace/symbol
-- TODO: Find a server that supports this request, and also figure out workspaces :)
-- add_default_callback('workspace/symbol', function(self, data)
--   print(self, data)
-- end, { })


--- Get a list of callbacks for a particular circumstance
-- @param method                (required) The name of the method to get the callbacks for
-- @param callback_parameter    (optional) If passed, will only execute this callback
-- @param default_only          (optional) If passed, will only execute the default. Overridden by callback_parameter
-- @param filetype              (optional) If passed, will execute filetype specific callbacks as well
local get_list_of_callbacks = function(method, callback_parameter, default_only, filetype)
  -- If they haven't passed a callback parameter, then fill with a default
  local cb = nil
  if callback_parameter == nil then
    cb = method_to_callback_object(method)
  elseif type(callback_parameter) == 'table' then
    cb = CallbackObject.new(method)

    for _, value in pairs(callback_parameter) do
      cb:add_default_callback(value)
    end
  elseif type(callback_parameter) == 'function' then
    cb = CallbackObject.new(method, callback_parameter)
  elseif type(callback_parameter) == 'string' then
    -- When we pass a string, that's a VimL function that we want to call
    -- so we create a callback function to run it.
    --
    --      See: |lsp#request()|
    cb = CallbackObject.new(method, callback_parameter)
  end

  if cb == nil then return {} end

  return cb:get_list_of_callbacks(default_only, filetype)
end

local call_callbacks = function(callback_list, success, params)
  local results = {}

  for key, callback in ipairs(callback_list) do
    results[key] = callback(success, params)
  end

  return unpack(results)
end

local call_callbacks_for_method = function(method, success, data, default_only, filetype)
  local cb = method_to_callback_object(method, false)

  if cb == nil then
    log.debug('Unsupported method:', method)
    return
  end

  return cb(success, data, default_only, filetype)
end

local set_default_callback = function(method, new_default_callback)
  method_to_callback_object(method, true):set_default_callback(new_default_callback)
end

local add_callback = function(method, new_callback)
  method_to_callback_object(method, true):add_callback(new_callback)
end

local add_filetype_callback = function(method, new_callback, filetype)
  method_to_callback_object(method, true):add_filetype_callback(new_callback, filetype)
end

local set_option = function(method, option, value)
  method_to_callback_object(method).options[option] = value
end

return {
  -- Calling configured callback objects
  call_callbacks_for_method = call_callbacks_for_method,

  -- Configuring callback objects
  set_default_callback = set_default_callback,
  add_callback = add_callback,
  add_filetype_callback = add_filetype_callback,
  set_option = set_option,

  -- Generally private functions
  _callback_mapping = CallbackMapping,
  _callback_object = CallbackObject,
  _get_list_of_callbacks = get_list_of_callbacks,
  _call_callbacks = call_callbacks,
}
