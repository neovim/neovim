local t = require('test.functional.testutil')()
local clear, feed_command, feed = t.clear, t.feed_command, t.feed
local eq, neq, eval = t.eq, t.neq, t.eval

describe('&encoding', function()
  before_each(function()
    clear()
    -- sanity check: tests should run with encoding=utf-8
    eq('utf-8', eval('&encoding'))
    eq(3, eval('strwidth("Bär")'))
  end)

  it('cannot be changed after setup', function()
    feed_command('set encoding=latin1')
    -- error message expected
    feed('<cr>')
    neq(nil, string.find(eval('v:errmsg'), '^E519:'))
    eq('utf-8', eval('&encoding'))
    -- check nvim is still in utf-8 mode
    eq(3, eval('strwidth("Bär")'))
  end)

  it('cannot be changed before startup', function()
    clear('--cmd', 'set enc=latin1')
    -- error message expected
    feed('<cr>')
    neq(nil, string.find(eval('v:errmsg'), '^E519:'))
    eq('utf-8', eval('&encoding'))
    eq(3, eval('strwidth("Bär")'))
  end)

  it('can be set to utf-8 without error', function()
    feed_command('set encoding=utf-8')
    eq('', eval('v:errmsg'))

    clear('--cmd', 'set enc=utf-8')
    eq('', eval('v:errmsg'))
  end)
end)
