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

local mt_callback_object = {
  __call = function(self, ...)
    if util.table.is_empty(self.default) then
      return nil
    end

    return self.default[1](...)
  end,

  __index = function(self, key)
    if rawget(self, key) ~= nil then
      return rawget(self, key)
    end

    if key == 'generic' or key == 'default' or key =='filetype_specif' then
      return {}
    end

    return nil
  end,
}

local callback_default = function(f)
  return setmetatable({
    default = { f },
    generic = {},
    filetype_specific = {},
  }, mt_callback_object)
end

local CallbackMapping = setmetatable({
  neovim = {
    error_callback = callback_default(function(name, error_message)
      local message = ''
      if error_message.message ~= nil and type(error_message.message) == 'string' then
        message = error_message.message
      elseif rawget(errorCodes, error_message.code) ~= nil then
        message = string.format('[%s] %s',
          error_message.code, errorCodes[error_message.code]
        )
      end

      vim.api.nvim_err_writeln(string.format('[LSP:%s] Error: %s', name, message))

      return
    end),
  },

  textDocument = {

  }
}, {
})

local get_method_table = function(method)
  local method_table = nil
  if type(method) == 'string' then
    method_table = util.split(method, '/')
  elseif type(method) == 'table' then
    method_table = method
  end

  return method_table
end

local method_to_callback_object = function(method, create_new)
  local method_table = get_method_table(method)

  if method_table == nil then
    return nil
  end

  local callback_object = CallbackMapping
  local previous_callback_object
  for _, key in ipairs(method_table) do
    previous_callback_object = callback_object
    callback_object = callback_object[key]

    if callback_object == nil then
      if not create_new then
        break
      else
        previous_callback_object[key] = {}
      end
    end
  end

  if type(callback_object) ~= 'table' then
    return nil
  end

  return callback_object
end

local set_default_callback = function(method, new_default_callback)
  local callback_object = method_to_callback_object(method)

  if callback_object == nil then
    return nil
  end

  callback_object.default = new_default_callback
end

local add_callback = function(method, new_callback, filetype)
  local callback_object = method_to_callback_object(method, true)

  local callback_list_location
  if filetype == nil then
    callback_list_location = callback_object.generic
  else
    if callback_object.filetype_specific[filetype] == nil then
      callback_object.filetype_specific[filetype] = {}
    end

    callback_list_location = callback_object.filetype_specific[filetype]
  end

  callback_list_location.insert(new_callback)
end

--------------------------------------------------------------------------------
-- Callback definition section
--------------------------------------------------------------------------------

CallbackMapping.textDocument.publishDiagnostics = callback_default(function(success, data)
  if not success then
    CallbackMapping.neovim.error_callback('textDocument/publishDiagnostics', data)
    return nil
  end

  local loclist = {}

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

    table.insert(loclist, {
      lnum = range.start.line + 1,
      col = range.start.character + 1,
      text = '[' .. source .. ']' .. message,
      filename = lsp_util.get_filename(data.uri),
      ['type'] = message_type,
    })
  end

  local result = vim.api.nvim_call_function('setloclist', {0, loclist})

  -- if loclist ~= {} and not util.is_loclist_open() then
  --   vim.api.nvim_command('lopen')
  --   vim.api.nvim_command('wincmd p')
  -- end

  return result
end)

CallbackMapping.textDocument.completion = callback_default(function(success, data)
  if not success then
    CallbackMapping.neovim.error_callback('textDocument/completion', data)
    return nil
  end

  if data == nil then
    return
  end

  return handle_completion.getLabels(data)
end)

CallbackMapping.textDocument.references = callback_default(function(success, data)
  if not success then
    CallbackMapping.neovim.error_callback('textDocument/references', data)
    return nil
  end

  local locations = data
  local loclist = {}

  for _, loc in ipairs(locations) do
    -- TODO: URL parsing here?
    local path = util.handle_uri(loc["uri"])
    local start = loc.range.start
    local line = start.line + 1
    local character = start.character + 1

    local text = util.get_file_line(path, line)

    table.insert(loclist, {
        filename = path,
        lnum = line,
        col = character,
        text = text,
    })
  end

  local result = vim.api.nvim_call_function('setloclist', {0, loclist})

  if loclist ~= {} and not util.is_loclist_open() then
    vim.api.nvim_command('lopen')
  else
    vim.api.nvim_command('lclose')
  end

  return result
end)

CallbackMapping.textDocument.hover = callback_default(function(success, data)
  log.trace('textDocument/hover', data)

  if not success then
    CallbackMapping.neovim.error_callback('textDocument/hover', data)
    return nil
  end

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
      -- vim.api.nvim_out_write(long_string)
    elseif type(data.contents) == 'table' then
      long_string = long_string .. data.contents.value
    else
      long_string = data.contents
    end

    vim.api.nvim_command('echon "' .. long_string .. '"')
    return long_string
  end

end)

CallbackMapping.textDocument.definition = callback_default(function(success, data)
  log.trace('callback:textDocument/definiton', data)

  if not success then
    CallbackMapping.neovim.error_callback('textDocument/definition', data)
    return nil
  end

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

--- Get a list of callbacks for a particular circumstance
-- @param method                (required) The name of the method to get the callbacks for
-- @param callback_parameter    (optional) If passed, will only execute this callback
-- @param filetype              (optional) If passed, will execute filetype specific callbacks as well
-- @param default_only          (optional) If passed, will only execute the default. Overridden by callback_parameter
local get_list_of_callbacks = function(method, callback_parameter, filetype, default_only)
  -- If they haven't passed a callback parameter, then fill with a default
  local callback_map
  if callback_parameter == nil then
    callback_map = method_to_callback_object(method)
  elseif type(callback_parameter) == 'table' then
    default_only = true
    callback_map = { default = callback_parameter }
  elseif type(callback_parameter) == 'function' then
    default_only = true
    callback_map = callback_default(callback_parameter)
  elseif type(callback_parameter) == 'string' then
    -- When we pass a string, that's a VimL function that we want to call
    -- so we create a callback function to run it.
    --
    --      See: |lsp#request()|
    default_only = true
    callback_map = {
      default = {
        function(success, data)
          return vim.api.nvim_call_function(callback_parameter, {success, data})
        end
      }
    }
  end

  if callback_map == nil then return {} end

  local callback_resulting_list = {}

  -- Always add the default map, since that should always run.
  util.table.extend(callback_resulting_list, callback_map.default)

  -- When specified to run the default callback only, quit here
  if not default_only then
    if filetype ~= nil
        and type(callback_resulting_list.filetype) == 'table'
        and callback_resulting_list.filetype[filetype] ~= nil then
      util.table.extend(callback_resulting_list, callback_resulting_list.filetype[filetype])
    end

    if not util.table.is_empty(callback_map.generic) then
      util.table.extend(callback_resulting_list, callback_map.generic)
    end
  end

  log.trace(method, ': callback_result_list -> ', util.tostring(callback_resulting_list))
  return callback_resulting_list
end

local call_callbacks = function(callback_list, success, params)
  local results = {}

  for key, callback in ipairs(callback_list) do
    results[key] = callback(success, params)
  end

  return results
end

return {
  callbacks = CallbackMapping,
  get_list_of_callbacks = get_list_of_callbacks,
  call_callbacks = call_callbacks,
  set_default_callback = set_default_callback,
  add_callback = add_callback,
}
