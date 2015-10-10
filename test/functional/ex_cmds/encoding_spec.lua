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

  it('is not changed by `set all&`', function()
    -- we need to set &encoding to something non-default
    -- use 'latin1' when enc&vi is 'utf-8', 'utf-8' otherwise
    execute('set fenc=default')
    local enc_default, enc_other, width = eval('&fenc'), 'utf-8', 3
    if enc_default == 'utf-8' then
      enc_other = 'latin1'
      width = 4 -- utf-8 string 'Bär' will count as 4 latin1 chars
    end

    clear('set enc=' .. enc_other)
    execute('set all&')
    eq(enc_other, eval('&encoding'))
    eq(width, eval('strwidth("Bär")'))
  end)

end)
