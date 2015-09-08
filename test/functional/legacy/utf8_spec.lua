-- Tests for Unicode manipulations

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

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
end)
