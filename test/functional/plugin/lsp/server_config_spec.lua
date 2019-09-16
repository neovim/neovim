local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local luaeval = helpers.funcs.luaeval
-- local neq = helpers.neq
-- local dedent = helpers.dedent
-- local source = helpers.source

before_each(clear)

describe('Setup and Configuration', function()
  it('should allow you to add clients and commands', function()
    luaeval([[
      require('vim.lsp.server_config').add(
        'rust',
        { execute_path = 'rustup', args = { 'run', 'stable', 'rls' }},
        { name = 'rls' }
      )
    ]])
    local result_name = luaeval("require('vim.lsp.server_config').get_server_name('rust')")
    eq('rls', result_name)
  end)

  it('should allow some extra configuration if you want', function()
    luaeval([[require('vim.lsp.server_config').add('rust', { execute_path = 'rustup', args = { 'run', 'stable', 'rls' }})]])
    local result_name = luaeval("require('vim.lsp.server_config').get_server_command('rust')").execute_path
    eq('rustup', result_name)
  end)
end)
