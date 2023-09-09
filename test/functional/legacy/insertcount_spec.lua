-- Tests for repeating insert and replace.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local feed_command, expect = helpers.feed_command, helpers.expect

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
