local t = require('test.testutil')
local parser = require('vim.net._ssh')
local describe, it = t.describe, t.it
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
      'foo',
      'gh',
    }, parser.parse_ssh_config(config))
  end)

  it('parses SSH configuration strings with inline comments', function()
    local config = [[
      Host * #comment
        ConnectTimeout 10
        ServerAliveInterval 60
        ServerAliveCountMax 3

      Host=dev # comment
        HostName=dev.example.com
        User=devuser
        Port=2222
        IdentityFile=~/.ssh/id_rsa_dev

      Host "quoted string"   # comment
        User quote # comment
        Port 22

      Match host foo host gh # comment
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_rsa_github
        IdentitiesOnly yes
    ]]

    eq({
      'dev',
      'quoted string',
      'foo',
      'gh',
    }, parser.parse_ssh_config(config))
  end)

  it('parses multiple hostnames separated by ","', function()
    local config = [[
      Host prod,dev,test,*,!yes
        HostName 198.51.100.10
        User admin
        Port 22
        IdentityFile ~/.ssh/id_rsa_prod
        ForwardAgent yes
    ]]

    eq({
      'prod',
      'dev',
      'test',
    }, parser.parse_ssh_config(config))
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

  it('fails when a Host segment does not have any hosts', function()
    local config = [[
      Host
        HostName 198.51.100.10
        User admin
        Port 22
        IdentityFile ~/.ssh/id_rsa_prod
        ForwardAgent yes
    ]]

    local ok, _ = pcall(parser.parse_ssh_config, config)
    eq(false, ok)
  end)

  it("fails when there's an invalid condition for match", function()
    local config = [[
      Match invalidcondition
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_rsa_github
        IdentitiesOnly yes
    ]]
    local ok, _ = pcall(parser.parse_ssh_config, config)
    eq(false, ok)
  end)
end)
