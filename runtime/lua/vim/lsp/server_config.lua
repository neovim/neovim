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

  if type(command) ~= 'table' then
    error('Command must be a table', 2)
  end

  for _, ft in pairs(filetype_list) do
    if server_config.servers[ft] == nil then
      vim.api.nvim_command(
        string.format("autocmd FileType %s ++once silent :lua require('vim.lsp').start_client('%s')", ft, ft, ft)
      )
      vim.api.nvim_command(
        string.format("autocmd VimLeavePre * :lua require('vim.lsp').stop_client('%s')", ft)
      )
      -- Add the config to our current servers
      server_config.servers[ft] = {
        command = command,
        config = config or {},
      }
    end
  end

  return true
end

server_config.get_server = function(filetype)
  if filetype == nil then
    error('filetype must be required', 2)
  end

  local server = server_config.servers[filetype]
  if server then
    return server
  else
    error('filetype, '..filetype..' , is not set language server', 2)
  end
end

server_config.get_server_command = function(filetype)
  return server_config.get_server(filetype).command
end

server_config.get_server_config = function(filetype)
  return server_config.get_server(filetype).config
end

server_config.get_server_name = function(filetype)
  local config = server_config.get_server_config(filetype)

  if vim.tbl_isempty(config) then
    return filetype
  end

  local name = config.name

  if name == nil then
    return filetype
  else
    return name
  end
end

server_config.default_root_uri = function()
  return vim.uri_from_fname(vim.api.nvim_call_function('getcwd', {}))
end

server_config.get_root_uri = function(filetype)
  local config = server_config.get_server_config(filetype)

  if (config or vim.tbl_isempty(config)) and config.rootUri then
    return config.rootUri
  else
    return server_config.default_root_uri()
  end
end

return {
  add = server_config.add,
  get_server_name = server_config.get_server_name,
  get_server_command = server_config.get_server_command,
  get_server_config = server_config.get_server_config,
  get_root_uri = server_config.get_root_uri,
}
