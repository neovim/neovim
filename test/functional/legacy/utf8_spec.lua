-- Tests for Unicode manipulations

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect
local eq, eval = helpers.eq, helpers.eval

describe('utf8', function()
  setup(clear)

  it('is working', function()
    insert('start:')

    execute('new')
    execute('call setline(1, ["aaa", "あああ", "bbb"])')

    -- Visual block Insert adjusts for multi-byte char
    feed('gg0l<C-V>jjIx<Esc>')

    execute('let r = getline(1, "$")')
    execute('bwipeout!')
    execute('$put=r')
    execute('call garbagecollect(1)')

    expect([[
      start:
      axaa
      xあああ
      bxbb]])
  end)

  it('strchars()', function()
    eq(1, eval('strchars("a")'))
    eq(1, eval('strchars("a", 0)'))
    eq(1, eval('strchars("a", 1)'))

    eq(3, eval('strchars("あいa")'))
    eq(3, eval('strchars("あいa", 0)'))
    eq(3, eval('strchars("あいa", 1)'))

    eq(2, eval('strchars("A\\u20dd")'))
    eq(2, eval('strchars("A\\u20dd", 0)'))
    eq(1, eval('strchars("A\\u20dd", 1)'))

    eq(3, eval('strchars("A\\u20dd\\u20dd")'))
    eq(3, eval('strchars("A\\u20dd\\u20dd", 0)'))
    eq(1, eval('strchars("A\\u20dd\\u20dd", 1)'))

    eq(1, eval('strchars("\\u20dd")'))
    eq(1, eval('strchars("\\u20dd", 0)'))
    eq(1, eval('strchars("\\u20dd", 1)'))
  end)
end)
