local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local parser = require('vim.net._ssh')
local describe, it = t.describe, t.it
local before_each = t.before_each
local clear = n.clear
local eq = t.eq
local is_os = t.is_os
local skip = t.skip

describe('parse_ssh_config()', function()
  it('parses SSH configuration strings', function()
    local config = [[
      Host *
        ConnectTimeout 10
        ServerAliveInterval 60
        ServerAliveCountMax 3
        # Use a specific key for any host not otherwise specified
        # IdentityFile ~/.ssh/id_rsa

      Host=dev
        HostName=dev.example.com
        User=devuser
        Port=2222
        IdentityFile=~/.ssh/id_rsa_dev

      Host prod test
        HostName 198.51.100.10
        User admin
        Port 22
        IdentityFile ~/.ssh/id_rsa_prod
        ForwardAgent yes

      Host test
        IdentitiesOnly yes

      Host "quoted string"
        User quote
        Port 22

      Match host foo host gh
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_rsa_github
        IdentitiesOnly yes
    ]]

    local hosts = parser.parse_ssh_config(config)
    eq(
      { 'dev', 'prod', 'test', 'quoted string', 'foo', 'gh' },
      vim.tbl_map(function(h)
        return h.alias
      end, hosts)
    )
    eq('dev.example.com', hosts[1].hostname)
    eq('devuser', hosts[1].user)
    eq('2222', hosts[1].port)
    eq('198.51.100.10', hosts[2].hostname)
    eq('admin', hosts[2].user)
  end)

  it('ignores repeated and trailing separators', function()
    -- Runs of separators between values, and trailing whitespace before the line break, must not
    -- yield empty aliases.
    local config = table.concat({
      'Host  alpha   beta ',
      '  HostName example.com',
      '',
    }, '\n')

    eq(
      { 'alpha', 'beta' },
      vim.tbl_map(function(h)
        return h.alias
      end, parser.parse_ssh_config(config))
    )
  end)

  it('fails when a quote is not closed', function()
    local config = [[
      Host prod dev "test prod my
        HostName 198.51.100.10
        User admin
        Port 22
        IdentityFile ~/.ssh/id_rsa_prod
        ForwardAgent yes
    ]]

    local ok, _ = pcall(parser.parse_ssh_config, config)
    eq(false, ok)
  end)

  it('fails when the line ends with a single backslash', function()
    local config = [[
      Host prod test
        HostName 198.51.100.10
        User admin\
        Port 22
        IdentityFile ~/.ssh/id_rsa_prod
        ForwardAgent yes
    ]]

    local ok, _ = pcall(parser.parse_ssh_config, config)
    eq(false, ok)
  end)
end)

describe('remote-ssh', function()
  local fake_dir --- @type string

  --- Makes `vim.net._ssh` run a fake `ssh` (fixtures/fake-ssh.lua), stubs `confirm()` (calls in
  --- `_G.confirm_log`), and records progress messages in `_G.progress_log`. The local config dir is
  --- `{fake_dir}/config/nvim`, absent unless the test creates it.
  ---
  --- @param behavior? table Optional fields:
  ---   - `confirm`: Result of `confirm()`.
  ---   - `ssh_config`, `uname`: Output of `ssh -G`, of `uname -s && uname -m`.
  ---   - `digest`: Digest of the release archive (any platform) per the GitHub API (a file), by
  ---     default `sha256:aaa…`. `false`: The API fails.
  ---   - `tunnel`: The tunnel (`-L`) command, by default `{ serve = true }`:
  ---     - `serve`: Serves a headless Nvim at the `-L` socket, then prints NVIM_READY.
  ---     - `stdout`, `stderr`: Printed.
  ---     - `exit`: Exit code. Else runs until the served Nvim exits, or until killed.
  local function setup_fake_ssh(behavior)
    behavior = behavior or {}
    local dir = vim.fs.abspath(t.tmpname(false))
    fake_dir = dir
    n.mkdir_p(dir)
    t.finally(function()
      n.rmdir(dir)
    end)
    local nvim_prog = vim.fs.abspath(n.nvim_prog)
    local config = vim.json.encode({
      dir = fake_dir,
      nvim_prog = nvim_prog,
      ssh_config = behavior.ssh_config or 'stricthostkeychecking ask\nserveraliveinterval 0\n',
      uname = behavior.uname or 'Linux\nx86_64\n',
      tunnel = behavior.tunnel or { serve = true },
    })
    local fake_ssh = vim.fs.abspath('test/functional/fixtures/fake-ssh.lua')
    local release = ('%s/release.json'):format(dir)
    -- Fake GitHub API release (see `fetch_sha256s()`): every platform's archive has the digest.
    if behavior.digest ~= false then
      local assets = vim
        .iter({ 'linux-x86_64', 'linux-arm64', 'macos-arm64', 'macos-x86_64' })
        :map(function(platform)
          local digest = behavior.digest or ('sha256:%s'):format(('a'):rep(64))
          return { name = ('nvim-%s.tar.gz'):format(platform), digest = digest }
        end)
        :totable()
      t.write_file(release, vim.json.encode({ assets = assets }))
    end

    n.exec_lua(function(ssh_cmd, choice)
      require('vim.net._ssh').ssh_cmd = ssh_cmd
      require('vim.net._autoinstall').release_api = ('file://%s'):format(release)
      vim.env.XDG_CONFIG_HOME = ('%s/config'):format(dir)
      _G.confirm_log = {}
      vim.fn.confirm = function(...)
        table.insert(_G.confirm_log, { ... })
        return choice
      end

      _G.progress_log = {} -- Records progress messages.
      vim.api.nvim_create_autocmd('Progress', {
        group = vim.api.nvim_create_augroup('test.remote-ssh', {}),
        pattern = 'remote-ssh',
        callback = function(ev)
          local msg = ('%s: %s'):format(ev.data.status, table.concat(ev.data.text))
          table.insert(_G.progress_log, msg)
        end,
      })
    end, { nvim_prog, '-l', fake_ssh, config }, behavior.confirm or 1)
  end

  --- Checks that the fake tunnel process has exited.
  local function tunnel_exited()
    local pid = assert(tonumber(t.read_file(('%s/tunnel.pid'):format(fake_dir))))
    return vim.uv.kill(pid, 0) ~= 0
  end

  before_each(function()
    clear()
  end)

  it('get_system_info() detects OS and arch', function()
    for _, c in ipairs({
      { 'Linux\nx86_64\n', { 'linux', 'x86_64' } },
      { 'Darwin\narm64\n', { 'darwin', 'arm64' } },
    }) do
      setup_fake_ssh({ uname = c[1] })
      eq(
        c[2],
        n.exec_lua(function()
          return { require('vim.net._ssh').get_system_info({ host = 'server' }) }
        end)
      )
    end

    setup_fake_ssh({ uname = 'MSYS_NT-10.0-19045\nx86_64\n' })
    t.matches(
      'Windows targets are not supported',
      t.pcall_err(n.exec_lua, function()
        require('vim.net._ssh').get_system_info({ host = 'server' })
      end)
    )
  end)

  it('connect() returns the local socket of the tunnel', function()
    skip(is_os('win'), 'remote-ssh is POSIX-only')
    setup_fake_ssh()
    local sock, logfile, progress = unpack(n.exec_lua([[
      local logfile = vim.fs.joinpath(vim.fn.stdpath('log'), 'remote-ssh.log')
      os.remove(logfile)
      local sock, teardown = require('vim.net._ssh').connect('ssh://user@test-server')
      teardown()
      return { sock, logfile, _G.progress_log }
    ]]))

    assert(sock:match('_remote_nvim%.sock$'))
    eq({
      'running: Connecting to ssh://user@test-server...',
      'running: Starting remote Nvim...',
      'success: Connected to ssh://user@test-server',
    }, progress)
    local msg = 'This will install Nvim on ssh://user@test-server (in ~/.local/share/nvim-remote/), '
      .. 'if missing.\n'
    local choices = n.exec_lua('return vim.version().prerelease')
        and 'Connect? &Yes\n&Update Nvim\n&No'
      or 'Connect? &Yes\n&No'
    eq({ { msg, choices, 1, 'Question' } }, n.exec_lua('return _G.confirm_log'))
    t.matches('Connected to ssh://user@test%-server', t.read_file(logfile))
    local tunnel_args = t.read_file(fake_dir .. '/tunnel.args')
    t.matches('BatchMode=yes', tunnel_args)
    t.matches('RemoteCommand=none', tunnel_args)
    t.matches('StrictHostKeyChecking=accept%-new', tunnel_args)
    t.matches('ServerAliveInterval=15', tunnel_args)
    -- Teardown stops the tunnel and cancels its forward, but not the local server.
    eq(true, tunnel_exited())
    eq(true, vim.uv.fs_stat(fake_dir .. '/forward.cancelled') ~= nil)
    n.poke_eventloop()
    n.assert_alive()

    -- Explicit ssh_config values are kept. The target is decoded, with an IPv6 host unbracketed.
    setup_fake_ssh({ ssh_config = 'stricthostkeychecking yes\nserveraliveinterval 60\n' })
    n.exec_lua(function()
      local _, teardown = require('vim.net._ssh').connect('ssh://a%40b@[::1]:2222/x')
      teardown()
    end)
    local explicit_args = t.read_file(fake_dir .. '/tunnel.args')
    t.matches(' %-p 2222 %-%- a@b@::1 sh ', explicit_args)
    eq(nil, explicit_args:find('StrictHostKeyChecking', 1, true))
    eq(nil, explicit_args:find('ServerAliveInterval', 1, true))
    eq(
      'No host in SSH URI: ssh:///x',
      t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('ssh:///x')]])
    )

    -- Stops the session if the UI detached meanwhile.
    setup_fake_ssh()
    t.matches(
      'UI detached: channel 999',
      t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('ssh://user@test-server', 999)]])
    )
    eq(true, tunnel_exited())
    eq(true, vim.uv.fs_stat(fake_dir .. '/forward.cancelled') ~= nil)
  end)

  it('stops the local server when the session ends, unless it is in use', function()
    skip(is_os('win'), 'remote-ssh is POSIX-only')
    setup_fake_ssh()
    local logfile = n.exec_lua([[return vim.fs.joinpath(vim.fn.stdpath('log'), 'remote-ssh.log')]])
    os.remove(logfile)
    -- Connects, then ends the session as the remote does: its Nvim quits.
    local session = [[
      local sock = require('vim.net._ssh').connect('ssh://user@test-server')
      vim.rpcnotify(vim.fn.sockconnect('pipe', sock, { rpc = true }), 'nvim_command', 'qall!')
    ]]

    n.command('set modified')
    n.exec_lua(session)
    t.retry(nil, 5000, function()
      t.matches('local server in use, keeping it', t.read_file(logfile))
    end)
    n.assert_alive()

    n.command('set nomodified')
    n.expect_exit(5000, n.exec_lua, session)
  end)

  it('passes the matching release + user config to the remote', function()
    skip(is_os('win'), 'remote-ssh is POSIX-only')
    setup_fake_ssh()
    local base, prerelease = unpack(n.exec_lua(function()
      local _, teardown = require('vim.net._ssh').connect('ssh://user@test-server')
      teardown()
      local v = vim.version()
      return { ('v%d.%d.%d'):format(v.major, v.minor, v.patch), v.prerelease or false }
    end))
    local url = 'https://github.com/neovim/neovim/releases/download/%s/nvim-linux-x86_64.tar.gz'
    local dir = '.local/share/nvim-remote/releases/%s-linux-x86_64'
    -- A prerelease installs the nightly, or uses a system `nvim` of that prerelease or newer.
    local sha256 = ('a'):rep(64)
    local args = prerelease
        and {
          dir:format('nightly-' .. base),
          url:format('nightly'),
          sha256,
          ('%s-%s'):format(base, prerelease),
        }
      or { dir:format(base), url:format(base), sha256, base }
    local function script_args()
      return t.read_file(fake_dir .. '/tunnel.args')
        :match(' sh %-s %-%- /tmp/nvim%-remote%.%x+/nvim%.sock (.-) #!/bin/sh')
    end
    eq(table.concat(args, ' '), script_args())

    -- Without the digest (e.g. offline), passes `-`: the remote can't install the release.
    setup_fake_ssh({ digest = false })
    n.exec_lua(function()
      local _, teardown = require('vim.net._ssh').connect('ssh://user@test-server')
      teardown()
    end)
    args[3] = '-'
    eq(table.concat(args, ' '), script_args())

    -- "Update Nvim" (prerelease only) re-installs the nightly.
    if prerelease then
      setup_fake_ssh({ confirm = 2 })
      n.exec_lua(function()
        local _, teardown = require('vim.net._ssh').connect('ssh://user@test-server')
        teardown()
      end)
      t.matches(' sh %-s %-%- %-%-update /tmp/', t.read_file(fake_dir .. '/tunnel.args'))
    end

    -- No release for the platform: passes `-`, so the remote can only use a `$PATH` nvim.
    setup_fake_ssh({ uname = 'FreeBSD\namd64\n' })
    n.exec_lua(function()
      local _, teardown = require('vim.net._ssh').connect('ssh://user@test-server')
      teardown()
    end)
    eq(('- - - %s'):format(args[4]), script_args())

    -- Overwrites the remote config files from local. Symlinks resolved, no `.git/`, no broken
    -- symlinks (which fail GNU `tar -h`). #42747
    setup_fake_ssh()
    local config = ('%s/config/nvim'):format(fake_dir)
    n.mkdir_p(config .. '/.git')
    t.write_file(fake_dir .. '/init.lua', '-- init')
    vim.uv.fs_symlink(fake_dir .. '/init.lua', config .. '/init.lua')
    n.mkdir_p(config .. '/lua')
    vim.uv.fs_symlink('doesnotexist', config .. '/lua/broken[1]')
    local remote_config = ('%s/home/.config/nvim-remote'):format(fake_dir)
    n.mkdir_p(remote_config)
    t.write_file(remote_config .. '/stale.lua', '')
    local msg = n.exec_lua(function()
      local _, teardown = require('vim.net._ssh').connect('ssh://user@test-server')
      teardown()
      return _G.confirm_log[1][1]
    end)
    local overwrite = 'This will overwrite the remote ~/.config/nvim-remote/ with a copy of %s/.\n'
    t.matches(('\n%s$'):format(vim.pesc(overwrite:format(n.fn.fnamemodify(config, ':~')))), msg)
    eq({ 'init.lua', 'lua' }, n.fn.readdir(remote_config))
    eq({}, n.fn.readdir(remote_config .. '/lua'))
    eq('file', vim.uv.fs_lstat(remote_config .. '/init.lua').type)
    eq('-- init', t.read_file(remote_config .. '/init.lua'))
  end)

  it('remote script runs acceptable `nvim` from $PATH, else installs the release', function()
    skip(is_os('win'), 'remote-ssh is POSIX-only')
    local home = vim.fs.abspath(t.tmpname(false))
    t.finally(function()
      n.rmdir(home)
    end)
    local nvim_prog = vim.fs.abspath(n.nvim_prog)
    n.mkdir_p(home .. '/bin')
    vim.uv.fs_symlink(nvim_prog, home .. '/bin/nvim')
    local release = home .. '/src/nvim-test'
    n.mkdir_p(release .. '/bin')
    -- Fake remote autoinstalled `nvim` release.
    t.write_file(
      release .. '/bin/nvim',
      table.concat({
        '#!/bin/sh',
        -- Simulates a release that does not run on the system (e.g. glibc-linked, on musl).
        'if [ -n "$NVIM_TEST_BROKEN" ]; then echo "symbol not found" >&2; exit 127; fi',
        'export NVIM_TEST_RELEASE=1', -- Marks the server it runs.
        ('exec %s "$@"'):format(nvim_prog),
        '',
      }, '\n')
    )
    vim.uv.fs_chmod(release .. '/bin/nvim', 493)
    local tarball = home .. '/nvim-test.tar.gz'
    eq(0, vim.system({ 'tar', '-czf', tarball, '-C', home .. '/src', 'nvim-test' }):wait().code)
    local url = ('file://%s'):format(tarball)
    local sha256 = n.exec_lua(function()
      return vim.fn.sha256(vim.fn.readblob(tarball))
    end)
    local dir = 'releases/v1-test'

    --- Runs the script locally, as the remote does. Returns `[$NVIM_APPNAME, $NVIM_TEST_RELEASE,
    --- v:startreason, v:vim_did_init]` of its server, whether its socket dir was removed on exit,
    --- its "Starting …" message, and its "Installing …" message, if any.
    local function serve(version, update)
      return n.exec_lua(function(...)
        local sock = ('%s/sock/nvim.sock'):format(home)
        local cmd =
          { 'env', ('HOME=%s'):format(home), ('PATH=%s/bin:%s'):format(home, vim.env.PATH) }
        vim.list_extend(cmd, { 'sh', 'runtime/scripts/remote_ssh.sh' })
        vim.list_extend(cmd, update and { '--update', sock, ... } or { sock, ... })
        local obj = vim.system(cmd, { stdin = true }) -- Use stdin to signal disconnect.
        obj:wait(10000, function(stdout)
          return stdout:match('NVIM_READY') ~= nil
        end)
        local ch = vim.fn.sockconnect('pipe', sock, { rpc = true })
        local expr = '[$NVIM_APPNAME, $NVIM_TEST_RELEASE, v:startreason, v:vim_did_init]'
        local env = vim.rpcrequest(ch, 'nvim_eval', expr)
        vim.fn.chanclose(ch)
        obj:write(nil) -- ssh disconnects (stdin closed).
        local res = obj:wait(5000)
        -- `vim.net._ssh.serve()` removes its socket dir on exit.
        local removed = vim.uv.fs_stat(vim.fs.dirname(sock)) == nil
        return { env, removed, res.stderr:match('Starting %S+'), res.stderr:match('Installing %S+') }
      end, dir, url, sha256, version)
    end

    local starting_path = ('Starting %s/bin/nvim...'):format(home)
    local starting_release = ('Starting %s/%s/bin/nvim...'):format(home, dir)
    -- v:vim_did_init=0: The server waits for a UI before sourcing the config.
    eq({ { 'nvim-remote', '', 'remote-ssh', 0 }, true, starting_path }, serve('v0.1.0'))
    -- A prerelease (e.g. `v0.13.0-dev`) accepts any build of it.
    local v = n.exec_lua('return vim.version()')
    local own = ('v%d.%d.%d-%s'):format(v.major, v.minor, v.patch, v.prerelease or 'dev')
    eq({ { 'nvim-remote', '', 'remote-ssh', 0 }, true, starting_path }, serve(own))
    eq(nil, vim.uv.fs_stat(('%s/%s'):format(home, dir)))

    -- Each fails to install, and cleans up its temp dir.
    for _, c in ipairs({
      { url, ('0'):rep(64), {}, 'SHA%-256 mismatch: ' },
      { url, '-', {}, 'SHA%-256 unknown' },
      { url, sha256, { NVIM_TEST_BROKEN = '1' }, 'Cannot run .*: symbol not found\n$' },
      { '-', '-', {}, 'No Nvim release for %S+ %S+: install nvim v999%.0%.0 or newer on %$PATH' },
      { url, sha256, { PATH = home .. '/none' }, 'Not found on %$PATH: curl\n$' },
    }) do
      local script =
        { '/bin/sh', 'runtime/scripts/remote_ssh.sh', 'sock', dir, c[1], c[2], 'v999.0.0' }
      local res =
        vim.system(script, { env = vim.tbl_extend('force', { HOME = home }, c[3]) }):wait()
      eq(1, res.code)
      t.matches(c[4], res.stderr)
    end

    eq({}, n.fn.readdir(home .. '/releases'))
    local installing = ('Installing %s/%s...'):format(home, dir)
    local release_env = { 'nvim-remote', '1', 'remote-ssh', 0 }
    eq({ release_env, true, starting_release, installing }, serve('v999.0.0'))
    -- Reuses the install.
    eq({ release_env, true, starting_release }, serve('v999.0.0'))
    -- --update replaces the install, and runs it instead of $PATH `nvim`. Leaves no temp dirs.
    t.write_file(('%s/%s/stale'):format(home, dir), '')
    eq({ release_env, true, starting_release, installing }, serve('v0.1.0', true))
    eq({ 'bin' }, n.fn.readdir(('%s/%s'):format(home, dir)))
    eq({ 'v1-test' }, n.fn.readdir(home .. '/releases'))

    -- Follows a restarted server, which re-binds the socket. The socket dir is private.
    eq(
      { tonumber('700', 8), true, true },
      n.exec_lua(function()
        local sock = ('%s/sock/nvim.sock'):format(home)
        local cmd =
          { 'env', ('HOME=%s'):format(home), ('PATH=%s/bin:%s'):format(home, vim.env.PATH) }
        vim.list_extend(
          cmd,
          { 'sh', 'runtime/scripts/remote_ssh.sh', sock, dir, '', '-', 'v0.1.0' }
        )
        local obj = vim.system(cmd, { stdin = true })
        obj:wait(10000, function(stdout)
          return stdout:match('NVIM_READY') ~= nil
        end)
        local mode = bit.band(assert(vim.uv.fs_stat(vim.fs.dirname(sock))).mode, tonumber('777', 8))
        -- As `:restart`: the old server stops listening, a new one listens, the old one exits.
        local old = vim.fn.sockconnect('pipe', sock, { rpc = true })
        vim.rpcrequest(old, 'nvim_call_function', 'serverstop', { sock })
        local count_chans = 'let g:chans = 0 | autocmd ChanOpen * let g:chans += 1'
        local new = vim.system({
          vim.v.progpath,
          '--clean',
          '--headless',
          '--cmd',
          count_chans,
          '--listen',
          sock,
        })
        vim.wait(5000, function()
          return vim.uv.fs_stat(sock) ~= nil
        end)
        local ch = vim.fn.sockconnect('pipe', sock, { rpc = true })
        vim.rpcnotify(old, 'nvim_command', 'qall!')
        -- `vim.net._ssh.serve()` connects to the new server (to get its PID).
        assert(vim.wait(5000, function()
          return vim.rpcrequest(ch, 'nvim_eval', 'g:chans') > 1
        end))
        obj:write(nil) -- ssh disconnects: stops the new server.
        return { mode, new:wait(5000).code ~= 124, obj:wait(5000).code == 0 }
      end)
    )

    -- Stops the server and removes the socket dir also on a signal.
    eq(
      { true, true },
      n.exec_lua(function()
        local sock = ('%s/sock/nvim.sock'):format(home)
        local cmd =
          { 'env', ('HOME=%s'):format(home), ('PATH=%s/bin:%s'):format(home, vim.env.PATH) }
        vim.list_extend(
          cmd,
          { 'sh', 'runtime/scripts/remote_ssh.sh', sock, dir, '', '-', 'v0.1.0' }
        )
        local obj = vim.system(cmd, { stdin = true })
        obj:wait(10000, function(stdout)
          return stdout:match('NVIM_READY') ~= nil
        end)
        local ch = vim.fn.sockconnect('pipe', sock, { rpc = true })
        local server = vim.rpcrequest(ch, 'nvim_call_function', 'getpid', {})
        vim.uv.kill(obj.pid, 'sigterm') -- The script `exec`s the supervisor.
        obj:wait(5000)
        return {
          vim.uv.fs_stat(vim.fs.dirname(sock)) == nil,
          (vim.wait(5000, function()
            return vim.uv.kill(server, 0) ~= 0
          end)),
        }
      end)
    )
  end)

  it('fails without ssh, or when ssh exits before remote Nvim is ready', function()
    -- Without ssh: fails before asking to confirm.
    setup_fake_ssh()
    n.exec_lua([[require('vim.net._ssh').ssh_cmd = { 'nvim-test-no-ssh' }]])
    eq(
      'Not found on $PATH: nvim-test-no-ssh',
      t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('ssh://user@test-server')]])
    )
    eq({}, n.exec_lua('return _G.confirm_log'))

    setup_fake_ssh({
      tunnel = { stderr = 'channel 0: open failed: administratively prohibited\n', exit = 255 },
    })
    t.matches(
      'SSH tunnel exited before the remote Nvim was ready: channel 0: open failed',
      t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('ssh://user@test-server')]])
    )
    eq(
      'failed: Failed to connect to ssh://user@test-server',
      n.exec_lua('return _G.progress_log[#_G.progress_log]')
    )
    eq(true, vim.uv.fs_stat(fake_dir .. '/forward.cancelled') ~= nil)
  end)

  it('CTRL-C during :connect, stops the tunnel', function()
    local status = 'Installing /home/user1/.local/share/nvim-remote/releases/nightly-linux-arm64...'
    setup_fake_ssh({ tunnel = { stderr = ('%s\n\n  \n'):format(status) } }) -- Never ready.
    local screen = Screen.new(60, 5)
    n.exec_lua(function()
      function _G.Connect()
        _G.interrupted = require('vim.net._ssh').connect('ssh://user@test-server') == nil
      end
    end)
    n.feed(':lua _G.Connect()<CR>')
    -- Shows what the remote prints while connecting, in one line.
    screen:expect([[
                                                                  |
      {1:~                                                           }|*3
      {6:remote-ssh}: Installing /home/user1/^.local/share/nvim-remote/|
    ]])
    n.feed('<C-C>')
    eq(true, n.exec_lua('return _G.interrupted'))
    eq({
      'running: Connecting to ssh://user@test-server...',
      'running: Starting remote Nvim...',
      ('running: %s'):format(status),
      'failed: Interrupted connecting to ssh://user@test-server',
    }, n.exec_lua('return _G.progress_log'))
    eq(true, tunnel_exited())
    eq(true, vim.uv.fs_stat(fake_dir .. '/forward.cancelled') ~= nil)
    eq('', n.eval('v:errmsg'))
  end)

  it('fails when the remote Nvim crashes during startup, or is unreachable', function()
    setup_fake_ssh({
      tunnel = { stdout = 'NVIM_CRASHED\n', exit = 1 },
    })
    t.matches(
      'Remote Nvim crashed during startup',
      t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('ssh://user@test-server')]])
    )

    -- The script runs, but sshd refused the forward.
    setup_fake_ssh({
      tunnel = { stdout = 'NVIM_READY\n' },
    })
    t.matches(
      'Remote Nvim is not reachable through the SSH forward',
      t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('ssh://user@test-server')]])
    )
    eq(true, vim.uv.fs_stat(fake_dir .. '/forward.cancelled') ~= nil)
  end)

  it('serves each session from a new remote directory', function()
    skip(is_os('win'), 'remote-ssh is POSIX-only')
    setup_fake_ssh()
    local function remote_dir()
      n.exec_lua([[
        local _, teardown = require('vim.net._ssh').connect('ssh://user@test-server')
        teardown()
      ]])
      local args = t.read_file(fake_dir .. '/tunnel.args')
      return args:match(':(/tmp/nvim%-remote%.%x+)/nvim%.sock ')
    end

    local dir1, dir2 = remote_dir(), remote_dir()
    assert(dir1 and dir2, 'remote socket path not found')
    assert(dir1 ~= dir2, 'remote socket directory reused across sessions')
  end)

  it(':connect ssh:// does nothing without a UI, or if the user declines', function()
    setup_fake_ssh({ confirm = 0 })
    eq('Vim(connect):E477: No ! allowed', t.pcall_err(n.command, 'connect! ssh://test-server'))
    eq('Vim(connect):E5768: No UI attached', t.pcall_err(n.command, 'connect ssh://test-server'))
    eq('Vim(connect):E5768: No UI attached', t.pcall_err(n.command, 'connect foo'))
    -- Typed by a client that is not a UI.
    n.command('let v:errmsg = ""')
    local client = n.connect(n.eval('v:servername'))
    client:request('nvim_input', ':connect ssh://test-server<CR>')
    t.retry(nil, nil, function()
      eq('E5768: No UI attached', n.eval('v:errmsg'))
    end)
    client:close()
    eq({}, n.exec_lua('return _G.confirm_log'))

    Screen.new()
    -- Scheme is case-insensitive.
    n.command('connect SSH://test-server')
    eq(1, #n.exec_lua('return _G.confirm_log'))
    eq(1, #n.api.nvim_list_uis())
    eq(nil, vim.uv.fs_stat(fake_dir .. '/tunnel.args'))
  end)
end)
