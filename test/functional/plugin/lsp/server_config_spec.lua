local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local luaeval = helpers.funcs.luaeval

before_each(clear)

describe('Setup and Configuration', function()
  it('should allow you to add clients and commands with server_name', function()
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'txt',
        server_name = 'nvim-server',
        cmd = { './build/bin/nvim', '--headless' }
      })
    ]])

    local server = luaeval("require('vim.lsp').server_config.get_server('txt', 'nvim-server')")
    eq('nvim-server', server.server_name)
  end)

  it('should allow you to add clients and commands without server_name', function()
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'txt',
        cmd = { './build/bin/nvim', '--headless' }
      })
    ]])

    local server = luaeval("require('vim.lsp').server_config.get_server('txt')")
    eq('txt', server.server_name)

    server = luaeval("require('vim.lsp').server_config.get_server('txt', 'txt')")
    eq('txt', server.server_name)
  end)

  it('should allow you to add multiple servers for one filetype', function()
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'txt',
        server_name = 'nvim-server-1',
        cmd = { './build/bin/nvim', '--headless' }
      })
    ]])
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'txt',
        server_name = 'nvim-server-2',
        cmd = { './build/bin/nvim', '--headless' }
      })
    ]])

    local server = luaeval("require('vim.lsp').server_config.get_server('txt', 'nvim-server-1')")
    eq('nvim-server-1', server.server_name)

    server = luaeval("require('vim.lsp').server_config.get_server('txt', 'nvim-server-2')")
    eq('nvim-server-2', server.server_name)
  end)

  it('should allow some extra configuration if you want', function()
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'txt',
        cmd = { './build/bin/nvim', '--headless' },
        capabilities = {
          foo = 'bar'
        }
      })
    ]])

    local server = luaeval("require('vim.lsp').server_config.get_server('txt')")
    eq({ foo = 'bar' }, server.capabilities)
  end)
end)
