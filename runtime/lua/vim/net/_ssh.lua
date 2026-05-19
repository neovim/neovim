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

local _log --- @type vim.Log?

--- Lazy `vim.log` instance for the remote-ssh feature. Writes to `stdpath('log')/remote-ssh.log`.
---@return vim.Log
local function log()
  if not _log then
    _log = vim.log.new({ name = 'remote-ssh', current_level = vim.log.levels.INFO })
  end
  return _log
end

---@param msg string
---@param level? integer vim.log.levels.* (default INFO)
local function notify(msg, level)
  level = level or vim.log.levels.INFO
  if level >= vim.log.levels.ERROR then
    log().error(msg)
  elseif level >= vim.log.levels.WARN then
    log().warn(msg)
  else
    log().info(msg)
  end
  local function show()
    vim.notify('remote-ssh: ' .. msg, level)
    vim.cmd.redraw()
  end
  if vim.in_fast_event() then
    vim.schedule(show)
  else
    show()
  end
end

local function core_system()
  -- Keep this lazy so parser-only users can load vim.net._ssh without editor state.
  return require('vim._core.system')
end

--- Builds a command for the host identified by `ssh_uri`.
---
--- `ssh_args` are inserted before the target; `remote_cmd` is appended after the target.
---
---@param ssh_uri {host:string, user?:string, port?:string}
---@param opts? { ssh_args?: string[], remote_cmd?: string[] }
---@return string[]
local function get_ssh_cmd(ssh_uri, opts)
  opts = opts or {}
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
  if opts.ssh_args then
    vim.list_extend(ssh_cmd, opts.ssh_args)
  end
  if ssh_uri.port then
    table.insert(ssh_cmd, '-p')
    table.insert(ssh_cmd, ssh_uri.port)
  end
  ---@type string
  local target = ssh_uri.host
  if ssh_uri.user then
    target = ssh_uri.user .. '@' .. ssh_uri.host
  end
  table.insert(ssh_cmd, target)

  if opts.remote_cmd then
    vim.list_extend(ssh_cmd, opts.remote_cmd)
  end

  return ssh_cmd
end

--- Gets the operating system and architecture from the remote system.
---
---@param uri {host:string, user?:string, port?:string}
---@return string os, string arch
function M.get_system_info(uri)
  local ssh_cmd = get_ssh_cmd(uri, { remote_cmd = { 'uname -s && uname -m' } })
  log().debug('get_system_info: running', ssh_cmd)

  local obj = core_system().run_wait(ssh_cmd, nil, 300000)
  log().debug('get_system_info: code', obj.code, 'stdout', obj.stdout, 'stderr', obj.stderr)
  if obj.code ~= 0 then
    error(
      'Failed to detect remote system info: ' .. (obj.stderr ~= '' and obj.stderr or obj.stdout)
    )
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
    set -euo pipefail
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
    cd "$INSTALL_DIR"
    curl -fL "%s" | tar -xzf -
    ln -sf "$INSTALL_DIR/nvim-%s-%s/bin/nvim" "$BIN_DIR/nvim"
  ]],
    nvim_version,
    release_url,
    target_os,
    target_arch
  )

  local ssh_cmd = get_ssh_cmd(uri, { remote_cmd = { remote_script } })
  log().debug('check_and_install: target_ver', nvim_version, 'os', target_os, 'arch', target_arch)

  local obj = core_system().run_wait(ssh_cmd, nil, 300000)
  log().debug('check_and_install: code', obj.code, 'stdout', obj.stdout, 'stderr', obj.stderr)
  if obj.code ~= 0 then
    error('Installation failed: ' .. (obj.stderr ~= '' and obj.stderr or obj.stdout))
  end
end

--- @param uri_str string
--- @return string local_socket path to the local forwarded socket
--- @return vim.net.SshUri uri parsed SSH URI for cleanup
--- @return fun() teardown function to close the SSH master connection
function M.start(uri_str)
  local uri = require('vim.uri')._parse_ssh_uri(uri_str)
  notify('Connecting to ' .. uri_str .. '...')
  local os, arch = M.get_system_info(uri)

  notify('Checking remote Nvim install...')
  check_and_install(uri, os, arch)

  local local_sock = vim.fn.tempname() .. '_remote_nvim.sock'

  local remote_cmd = [[
    rm -f /tmp/nvim-remote.sock
    NVIM_APPNAME=nvim-remote ~/.local/bin/nvim --headless --listen /tmp/nvim-remote.sock &
    NVIM_PID=$!
    trap 'kill $NVIM_PID 2>/dev/null; rm -f /tmp/nvim-remote.sock' EXIT
    while [ ! -S /tmp/nvim-remote.sock ]; do
      if ! kill -0 $NVIM_PID 2>/dev/null; then
        echo "NVIM_CRASHED"
        exit 1
      fi
      sleep 0.1
    done
    echo "NVIM_READY"
    wait $NVIM_PID
  ]]

  local ssh_cmd = get_ssh_cmd(uri, {
    ssh_args = { '-L', local_sock .. ':/tmp/nvim-remote.sock' },
    remote_cmd = { 'bash', '-c', remote_cmd },
  })

  notify('Establishing SSH tunnel...')
  log().debug('start: local_sock', local_sock)
  local tunnel = core_system().run_wait(ssh_cmd, function(stdout)
    return stdout:match('NVIM_READY') ~= nil
  end, 300000)
  log().debug('start: tunnel stdout', tunnel.stdout, 'stderr', tunnel.stderr)

  if tunnel.stdout:match('NVIM_CRASHED') then
    log().error('Remote Nvim crashed during startup', tunnel.stderr)
    error('Remote Nvim crashed during startup')
  end

  notify('Connected to ' .. uri_str)

  local cleaned_up = false

  local function teardown()
    if cleaned_up then
      return
    end
    cleaned_up = true
    log().info('teardown: closing ssh mux for ' .. uri_str)
    local stop_cmd = get_ssh_cmd(uri, { ssh_args = { '-O', 'exit' } })
    vim.system(stop_cmd):wait()
    -- Wait for the original tunnel process to close its stdio handles.
    if not tunnel:is_closing() then
      tunnel:wait(1000)
    end
  end

  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = teardown,
  })

  return local_sock, uri, teardown
end

return M
