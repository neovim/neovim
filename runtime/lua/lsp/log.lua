-- TODO(tjdevries): Change over logging within LSP to this.
-- TODO(tjdevries): Create a better logging interface, so if other plugins want to use this, they can.
--  Maybe even make a few vimL wrapper functions.
--  Maybe make a remote function
local nvim_log = require('nvim.log')

local log = nvim_log:new('LSP')
log.client = nvim_log:new('LSP')
log.server = nvim_log:new('LSP')

log:set_log_level('debug')
log:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/full.log')

log.client:set_log_level('debug')
log.client:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/language_client.log')

log.server:set_log_level('debug')
log.server:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/language_server.log')

return log
