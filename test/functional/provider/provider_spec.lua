
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
    expect_err('Vim:provider: brokenenabled: missing required variable g:loaded_brokenenabled_provider',
      eval, "has('brokenenabled')")
  end)

  it('without Call() but with g:loaded_xx_provider', function()
    eq(1, eval("has('brokencall')"))
  end)
end)
