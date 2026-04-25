local api = vim.api
local fs = vim.fs
local time = require('vim._core.time')
local util = require('vim._core.util')
local uv = vim.uv
local N_ = vim.fn.gettext

--- Parsed ex command arguments for builtin commands, passed from C via `nlua_call_excmd`.
--- Inherits fields from user command args: args, bang, line1, line2, range, count, reg, smods.
--- @class vim._core.ExCmdArgs : vim.api.keyset.create_user_command.command_args

local M = {}

--- @param msg string
local function echo_err(msg)
  api.nvim_echo({ { msg } }, true, { err = true })
end

--- @return string[]
local function get_client_names()
  return vim
    .iter(vim.lsp.get_clients())
    :map(function(client)
      return client.name
    end)
    :unique()
    :totable()
end

--- @param filter vim.lsp.get_configs.Filter
--- @return fun():string[]
local function filtered_config_names(filter)
  return function()
    return vim
      .iter(vim.lsp.get_configs(filter))
      :map(function(config)
        return config.name
      end)
      :totable()
  end
end

local complete_args = {
  enable = filtered_config_names { enabled = false },
  disable = filtered_config_names { enabled = true },
  restart = get_client_names,
  stop = get_client_names,
}

--- @param names string[]
--- @param enable? boolean
local function checked_enable(names, enable)
  for _, name in ipairs(names) do
    if name:find('*') == nil and vim.lsp.config[name] ~= nil then
      vim.lsp.enable(name, enable)
    else
      echo_err(N_('E5801: No client config named: %s'):format(name))
    end
  end
end

--- @param config_names string[]
local function ex_lsp_enable(config_names)
  -- Default to enabling all clients matching the filetype of the current buffer.
  if #config_names == 0 then
    local filetype = vim.bo.filetype
    for _, config in ipairs(vim.lsp.get_configs()) do
      local filetypes = config.filetypes
      if filetypes == nil or vim.list_contains(filetypes, filetype) then
        table.insert(config_names, config.name)
      end
    end
    if #config_names == 0 then
      if filetype == '' then
        echo_err(N_('E5802: Current buffer has no filetype'))
      else
        echo_err(N_('E5803: No configs for filetype: %s'):format(filetype))
      end
      return
    end
  end

  checked_enable(config_names)
end

--- @param config_names string[]
local function ex_lsp_disable(config_names)
  -- Default to disabling all clients attached to the current buffer.
  if #config_names == 0 then
    config_names = vim
      .iter(vim.lsp.get_clients { bufnr = api.nvim_get_current_buf() })
      :map(function(client)
        return client.name
      end)
      :filter(function(name)
        return vim.lsp.config[name] ~= nil
      end)
      :totable()
    if #config_names == 0 then
      echo_err(N_('E5804: No configs with clients attached to current buffer'))
      return
    end
  end

  checked_enable(config_names, false)
end

--- @param client_names string[]
--- @return vim.lsp.Client[]
local function get_clients_from_names(client_names)
  -- Default to all active clients attached to the current buffer.
  if #client_names == 0 then
    local clients = vim.lsp.get_clients { bufnr = api.nvim_get_current_buf() }
    if #clients == 0 then
      echo_err(N_('E5805: No clients attached to current buffer'))
    end
    return clients
  else
    return vim
      .iter(client_names)
      :map(function(name)
        local clients = vim.lsp.get_clients { name = name }
        if #clients == 0 then
          echo_err(N_('E5806: No active clients matching name: %s'):format(name))
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
    client:_restart(client.exit_timeout)
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
--- @param eap vim._core.ExCmdArgs
function M.ex_lsp(eap)
  local fargs = api.nvim_parse_cmd('lsp ' .. eap.args, {}).args
  if not fargs then
    return
  end
  local subcmd = fargs[1]
  if not vim.list_contains(available_subcmds, subcmd) then
    echo_err(N_('E5800: Invalid :lsp subcommand: %s'):format(subcmd))
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

--- @type string
--- @diagnostic disable-next-line: assign-type-mismatch
local log_dir = vim.fn.stdpath('log')

--- Implements command: `:log {file}`.
--- @param eap vim._core.ExCmdArgs
function M.ex_log(eap)
  local filename = eap.args
  if filename == '' then
    util.wrapped_edit(log_dir, eap.smods)
  else
    local path --- @type string
    -- Special case for NVIM_LOG_FILE
    local nvim_log_file = vim.env.NVIM_LOG_FILE --- @type string
    if filename == 'nvim' and nvim_log_file and nvim_log_file ~= '' then
      path = nvim_log_file
    else
      path = fs.joinpath(log_dir, filename .. '.log')
    end
    if not vim.uv.fs_stat(path) then
      echo_err(N_('E5200: No such log file: %s'):format(path))
      return
    end
    util.wrapped_edit(path, eap.smods)
    vim.cmd.normal { 'G', bang = true }
  end
end

--- Completion logic for `:log` command
--- @return string[] list of completions
function M.log_complete()
  local names = { 'nvim' } --- @type string[]
  for file, type in vim.fs.dir(log_dir, { depth = math.huge }) do
    local name, matches = file:gsub('%.log$', '')
    if matches ~= 0 and type == 'file' and name ~= 'nvim' then
      names[#names + 1] = name
    end
  end
  return names
end

--- `:terminal [cmd]`
--- @param eap vim._core.ExCmdArgs
--- @param shell_argv? string[] Tokenized 'shell' from C (shell_build_argv), for the no-cmd case.
function M.ex_terminal(eap, shell_argv)
  local smods = eap.smods
  local has_mods = (smods.tab or 0) > 0
    or (smods.split or '') ~= ''
    or smods.horizontal
    or smods.vertical

  if has_mods then
    vim.cmd.new { mods = smods }
  else
    vim.cmd.enew { bang = eap.bang }
  end

  if shell_argv then -- No `cmd`, run 'shell'.
    vim.fn.jobstart(shell_argv, { term = true })
  else -- Run [cmd] in 'shell'.
    vim.fn.jobstart(eap.args, { term = true })
  end
end

function M.ex_uptime()
  local uptime = math.floor((uv.hrtime() - vim.v.starttime) / 1e9)
  local uptime_display = time.fmt_rtime(uptime)
  api.nvim_echo({ { N_('Up %s'):format(uptime_display) } }, true, {})
end

return M
