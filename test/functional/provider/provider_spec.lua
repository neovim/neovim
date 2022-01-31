
local helpers = require('test.functional.helpers')(after_each)
local clear, eval = helpers.clear, helpers.eval
local command = helpers.command
local eq = helpers.eq
local pcall_err = helpers.pcall_err

describe('providers', function()
  before_each(function()
    clear('--cmd', 'let &rtp = "test/functional/fixtures,".&rtp')
  end)

  it('with g:loaded_xx_provider, missing #Call()', function()
    -- Using test-fixture with broken impl:
    -- test/functional/fixtures/autoload/provider/ruby.vim
    eq('Vim:provider: ruby: g:loaded_ruby_provider=2 but provider#ruby#Call is not defined',
      pcall_err(eval, "has('ruby')"))
  end)
end)
