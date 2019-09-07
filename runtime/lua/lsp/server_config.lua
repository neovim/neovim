local shared = require('vim.shared')

local server_config = {}
server_config.__index = server_config

server_config.servers = {}

server_config.add = function(filetype, command, config)
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
    if server_config.servers[cur_type] == nil then
      vim.api.nvim_command(
        string.format(
            [[autocmd FileType %s ++once silent :lua require('vim.lsp').start_client(nil, '%s')]],
            cur_type, cur_type, cur_type
          )
      )
      vim.api.nvim_command(
        string.format(
          [[autocmd VimLeavePre * :lua require('vim.lsp').stop_client('%s')]],
          cur_type
        )
      )
      -- Add the config to our current servers
      server_config.servers[cur_type] = {
        command = command,
        config = config or {},
      }
    end
  end

  return true
end

server_config.get_name = function(filetype)
  if filetype == nil then
    error('filetype must be required', 2)
  end

  local ft_config = server_config.servers[filetype]

  if shared.tbl_isempty(ft_config) then
    return nil
  end

  local name = ft_config.config.name

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

  local ft_config = server_config.servers[filetype]

  if ft_config == nil or shared.tbl_isempty(ft_config) then
    error(string.format('%s filetype is not set language server config', filetype), 2)
  end

  return ft_config.command
end

server_config.default_root_uri = function()
  return vim.fname_to_uri(vim.api.nvim_call_function('getcwd', {}))
end

server_config.get_root_uri = function(filetype)
  local ft_config = server_config.servers[filetype]

  if (ft_config or shared.tbl_isempty(ft_config)) and ft_config.config.root_uri then
    return ft_config.config.root_uri
  else
    return server_config.default_root_uri()
  end
end

server_config.get_callback = function(filetype, callback_name)
  local ft_config = server_config.servers[filetype]

  if (ft_config or shared.tbl_isempty(ft_config))
      or (ft_config.config.callbacks or shared.tbl_isempty(ft_config.config.callbacks))
      or (ft_config.config.callback_name or ft_config.config.callback_name[callback_name] == nil) then
    return nil
  else
    return ft_config.config.callback_name[callback_name]
  end
end


return {
  add = server_config.add,
  get_name = server_config.get_name,
  get_command = server_config.get_command,
  get_root_uri = server_config.get_root_uri,
  get_callback = server_config.get_callback,
}
