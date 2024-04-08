local t = require('test.functional.testutil')(after_each)
local clear, eval = t.clear, t.eval
local command = t.command
local eq = t.eq
local pcall_err = t.pcall_err

describe('providers', function()
  before_each(function()
    clear('--cmd', 'set rtp^=test/functional/fixtures')
  end)

  it('with #Call(), missing g:loaded_xx_provider', function()
    command('set loadplugins')
    -- Using test-fixture with broken impl:
    -- test/functional/fixtures/autoload/provider/python.vim
    eq(
      'Vim:provider: python3: missing required variable g:loaded_python3_provider',
      pcall_err(eval, "has('python3')")
    )
  end)

  it('with g:loaded_xx_provider, missing #Call()', function()
    -- Using test-fixture with broken impl:
    -- test/functional/fixtures/autoload/provider/ruby.vim
    eq(
      'Vim:provider: ruby: g:loaded_ruby_provider=2 but provider#ruby#Call is not defined',
      pcall_err(eval, "has('ruby')")
    )
  end)
end)
