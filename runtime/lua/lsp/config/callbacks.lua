local util = require('neovim.util')
local errorCodes = require('lsp.protocol').errorCodes

local configure = {}

configure.error_callback = function(name, error_message)
  local message = ''
  if error_message.message ~= nil and type(error_message.message) == 'string' then
    message = error_message.message
  elseif rawget(errorCodes, error_message.code) ~= nil then
    message = string.format('[%s] %s',
      error_message.code, errorCodes[error_message.code]
    )
  end

  vim.api.nvim_err_writeln(string.format('[LSP:%s] Error: %s', name, message))

  return message
end

configure.add_callback = function(method, cb, override_default_callback)
  local method_table
  if type(method) == 'string' then
    method_table = util.split(method, '/')
  elseif type(method) == 'table' then
    method_table = method
  else
    -- TODO: Error out here.
    return nil
  end

  local default_callbacks = require('lsp.callbacks').callbacks

  for _, key in ipairs(method_table) do
    default_callbacks = default_callbacks[key]

    if default_callbacks == nil then
      break
    end
  end

  if default_callbacks then
    if override_default_callback then
      default_callbacks[1] = cb
    else
      default_callbacks.insert(cb)
    end
  end
end

configure.disable_default_callback = function(method)
  configure.add_callback(method, nil, true)
end

return configure
