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
    -- Runs of separators between values, and trailing whitespace before the
    -- line break, must not yield empty hostnames.
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

describe('vim.net._ssh', function()
  local fake_dir --- @type string

  --- Makes `vim.net._ssh` run a fake `ssh` (fixtures/fake-ssh.lua), and stubs `confirm()`.
  ---
  --- @param behavior? table Optional fields:
  ---   - `confirm`: Result of `confirm()`.
  ---   - `ssh_config`, `uname`: Output of `ssh -G`, of `uname -s && uname -m`.
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

    n.exec_lua(function(ssh_cmd, choice)
      require('vim.net._ssh').ssh_cmd = ssh_cmd
      _G.confirm_log = {}
      vim.fn.confirm = function(...)
        table.insert(_G.confirm_log, { ... })
        return choice
      end
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

  describe('remote-ssh (Introspection)', function()
    it('detects linux x86_64', function()
      setup_fake_ssh({
        uname = 'Linux\nx86_64\n',
      })
      local res = n.exec_lua([[
        return { require('vim.net._ssh').get_system_info({ host = 'server' }) }
      ]])
      eq('linux', res[1])
      eq('x86_64', res[2])
    end)

    it('detects macos arm64', function()
      setup_fake_ssh({
        uname = 'Darwin\narm64\n',
      })
      local res = n.exec_lua([[
        return { require('vim.net._ssh').get_system_info({ host = 'server' }) }
      ]])
      eq('darwin', res[1])
      eq('arm64', res[2])
    end)

    it('fails fast on Windows', function()
      setup_fake_ssh({
        uname = 'MSYS_NT-10.0-19045\nx86_64\n',
      })
      local status, err = pcall(function()
        n.exec_lua([[
          require('vim.net._ssh').get_system_info({ host = 'server' })
        ]])
      end)
      eq(false, status)
      assert(string.match(err, 'Windows targets are not supported'))
    end)
  end)

  describe('remote-ssh (Orchestration)', function()
    it('returns local socket with key-based auth', function()
      skip(is_os('win'), 'remote-ssh is POSIX-only')
      setup_fake_ssh()
      local sock, logfile, progress = unpack(n.exec_lua([[
        local logfile = vim.fs.joinpath(vim.fn.stdpath('log'), 'remote-ssh.log')
        os.remove(logfile)
        local progress = {}
        vim.api.nvim_create_autocmd('Progress', {
          pattern = 'remote-ssh',
          callback = function(ev)
            table.insert(progress, ('%s: %s'):format(ev.data.status, table.concat(ev.data.text)))
          end,
        })
        local sock, teardown = require('vim.net._ssh').connect('user@test-server')
        teardown()
        return { sock, logfile, progress }
      ]]))

      assert(sock:match('_remote_nvim%.sock$'))
      eq({
        'running: Connecting to user@test-server...',
        'running: Starting remote Nvim...',
        'success: Connected to user@test-server',
      }, progress)
      local msg = 'This will install Nvim on user@test-server (in ~/.local/share/nvim-remote/), '
        .. 'if missing.\n'
      eq({ { msg, 'Connect? &Yes\n&No', 1, 'Question' } }, n.exec_lua('return _G.confirm_log'))
      t.matches('Connected to user@test%-server', t.read_file(logfile))
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

      -- Explicit ssh_config values are kept.
      setup_fake_ssh({ ssh_config = 'stricthostkeychecking yes\nserveraliveinterval 60\n' })
      n.exec_lua(function()
        local _, teardown = require('vim.net._ssh').connect('user@test-server')
        teardown()
      end)
      local explicit_args = t.read_file(fake_dir .. '/tunnel.args')
      eq(nil, explicit_args:find('StrictHostKeyChecking', 1, true))
      eq(nil, explicit_args:find('ServerAliveInterval', 1, true))

      -- Stops the session if the UI detached meanwhile.
      setup_fake_ssh()
      t.matches(
        'UI detached: channel 999',
        t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('user@test-server', 999)]])
      )
      eq(true, tunnel_exited())
      eq(true, vim.uv.fs_stat(fake_dir .. '/forward.cancelled') ~= nil)
    end)

    it('stops the local server when the session ends, unless it is in use', function()
      skip(is_os('win'), 'remote-ssh is POSIX-only')
      setup_fake_ssh()
      local logfile =
        n.exec_lua([[return vim.fs.joinpath(vim.fn.stdpath('log'), 'remote-ssh.log')]])
      os.remove(logfile)
      -- Connects, then ends the session as the remote does: its Nvim quits.
      local session = [[
        local sock = require('vim.net._ssh').connect('user@test-server')
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

    it('passes the matching release to the remote script', function()
      skip(is_os('win'), 'remote-ssh is POSIX-only')
      setup_fake_ssh()
      local base, prerelease = unpack(n.exec_lua(function()
        local _, teardown = require('vim.net._ssh').connect('user@test-server')
        teardown()
        local v = vim.version()
        return { ('v%d.%d.%d'):format(v.major, v.minor, v.patch), v.prerelease and true or false }
      end))
      local url = 'https://github.com/neovim/neovim/releases/download/%s/nvim-linux-x86_64.tar.gz'
      local dir = '.local/share/nvim-remote/releases/%s-linux-x86_64'
      -- A prerelease installs the current nightly, and passes no version for a system `nvim`.
      local args = prerelease and { dir:format('nightly-' .. base), url:format('nightly') }
        or { dir:format(base), url:format(base), base }
      eq(
        table.concat(args, ' '),
        t.read_file(fake_dir .. '/tunnel.args')
          :match(' sh %-s %-%- /tmp/nvim%-remote%.%x+/nvim%.sock (.-) #!/bin/sh')
      )
    end)

    it('remote script runs `nvim` from $PATH if new enough, else installs the release', function()
      skip(is_os('win'), 'remote-ssh is POSIX-only')
      local home = vim.fs.abspath(t.tmpname(false))
      t.finally(function()
        n.rmdir(home)
      end)
      local nvim_prog = vim.fs.abspath(n.nvim_prog)
      n.mkdir_p(home .. '/bin')
      vim.uv.fs_symlink(nvim_prog, home .. '/bin/nvim')
      -- Release archive: its `nvim` marks the server it runs.
      local release = home .. '/src/nvim-test'
      n.mkdir_p(release .. '/bin')
      t.write_file(
        release .. '/bin/nvim',
        ('#!/bin/sh\nexport NVIM_TEST_RELEASE=1\nexec %s "$@"\n'):format(nvim_prog)
      )
      vim.uv.fs_chmod(release .. '/bin/nvim', 493)
      local tarball = home .. '/nvim-test.tar.gz'
      eq(0, vim.system({ 'tar', '-czf', tarball, '-C', home .. '/src', 'nvim-test' }):wait().code)
      local dir = 'releases/v1-test'

      --- Runs the script locally, as the remote does, and asks its server for `[$NVIM_APPNAME,
      --- $NVIM_TEST_RELEASE, v:startreason]`.
      local function serve(version)
        return n.exec_lua(function(...)
          local sock = ('%s/sock/nvim.sock'):format(home)
          local cmd =
            { 'env', ('HOME=%s'):format(home), ('PATH=%s/bin:%s'):format(home, vim.env.PATH) }
          vim.list_extend(cmd, { 'sh', 'runtime/scripts/remote_ssh.sh', sock, ... })
          local obj = vim.system(cmd)
          obj:wait(10000, function(stdout)
            return stdout:match('NVIM_READY') ~= nil
          end)
          local ch = vim.fn.sockconnect('pipe', sock, { rpc = true })
          local env =
            vim.rpcrequest(ch, 'nvim_eval', '[$NVIM_APPNAME, $NVIM_TEST_RELEASE, v:startreason]')
          vim.fn.chanclose(ch)
          obj:kill('sigterm')
          local res = obj:wait(5000)
          -- The script removes its socket dir on exit.
          local removed = vim.uv.fs_stat(vim.fs.dirname(sock)) == nil
          return { env, removed, res.stderr:match('Installing %S+') }
        end, dir, ('file://%s'):format(tarball), version)
      end

      eq({ { 'nvim-remote', '', 'remote-ssh' }, true }, serve('v0.1.0'))
      eq(nil, vim.uv.fs_stat(('%s/%s'):format(home, dir)))
      local installing = ('Installing %s/%s...'):format(home, dir)
      eq({ { 'nvim-remote', '1', 'remote-ssh' }, true, installing }, serve('v999.0.0'))
      -- No version (a prerelease): never uses $PATH; the install is kept.
      eq({ { 'nvim-remote', '1', 'remote-ssh' }, true }, serve())

      -- The UI could not reach a restarted server through the tunnel.
      n.clear({ env = { __NVIM_STARTREASON = 'remote-ssh' } })
      eq(
        'Vim(restart):E6103: :restart is not supported with remote-ssh',
        t.pcall_err(n.command, 'restart')
      )
    end)

    it('fails when ssh exits before the remote Nvim is ready', function()
      setup_fake_ssh({
        tunnel = { stderr = 'channel 0: open failed: administratively prohibited\n', exit = 255 },
      })
      n.exec_lua(function()
        vim.api.nvim_create_autocmd('Progress', {
          pattern = 'remote-ssh',
          callback = function(ev)
            _G.last_progress = ('%s: %s'):format(ev.data.status, table.concat(ev.data.text))
          end,
        })
      end)
      t.matches(
        'SSH tunnel exited before the remote Nvim was ready: channel 0: open failed',
        t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('user@test-server')]])
      )
      eq('failed: Failed to connect to user@test-server', n.exec_lua('return _G.last_progress'))
      eq(true, vim.uv.fs_stat(fake_dir .. '/forward.cancelled') ~= nil)
    end)

    it('fails when the remote Nvim crashes during startup, or is unreachable', function()
      setup_fake_ssh({
        tunnel = { stdout = 'NVIM_CRASHED\n', exit = 1 },
      })
      t.matches(
        'Remote Nvim crashed during startup',
        t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('user@test-server')]])
      )

      -- The script runs, but sshd refused the forward.
      setup_fake_ssh({
        tunnel = { stdout = 'NVIM_READY\n' },
      })
      t.matches(
        'Remote Nvim is not reachable through the SSH forward',
        t.pcall_err(n.exec_lua, [[require('vim.net._ssh').connect('user@test-server')]])
      )
      eq(true, vim.uv.fs_stat(fake_dir .. '/forward.cancelled') ~= nil)
    end)

    it('serves each session from a fresh private remote directory', function()
      skip(is_os('win'), 'remote-ssh is POSIX-only')
      setup_fake_ssh()
      local function remote_dir()
        n.exec_lua([[
          local _, teardown = require('vim.net._ssh').connect('user@test-server')
          teardown()
        ]])
        local args = t.read_file(fake_dir .. '/tunnel.args')
        t.matches('mkdir %-m 700 "%$dir"', args)
        return args:match(':(/tmp/nvim%-remote%.%x+)/nvim%.sock ')
      end

      local dir1, dir2 = remote_dir(), remote_dir()
      assert(dir1 and dir2, 'remote socket path not found')
      assert(dir1 ~= dir2, 'remote socket directory reused across sessions')
    end)

    it(':connect ssh:// does nothing if it cannot attach, or is declined', function()
      setup_fake_ssh({ confirm = 2 })
      eq('Vim(connect):E477: No ! allowed', t.pcall_err(n.command, 'connect! ssh://test-server'))
      eq('Vim(connect):E5768: No UI attached', t.pcall_err(n.command, 'connect ssh://test-server'))
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
end)
