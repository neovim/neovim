-- First a simple test to check if the test script works.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local eval = helpers.eval

describe('test script', function()
  setup(clear)

  it('is working', function()
    -- Write a single line to test.out to check if testing works at all.
    execute('%d')
    feed('athis is a test<esc>')

    -- Assert buffer contents.
    expect([[
      this is a test]])
  end)
end)

describe('term size', function()
  setup(clear)

  it('is greater than 80x24', function()
    -- (Some tests will fail. When columns and/or lines are small).
    local lines = eval('&lines')
    local columns = eval('&columns')
    assert.False( lines < 24 )
    assert.False( columns < 80 )
  end)
end)

