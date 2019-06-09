
local helpers = require('test.functional.helpers')(after_each)
local clear, eq, feed_command, eval = helpers.clear, helpers.eq, helpers.feed_command, helpers.eval

describe('Providers', function()
  before_each(function()
    clear('--cmd', 'let &rtp = "test/functional/fixtures,".&rtp')
  end)

  it('must set the enabled variable or fail', function()
    eq(42, eval("provider#brokenenabled#Call('dosomething', [])"))
	feed_command("call has('brokenenabled')")
    eq(0, eval("has('brokenenabled')"))
  end)

  it('without Call() are enabled', function()
    eq(1, eval("has('brokencall')"))
  end)
end)
