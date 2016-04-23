-- Test for writing and reading a file of over 100 Kbyte

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('writing and reading a file of over 100 Kbyte', function()
  setup(clear)

  it('is working', function()
    insert([[
      This is the start
      This is the leader
      This is the middle
      This is the trailer
      This is the end]])

    feed('kY3000p2GY3000p')

    execute('w! test.out')
    execute('%d')
    execute('e! test.out')
    execute('yank A')
    execute('3003yank A')
    execute('6005yank A')
    execute('%d')
    execute('0put a')
    execute('$d')
    execute('w!')

    expect([[
      This is the start
      This is the middle
      This is the end]])
  end)

  teardown(function()
    os.remove('test.out')
  end)
end)
