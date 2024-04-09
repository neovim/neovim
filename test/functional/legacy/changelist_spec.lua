-- Test changelist position after splitting window
-- Set 'undolevels' to make changelist for sourced file

local t = require('test.functional.testutil')()
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

describe('changelist', function()
  setup(clear)

  it('is working', function()
    insert('1\n2')

    feed('Gkylp')
    feed_command('set ul=100')

    feed('Gylp')
    feed_command('set ul=100')

    feed('gg')
    feed_command('vsplit')
    feed_command('try', 'normal g;', 'normal ggVGcpass', 'catch', 'normal ggVGcfail', 'endtry')

    expect('pass')
  end)
end)
