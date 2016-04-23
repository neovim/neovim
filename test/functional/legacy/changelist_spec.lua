-- Test changelist position after splitting window
-- Set 'undolevels' to make changelist for sourced file

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('changelist', function()
  setup(clear)

  it('is working', function()
    insert("1\n2")

    feed('Gkylp')
    execute('set ul=100')

    feed('Gylp')
    execute('set ul=100')

    feed('gg')
    execute('vsplit')
    execute('try', 'normal g;', 'normal ggVGcpass', 'catch', 'normal ggVGcfail', 'endtry')

    expect('pass')
  end)
end)
