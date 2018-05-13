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
    luaeval([[require('lsp.server').add('vim', 'vim-lsp')]])
    local result_name = luaeval("require('lsp.server').get_name('vim')")
    eq('vim', result_name)
  end)

  it('should allow some extra configuration if you want', function()
    luaeval([[require('lsp.server').add('vim', 'vim-lsp', { name = 'test-server' })]])
    local result_name = luaeval("require('lsp.server').get_name('vim')")
    eq('test-server', result_name)
  end)

end)
