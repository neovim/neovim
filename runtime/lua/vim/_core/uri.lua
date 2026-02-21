local M = {}

local function uri_decode(str)
  return (
    str:gsub('%%([a-fA-F0-9][a-fA-F0-9])', function(hex)
      return string.char(vim._assert_integer(hex, 16))
    end)
  )
end

local function connect(server)
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', server, { rpc = true })
  if ok and chan and chan > 0 then
    return chan
  end
  return 0
end

local function find_server(server)
  if server then
    return connect(server)
  end

  local current_server = vim.v.servername
  local runtime_dir = (vim.env.XDG_RUNTIME_DIR or ('/run/user/' .. vim.fn.getuid())) --[[@as string]]
  local sockets = vim.fn.glob(runtime_dir .. '/nvim.*.0', false, true) --[[@as string[] ]]
  for _, socket in ipairs(sockets) do
    if socket ~= current_server then
      local chan = connect(socket)
      if chan > 0 then
        return chan
      end
    end
  end

  return 0
end

---@param uri string
---@return vim.uri.NvimUri? parsed
---@return string? err
function M.parse(uri)
  if not vim.startswith(uri, 'nvim://') then
    return nil, 'URI scheme must be "nvim"'
  end

  local action, query = uri:match('^nvim://([^?]+)%?(.*)$')
  if not action or not query then
    return nil, 'Unsupported nvim:// URI format. Expected: nvim://{action}?file=...'
  end

  if action ~= 'open' then
    return nil, 'Unsupported action: ' .. action .. '. Supported actions: open'
  end

  local params = {} --- @type table<string, string>
  --- @diagnostic disable-next-line: no-unknown
  for key, value in query:gmatch('([^&=]+)=([^&]*)') do
    params[key] = uri_decode(value)
  end

  if not params.file or params.file == '' then
    return nil, 'Missing required "file" parameter'
  end

  return {
    action = action,
    file = params.file,
    line = tonumber(params.line),
    column = tonumber(params.column),
    server = params.server,
  }
end

---@param uri string
---@return boolean? remote
---@return string? err
function M.handle(uri)
  local parsed, err = M.parse(uri)
  if not parsed then
    return nil, ('Failed to parse URI %q: %s'):format(uri, err or 'unknown error')
  end

  local opts = {
    line = parsed.line,
    column = parsed.column,
  }

  local rcid = find_server(parsed.server)
  if rcid ~= 0 then
    vim.fn.rpcrequest(
      rcid,
      'nvim_exec_lua',
      "return require('vim.ui').edit(...)",
      { parsed.file, opts }
    )
    vim.fn.chanclose(rcid)
    return true
  end

  vim.defer_fn(function()
    require('vim.ui').edit(parsed.file, opts)
  end, 0)
  return false
end

function M.handle_startup_uris()
  local uris = {} --- @type string[]
  for _, arg in ipairs(vim.v.argf) do
    if vim.startswith(arg, 'nvim://') then
      table.insert(uris, arg)
    end
  end

  if #uris == 0 then
    return
  end

  local all_remote = true
  for _, uri in ipairs(uris) do
    local remote, err = M.handle(uri)
    if err then
      io.stderr:write(err .. '\n')
      os.exit(2)
    end
    all_remote = all_remote and remote == true
  end

  if all_remote and vim.fn.argc() == 0 then
    os.exit(0)
  end
end

return M
