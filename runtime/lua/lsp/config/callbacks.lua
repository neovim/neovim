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

return configure
