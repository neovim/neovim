-- Test changelist position after splitting window
-- Set 'undolevels' to make changelist for sourced file

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local feed_command, expect = helpers.feed_command, helpers.expect

describe('changelist', function()
  setup(clear)

  it('is working', function()
    insert("1\n2")

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
