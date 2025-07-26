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
      return not not vim.lsp.config[name]
    end)
    :totable()
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

  local clients = {}
  for i, client in ipairs(fargs) do
    if i > 1 then
      table.insert(clients, client)
    end
  end

  actions[subcmd](clients)
end

--- Completion logic for `:lsp` command
--- @param line string content of the current command line
--- @return string[] list of completions
function M._ex_lsp_complete(line)
  local splited = vim.split(line, ' ')
  if #splited == 2 then
    return available_subcmds
  else
    ---@param n string
    return vim.tbl_map(function(n)
      return vim.fn.escape(n, [[" |]])
    end, get_client_names())
  end
end

return M
