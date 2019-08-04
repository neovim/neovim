
local helpers = require('test.functional.helpers')(after_each)
local clear, eval = helpers.clear, helpers.eval
local command = helpers.command
local expect_err = helpers.expect_err

describe('providers', function()
  before_each(function()
    clear('--cmd', 'let &rtp = "test/functional/fixtures,".&rtp')
  end)

  it('with #Call(), missing g:loaded_xx_provider', function()
    command('set loadplugins')
    -- Using test-fixture with broken impl:
    -- test/functional/fixtures/autoload/provider/python.vim
    expect_err('Vim:provider: python: missing required variable g:loaded_python_provider',
      eval, "has('python')")
  end)

  it('with g:loaded_xx_provider, missing #Call()', function()
    -- Using test-fixture with broken impl:
    -- test/functional/fixtures/autoload/provider/ruby.vim
    expect_err('Vim:provider: ruby: g:loaded_ruby_provider=2 but provider#ruby#Call is not defined',
      eval, "has('ruby')")
  end)
end)
