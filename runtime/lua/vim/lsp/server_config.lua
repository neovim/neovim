FILETYPE_SERVER_CONFIGS = {}
--local FILETYPE_SERVER_CONFIGS = {}

local function get_shell()
	return vim.api.nvim_get_option('shell')
	-- return os.getenv("SHELL") or "sh"
end

local VALID_ENCODINGS = {
	["utf-8"] = 'utf-8'; ["utf-16"] = 'utf-16'; ["utf-32"] = 'utf-32';
	["utf8"] = 'utf-8'; ["utf16"] = 'utf-16'; ["utf32"] = 'utf-32';
	UTF8 = 'utf-8'; UTF16 = 'utf-16'; UTF32 = 'utf-32';
}

local function add_config(config)
  assert(type(config) == 'table', 'argument must be a table')
  assert(config.filetype, "config must have 'filetype' key")
  assert(config.cmd, "config must have 'cmd' key")

	local capabilities = config.capabilities or {}
	assert(type(capabilities) == 'table', "config.capabilities must be a table")

  local filetypes
  if type(config.filetype) == 'string' then
    filetypes = { config.filetype }
  elseif type(config.filetype) == 'table' then
    filetypes = config.filetype
  else
    error("config.filetype must be a string or a list of strings")
  end

	local offset_encoding = VALID_ENCODINGS.UTF16
  if config.offset_encoding then
    assert(type(config.offset_encoding) == 'string', "config.offset_encoding must be a string")
		-- Ignore case here.
		offset_encoding = VALID_ENCODINGS[config.offset_encoding:lower()]
    assert(offset_encoding, "config.offset_encoding must be one of 'utf-8', 'utf-16', or 'utf32'")
  end

	-- DELETEME use ipairs for arrays
  for _, ft in ipairs(filetypes) do
    local server_name = config.server_name or ft

		if not FILETYPE_SERVER_CONFIGS[ft] then
			FILETYPE_SERVER_CONFIGS[ft] = {}
		end
		local filetype_servers = FILETYPE_SERVER_CONFIGS[ft]

    if not filetype_servers[server_name] then
			-- DELETEME using %q is less error prone.
			-- DELETEME TODO we may want to validate the filetype is correct before starting this.
			-- Start the lanuage server the first time a filetype is encountered.
      vim.api.nvim_command(string.format("autocmd FileType %s ++once silent :lua vim.lsp.start_client(%q, %q)", ft, ft, server_name))
      vim.api.nvim_command(string.format("autocmd VimLeavePre * :lua vim.lsp.stop_client(%q, %q)", ft, server_name))

      local execute_path, execute_opts
      if type(config.cmd) == 'string' then
				-- Use a shell to execute the command if it is a string.
        execute_path = get_shell()
        execute_opts = {"-c", config.cmd}
      elseif vim.tbl_islist(config.cmd) then
        local cmd_with_opts = config.cmd
        execute_path = table.remove(cmd_with_opts, 1)
        execute_opts = cmd_with_opts
      else
        error("cmd type must be string or table.")
      end

      filetype_servers[server_name] = {
        server_name = server_name,
        cmd = {
          execute_path = execute_path,
          execute_opts = execute_opts,
        },
        offset_encoding = offset_encoding,
        capabilities = capabilities,
      }
    end
  end

  return true
end

local function get_server_configuration(filetype, server_name)
	if not filetype then
		return nil, 'filetype is required'
	end

	local filetype_servers = FILETYPE_SERVER_CONFIGS[filetype]
	if not filetype_servers then
		return nil, string.format('no configuration for the filetype %q exists', filetype)
	end

	return filetype_servers[server_name or filetype]
end

local function default_root_uri()
  return vim.uri_from_fname(vim.loop.cwd())
end

local function get_root_uri(filetype, server_name)
  local capabilities = get_server_configuration(filetype, server_name)

	return (capabilities or {}).rootUri or default_root_uri()
end

return {
	add = add_config;
	default_root_uri = default_root_uri;
	get_root_uri = get_root_uri;
	get_server = get_server_configuration;
}
