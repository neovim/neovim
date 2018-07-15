local autocmds = require('lsp.autocmds')

local config = {}

config.enable_event = function(request_name, autocmd_event, autocmd_pattern)
  autocmds.get_autocmd_event_name(autocmd_event, autocmd_pattern)
  autocmds.nvim_enable_autocmd(request_name, autocmd_event)
end

config.disable_event = function(request_name, asdf)
  print(request_name, asdf)
end

return config
