-- Tests for repeating insert and replace.

local t = require('test.functional.testutil')()
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

describe('insertcount', function()
  setup(clear)

  it('is working', function()
    insert([[
      First line
      Second line
      Last line]])

    feed_command('/Second')
    feed('4gro')

    expect([[
      First line
      oooond line
      Last line]])
  end)
end)
