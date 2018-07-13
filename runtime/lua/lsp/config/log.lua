local neovim_log = require('neovim.log')
local log = require('lsp.log')

return {
  set_file_level = function(level)
    neovim_log.set_file_level(log, level)
  end,

  set_outfile = function(file_name)
    neovim_log.set_outfile(log, vim.api.nvim_call_function('expand', {file_name}))
  end,

  set_console_level = function(level)
    neovim_log.set_console_level(log, level)
  end,


}
