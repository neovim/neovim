-- Converted into Lua from https://github.com/cyjake/ssh-config
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

---@class vim.net.SshHost
---@field alias string Host alias from ssh config
---@field hostname? string Resolved Hostname directive
---@field user? string User directive
---@field port? string Port directive
---@field identity_file? string IdentityFile directive

---@param text string The ssh configuration which needs to be parsed
---@return vim.net.SshHost[] The parsed host configurations
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
      elseif chr == '"' and (#val == 0 or quoted) then
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
        if #val > 0 then
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

    if #val > 0 then
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

  ---@type vim.net.SshHost[]
  local hosts = {}
  local seen = {} ---@type table<string, boolean>
  ---@type vim.net.SshHost[]
  local current_hosts = {}

  ---@param value string
  local function is_valid(value)
    return not (value:find('[?*!]') or seen[value])
  end

  local function flush()
    for _, h in ipairs(current_hosts) do
      table.insert(hosts, h)
    end
    current_hosts = {}
  end

  ---@param aliases string[]
  local function add_aliases(aliases)
    flush()
    for _, alias in ipairs(aliases) do
      if is_valid(alias) then
        seen[alias] = true
        table.insert(current_hosts, { alias = alias })
      end
    end
  end

  while chr do
    local node = parse_line()
    if node then
      local lp = node.param:lower()
      if lp == 'match' and node.value then
        local values = node.value --[[@as string[] ]]
        local match_aliases = {} ---@type string[]
        for ind, val in ipairs(values) do
          if val:lower() == 'host' and ind + 1 <= #values and is_valid(values[ind + 1]) then
            table.insert(match_aliases, values[ind + 1])
          end
        end
        add_aliases(match_aliases)
      elseif lp == 'host' and node.value then
        local valid = {} ---@type string[]
        for _, value in
          ipairs(node.value --[[@as string[] ]])
        do
          if is_valid(value) then
            table.insert(valid, value)
          end
        end
        add_aliases(valid)
      else
        local val = (type(node.value) == 'string' and node.value or nil) --[[@as string?]]
        if val then
          for _, h in ipairs(current_hosts) do
            if lp == 'hostname' then
              h.hostname = val
            elseif lp == 'user' then
              h.user = val
            elseif lp == 'port' then
              h.port = val
            elseif lp == 'identityfile' then
              h.identity_file = val
            end
          end
        end
      end
    end
  end
  flush()

  return hosts
end

---@param filename string
---@return vim.net.SshHost[] The host configurations in the file
function M.parse_config(filename)
  local text = vim.fn.readblob(filename)
  return M.parse_ssh_config(text)
end

---@param filename? string Path to the SSH config file. Defaults to ~/.ssh/config
---@return string[] The hostnames configured in the SSH config file.
---                 Note: This does not currently process `Include` directives.
function M.get_hosts(filename)
  filename = filename or vim.fs.normalize('~/.ssh/config')
  local ok, hosts = pcall(M.parse_config, filename)
  if not ok then
    return {}
  end
  return vim.tbl_map(
    ---@param h vim.net.SshHost
    function(h)
      return h.alias
    end,
    hosts
  )
end

---@class vim.net.SshUri
---@field host string
---@field user? string
---@field port? string

---@param str string
---@return vim.net.SshUri
function M.parse_uri(str)
  ---@type vim.net.SshUri
  local uri = { host = '' }
  ---@type string?
  local scheme_match = str:match('^ssh://(.*)')
  if scheme_match then
    str = scheme_match
  end
  local user_match = str:match('^(.-)@(.*)')
  if user_match then
    uri.user = str:match('^(.-)@')
    str = str:match('@(.*)')
  end
  local port_match = str:match(':(%d+)$')
  if port_match then
    uri.port = port_match
    str = str:sub(1, -(#port_match + 2))
  end
  uri.host = str
  return uri
end

---@param msg string
---@param level? integer vim.log.levels.* (default INFO)
local function notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.schedule(function()
    vim.notify('[Remote SSH] ' .. msg, level)
  end)
end

---@param uri {host:string, user?:string, port?:string}
local function get_base_ssh_cmd(uri)
  local mux_dir = vim.fn.stdpath('run') --[[@as string]]
  local mux_path = mux_dir .. '/ssh_mux_%h_%p_%r'
  local ssh_cmd = {
    'ssh',
    '-T',
    '-o',
    'ControlMaster=auto',
    '-o',
    'ControlPath=' .. mux_path,
    '-o',
    'ControlPersist=10m',
  }
  if uri.port then
    table.insert(ssh_cmd, '-p')
    table.insert(ssh_cmd, uri.port)
  end
  ---@type string
  local target = uri.host
  if uri.user then
    target = uri.user .. '@' .. uri.host
  end
  table.insert(ssh_cmd, target)

  return ssh_cmd
end

---@param ssh_cmd string[]
---@param wait_mode boolean|string true to wait for exit, string to wait for specific output
---@return { code?: number, stdout?: string, job_id?: number }
local function exec_ssh(ssh_cmd, wait_mode)
  local stdout_lines = {}
  local is_done = false
  local code = -1
  ---@type string
  local buffer = ''

  ---@param _ number
  ---@param data string[]
  local on_stdout = function(_, data, _)
    if not data then
      return
    end
    for i, chunk in ipairs(data) do
      if i < #data then
        table.insert(stdout_lines, buffer .. chunk)
        buffer = ''
      else
        buffer = buffer .. chunk
      end
    end
  end

  local on_exit = function(_, exit_code, _)
    code = exit_code
    is_done = true
  end

  local job_id = vim.fn.jobstart(ssh_cmd, {
    on_stdout = on_stdout,
    on_exit = on_exit,
  })

  if job_id <= 0 then
    error('Failed to start SSH job')
  end

  if wait_mode then
    local success = vim.wait(300000, function()
      if type(wait_mode) == 'string' then
        local output = table.concat(stdout_lines, '\n') .. buffer
        if output:match(wait_mode) then
          return true
        end
      end
      return is_done
    end, 50)
    if not success then
      vim.fn.jobstop(job_id)
      error('SSH command timed out')
    end
    if buffer ~= '' then
      table.insert(stdout_lines, buffer)
    end
    local stdout = table.concat(stdout_lines, '\n')

    return { code = code, stdout = stdout }
  else
    return { job_id = job_id }
  end
end

---@param uri {host:string, user?:string, port?:string}
---@return string os, string arch
function M.get_system_info(uri)
  local ssh_cmd = get_base_ssh_cmd(uri)
  table.insert(ssh_cmd, 'uname -s && uname -m')

  local obj = exec_ssh(ssh_cmd, true)
  if obj.code ~= 0 then
    error('Failed to detect remote system info: ' .. obj.stdout)
  end

  local lines = vim.split(vim.trim(obj.stdout), '\n', { plain = true })
  local valid_lines = {}
  for _, line in ipairs(lines) do
    if vim.trim(line) ~= '' then
      table.insert(valid_lines, vim.trim(line))
    end
  end

  if #valid_lines < 2 then
    error('Unexpected output from system info detection: ' .. obj.stdout)
  end

  ---@type string
  local os = valid_lines[#valid_lines - 1]:lower()
  ---@type string
  local arch = valid_lines[#valid_lines]:lower()

  if os:match('msys') or os:match('windows') or os:match('mingw') or os:match('cygwin') then
    error('Not implemented yet: Windows targets are not supported.')
  end

  return os, arch
end

local function check_and_install(uri, os, arch)
  local ver = vim.version() --[[@as vim.Version]]
  local nvim_version = 'v' .. tostring(ver)
  local is_nightly = ver.prerelease and true or false

  local os_map = { linux = 'linux', darwin = 'macos' }
  local arch_map = { x86_64 = 'x86_64', aarch64 = 'arm64', arm64 = 'arm64' }

  local target_os = os_map[os]
  local target_arch = arch_map[arch]
  if not target_os or not target_arch then
    error(string.format('Unsupported OS/Arch combination: %s/%s', os, arch))
  end

  local release_file = string.format('nvim-%s-%s.tar.gz', target_os, target_arch)
  local release_url =
    string.format('https://github.com/neovim/neovim/releases/latest/download/%s', release_file)
  if is_nightly then
    release_url =
      string.format('https://github.com/neovim/neovim/releases/download/nightly/%s', release_file)
  end

  local remote_script = string.format(
    [[
    TARGET_VER="%s"
    INSTALL_DIR="$HOME/.local/share/nvim-remote"
    BIN_DIR="$HOME/.local/bin"

    mkdir -p "$BIN_DIR"
    mkdir -p "$INSTALL_DIR"

    if [ -x "$BIN_DIR/nvim" ]; then
      CURRENT_VER=$("$BIN_DIR/nvim" -v | head -n1 | sed 's/^NVIM //')
      if [ "$CURRENT_VER" = "$TARGET_VER" ]; then
        exit 0
      fi
    fi

    echo "Installing Nvim $TARGET_VER..." >&2
    cd "$INSTALL_DIR" || exit 1
    curl -fLo nvim.tar.gz "%s" || wget -O nvim.tar.gz "%s" || exit 1
    rm -rf nvim-%s-%s
    tar -xzf nvim.tar.gz || exit 1
    ln -sf "$INSTALL_DIR/nvim-%s-%s/bin/nvim" "$BIN_DIR/nvim"
  ]],
    nvim_version,
    release_url,
    release_url,
    target_os,
    target_arch,
    target_os,
    target_arch
  )

  local ssh_cmd = get_base_ssh_cmd(uri)
  table.insert(ssh_cmd, remote_script)

  local obj = exec_ssh(ssh_cmd, true)
  if obj.code ~= 0 then
    error('Installation failed: ' .. obj.stdout)
  end
end

--- @param uri_str string
--- @return string local_socket path to the local forwarded socket
--- @return vim.net.SshUri uri parsed SSH URI for cleanup
--- @return fun() teardown function to close the SSH master connection
function M.start(uri_str)
  local uri = M.parse_uri(uri_str)
  notify('Connecting to ' .. uri_str .. '...')
  local os, arch = M.get_system_info(uri)

  notify('Checking remote Nvim install...')
  check_and_install(uri, os, arch)

  local local_sock = vim.fn.tempname() .. '_remote_nvim.sock'

  local ssh_cmd = get_base_ssh_cmd(uri)
  table.insert(ssh_cmd, '-L')
  table.insert(ssh_cmd, local_sock .. ':/tmp/nvim.sock')

  local remote_cmd = [[
    rm -f /tmp/nvim.sock
    NVIM_APPNAME=nvim-remote ~/.local/bin/nvim --headless --listen /tmp/nvim.sock &
    NVIM_PID=$!
    trap 'kill $NVIM_PID 2>/dev/null; rm -f /tmp/nvim.sock' EXIT
    while [ ! -S /tmp/nvim.sock ]; do
      if ! kill -0 $NVIM_PID 2>/dev/null; then
        echo "NVIM_CRASHED"
        exit 1
      fi
      sleep 0.1
    done
    echo "NVIM_READY"
    wait $NVIM_PID
  ]]

  table.insert(ssh_cmd, 'bash')
  table.insert(ssh_cmd, '-c')
  table.insert(ssh_cmd, remote_cmd)

  notify('Establishing SSH tunnel...')
  local obj = exec_ssh(ssh_cmd, 'NVIM_READY')

  if obj.stdout:match('NVIM_CRASHED') then
    error('Remote Nvim crashed during startup')
  end

  notify('Connected to ' .. uri_str)

  local cleaned_up = false

  local function teardown()
    if cleaned_up then
      return
    end
    cleaned_up = true
    local stop_cmd = get_base_ssh_cmd(uri)
    table.insert(stop_cmd, '-O')
    table.insert(stop_cmd, 'exit')
    vim.system(stop_cmd):wait()
  end

  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = teardown,
  })

  return local_sock, uri, teardown
end

return M
