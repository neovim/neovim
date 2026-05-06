local M = {}

local ssh = require('vim.net._ssh')

---@type string?
local ssh_password = nil

---@param msg string
---@param level? integer vim.log.levels.* (default INFO)
local function notify(msg, level)
  level = level or vim.log.levels.INFO
  local is_headless = #vim.api.nvim_list_uis() == 0 and vim.env.NVIM_TEST_MOCK_UI ~= '1'
  if is_headless then
    io.stderr:write('[Remote SSH] ' .. msg .. '\n')
    io.stderr:flush()
  else
    vim.schedule(function()
      vim.notify('[Remote SSH] ' .. msg, level)
    end)
  end
end

---@param uri {host:string, user?:string, port?:string}
local function get_base_ssh_cmd(uri)
  local mux_path = string.format('/tmp/nvim_ssh_mux_%s_%%h_%%p_%%r', vim.env.USER or 'user')
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
---@return table { code = number, stdout = string, job_id = number }
local function exec_ssh(ssh_cmd, wait_mode)
  local stdout_lines = {}
  local is_done = false
  local code = -1
  ---@type string
  local buffer = ''
  local prompt_count = 0

  ---@param j number
  ---@param data string[]
  ---@param _ any
  local on_stdout = function(j, data, _)
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

    local text = table.concat(data, '\n')
    if text:match('[Pp]assword:') or text:match('passphrase') then
      prompt_count = prompt_count + 1
      if prompt_count > 1 then
        ssh_password = nil
        notify('Authentication failed! Incorrect password.', vim.log.levels.ERROR)
        vim.fn.jobstop(j)
        return
      end

      vim.schedule(function()
        local is_headless = #vim.api.nvim_list_uis() == 0 and vim.env.NVIM_TEST_MOCK_UI ~= '1'
        if is_headless then
          if ssh_password then
            vim.fn.chansend(j, ssh_password .. '\n')
            return
          end

          io.stderr:write('\r' .. vim.trim(text) .. ' ')
          io.stderr:flush()

          ---@type string?
          local input = nil
          if vim.fn.has('win32') == 1 then
            input = io.read('*l')
          else
            os.execute('stty -echo < /dev/tty 2>/dev/null')
            local f = io.open('/dev/tty', 'r')
            if f then
              input = f:read('*l')
              f:close()
            else
              input = io.read('*l')
            end
            os.execute('stty echo < /dev/tty 2>/dev/null')
          end
          io.stderr:write('\n')

          if input then
            ---@cast input string
            local sanitized = input:gsub('\r', '')
            ssh_password = sanitized
            vim.fn.chansend(j, sanitized .. '\n')
          else
            vim.fn.jobstop(j)
          end
        else
          if ssh_password then
            vim.fn.chansend(j, ssh_password .. '\n')
            return
          end
          ---@param input string?
          local function on_input(input)
            if input then
              ---@cast input string
              ssh_password = input
              vim.fn.chansend(j, input .. '\n')
            else
              vim.fn.jobstop(j)
            end
          end
          vim.ui.input({ prompt = vim.trim(text) .. ' ', secret = true }, on_input)
        end
      end)
    end
  end

  local on_exit = function(_, exit_code, _)
    code = exit_code
    is_done = true
  end

  local job_id = vim.fn.jobstart(ssh_cmd, {
    pty = true,
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
    local raw_stdout = table.concat(stdout_lines, '\n')
    local clean_stdout = string.gsub(raw_stdout, '\r', '')

    if code ~= 0 then
      if clean_stdout:match('Permission denied') or clean_stdout:match('Connection closed') then
        if prompt_count == 0 then
          ssh_password = nil
          notify(
            'Authentication failed! Please check your password or SSH keys.',
            vim.log.levels.ERROR
          )
        end
      end
    end

    return { code = code, stdout = clean_stdout }
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
  -- password prompt itself might pollute stdout from the PTY
  -- we should extract the last 2 non-empty lines
  local valid_lines = {}
  for _, line in ipairs(lines) do
    if vim.trim(line) ~= '' and not line:match('[Pp]assword:') and not line:match('passphrase') then
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
  local version_out = vim.api.nvim_exec2('version', { output = true }).output
  local nvim_version = version_out:match('NVIM (v[^\n]+)') or 'unknown'
  ---@type boolean
  local is_nightly = vim.version().prerelease

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

    echo "Installing Neovim $TARGET_VER..." >&2
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
  local uri = ssh.parse_uri(uri_str)
  notify('Connecting to ' .. uri_str .. '...')
  local os, arch = M.get_system_info(uri)

  notify('Checking remote Neovim install...')
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
    error('Remote Neovim crashed during startup')
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
