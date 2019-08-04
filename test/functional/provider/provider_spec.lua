
local helpers = require('test.functional.helpers')(after_each)
local clear, eq, eval = helpers.clear, helpers.eq, helpers.eval
local command = helpers.command
local expect_err = helpers.expect_err

describe('providers', function()
  before_each(function()
    clear('--cmd', 'let &rtp = "test/functional/fixtures,".&rtp')
  end)

  it('must define g:loaded_xx_provider', function()
    command('set loadplugins')
    -- Using test-fixture with broken impl:
    -- test/functional/fixtures/autoload/provider/python.vim
    expect_err('Vim:provider: python: missing required variable g:loaded_python_provider',
      eval, "has('python')")
  end)

  it('without Call() but with g:loaded_xx_provider', function()
    -- Using test-fixture with broken impl:
    -- test/functional/fixtures/autoload/provider/ruby.vim
    eq(1, eval("has('ruby')"))
  end)
end)
