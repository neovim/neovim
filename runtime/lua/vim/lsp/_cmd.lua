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

---@return string[]
local function get_config_names()
  local config_names = vim
    .iter(vim.api.nvim_get_runtime_file('lsp/*.lua', true))
    ---@param path string
    :map(function(path)
      local file_name = path:match('[^/]*.lua$')
      return file_name:sub(0, #file_name - 4)
    end)
    :totable()

  ---@diagnostic disable-next-line: invisible
  vim.list_extend(config_names, vim.tbl_keys(vim.lsp.config._configs))
  return vim.list.unique(config_names)
end

local complete_args = {
  start = get_config_names,
  stop = get_client_names,
  restart = get_client_names,
}

local function ex_lsp_start(servers)
  -- Default to enabling all servers matching the filetype of the current buffer.
  -- This assumes that they've been explicitly configured through `vim.lsp.config`,
  -- otherwise they won't be present in the private `vim.lsp.config._configs` table.
  if #servers == 0 then
    local filetype = vim.bo.filetype
    ---@diagnostic disable-next-line: invisible
    for name, _ in pairs(vim.lsp.config._configs) do
      local filetypes = vim.lsp.config[name].filetypes
      if filetypes and vim.tbl_contains(filetypes, filetype) then
        table.insert(servers, name)
      end
    end
  end

  vim.lsp.enable(servers)
end

---@param clients string[]
local function ex_lsp_stop(clients)
  -- Default to disabling all servers on current buffer
  if #clients == 0 then
    clients = get_client_names { bufnr = vim.api.nvim_get_current_buf() }
  end

  for _, name in ipairs(clients) do
    if vim.lsp.config[name] == nil then
      vim.notify(("Invalid server name '%s'"):format(name))
    else
      vim.lsp.enable(name, false)
    end
  end
end

---@param clients string[]
local function ex_lsp_restart(clients)
  -- Default to restarting all active servers
  if #clients == 0 then
    clients = get_client_names()
  end

  for _, name in ipairs(clients) do
    if vim.lsp.config[name] == nil then
      vim.notify(("Invalid server name '%s'"):format(name))
    else
      vim.lsp.enable(name, false)
    end
  end

  local timer = assert(vim.uv.new_timer())
  timer:start(500, 0, function()
    for _, name in ipairs(clients) do
      vim.schedule_wrap(function(x)
        vim.lsp.enable(x)
      end)(name)
    end
  end)
end

local actions = {
  start = ex_lsp_start,
  restart = ex_lsp_restart,
  stop = ex_lsp_stop,
}

local available_subcmds = vim.tbl_keys(actions)

--- Use for `:lsp {subcmd} {clients}` command
---@param args string
M._ex_lsp = function(args)
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
function M._ex_lsp_complete(line)
  local splited = vim.split(line, '%s+')
  if #splited == 2 then
    return available_subcmds
  else
    local subcmd = splited[2]
    ---@param n string
    return vim.tbl_map(function(n)
      return vim.fn.escape(n, [[" |]])
    end, complete_args[subcmd]())
  end
end

return M
