-- Test for Bufleave autocommand that deletes the buffer we are about to edit.

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('BufLeave autocommand', function()
  setup(clear)

  it('is working', function()
    insert([[
      start of test file xx
      end of test file xx]])

    execute('au BufLeave * bwipe yy')
    execute('e yy')

    expect([[
      start of test file xx
      end of test file xx]])
  end)
end)
