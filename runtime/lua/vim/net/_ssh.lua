-- Converted into Lua from https://github.com/cyjake/ssh-config
-- TODO (siddhantdev): deal with include directives

local nvim_on = require('vim._core.util').nvim_on
local echo_err = require('vim._core.util').echo_err
local autoinstall = require('vim.net._autoinstall')
local N_ = vim.fn.gettext

local M = {}

local whitespace_pattern = '%s'
local line_break_pattern = '[\r\n]'

--- Command that runs ssh. Tests replace it with a fake.
M.ssh_cmd = { 'ssh' }

local sock_maxlen = 103 -- Max lenth of Unix socket path. sun_path=104 on macOS, 108 on Linux.
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
  local progress = {
    kind = 'progress',
    source = 'remote-ssh',
    title = 'remote-ssh',
    _truncate = true,
  }
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
  -- `%C` is SSH's hash of (local hostname, remote host, port, user): 40 chars, unlike `%h_%p_%r`.
  -- The ssh master listens at it plus a 17-char temp suffix, which must fit `sock_maxlen`. Else
  -- (e.g. a long stdpath("cache")) no multiplexing: slower, but works.
  local mux_path = vim.fs.joinpath(mux_dir, 'mux_%C')
  if #mux_path - #'%C' + 40 + 17 > sock_maxlen then
    log().warn(('ControlPath too long, no multiplexing: %s'):format(mux_path))
    mux_path = 'none'
  end
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
  local cmd = { 'tar', '-czf', '-', '-h', '--exclude=.git' }

  -- Exclude broken symlinks (fails GNU `tar -h` #42747).
  for name, type in
    vim.fs.dir(dir, {
      depth = vim._maxint,
      skip = function(d)
        return vim.fs.basename(d) ~= '.git'
      end,
    })
  do
    if type == 'link' and not vim.uv.fs_stat(vim.fs.joinpath(dir, name)) then
      table.insert(cmd, ('--exclude=./%s'):format((name:gsub('[][*?\\]', '\\%0'))))
    end
  end

  vim.list_extend(cmd, { '-C', dir, '.' })
  local tar = vim.system(cmd, { env = env }):wait()
  if tar.code ~= 0 then
    error(('Failed to pack %s: %s'):format(dir, vim.trim(tar.stderr or '')), 0)
  end
  local script = table.concat({
    ('d="${XDG_CONFIG_HOME:-$HOME/.config}/%s"'):format(autoinstall.appname),
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
    error(('Failed to copy %s: %s'):format(dir, vim.trim(obj.stderr or '')), 0)
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
  local stdout = vim.trim(obj.stdout or '')
  if obj.code ~= 0 then
    local stderr = vim.trim(obj.stderr or '')
    error(('Failed to detect remote system info: %s'):format(stderr ~= '' and stderr or stdout), 0)
  end

  local lines = vim.split(stdout, '\n', { plain = true })
  local valid_lines = {}
  for _, line in ipairs(lines) do
    if vim.trim(line) ~= '' then
      table.insert(valid_lines, vim.trim(line))
    end
  end

  if #valid_lines < 2 then
    error(('Unexpected output from system info detection: %s'):format(stdout), 0)
  end

  ---@type string
  local os = valid_lines[#valid_lines - 1]:lower()
  ---@type string
  local arch = valid_lines[#valid_lines]:lower()

  if os:match('msys') or os:match('windows') or os:match('mingw') or os:match('cygwin') then
    error('Not implemented yet: Windows targets are not supported.', 0)
  end

  return os, arch
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
  -- TODO: Let CTRL-C cancel vim.rpcrequest(). #7546
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
  -- Fetched meanwhile, for the remote to verify the release, if it installs it.
  local get_sha256 = autoinstall.fetch_sha256s()
  local dir, url, version = autoinstall.get_release(M.get_system_info(uri))
  if config then
    report('running', 'Copying config...')
    push_config(uri, config)
  end
  local sha256, sha256_err = get_sha256(vim.fs.basename(url))
  if not sha256 and url ~= '-' then
    log().warn(sha256_err)
  end

  -- Session token, name both ends of the tunnel:
  -- - Random: avoids /tmp collisions.
  -- - relink() finds the remote session from the UI's address (the local socket name).
  local token = vim.text.hexencode(assert(vim.uv.random(4)))
  -- "nvim-ssh.<host>.<token>". Listed by :connect (serverlist()).
  -- Hostname is truncated to fit `sock_maxlen`.
  local run = vim.fn.stdpath('run')
  local max_host = sock_maxlen - #('%s/nvim-ssh..%s'):format(run, token)
  local host = uri.host:gsub('[^%w.-]', '_'):sub(1, math.max(0, max_host))
  local local_sock = ('%s/nvim-ssh.%s.%s'):format(run, host, token)
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

  --- Stops the tunnel (see `serve()` for the remote server), and cancels its forward, which lives
  --- in the ssh master.
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
    vim.uv.fs_unlink(local_sock) -- ssh leaves it, e.g. in $XDG_RUNTIME_DIR.
  end

  report('running', 'Starting remote Nvim...')
  log().debug('connect: local_sock', local_sock)
  local args = { remote_sock, dir, url, sha256 or '-', version }
  if update then
    table.insert(args, 1, '--update')
  end
  tunnel = run_script(uri, args, { ssh_args = { '-L', forward } }, on_exit)

  local shown --- @type string? Latest line of stderr, e.g. the status of `remote_ssh.sh`.
  -- Report stderr lines until NVIM_READY.
  local ok, res = pcall(tunnel.wait, tunnel, 300000, function(stdout, stderr)
    if stdout:match('NVIM_READY') then
      return true
    end
    local line = vim.trim(stderr):match('[^\n]+$') -- Skip blank lines.
    if line and line ~= shown then
      shown = line
      report('running', line)
    end
    return false
  end)

  if not ok then -- CTRL-C.
    teardown()
    error(res, 0)
  end
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
    error(err, 0)
  end

  report('success', ('Connected to %s'):format(uri_str))
  nvim_on('VimLeavePre', nil, teardown)

  return local_sock, teardown
end

--- Asks to confirm, then connects. Shows E6101 on failure.
---
--- @param uri_str string
--- @param chan? integer UI to connect: fails (and stops the session) if it detached meanwhile.
--- @return string? local_socket Path to the local forwarded socket, or nil if declined,
---   interrupted (CTRL-C), or failed.
--- @return fun()? teardown Stops this session's tunnel. Other sessions sharing the SSH master are
---   unaffected.
function M.connect(uri_str, chan)
  if vim.fn.executable(M.ssh_cmd[1]) == 0 then
    echo_err(N_('E6101: SSH connection failed: Not found on $PATH: %s'):format(M.ssh_cmd[1]))
    return nil
  end
  local lines = {
    ('Connect to %s'):format(uri_str),
    ('- Installs Nvim (if needed) to ~/%s/'):format(autoinstall.data_dir),
  }
  local config_dir = vim.fn.stdpath('config') --[[@as string]]
  local config = vim.fn.isdirectory(config_dir) == 1 and config_dir or nil
  if config then
    local copy = ('- Overwrites ~/.config/%s/ with your local %s/'):format(
      autoinstall.appname,
      vim.fn.fnamemodify(config, ':~')
    )
    table.insert(lines, copy)
  end
  local prerelease = vim.version().prerelease ~= nil
  -- "(U)pdate": refreshes the nightly, and runs it instead of `$PATH` nvim.
  local choices = prerelease and '&Yes\n&Update Nvim\n&No' or '&Yes\n&No'
  local choice = vim.fn.confirm(('%s\n'):format(table.concat(lines, '\n')), choices, 1, 'Question')
  local update = prerelease and choice == 2
  if choice ~= 1 and not update then
    return nil
  end
  local report = new_progress_report()
  local ok, local_sock, teardown = pcall(connect, uri_str, chan, report, update, config)
  if not ok and local_sock == 'interrupted' then
    report('failed', ('Interrupted connecting to %s'):format(uri_str))
    return nil
  elseif not ok then
    report('failed', ('Failed to connect to %s'):format(uri_str))
    echo_err(N_('E6101: SSH connection failed: %s'):format(local_sock))
    return nil
  end
  return local_sock, teardown
end

--- Calls API `method` on the server at `sock`. Returns its result, or nil if no answer.
---@param sock string
---@param method string
---@return any
local function request(sock, method, ...)
  local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true, trust = false })
  if not ok or chan == 0 then
    return nil
  end
  ---@cast chan integer
  local res = { pcall(vim.rpcrequest, chan, { timeout = 5000 }, method, ...) }
  pcall(vim.fn.chanclose, chan)
  return res[1] and res[2] or nil
end

--- Gets server info, or nil if no answer.
---@param sock string
---@return [integer, integer]?
local function server_info(sock)
  return request(sock, 'nvim_eval', '[getpid(), v:useractive]')
end

--- Called by `:connect {addr}` on a server: if UI is connected via tunnel (see `serve()`), links
--- the session to the server at `addr`, so UI can reconnect through the same tunnel. On attach,
--- that server detaches other UIs (":%detach"), whose connections presumably dropped silently (sshd
--- may not notice for hours), which would limit the screen size.
---@param chan_addr string UI-local tunnel address (nvim_chan_set()). "…/nvim-ssh.<host>.<token>"
---@param addr string Socket path.
---@return boolean relinked
function M.relink(chan_addr, addr)
  local token = chan_addr:match('/nvim%-ssh%.[^/]*%.(%x+)$')
  if not token then
    return false
  end
  local sock = ('/tmp/nvim-remote.%s/nvim.sock'):format(token)
  local stat = vim.uv.fs_lstat(sock)
  if not (stat and stat.type == 'link' and stat.uid == vim.uv.getuid()) then
    return false
  end
  -- Atomic, so the tunnel always finds a server at `sock`.
  local tmp = ('%s.%d'):format(sock, vim.fn.getpid())
  assert(vim.uv.fs_symlink(addr, tmp))
  assert(vim.uv.fs_rename(tmp, sock))
  request(addr, 'nvim_create_autocmd', 'UIEnter', {
    once = true,
    -- Scheduled: UILeave (of the detached UIs) can't fire during UIEnter, even if nested.
    command = [[lua vim.schedule(function() vim.cmd('silent %detach') end)]],
  })
  return true
end

--- Runs on the remote host: serves the session at `sock`, a symlink to a new server (or another one,
--- see `relink()`), and supervises the server it links to, following `:restart` (which re-binds the
--- server's address). On a dropped connection, the new server stays running if it has user activity
--- (|v:useractive|).
---
--- PROTOCOL: `remote_ssh.sh` of other (older) Nvim versions calls this, so keep it compatible, or
--- extend it with an `opts` param (e.g. a protocol version):
--- - Called as `nvim … +"lua require('vim.net._ssh').serve(sock)" +qa!`, with stdin from ssh.
--- - Creates the dir of `sock`, which must not exist (for security), with mode 0700.
--- - Prints "NVIM_READY" once the server listens, or "NVIM_CRASHED".
--- - Returns when stdin closes (ssh disconnect) or the server disappears.
--- - On exit (also SIGTERM, SIGHUP): stops (SIGTERM) the new server if `sock` still links to it and
---   it has no user activity, and removes the dir.
---@param sock string
function M.serve(sock)
  local dir = vim.fs.dirname(sock)
  -- Fresh private dir (0700): fails if it exists, so nobody can plant a socket.
  assert(vim.uv.fs_mkdir(dir, 448))
  -- Address of the new server, where `serverlist()` finds it, also after the session: in
  -- stdpath("run"), or its parent if that is the tempdir of this Nvim (removed on exit).
  local run = vim.fn.stdpath('run')
  local run_dir = vim.env.XDG_RUNTIME_DIR and run or vim.fs.dirname(run)
  local addr = ('%s/nvim-remote.%s'):format(run_dir, vim.text.hexencode(assert(vim.uv.random(8))))
  -- Not a peer (`serverlist()`) of the server.
  vim.fn.serverstop(vim.v.servername)

  -- No pty, so no SIGHUP when ssh disconnects: stdin EOF instead (see `run_script()`).
  local disconnected = false
  local stdin = assert(vim.uv.new_pipe())
  stdin:open(0)
  stdin:read_start(function(_, data)
    disconnected = disconnected or data == nil
  end)

  -- Cleanup when Nvim exits (also SIGTERM/SIGHUP).
  nvim_on('VimLeavePre', nil, function()
    local info = vim.uv.fs_readlink(sock) == addr and server_info(sock)
    if info and info[2] == 0 then
      -- SIGTERM (unlike `:qall!`) preserves swap files.
      vim.uv.kill(info[1], 'sigterm')
      vim.wait(5000, function()
        return vim.uv.kill(info[1], 0) ~= 0
      end, 50)
    end
    vim.fs.rm(dir, { recursive = true, force = true })
    stdin:close() -- Release stdin handle, else EXITFREE build will complain.
  end)

  vim.env.__NVIM_STARTREASON = 'remote-ssh'
  vim.env.NVIM_APPNAME = autoinstall.appname
  assert(vim.uv.fs_symlink(addr, sock))
  local exited = false
  -- --embed: Waits for the UI to attach before sourcing the config.
  local job = vim.fn.jobstart({ vim.v.progpath, '--embed', '--listen', addr }, {
    detach = true, -- Not stopped when this Nvim exits (see above).
    stdin = 'null',
    on_stderr = function(_, data)
      io.stderr:write(table.concat(data, '\n'))
    end,
    on_exit = function()
      exited = true
    end,
  })
  vim.wait(vim._maxint, function()
    return disconnected or exited or vim.uv.fs_stat(sock) ~= nil
  end, 50)
  local pid = not exited and vim.fn.jobpid(job) or nil --- @type integer? Server that `sock` links to.
  io.stdout:write(pid and 'NVIM_READY\n' or 'NVIM_CRASHED\n')
  io.stdout:flush()

  -- Supervises (polls every 1s) the server that `sock` links to, until ssh disconnects. Follows
  -- `:connect` (see `relink()`), and `:restart` (which re-binds the server's address).
  while pid and not disconnected do
    local cur, target = pid, vim.uv.fs_readlink(sock)
    vim.wait(vim._maxint, function()
      return disconnected or vim.uv.kill(cur, 0) ~= 0 or vim.uv.fs_readlink(sock) ~= target
    end, 1000)
    if not disconnected then
      local info = server_info(sock)
      pid = info and info[1]
    end
  end
end

return M
