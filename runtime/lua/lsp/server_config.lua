local shared = require('vim.shared')

local server_config = {}
server_config.__index = server_config

server_config.configured_servers = {}

server_config.add = function(filetype, command, additional_configuration)
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
    if server_config.configured_servers[cur_type] == nil then
      vim.api.nvim_command(
        string.format(
            [[autocmd FileType %s silent :lua require('lsp.api').plugin.start_client(nil, %s)]],
            cur_type, cur_type, cur_type
          )
      )

      -- Add the configuration to our current servers
      server_config.configured_servers[cur_type] = {
        command = command,
        configuration = additional_configuration or {},
      }
    end
  end

  return true
end

server_config.get_name = function(filetype)
  if filetype == nil then
    error('filetype must be required', 2)
  end

  local ft_config = server_config.configured_servers[filetype]

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

server_config.get_command = function(filetype)
  if filetype == nil then
    error('filetype must be required', 2)
  end

  local ft_config = server_config.configured_servers[filetype]

  if ft_config == nil or shared.tbl_isempty(ft_config) then
    error(string.format('%s filetype is not set language server config', filetype), 2)
  end

  return ft_config.command
end

server_config.default_callbacks = {
  root_uri = function()
    return 'file://' .. (vim.api.nvim_call_function('getcwd', { }) or '/tmp/')
  end,
}

server_config.get_callback = function(filetype, callback_name)
  local ft_config = server_config.configured_servers[filetype]

  local callback
  if (ft_config or shared.tbl_isempty(ft_config))
      or (ft_config.configuration or shared.tbl_isempty(ft_config.configuration))
      or (ft_config.configuration.callbacks or shared.tbl_isempty(ft_config.configuration.callbacks))
      or (ft_config.configuration.callback_name or ft_config.configuration.callback_name[callback_name] == nil) then
    callback = server_config.default_callbacks[callback_name]
  else
    callback = ft_config.configuration.callback_name[callback_name]
  end

  return callback
end


return {
  add = server_config.add,
  get_name = server_config.get_name,
  get_command = server_config.get_command,
  get_callback = server_config.get_callback,
}
