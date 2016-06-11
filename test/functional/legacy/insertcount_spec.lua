-- Tests for repeating insert and replace.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('insertcount', function()
  setup(clear)

  it('is working', function()
    insert([[
      First line
      Second line
      Last line]])

    execute('/Second')
    feed('4gro')

    expect([[
      First line
      oooond line
      Last line]])
  end)
end)
