local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local parser = require('vim.net._ssh')

local clear = n.clear
local eq = t.eq
local is_os = t.is_os
local skip = t.skip

describe('SSH parser', function()
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

  describe('URI parser', function()
    it('parses ssh://user@host:port', function()
      local uri = parser.parse_uri('ssh://root@localhost:2222')
      eq('root', uri.user)
      eq('localhost', uri.host)
      eq('2222', uri.port)
    end)

    it('parses user@host', function()
      local uri = parser.parse_uri('admin@server.local')
      eq('admin', uri.user)
      eq('server.local', uri.host)
      eq(nil, uri.port)
    end)

    it('parses host only', function()
      local uri = parser.parse_uri('myalias')
      eq(nil, uri.user)
      eq('myalias', uri.host)
      eq(nil, uri.port)
    end)
  end)
end)

describe('vim.net._ssh', function()
  local fake_bin_dir

  local function setup_fake_ssh(behavior)
    behavior = behavior or {}
    local is_windows = package.config:sub(1, 1) == '\\'
    fake_bin_dir = t.tmpname()
    os.remove(fake_bin_dir)
    vim.uv.fs_mkdir(fake_bin_dir, 511)
    local fake_ssh_path = fake_bin_dir .. (is_windows and '/ssh.cmd' or '/ssh')

    local script
    if is_windows then
      script = t.dedent([=[
        @echo off
        setlocal EnableDelayedExpansion
        set "ARGS=%*"

        echo(!ARGS! | findstr /C:"uname -s && uname -m" >nul
        if not errorlevel 1 (
      ]=] .. (behavior.uname or [=[
          echo Linux
          echo x86_64
      ]=]) .. [=[
          exit /b 0
        )

        echo(!ARGS! | findstr /C:"-L" >nul
        if not errorlevel 1 (
          echo(!ARGS! | findstr /C:"ControlMaster" >nul
          if errorlevel 1 (
            echo FAIL: Multiplexing flags missing! 1>&2
            exit /b 1
          )
      ]=] .. (behavior.tunnel or [=[
          set "SOCK="
          set "NEXT_L="
          for %%A in (%*) do (
            if defined NEXT_L (
              set "SOCK=%%~A"
              set "NEXT_L="
            ) else if "%%~A"=="-L" (
              set "NEXT_L=1"
            )
          )
          if not defined SOCK (
            echo Unexpected SSH command: !ARGS! 1>&2
            exit /b 1
          )
          > "!SOCK!" type NUL
          exit /b 0
      ]=]) .. [=[
        )

        echo(!ARGS! | findstr /C:"TARGET_VER" >nul
        if not errorlevel 1 (
      ]=] .. (behavior.installer or [=[
          echo Installing Neovim... 1>&2
          exit /b 0
      ]=]) .. [=[
        )

        echo(!ARGS! | findstr /C:"-O" >nul
        if not errorlevel 1 (
          echo(!ARGS! | findstr /C:"exit" >nul
          if not errorlevel 1 exit /b 0
        )

        echo Unexpected SSH command: !ARGS! 1>&2
        exit /b 1
      ]=])
    else
      script = t.dedent([=[
        #!/usr/bin/env bash
        ARGS="$*"

        if [[ "$ARGS" == *"uname -s && uname -m"* ]]; then
      ]=] .. (behavior.uname or [=[
          echo "Linux"
          echo "x86_64"
      ]=]) .. [=[
          exit 0
        fi

        if [[ "$ARGS" == *"-L"* ]]; then
          if [[ "$ARGS" != *"ControlMaster"* ]]; then
            echo "FAIL: Multiplexing flags missing!" >&2
            exit 1
          fi
      ]=] .. (behavior.tunnel or [=[
          SOCK=$(echo "$ARGS" | grep -oE '\-L [^:]+' | cut -d' ' -f2)
          echo "NVIM_READY"
          touch "$SOCK"
          sleep 60 &
          exit 0
      ]=]) .. [=[
        fi

        if [[ "$ARGS" == *"TARGET_VER"* ]]; then
      ]=] .. (behavior.installer or [=[
          echo "Installing Neovim..." >&2
          exit 0
      ]=]) .. [=[
        fi

        if [[ "$ARGS" == *"-O"*"exit"* ]]; then
          exit 0
        fi

        echo "Unexpected SSH command: $ARGS" >&2
        exit 1
      ]=])
    end
    t.write_file(fake_ssh_path, script)
    vim.uv.fs_chmod(fake_ssh_path, 493)

    local path_sep = is_windows and ';' or ':'
    n.exec_lua(string.format(
      [[
      _G.orig_path = vim.fn.getenv('PATH')
      vim.fn.setenv('PATH', %q .. %q .. _G.orig_path)
    ]],
      fake_bin_dir,
      path_sep
    ))
  end

  local function teardown_fake_ssh()
    if fake_bin_dir then
      n.exec_lua([[
        if _G.orig_path then
          vim.fn.setenv('PATH', _G.orig_path)
        end
      ]])
    end
  end

  before_each(function()
    clear()
  end)

  after_each(function()
    teardown_fake_ssh()
  end)

  describe('Remote Engine (Introspection)', function()
    it('detects linux x86_64 successfully', function()
      skip(is_os('win'), 'remote-ssh engine is POSIX-only')
      setup_fake_ssh({
        uname = [[
          echo "Linux"
          echo "x86_64"
        ]],
      })
      local res = n.exec_lua([[
        return { require('vim.net._ssh').get_system_info({ host = 'server' }) }
      ]])
      eq('linux', res[1])
      eq('x86_64', res[2])
    end)

    it('detects macos arm64 successfully', function()
      skip(is_os('win'), 'remote-ssh engine is POSIX-only')
      setup_fake_ssh({
        uname = [[
          echo "Darwin"
          echo "arm64"
        ]],
      })
      local res = n.exec_lua([[
        return { require('vim.net._ssh').get_system_info({ host = 'server' }) }
      ]])
      eq('darwin', res[1])
      eq('arm64', res[2])
    end)

    it('fails fast on Windows', function()
      skip(is_os('win'), 'remote-ssh engine is POSIX-only')
      setup_fake_ssh({
        uname = [[
          echo "MSYS_NT-10.0-19045"
          echo "x86_64"
        ]],
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

  describe('Remote Engine (Orchestration)', function()
    it('returns local socket with key-based auth', function()
      skip(is_os('win'), 'remote-ssh engine is POSIX-only')
      setup_fake_ssh()
      local sock = n.exec_lua([[
        return require('vim.net._ssh').start('user@test-server')
      ]])

      assert(sock:match('_remote_nvim%.sock$'))
    end)
  end)
end)
