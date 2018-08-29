-- TODO(tjdevries): Change over logging within LSP to this.
-- TODO(tjdevries): Create a better logging interface, so if other plugins want to use this, they can.
--  Maybe even make a few vimL wrapper functions.
--  Maybe make a remote function

local neovim_log = require('neovim.log')
local log = neovim_log:new('LSP')

log:set_console_level('warn')
log:set_file_level('bad_level')
log:set_outfile(vim.api.nvim_call_function('expand', {'~'}) .. '/test_logfile.txt')

return log

