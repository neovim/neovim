-- Converted into Lua from https://github.com/cyjake/ssh-config
-- TODO (siddhantdev): deal with include directives

local nvim_on = require('vim._core.util').nvim_on

local M = {}

local whitespace_pattern = '%s'
local line_break_pattern = '[\r\n]'

--- Command that runs ssh. Tests replace it with a fake.
M.ssh_cmd = { 'ssh' }

--- |$NVIM_APPNAME| of the remote Nvim. Remote-ssh owns its dirs, e.g. `push_config()` replaces the
--- config dir.
local appname = 'nvim-remote'

--- Remote-ssh data dir, relative to the remote `$HOME`.
local remote_data_dir = ('.local/share/%s'):format(appname)

local _log --- @type vim.Log?

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
---@field alias string Host alias from ssh config.
---@field hostname? string Resolved Hostname directive.
---@field user? string User directive.
---@field port? string Port directive.
---@field identity_file? string IdentityFile directive.

---@param text string The ssh configuration which needs to be parsed.
---@return vim.net.SshHost[] The parsed host configurations.
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
      error(('Unexpected line break at line %d'):format(line))
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
      error(('Unexpected line break at line %d'):format(line))
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
          if val:lower() == 'host' and ind + 1 <= #values and is_valid(assert(values[ind + 1])) then
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
        local field = ({
          hostname = 'hostname',
          user = 'user',
          port = 'port',
          identityfile = 'identity_file',
        })[lp]
        local val = (type(node.value) == 'string' and node.value or nil) --[[@as string?]]
        if field and val then
          -- As ssh: the first obtained value wins.
          for _, h in ipairs(current_hosts) do
            h[field] = h[field] or val
          end
        end
      end
    end
  end
  flush()

  return hosts
end

---@param filename string
---@return vim.net.SshHost[] The host configurations in the file.
function M.parse_config(filename)
  local text = vim.fn.readblob(filename)
  return M.parse_ssh_config(text)
end

---@param filename? string Path to the SSH config file. Defaults to `~/.ssh/config`.
---@return string[] The hostnames configured in the SSH config file. Note: This does not process
---                 `Include` directives.
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

--- Lazy `vim.log` instance for the remote-ssh feature. Writes to `stdpath('log')/remote-ssh.log`.
---@return vim.Log
local function log()
  if not _log then
    _log = vim.log.new({ name = 'remote-ssh', level = vim.log.levels.INFO })
  end
  return _log
end

--- Returns a function that shows (and logs) connect status as one |progress-message|, updated in
--- place.
---@return fun(status: 'running'|'success'|'failed', msg: string)
local function new_progress_report()
  local progress = { kind = 'progress', source = 'remote-ssh', title = 'remote-ssh' }
  return function(status, msg)
    if status == 'failed' then
      log().error(msg)
    else
      log().info(msg)
    end
    progress.status = status
    progress.id = vim.api.nvim_echo({ { msg } }, status ~= 'running', progress)
    vim.cmd.redraw()
  end
end

--- Builds a command for the remote host identified by `ssh_uri`.
---
--- `ssh_args` are inserted before the target; `remote_cmd` is appended after the target.
---
---@param ssh_uri vim.Uri & {host:string, config?:string}
---@param opts? { ssh_args?: string[], remote_cmd?: string[] }
---@return string[]
local function get_ssh_cmd(ssh_uri, opts)
  opts = opts or {}
  local mux_dir = vim.fs.joinpath(vim.fn.stdpath('cache') --[[@as string]], 'ssh')
  vim.fn.mkdir(mux_dir, 'p')
  -- `%C` is SSH's hash of (local hostname, remote host, port, user). Its fixed length keeps the
  -- ControlPath socket under the 104-byte `sun_path` limit, which the raw `%h_%p_%r` name plus a
  -- long base dir can exceed. See also |vim.fs.slug()|.
  local mux_path = vim.fs.joinpath(mux_dir, 'mux_%C')
  local ssh_cmd = vim.list_extend(vim.list_slice(M.ssh_cmd), {
    '-T',
    -- Fails instead of prompting for a password or key passphrase.
    '-o',
    'BatchMode=yes',
    '-o',
    'ControlMaster=auto',
    '-o',
    ('ControlPath=%s'):format(mux_path),
    '-o',
    'ControlPersist=10m',
    -- Workaround "Cannot execute command-line and remote command" if `RemoteCommand` is in user
    -- ssh_config.
    '-o',
    'RemoteCommand=none',
  })
  local target = ssh_uri.user and ('%s@%s'):format(ssh_uri.user, ssh_uri.host) or ssh_uri.host
  local dest = ssh_uri.port and { '-p', tostring(ssh_uri.port) } or {}
  -- Ends option parsing, so a target like `-oProxyCommand=x` is not taken as an option.
  vim.list_extend(dest, { '--', target })

  -- Effective ssh_config. Once per `ssh_uri`: `ssh -G` evaluates e.g. `Match exec`, or DNS for
  -- `CanonicalizeHostname`.
  if not ssh_uri.config then
    local cmd = vim.list_extend(vim.list_slice(M.ssh_cmd), { '-G', unpack(dest) })
    ssh_uri.config = vim.system(cmd, { text = true }):wait().stdout or ''
  end
  local config = ('\n%s'):format(ssh_uri.config)
  -- At the default `ask`, BatchMode fails on an unknown host key. `accept-new` records it instead,
  -- as if the user typed "yes"; a changed key still fails. An explicit ssh_config value is kept.
  if config:match('\nstricthostkeychecking (%S+)') == 'ask' then
    vim.list_extend(ssh_cmd, { '-o', 'StrictHostKeyChecking=accept-new' })
  end
  -- At the default 0, a dropped connection (e.g. after sleep) leaves the session frozen until TCP
  -- gives up. 15s, times the default `ServerAliveCountMax` 3: ends the session within 45s.
  if config:match('\nserveraliveinterval (%S+)') == '0' then
    vim.list_extend(ssh_cmd, { '-o', 'ServerAliveInterval=15' })
  end
  if opts.ssh_args then
    vim.list_extend(ssh_cmd, opts.ssh_args)
  end
  vim.list_extend(ssh_cmd, dest)

  if opts.remote_cmd then
    vim.list_extend(ssh_cmd, opts.remote_cmd)
  end

  return ssh_cmd
end

--- Runs the local `$VIMRUNTIME/scripts/remote_ssh.sh` on the remote host. The script goes to
--- `sh -s` over stdin, so the remote login shell (any shell) parses only `args`. Stdin stays open:
--- its EOF tells the remote (`M.serve()`) that ssh disconnected.
---
---@param uri vim.Uri & {host:string}
---@param args string[] Script args: plain words, which no shell expands, so they need no quoting.
---@param opts? { ssh_args?: string[] }
---@param on_exit? fun(out: vim.SystemCompleted)
---@return vim.SystemObj
local function run_script(uri, args, opts, on_exit)
  opts = opts or {}
  for _, arg in ipairs(args) do
    assert(arg:match('^[%w%-%._/:]+$'), ('not a plain word: %s'):format(arg))
  end
  local script =
    vim.fn.readblob(vim.fs.joinpath(assert(vim.env.VIMRUNTIME), 'scripts', 'remote_ssh.sh'))
  local remote_cmd = vim.list_extend({ 'sh', '-s', '--' }, args)
  local ssh_cmd = get_ssh_cmd(uri, { ssh_args = opts.ssh_args, remote_cmd = remote_cmd })
  log().debug('run_script: running', ssh_cmd)
  local obj = vim.system(ssh_cmd, { stdin = true }, on_exit)
  -- Write the script to stdin, `sh -s -` executes it.
  -- Stdin stays open and the remote Nvim inherits it (see remote_ssh.sh).
  obj:write(script)
  return obj
end

--- Replaces the remote config dir (`$XDG_CONFIG_HOME/nvim-remote/`) with a copy of `dir`, without
--- `.git/`. Plugins are not copied: the config's plugin manager (e.g. |vim.pack|) installs them.
---
---@param uri vim.Uri & {host:string}
---@param dir string Local config dir.
local function push_config(uri, dir)
  local env = { COPYFILE_DISABLE = '1' } -- No macOS `._*` files.
  -- -h: Copies symlink targets (e.g. links made by a dotfiles manager).
  local tar = vim
    .system({ 'tar', '-czf', '-', '-h', '--exclude=.git', '-C', dir, '.' }, { env = env })
    :wait()
  if tar.code ~= 0 then
    error(('Failed to pack %s: %s'):format(dir, tar.stderr))
  end
  local script = table.concat({
    ('d="${XDG_CONFIG_HOME:-$HOME/.config}/%s"'):format(appname),
    -- Sanity check before `rm -rf`. Literal, so a bad `appname` (e.g. empty) can't pass it.
    'case "$d" in */nvim-remote) ;; *) echo "Refusing to replace $d" >&2; exit 1 ;; esac',
    'rm -rf "$d"',
    'mkdir -p "$d"',
    'tar -xzf - -C "$d"',
  }, ' && ')
  -- Quoted for the remote login shell (any shell, e.g. fish), which passes it to `sh` verbatim.
  local ssh_cmd = get_ssh_cmd(uri, { remote_cmd = { 'sh', '-c', ("'%s'"):format(script) } })
  log().debug('push_config: running', ssh_cmd)
  local obj = vim.system(ssh_cmd, { stdin = tar.stdout }):wait(300000)
  if obj.code ~= 0 then
    error(('Failed to copy %s: %s'):format(dir, obj.stderr))
  end
end

--- Gets the operating system and architecture from the remote system.
---
---@param uri vim.Uri & {host:string}
---@return string os, string arch
function M.get_system_info(uri)
  local ssh_cmd = get_ssh_cmd(uri, { remote_cmd = { 'uname -s && uname -m' } })
  log().debug('get_system_info: running', ssh_cmd)

  local obj = vim.system(ssh_cmd, { text = true }):wait(300000)
  log().debug('get_system_info: code', obj.code, 'stdout', obj.stdout, 'stderr', obj.stderr)
  if obj.code ~= 0 then
    local detail = obj.stderr ~= '' and obj.stderr or obj.stdout
    error(('Failed to detect remote system info: %s'):format(detail))
  end

  local lines = vim.split(vim.trim(obj.stdout or ''), '\n', { plain = true })
  local valid_lines = {}
  for _, line in ipairs(lines) do
    if vim.trim(line) ~= '' then
      table.insert(valid_lines, vim.trim(line))
    end
  end

  if #valid_lines < 2 then
    error(('Unexpected output from system info detection: %s'):format(obj.stdout))
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

--- Gets the Nvim release URL/dir/version based on the local version + remote platform.
---
---@param os string
---@param arch string
---@return string dir Install dir, relative to the remote `$HOME`, e.g.
---   `.local/share/nvim-remote/releases/v0.12.0-linux-x86_64`. Per platform too: a shared `$HOME`
---   may be mounted on remote hosts of different platforms.
---@return string url Release archive.
---@return string version Minimum version of an `nvim` on the remote `$PATH` to use instead, e.g.
---   `v0.12.0`, or `v0.13.0-dev` (any build) for a prerelease.
local function get_release(os, arch)
  local ver = vim.version()
  local base = ('v%d.%d.%d'):format(ver.major, ver.minor, ver.patch)
  -- Prerelease: installs the current nightly once per version, until "Update" (see `M.connect()`).
  local tag = ver.prerelease and 'nightly' or base
  local install_name = ver.prerelease and ('nightly-%s'):format(base) or base

  local os_map = { linux = 'linux', darwin = 'macos' }
  local arch_map = { x86_64 = 'x86_64', aarch64 = 'arm64', arm64 = 'arm64' }

  local target_os = os_map[os]
  local target_arch = arch_map[arch]
  if not target_os or not target_arch then
    error(('Unsupported OS/Arch combination: %s/%s'):format(os, arch))
  end

  local release_name = ('nvim-%s-%s'):format(target_os, target_arch)
  local release_url = ('https://github.com/neovim/neovim/releases/download/%s/%s.tar.gz'):format(
    tag,
    release_name
  )
  local dir = ('%s/releases/%s-%s-%s'):format(remote_data_dir, install_name, target_os, target_arch)
  return dir, release_url, ver.prerelease and ('%s-%s'):format(base, ver.prerelease) or base
end

--- Checks that the Nvim server at `addr` answers a request.
---@param addr string
---@return boolean
local function answers(addr)
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', addr, {
    rpc = true,
    trust = false, -- Security: remote is untrusted, don't allow API requests from it.
  })
  if not ok or chan == 0 then
    return false
  end
  ---@cast chan integer
  local answered = pcall(vim.rpcrequest, chan, { timeout = 10000 }, 'nvim_get_api_info')
  pcall(vim.fn.chanclose, chan)
  return answered
end

--- See `M.connect()`.
---@param chan? integer
---@param report fun(status: 'running'|'success'|'failed', msg: string)
---@param update boolean Re-installs the release, and runs it even if a `$PATH` nvim qualifies.
---@param config? string Local config dir to copy (see `push_config()`).
local function connect(uri_str, chan, report, update, config)
  local uri = vim.uri.parse(uri_str)
  if not (uri and uri.host and uri.host ~= '') then
    error(('No host in SSH URI: %s'):format(uri_str), 0)
  end
  ---@cast uri vim.Uri & {host:string}
  report('running', ('Connecting to %s...'):format(uri_str))
  local dir, url, version = get_release(M.get_system_info(uri))
  if config then
    report('running', 'Copying config...')
    push_config(uri, config)
  end

  local local_sock = ('%s_remote_nvim.sock'):format(vim.fn.tempname())
  local token = vim.text.hexencode(assert(vim.uv.random(8)))
  local remote_sock = ('/tmp/nvim-remote.%s/nvim.sock'):format(token)

  local forward = ('%s:%s'):format(local_sock, remote_sock)
  local cleaned_up = false
  local tunnel --- @type vim.SystemObj

  --- Stops this (local) server when the session ends (remote quit, crash, lost connection),
  --- unless it is still in use: a UI is attached or a buffer is modified.
  --- @param out vim.SystemCompleted
  local function on_exit(out)
    vim.schedule(function()
      -- Without NVIM_READY there was no session (`connect()` fails instead).
      if cleaned_up or not (out.stdout or ''):match('NVIM_READY') then
        return
      end
      local modified = vim.iter(vim.api.nvim_list_bufs()):any(function(buf)
        return vim.bo[buf].modified
      end)
      if modified or #vim.api.nvim_list_uis() > 0 then
        log().info(('session ended: %s; local server in use, keeping it'):format(uri_str))
        return
      end
      log().info(('session ended: %s; stopping local server'):format(uri_str))
      -- Not `qall!`, so a running :terminal job keeps this server alive.
      local ok, err = pcall(vim.cmd.qall)
      if not ok then
        log().info(('local server kept: %s'):format(err))
      end
    end)
  end

  --- Stops the tunnel (and thus the remote server), and cancels its forward, which lives in the ssh
  --- master.
  local function teardown()
    if cleaned_up then
      return
    end
    cleaned_up = true
    log().info(('teardown: stopping tunnel for %s'):format(uri_str))
    if not tunnel:is_closing() then
      tunnel:kill('sigterm')
    end
    -- Waits for the tunnel to close its stdio handles.
    tunnel:wait(1000)
    vim.system(get_ssh_cmd(uri, { ssh_args = { '-O', 'cancel', '-L', forward } })):wait(1000)
  end

  report('running', 'Starting remote Nvim...')
  log().debug('connect: local_sock', local_sock)
  local args = { remote_sock, dir, url, version }
  if update then
    table.insert(args, 1, '--update')
  end
  tunnel = run_script(uri, args, { ssh_args = { '-L', forward } }, on_exit)
  local res = tunnel:wait(300000, function(stdout)
    return stdout:match('NVIM_READY') ~= nil
  end)
  log().debug('connect: tunnel stdout', res.stdout, 'stderr', res.stderr)

  local err --- @type string?
  if res.code then
    -- The tunnel exited (or timed out).
    err = (res.stdout or ''):match('NVIM_CRASHED') and 'Remote Nvim crashed during startup'
      or res.code == 124 and 'Timed out waiting for the remote Nvim'
      or 'SSH tunnel exited before the remote Nvim was ready'
    local detail = vim.trim(res.stderr or '')
    err = detail ~= '' and ('%s: %s'):format(err, detail) or err
  elseif not answers(local_sock) then
    -- sshd may refuse the forward (e.g. `AllowStreamLocalForwarding no`) but run the script.
    err = 'Remote Nvim is not reachable through the SSH forward'
  elseif
    chan
    and not vim.iter(vim.api.nvim_list_uis()):any(function(ui)
      return ui.chan == chan
    end)
  then
    err = ('UI detached: channel %d'):format(chan)
  end
  if err then
    log().error(err, 'code', res.code, 'stderr', res.stderr)
    teardown()
    error(err)
  end

  report('success', ('Connected to %s'):format(uri_str))
  nvim_on('VimLeavePre', nil, teardown)

  return local_sock, teardown
end

--- Asks to confirm, then connects.
---
--- @param uri_str string
--- @param chan? integer UI to connect: fails (and stops the session) if it detached meanwhile.
--- @return string? local_socket Path to the local forwarded socket, or nil if declined.
--- @return fun()? teardown Stops this session's tunnel (and thus the remote server). Other sessions
---   sharing the SSH master are unaffected.
function M.connect(uri_str, chan)
  local msg = ('This will install Nvim on %s (in ~/%s/), if missing.\n'):format(
    uri_str,
    remote_data_dir
  )
  local config_dir = vim.fn.stdpath('config') --[[@as string]]
  local config = vim.fn.isdirectory(config_dir) == 1 and config_dir or nil
  if config then
    msg = ('%sThis will overwrite the remote ~/.config/%s/ with a copy of %s/.\n'):format(
      msg,
      appname,
      vim.fn.fnamemodify(config, ':~')
    )
  end
  local prerelease = vim.version().prerelease ~= nil
  -- "(U)pdate": refreshes the nightly, and runs it instead of `$PATH` nvim.
  local choices = prerelease and 'Connect? &Yes\n&Update Nvim\n&No' or 'Connect? &Yes\n&No'
  local choice = vim.fn.confirm(msg, choices, 1, 'Question')
  local update = prerelease and choice == 2
  if choice ~= 1 and not update then
    return nil
  end
  local report = new_progress_report()
  local ok, local_sock, teardown = pcall(connect, uri_str, chan, report, update, config)
  if not ok then
    report('failed', ('Failed to connect to %s'):format(uri_str))
    error(local_sock, 0)
  end
  return local_sock, teardown
end

--- Gets the PID of the server at `sock`, or nil if none answers.
---@param sock string
---@return integer?
local function server_pid(sock)
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true, trust = false })
  if not ok or chan == 0 then
    return nil
  end
  ---@cast chan integer
  local _, pid = pcall(vim.rpcrequest, chan, { timeout = 5000 }, 'nvim_call_function', 'getpid', {})
  pcall(vim.fn.chanclose, chan)
  return type(pid) == 'number' and pid --[[@as integer]] or nil
end

--- Runs on the remote host: starts the server at `sock` and supervises it, following a `:restart`ed
--- server (which re-binds `sock`).
---
--- PROTOCOL: `remote_ssh.sh` of other (older) Nvim versions calls this, so keep it compatible, or
--- extend it with an `opts` param (e.g. a protocol version):
--- - Called as `nvim … +"lua require('vim.net._ssh').serve(sock)" +qa!`, with stdin from ssh.
--- - Creates the dir of `sock`, which must not exist (for security), with mode 0700.
--- - Prints "NVIM_READY" once the server listens, or "NVIM_CRASHED".
--- - Returns when stdin closes (ssh disconnect) or the server disappears.
--- - On exit (also SIGTERM, SIGHUP): stops the server (SIGTERM) and removes the dir.
---@param sock string
function M.serve(sock)
  local dir = vim.fs.dirname(sock)
  -- Fresh private dir (0700): fails if it exists, so nobody can plant a socket.
  assert(vim.uv.fs_mkdir(dir, 448))
  -- Not a peer (`serverlist()`) of the server.
  vim.fn.serverstop(vim.v.servername)

  -- No pty, so no SIGHUP when ssh disconnects: stdin EOF instead (see `run_script()`).
  local disconnected = false
  local stdin = assert(vim.uv.new_pipe())
  stdin:open(0)
  stdin:read_start(function(_, data)
    disconnected = disconnected or data == nil
  end)

  local pid --- @type integer? Current server.
  -- Cleanup: stops the server and removes `dir` when Nvim exits (SIGTERM/SIGHUP).
  nvim_on('VimLeavePre', nil, function()
    local cur = pid and (server_pid(sock) or pid)
    if cur then
      -- SIGTERM (unlike `:qall!`) preserves swap files.
      vim.uv.kill(cur, 'sigterm')
      vim.wait(5000, function()
        return vim.uv.kill(cur, 0) ~= 0
      end, 50)
    end
    vim.fs.rm(dir, { recursive = true, force = true })
    stdin:close() -- Release stdin handle, else EXITFREE build will complain.
  end)

  vim.env.__NVIM_STARTREASON = 'remote-ssh'
  vim.env.NVIM_APPNAME = appname
  -- --embed: Waits for the UI to attach (at `sock`) before sourcing the config.
  local server = vim.system({ vim.v.progpath, '--embed', '--listen', sock }, {
    stdout = false,
    stderr = function(_, data)
      io.stderr:write(data or '')
    end,
  })
  vim.wait(vim._maxint, function()
    return disconnected or server:is_closing() or vim.uv.fs_stat(sock) ~= nil
  end, 50)
  io.stdout:write(server:is_closing() and 'NVIM_CRASHED\n' or 'NVIM_READY\n')
  io.stdout:flush()

  pid = server.pid
  -- Supervises the server (polls every 1s) at `sock` until ssh disconnects, including a new server after `:restart`.
  while pid and not disconnected do
    local cur = pid
    vim.wait(vim._maxint, function()
      return disconnected or vim.uv.kill(cur, 0) ~= 0
    end, 1000)
    if not disconnected then
      -- The server exited. A `:restart`ed server re-binds `sock`.
      pid = server_pid(sock)
    end
  end
end

return M
