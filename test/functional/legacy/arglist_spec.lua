-- Test argument list commands

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect
local eq, eval = helpers.eq, helpers.eval

describe('argument list commands', function()
  before_each(clear)

  function assert_argc(l)
    eq(#l, eval('argc()'))
    for i = 1, #l do
      eq(l[i], eval('argv(' .. (i - 1) .. ')'))
    end
  end

  function init_abc()
    execute('args a b c')
    execute('next')
  end

  it('test that argidx() works', function()
    execute('args a b c')
    execute('last')
    eq(2, eval('argidx()'))
    execute('%argdelete')
    eq(0, eval('argidx()'))

    execute('args a b c')
    eq(0, eval('argidx()'))
    execute('next')
    eq(1, eval('argidx()'))
    execute('next')
    eq(2, eval('argidx()'))
    execute('1argdelete')
    eq(1, eval('argidx()'))
    execute('1argdelete')
    eq(0, eval('argidx()'))
    execute('1argdelete')
    eq(0, eval('argidx()'))
  end)

  it('test that argadd() works', function()
    execute('%argdelete')
    execute('argadd a b c')
    eq(0, eval('argidx()'))

    execute('%argdelete')
    execute('argadd a')
    eq(0, eval('argidx()'))
    execute('argadd b c d')
    eq(0, eval('argidx()'))

    init_abc()
    execute('argadd x')
    assert_argc({'a', 'b', 'x', 'c'})
    eq(1, eval('argidx()'))

    init_abc()
    execute('0argadd x')
    assert_argc({'x', 'a', 'b', 'c'})
    eq(2, eval('argidx()'))

    init_abc()
    execute('1argadd x')
    assert_argc({'a', 'x', 'b', 'c'})
    eq(2, eval('argidx()'))

    init_abc()
    execute('$argadd x')
    assert_argc({'a', 'b', 'c', 'x'})
    eq(1, eval('argidx()'))

    init_abc()
    execute('$argadd x')
    execute('+2argadd y')
    assert_argc({'a', 'b', 'c', 'x', 'y'})
    eq(1, eval('argidx()'))
  end)
end)
