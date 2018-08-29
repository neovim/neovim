local log = require('lsp.log')

return {
  set_file_level = function(level)
    log:set_file_level(level)
  end,

  set_outfile = function(file_name)
    log:set_outfile(vim.api.nvim_call_function('expand', {file_name}))
  end,

  set_console_level = function(level)
    log:set_console_level(level)
  end,

}
