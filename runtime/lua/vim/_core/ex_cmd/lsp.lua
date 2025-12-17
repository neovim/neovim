local api = vim.api
local lsp = vim.lsp

local M = {}

--- @return string[]
local function get_client_names()
  local client_names = vim
    .iter(lsp.get_clients())
    :map(function(client)
      return client.name
    end)
    :totable()
  return vim.list.unique(client_names)
end

--- @return string[]
local function get_config_names()
  local config_names = vim
    .iter(api.nvim_get_runtime_file('lsp/*.lua', true))
    --- @param path string
    :map(function(path)
      local file_name = path:match('[^/]*.lua$')
      return file_name:sub(0, #file_name - 4)
    end)
    :totable()

  --- @diagnostic disable-next-line
  vim.list_extend(config_names, vim.tbl_keys(lsp.config._configs))

  return vim
    .iter(vim.list.unique(config_names))
    --- @param name string
    :filter(function(name)
      return name ~= '*'
    end)
    :totable()
end

--- @param filter fun(string):boolean
--- @return fun():string[]
local function filtered_config_names(filter)
  return function()
    return vim.iter(get_config_names()):filter(filter):totable()
  end
end

--- @return string[]
local function get_attached_config_names()
  return vim
    .iter(lsp.get_clients { bufnr = api.nvim_get_current_buf() })
    :filter(function(client)
      return lsp.config[client.name] ~= nil
    end)
    :map(function(client)
      return client.name
    end)
    :totable()
end

local complete_args = {
  enable = filtered_config_names(function(name)
    return not lsp.is_enabled(name)
  end),
  disable = get_attached_config_names,
  restart = get_client_names,
  stop = get_client_names,
}

--- @param names string[]
--- @param enable? boolean
local function checked_enable(names, enable)
  for _, name in ipairs(names) do
    if name:find('*') == nil and lsp.config[name] ~= nil then
      lsp.enable(name, enable)
    else
      vim.notify(("No client config named '%s'"):format(name), vim.log.levels.ERROR)
    end
  end
end

--- @param config_names string[]
local function ex_lsp_enable(config_names)
  -- Default to enabling all clients matching the filetype of the current buffer.
  if #config_names == 0 then
    local filetype = vim.bo.filetype
    for _, name in ipairs(get_config_names()) do
      local filetypes = lsp.config[name].filetypes
      if filetypes and vim.tbl_contains(filetypes, filetype) then
        table.insert(config_names, name)
      end
    end
  end

  checked_enable(config_names)
end

--- @param config_names string[]
local function ex_lsp_disable(config_names)
  -- Default to disabling all clients attached to the current buffer.
  if #config_names == 0 then
    config_names = get_attached_config_names()
  end

  checked_enable(config_names, false)
end

--- @param client_names string[]
--- @return vim.lsp.Client[]
local function get_clients_from_names(client_names)
  -- Default to stopping all active clients attached to the current buffer.
  if #client_names == 0 then
    return lsp.get_clients { bufnr = api.nvim_get_current_buf() }
  else
    return vim
      .iter(client_names)
      :map(function(name)
        local clients = lsp.get_clients { name = name }
        if #clients == 0 then
          vim.notify(("No active clients named '%s'"):format(name), vim.log.levels.ERROR)
        end
        return clients
      end)
      :flatten()
      :totable()
  end
end

--- @param client_names string[]
local function ex_lsp_restart(client_names)
  local clients = get_clients_from_names(client_names)

  for _, client in ipairs(clients) do
    --- @type integer[]
    local attached_buffers = vim.tbl_keys(client.attached_buffers)

    -- Reattach new client once the old one exits
    api.nvim_create_autocmd('LspDetach', {
      group = api.nvim_create_augroup('nvim.lsp.ex_restart_' .. client.id, {}),
      callback = function(info)
        if info.data.client_id ~= client.id then
          return
        end

        local new_client_id = lsp.start(client.config, { attach = false })
        if new_client_id then
          for _, buffer in ipairs(attached_buffers) do
            lsp.buf_attach_client(buffer, new_client_id)
          end
        end

        return true -- Delete autocmd
      end,
    })

    client:stop(client.exit_timeout)
  end
end

--- @param client_names string[]
local function ex_lsp_stop(client_names)
  local clients = get_clients_from_names(client_names)

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

--- Implements command: `:lsp {subcmd} {name}?`.
--- @param args string
M.ex_lsp = function(args)
  local fargs = api.nvim_parse_cmd('lsp ' .. args, {}).args
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
  local split = vim.split(line, '%s+')
  if #split == 2 then
    return available_subcmds
  else
    local subcmd = split[2]
    return vim
      .iter(complete_args[subcmd]())
      --- @param n string
      :map(function(n)
        return vim.fn.escape(n, ' \t')
      end)
      :totable()
  end
end

return M
