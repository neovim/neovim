local shared = require('vim.shared')

local lsp_util = require('lsp.util')

local server = {}
server.__index = server

server.configured_servers = {}

server.add = function(filetype, command, additional_configuration)
  local filetype_list
  if type(filetype) == 'string' then
    filetype_list = { filetype }
  elseif type(filetype) == 'table' then
    filetype_list = filetype
  else
    error('filetype must be a string or a list of strings', 2)
  end

  if type(command) ~= 'table' and type(command) ~= 'string' then
    error('Command must be a string or a list', 2)
  end

  for _, cur_type in pairs(filetype_list) do
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

  if shared.tbl_isempty(ft_config) then
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

  if shared.tbl_isempty(ft_config) then return nil end

  return ft_config.command
end

server.default_callbacks = {
  root_uri = function()
    return 'file://' .. (vim.api.nvim_call_function('getcwd', { }) or '/tmp/')
  end,
}

server.get_callback = function(filetype, callback_name)
  local ft_config = server.configured_servers[filetype]

  local callback
  if shared.tbl_isempty(ft_config)
      or shared.tbl_isempty(ft_config.configuration)
      or shared.tbl_isempty(ft_config.configuration.callbacks)
      or ft_config.configuration.callback_name[callback_name] == nil then
    callback = server.default_callbacks[callback_name]
  else
    callback = ft_config.configuration.callback_name[callback_name]
  end

  if callback == nil then return nil end

  return callback
end


return server
