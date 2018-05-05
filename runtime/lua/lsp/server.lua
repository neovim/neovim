
local log = require('lsp.log')

local server = {}
server.__index = server

server.configured_servers = {}

server.add = function(ftype, command, additional_configuration)
  local ftype_list = {}
  if type(ftype) == type("") then
    ftype_list = { ftype }
  else if type(ftype) == type({}) then
    ftype_list = ftype
  else
    log.warn('ftype must be a string or a list of strings')
  end

  if type(command) ~= type({}) and type(command) ~= type("") then
    log.warn('Command must be a string or a list')
    return false
  end

  if additional_configuration.root_uri == nil then
    additional_configuration.root_uri = 'file:///tmp/'
  end

  for i, cur_type in pairs(ftype_list) do
    if server.configured_servers[cur_type] == nil then
      vim.api.nvim_command(
        string.format([[autocmd FileType %s silent call lsp#start("%s")]], cur_type)
      )

      -- Add the configuration to our current servers
      server.configured_servers[cur_type] = {
        command = command,
        configuration = additional_configuration
      }
    end
  end

  return true
end

return server
