local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local luaeval = helpers.funcs.luaeval

before_each(clear)

describe('Setup and Configuration', function()
  it('should allow you to add clients and commands', function()
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

  it('should allow some extra configuration if you want', function()
    luaeval([[
        require('vim.lsp').server_config.add({
        filetype = 'rust',
        cmd = 'rls'
      })
    ]])
    local execute_path = luaeval("require('vim.lsp').server_config.get_server_cmd('rust')")
    eq('rls', execute_path)
  end)
end)
