local server_config = {}
server_config.__index = server_config

server_config.servers = {}

server_config.add = function(config)
  if type(config) ~= 'table' then
    error('argument must be a table', 2)
  end

  assert(config.filetype, "config must have 'filetype' key")
  assert(config.cmd, "config must have 'cmd' key")
  assert(config.cmd.execute_path, "config.cmd must have 'execute_path' key", 2)

  if config.server_config and type(config.server_config) ~= 'table' then
    error("config.server_config must be a table", 2)
  end

  local filetypes

  if type(config.filetype) == 'string' then
    filetypes = { config.filetype }
  elseif type(config.filetype) == 'table' then
    filetypes = config.filetype
  else
    error('config.filetype must be a string or a list of strings', 2)
  end

  for _, ft in pairs(filetypes) do
    local server_name

    if config.server_name then
      server_name = config.server_name
    else
      server_name = ft
    end

    if not server_config[ft] then
      server_config.servers[ft] = {}
    end

    if not server_config.servers[ft][server_name] then
      vim.api.nvim_command(
        string.format(
          "autocmd FileType %s ++once silent :lua require('vim.lsp').start_client('%s', '%s')", ft, ft, server_name
        )
      )

      vim.api.nvim_command(
        string.format("autocmd VimLeavePre * :lua require('vim.lsp').stop_client('%s', '%s')", ft, server_name)
      )

      server_config.servers[ft][server_name] = {
        server_name = server_name,
        cmd = config.cmd,
        server_config = config.server_config or {},
      }
    end
  end

  return true
end

server_config.get_server = function(filetype, server_name)
  assert(filetype, 'filetype is required')
  assert(server_name, 'server_name is required')

  local server = server_config.servers[filetype][server_name]

  return assert(server, 'filetype: '..filetype..' , server_name:'..server_name..' is not set')
end

server_config.get_server_cmd = function(filetype, server_name)
  if not server_name then server_name = filetype end
  return server_config.get_server(filetype, server_name).cmd
end

server_config.get_server_config = function(filetype, server_name)
  if not server_name then server_name = filetype end
  return server_config.get_server(filetype, server_name).server_config
end

server_config.default_root_uri = function()
  return vim.uri_from_fname(vim.api.nvim_call_function('getcwd', {}))
end

server_config.get_root_uri = function(filetype, server_name)
  local config = server_config.get_server_config(filetype, server_name)

  if (config or vim.tbl_isempty(config)) and config.rootUri then
    return config.rootUri
  else
    return server_config.default_root_uri()
  end
end

return {
  add = server_config.add,
  get_server = server_config.get_server,
  get_server_cmd = server_config.get_server_cmd,
  get_server_config = server_config.get_server_config,
  get_root_uri = server_config.get_root_uri,
}
