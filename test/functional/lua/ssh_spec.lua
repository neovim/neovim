local t = require('test.testutil')
local ssh = require('vim.net._ssh')
local eq = t.eq

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

    eq({
      'dev',
      'prod',
      'test',
      'quoted string',
      'gh',
    }, ssh.parse_ssh_config(config))
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

    local ok, _ = pcall(ssh.parse_ssh_config, config)
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

    local ok, _ = pcall(ssh.parse_ssh_config, config)
    eq(false, ok)
  end)
end)

describe('SSH connector', function()
  it('validation', function()
    local ok, _ = pcall(ssh.connect_to_address, '')
    eq(false, ok)

    ok, _ = pcall(ssh.connect_to_address, nil)
    eq(false, ok)

    ok, _ = pcall(ssh.connect_to_address, 'address cannot have spaces')
    eq(false, ok)
  end)
end)
