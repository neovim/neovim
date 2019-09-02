-- Logger for language client plugin.
-- You can set log levels, debug, info, warn, error and none, like this.
-- let g:language_client_log_level = 'debug'
-- Default value is 'none'.

local nvim_log = require('nvim.log')

local log = nvim_log:new('LSP')
log.client = nvim_log:new('LSP')
log.server = nvim_log:new('LSP')

local log_level = 'none'

if (vim.api.nvim_call_function('exists', {'g:language_client_log_level'}) == 1) then
  log_level = vim.api.nvim_get_var('language_client_log_level')
end

log:set_log_level(log_level)
log:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/all.log')

log.client:set_log_level(log_level)
log.client:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/client.log')

log.server:set_log_level(log_level)
log.server:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/server.log')

return log
