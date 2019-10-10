local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local luaeval = helpers.funcs.luaeval

before_each(clear)

describe('Setup and Configuration', function()
  it('should allow you to add clients and commands with server_name', function()
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'rust',
        server_name = 'rls',
        cmd = 'rls'
      })
    ]])

    local server = luaeval("require('vim.lsp').server_config.get_server('rust', 'rls')")
    eq('rls', server.server_name)
  end)

  it('should allow you to add clients and commands without server_name', function()
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'rust',
        cmd = 'rls'
      })
    ]])

    local server = luaeval("require('vim.lsp').server_config.get_server('rust')")
    eq('rust', server.server_name)

    server = luaeval("require('vim.lsp').server_config.get_server('rust', 'rust')")
    eq('rust', server.server_name)
  end)

  it('should allow you to add multiple servers for one filetype', function()
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'rust',
        server_name = 'rls',
        cmd = 'rls'
      })
    ]])
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'rust',
        server_name = 'rust-analyzer',
        cmd = 'rust-analyzer'
      })
    ]])

    local server = luaeval("require('vim.lsp').server_config.get_server('rust', 'rls')")
    eq('rls', server.server_name)

    server = luaeval("require('vim.lsp').server_config.get_server('rust', 'rust-analyzer')")
    eq('rust-analyzer', server.server_name)
  end)

  it('should allow some extra configuration if you want', function()
    luaeval([[
      require('vim.lsp').server_config.add({
        filetype = 'rust',
        cmd = 'rls',
        capabilities = {
          foo = 'bar'
        }
      })
    ]])

    local server = luaeval("require('vim.lsp').server_config.get_server('rust')")
    eq({ foo = 'bar' }, server.capabilities)
  end)
end)
