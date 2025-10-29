-- The sshconfig parser was converted into Lua from https://github.com/cyjake/ssh-config
-- TODO (siddhantdev): deal with include directives

local M = {}

local whitespace_pattern = '%s'
local line_break_pattern = '[\r\n]'

---@param param string
local function is_multi_value_directive(param)
  local multi_value_directives = {
    'globalknownhostsfile',
    'host',
    'ipqos',
    'sendenv',
    'userknownhostsfile',
    'proxycommand',
    'match',
    'canonicaldomains',
  }

  return vim.list_contains(multi_value_directives, param:lower())
end

---@param text string The ssh configuration which needs to be parsed
---@return string[] The parsed host names in the configuration
function M.parse_ssh_config(text)
  local i = 1
  local line = 1

  local function consume()
    if i <= #text then
      local char = text:sub(i, i)
      i = i + 1
      return char
    end
    return nil
  end

  local chr = consume()

  local function parse_spaces()
    local spaces = ''
    while chr and chr:match(whitespace_pattern) do
      spaces = spaces .. chr
      chr = consume()
    end
    return spaces
  end

  local function parse_linebreaks()
    local breaks = ''
    while chr and chr:match(line_break_pattern) do
      line = line + 1
      breaks = breaks .. chr
      chr = consume()
    end
    return breaks
  end

  local function parse_parameter_name()
    local param = ''
    while chr and not chr:match('[ \t=]') do
      param = param .. chr
      chr = consume()
    end
    return param
  end

  local function parse_separator()
    local sep = parse_spaces()
    if chr == '=' then
      sep = sep .. chr
      chr = consume()
    end
    return sep .. parse_spaces()
  end

  local function parse_value()
    local val = {}
    local quoted, escaped = false, false

    while chr and not chr:match(line_break_pattern) do
      if escaped then
        table.insert(val, chr == '"' and chr or '\\' .. chr)
        escaped = false
      elseif chr == '"' and (val == {} or quoted) then
        quoted = not quoted
      elseif chr == '\\' then
        escaped = true
      elseif chr == '#' and not quoted then
        break
      else
        table.insert(val, chr)
      end
      chr = consume()
    end

    if quoted or escaped then
      error('Unexpected line break at line ' .. line)
    end

    return vim.trim(table.concat(val))
  end

  local function parse_comment()
    while chr and not chr:match(line_break_pattern) do
      chr = consume()
    end
  end

  ---@return string[]
  local function parse_multiple_values()
    local results = {}
    local val = {}
    local quoted = false
    local escaped = false

    while chr and not chr:match(line_break_pattern) do
      if escaped then
        table.insert(val, chr == '"' and chr or '\\' .. chr)
        escaped = false
      elseif chr == '"' then
        quoted = not quoted
      elseif chr == '\\' then
        escaped = true
      elseif quoted then
        table.insert(val, chr)
      elseif chr:match('[ \t=]') then
        if val ~= {} then
          table.insert(results, vim.trim(table.concat(val)))
          val = {}
        end
      elseif chr == '#' and #results > 0 then
        break
      else
        table.insert(val, chr)
      end
      chr = consume()
    end

    if quoted or escaped then
      error('Unexpected line break at line ' .. line)
    end

    if val ~= {} then
      table.insert(results, vim.trim(table.concat(val)))
    end

    return results
  end

  local function parse_directive()
    local param = parse_parameter_name()
    local multiple = is_multi_value_directive(param)
    local _ = parse_separator()
    local value = multiple and parse_multiple_values() or parse_value()

    local result = {
      param = param,
      value = value,
    }

    return result
  end

  local function parse_line()
    local _ = parse_spaces()
    if chr == '#' then
      parse_comment()
      return nil
    end
    local node = parse_directive()
    local _ = parse_linebreaks()

    return node
  end

  local hostnames = {}

  ---@param value string
  local function is_valid(value)
    return not (value:find('[?*!]') or vim.list_contains(hostnames, value))
  end

  while chr do
    local node = parse_line()
    if node then
      -- This is done just to assign the type
      node.value = node.value ---@type string[]
      if node.param:lower() == 'match' and node.value then
        local current = nil
        for ind, val in ipairs(node.value) do
          if val:lower() == 'host' and ind + 1 <= #node.value and is_valid(node.value[ind + 1]) then
            current = node.value[ind + 1]
          end
        end
        if current then
          table.insert(hostnames, current)
        end
      elseif node.param:lower() == 'host' and node.value then
        for _, value in ipairs(node.value) do
          if is_valid(value) then
            table.insert(hostnames, value)
          end
        end
      end
    end
  end

  return hostnames
end

---@param filename string
---@return string[] The hostnames configured in the file located at filename
function M.parse_config(filename)
  if vim.fn.filereadable(filename) == 0 then
    return {}
  end

  local file = io.open(filename, 'r')
  if not file then
    error('Cannot read ssh configuration file')
  end
  local config_string = file:read('*a')
  file:close()

  return M.parse_ssh_config(config_string)
end

---@return string[] The hostnames configured in the ssh configuration file
---                 located at "~/.ssh/config".
---                 Note: This does not currently process `Include` directives in the
---                 configuration file.
function M.get_hosts()
  local config_path = vim.fs.normalize('~/.ssh/config') ---@type string

  return M.parse_config(config_path)
end

-- Prompts table obtained from https://github.com/amitds1997/remote-nvim.nvim/blob/9992c2fb8bf4f11aca2c8be8db286b506f92efcb/lua/remote-nvim/init.lua#L110-L145
local ssh_prompts = {
  {
    prompt = 'password:',
    type = 'secret',
    value = '',
  },
  {
    prompt = 'continue connecting (yes/no/[fingerprint])?',
    type = 'plain',
    value = '',
  },
  {
    prompt = 'Password for',
    type = 'secret',
    value = '',
  },
  {
    prompt = 'Password:',
    type = 'secret',
    value = '',
  },
  {
    prompt = 'Enter passphrase',
    type = 'secret',
    value = '',
  },
}

local stdout = {} ---@type string[]
local processed_idx = 0
local job_id = 0
local is_remote_running = false

local function _run_cmd(cmd, on_exit)
  stdout = {}
  processed_idx = 0

  job_id = vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = function(_job_id, data, _event)
      data = data ---@type string[]
      for _, chunk in ipairs(data) do
        local line = chunk:gsub('\r', '\n')
        table.insert(stdout, line)
      end

      local unprocessed_data = table.concat(vim.list_slice(stdout, processed_idx + 1))
      if unprocessed_data:find('Tunnel created successfully') then
        is_remote_running = true
      end
      for i, prompt in ipairs(ssh_prompts) do
        if unprocessed_data:find(vim.pesc(prompt.prompt)) then
          local resp = ''
          if prompt.value ~= '' then
            resp = prompt.value
          else
            local unprocessed_data_lines = vim.split(vim.trim(unprocessed_data), '\n')
            local input_label =
              string.format('%s ', unprocessed_data_lines[#unprocessed_data_lines])
            if prompt.type == 'secret' then
              resp = vim.fn.inputsecret(input_label)
            else
              resp = vim.fn.input(input_label)
            end
            vim.cmd('redraw')
          end

          ssh_prompts[i].value = resp
          processed_idx = #stdout
          vim.api.nvim_chan_send(job_id, resp .. '\n')
        end
      end
    end,
    on_exit = function(chan_id, data, event)
      if on_exit ~= nil then
        on_exit(chan_id, data, event)
      end
    end,
  })

  return job_id
end

--- Starts a Nvim server on the remote machine via ssh and tunnels it to a local socket.
---@param address string
---@return string local_socket
function M.connect_to_address(address)
  if not address or address == '' then
    error('invalid SSH address given')
  end

  if address:find(' ') ~= nil then
    error('SSH address cannot contain spaces')
  end

  if vim.fn.executable('ssh') ~= 1 then
    error('"ssh" client not found')
  end

  -- Reset the prompts table
  for i, prompt in ipairs(ssh_prompts) do
    if prompt.value ~= '' then
      ssh_prompts[i].value = ''
    end
  end

  local remote_has_nvim = false
  local check_cmd = { 'ssh', '-t', address, 'nvim --clean -v' }
  local check_on_exit = function(_job_id, _data, _event)
    local check_str = table.concat(stdout, '')
    if check_str:find('NVIM v.*') ~= nil then
      remote_has_nvim = true
    end
  end
  local check_id = _run_cmd(check_cmd, check_on_exit)

  vim.fn.jobwait({ check_id })

  if not remote_has_nvim then
    error('Neovim needs to be installed on the remote machine')
  end

  local local_socket = vim.fn.stdpath('run') .. '/host_nvim_' .. vim.fn.getpid() .. '.pipe'
  local remote_socket = ''

  local echo_cmd = 'lua require("vim.net._ssh").get_free_socket()'
  local find_socket_nvim_cmd = string.format("nvim --headless --cmd '%s'", echo_cmd)
  local find_socket_cmd = {
    'ssh',
    '-t',
    address,
    find_socket_nvim_cmd,
  }
  vim.print(find_socket_cmd)
  -- local find_socket_cmd = string.format('ssh -t %s %s', address, find_socket_nvim_cmd)
  local find_socket_on_exit = function(_job_id, _data, _event)
    for _, find_str in ipairs(stdout) do
      local needle = 'Free socket:'
      local serv_ind = find_str:find(needle)
      if serv_ind ~= nil then
        remote_socket = vim.trim(find_str:sub(serv_ind + needle:len()))
      end
    end
  end
  local find_socket_id = _run_cmd(find_socket_cmd, find_socket_on_exit)

  vim.fn.jobwait({ find_socket_id })

  if remote_socket == '' then
    error('Could not find free socket on remote machine')
  end

  local forward = string.format('%s:%s', local_socket, remote_socket)
  local tunnel_nvim_cmd = string.format(
    'nvim --headless --listen %s --cmd \'echo "Tunnel created successfully"\'',
    remote_socket
  )
  local tunnel_cmd = { 'ssh', '-t', '-L', forward, address, tunnel_nvim_cmd }
  is_remote_running = false
  local tunnel_id = _run_cmd(tunnel_cmd, nil)

  -- Wait for the tunnel to start before returning local_socket
  while not is_remote_running and vim.fn.jobwait({ tunnel_id }, 500)[1] == -1 do
  end

  return local_socket
end

function M.get_free_socket()
  local socket_name = vim.fn.serverstart()
  vim.fn.serverstop(socket_name)
  os.remove(socket_name)
  vim.print('Free socket: ' .. socket_name)
  vim.cmd('qall!')
end

function M.get_connect_choice()
  local servers = vim.fn.serverlist({ peer = true })
  local ssh_hosts = M.get_hosts()

  local retvals = {}
  local inputs = {}

  local i = 1
  for _, server in ipairs(servers) do
    table.insert(retvals, server)
    local curr = i .. '. Server: ' .. server

    if server == vim.v.servername then
      curr = curr .. ' (current)'
    end

    table.insert(inputs, curr)
    i = i + 1
  end

  for _, host in ipairs(ssh_hosts) do
    table.insert(retvals, 'ssh://' .. host)
    table.insert(inputs, i .. '. SSH: ' .. host)
    i = i + 1 ---@type integer
  end

  -- Use inputlist rather than vim.ui.select for blocking select
  local choice = vim.fn.inputlist(inputs)
  return retvals[choice]
end

return M
