-- Tests for repeating insert and replace.

local n = require('test.functional.testnvim')()

local clear, feed, insert = n.clear, n.feed, n.insert
local feed_command, expect = n.feed_command, n.expect

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
