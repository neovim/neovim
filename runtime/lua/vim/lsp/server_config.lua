local server_config = {}
server_config.__index = server_config

server_config.servers = {}

server_config.add = function(config)
  assert(type(config) == 'table', 'argument must be a table')
  assert(config.filetype, "config must have 'filetype' key")
  assert(config.cmd, "config must have 'cmd' key")

  if config.capabilities and type(config.capabilities) ~= 'table' then
    error("config.capabilities must be a table", 2)
  end

  local filetypes

  if type(config.filetype) == 'string' then
    filetypes = { config.filetype }
  elseif type(config.filetype) == 'table' then
    filetypes = config.filetype
  else
    error('config.filetype must be a string or a list of strings', 2)
  end

  if config.offset_encoding then
    assert(type(config.offset_encoding == 'table', 'config.offset_encoding must be a string'))
    assert(
      vim.tbl_contains({'utf-8', 'utf-16', 'utf-32'}, config.offset_encoding),
      "config.offset_encoding must be one of 'utf-8', 'utf-16', or 'utf32'"
    )
  end

  for _, ft in pairs(filetypes) do
    local server_name

    if config.server_name then
      server_name = config.server_name
    else
      server_name = ft
    end

    if not server_config.servers[ft] then server_config.servers[ft] = {} end

    if not server_config.servers[ft][server_name] then
      vim.api.nvim_command(string.format("autocmd FileType %s ++once silent :lua vim.lsp.start_client('%s', '%s')", ft, ft, server_name))
      vim.api.nvim_command(string.format("autocmd VimLeavePre * :lua vim.lsp.stop_client('%s', '%s')", ft, server_name))

      local cmd_with_opts, execute_path, execute_opts
      if type(config.cmd) == 'string' then
        cmd_with_opts = vim.split(config.cmd, ' ', true)
        execute_path = table.remove(cmd_with_opts, 1)
        execute_opts = cmd_with_opts
      elseif vim.tbl_islist(config.cmd) then
        cmd_with_opts = config.cmd
        execute_path = table.remove(cmd_with_opts, 1)
        execute_opts = cmd_with_opts
      else
        error("cmd type must be string or table.")
      end

      server_config.servers[ft][server_name] = {
        server_name = server_name,
        cmd = {
          execute_path = execute_path,
          execute_opts = execute_opts,
        },
        offset_encoding = config.offset_encoding or 'utf-16',
        capabilities = config.capabilities or {},
      }
    end
  end

  return true
end

server_config.get_server = function(filetype, server_name)
  assert(filetype, 'filetype is required')
  if not server_name then server_name = filetype end

  local server = server_config.servers[filetype][server_name]

  return assert(server, 'filetype: '..filetype..' , server_name: '..server_name..' is not set. ')
end

server_config.get_server_cmd = function(filetype, server_name)
  if not server_name then server_name = filetype end
  return server_config.get_server(filetype, server_name).cmd
end

server_config.get_server_offset_encoding = function(filetype, server_name)
  if not server_name then server_name = filetype end
  return server_config.get_server(filetype, server_name).offset_encoding
end

server_config.get_capabilities = function(filetype, server_name)
  if not server_name then server_name = filetype end
  return server_config.get_server(filetype, server_name).capabilities
end

server_config.default_root_uri = function()
  return vim.uri_from_fname(vim.api.nvim_call_function('getcwd', {}))
end

server_config.get_root_uri = function(filetype, server_name)
  local capabilities = server_config.get_capabilities(filetype, server_name)

  if (capabilities or vim.tbl_isempty(capabilities)) and capabilities.rootUri then
    return capabilities.rootUri
  else
    return server_config.default_root_uri()
  end
end

return {
  add = server_config.add,
  get_server = server_config.get_server,
  get_server_cmd = server_config.get_server_cmd,
  get_server_offset_encoding = server_config.get_server_offset_encoding,
  get_capabilities = server_config.get_capabilities,
  get_root_uri = server_config.get_root_uri,
}
