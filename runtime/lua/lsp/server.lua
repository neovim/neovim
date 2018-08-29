
local util = require('neovim.util')

local log = require('lsp.log')
local lsp_util = require('lsp.util')

local server = {}
server.__index = server

server.configured_servers = {}

server.add = function(ftype, command, additional_configuration)
  local ftype_list
  if type(ftype) == 'string' then
    ftype_list = { ftype }
  elseif type(ftype) == 'table' then
    ftype_list = ftype
  else
    log.warn('ftype must be a string or a list of strings')
  end

  if type(command) ~= 'table' and type(command) ~= 'string' then
    log.warn('Command must be a string or a list')
    return false
  end

  for _, cur_type in pairs(ftype_list) do
    if server.configured_servers[cur_type] == nil then
      vim.api.nvim_command(
        string.format([[autocmd FileType %s silent call lsp#start("%s")]], cur_type, cur_type)
      )

      -- Add the configuration to our current servers
      server.configured_servers[cur_type] = {
        command = command,
        configuration = additional_configuration or {},
      }
    end
  end

  return true
end

server.get_name = function(filetype)
  filetype = lsp_util.get_filetype(filetype)

  local ft_config = server.configured_servers[filetype]

  if util.table.is_empty(ft_config) then
    return nil
  end

  local name = ft_config.configuration.name

  if name == nil then
    return filetype
  else
    return name
  end
end

server.get_command = function(cmd, filetype)
  if cmd ~= nil then
    return cmd
  end

  filetype = lsp_util.get_filetype(filetype)

  local ft_config = server.configured_servers[filetype]

  if util.table.is_empty(ft_config) then return nil end

  return ft_config.command
end

server.default_callbacks = {

  root_uri = function()
    return 'file://' .. (vim.api.nvim_call_function('getcwd', { }) or '/tmp/')
  end,

}

server.get_callback = function(ftype, callback_name)
  local ft_config = server.configured_servers[ftype]

  local callback
  if util.table.is_empty(ft_config)
      or util.table.is_empty(ft_config.configuration)
      or util.table.is_empty(ft_config.configuration.callbacks)
      or ft_config.configuration.callback_name[callback_name] == nil then
    callback = server.default_callbacks[callback_name]
  else
    callback = ft_config.configuration.callback_name[callback_name]
  end

  if callback == nil then return nil end

  return callback
end


return server
