local helpers = require('test.functional.helpers')
local clear, execute, feed = helpers.clear, helpers.execute, helpers.feed
local eq, neq, eval = helpers.eq, helpers.neq, helpers.eval

describe('&encoding', function()

  before_each(function()
    clear()
    -- sanity check: tests should run with encoding=utf-8
    eq('utf-8', eval('&encoding'))
    eq(3, eval('strwidth("Bär")'))
  end)

  it('cannot be changed after setup', function()
    execute('set encoding=latin1')
    -- error message expected
    feed('<cr>')
    neq(nil, string.find(eval('v:errmsg'), '^E905:'))
    eq('utf-8', eval('&encoding'))
    -- check nvim is still in utf-8 mode
    eq(3, eval('strwidth("Bär")'))
  end)

  it('can be changed before startup', function()
    clear('set enc=latin1')
    execute('set encoding=utf-8')
    -- error message expected
    feed('<cr>')
    eq('latin1', eval('&encoding'))
    eq(4, eval('strwidth("Bär")'))
  end)

  it('is not changed by `set all&`', function()
    -- we need to set &encoding to something non-default. Use 'latin1'
    clear('set enc=latin1')
    execute('set all&')
    eq('latin1', eval('&encoding'))
    eq(4, eval('strwidth("Bär")'))
  end)

end)
