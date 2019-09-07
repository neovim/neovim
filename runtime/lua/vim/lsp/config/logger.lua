local logger = require('vim.lsp.logger')

return {
  set_file_level = function(level)
    logger:set_file_level(level)
  end,

  set_outfile = function(file_name)
    logger:set_outfile(vim.api.nvim_call_function('expand', {file_name}))
  end,

  set_console_level = function(level)
    logger:set_console_level(level)
  end,

}
