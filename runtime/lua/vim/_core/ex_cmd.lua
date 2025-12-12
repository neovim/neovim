local lsp = vim.lsp

local M = {}

--- @param filter? vim.lsp.get_clients.Filter
--- @return string[]
local function get_client_names(filter)
  return vim
    .iter(lsp.get_clients(filter))
    :map(function(client)
      return client.name
    end)
    :filter(function(name)
      return vim.lsp.config[name] ~= nil
    end)
    :totable()
end

--- @return string[]
local function get_config_names()
  local config_names = vim
    .iter(vim.api.nvim_get_runtime_file('lsp/*.lua', true))
    --- @param path string
    :map(function(path)
      local file_name = path:match('[^/]*.lua$')
      return file_name:sub(0, #file_name - 4)
    end)
    :totable()

  --- @diagnostic disable-next-line
  vim.list_extend(config_names, vim.tbl_keys(vim.lsp.config._configs))
  return vim.list.unique(config_names)
end

--- @return string[]
local function get_enabled_config_names()
  return vim
    .iter(get_config_names())
    --- @param name string
    :filter(function(name)
      return vim.lsp.is_enabled(name)
    end)
    :totable()
end

local complete_args = {
  enable = get_config_names,
  disable = get_enabled_config_names,
  restart = get_client_names,
  stop = get_client_names,
}

local function ex_lsp_enable(config_names)
  -- Default to enabling all clients matching the filetype of the current buffer.
  if #config_names == 0 then
    local filetype = vim.bo.filetype
    for _, name in ipairs(get_config_names()) do
      local filetypes = vim.lsp.config[name].filetypes
      if filetypes and vim.tbl_contains(filetypes, filetype) then
        table.insert(config_names, name)
      end
    end
  end

  vim.lsp.enable(config_names)
end

--- @param config_names string[]
local function ex_lsp_disable(config_names)
  -- Default to disabling all clients attached to the current buffer.
  if #config_names == 0 then
    config_names = get_client_names { bufnr = vim.api.nvim_get_current_buf() }
  end

  for _, name in ipairs(config_names) do
    if vim.lsp.config[name] == nil then
      vim.notify(("Invalid server name '%s'"):format(name))
    else
      vim.lsp.enable(name, false)
    end
  end
end

--- @param client_names string[]
local function ex_lsp_restart(client_names)
  -- Default to restarting all active clients.
  if #client_names == 0 then
    client_names = get_client_names()
  end

  for _, name in ipairs(client_names) do
    if vim.lsp.config[name] == nil then
      vim.notify(("Invalid server name '%s'"):format(name))
    else
      vim.lsp.enable(name, false)
    end
  end

  local timer = assert(vim.uv.new_timer())
  timer:start(500, 0, function()
    for _, name in ipairs(client_names) do
      vim.schedule_wrap(function(x)
        vim.lsp.enable(x)
      end)(name)
    end
  end)
end

--- @param client_names string[]
local function ex_lsp_stop(client_names)
  --- @type vim.lsp.Client[]
  local clients
  -- Default to stopping all active clients attached to the current buffer.
  if #client_names == 0 then
    clients = lsp.get_clients { bufnr = vim.api.nvim_get_current_buf() }
  else
    clients = vim
      .iter(client_names)
      :map(function(name)
        return lsp.get_clients { name = name }
      end)
      :flatten()
      :totable()
  end

  for _, client in ipairs(clients) do
    client:stop(client.exit_timeout)
  end
end

local actions = {
  enable = ex_lsp_enable,
  disable = ex_lsp_disable,
  restart = ex_lsp_restart,
  stop = ex_lsp_stop,
}

local available_subcmds = vim.tbl_keys(actions)

--- Use for `:lsp {subcmd} {name}?` command
--- @param args string
M.lsp = function(args)
  local fargs = vim.api.nvim_parse_cmd('lsp ' .. args, {}).args
  if not fargs then
    return
  end
  local subcmd = fargs[1]
  if not vim.list_contains(available_subcmds, subcmd) then
    vim.notify(("Invalid subcommand '%s'"):format(subcmd), vim.log.levels.ERROR)
    return
  end

  local clients = { unpack(fargs, 2) }

  actions[subcmd](clients)
end

--- Completion logic for `:lsp` command
--- @param line string content of the current command line
--- @return string[] list of completions
function M.lsp_complete(line)
  local splited = vim.split(line, '%s+')
  if #splited == 2 then
    return available_subcmds
  else
    local subcmd = splited[2]
    --- @param n string
    return vim.tbl_map(function(n)
      return vim.fn.escape(n, [[" |]])
    end, complete_args[subcmd]())
  end
end

return M
