-- Test for writing and reading a file of over 100 Kbyte

local helpers = require('test.functional.helpers')(after_each)

local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command, expect = helpers.command, helpers.expect
local wait = helpers.wait

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
    wait()

    command('w! test.out')
    command('%d')
    command('e! test.out')
    command('yank A')
    command('3003yank A')
    command('6005yank A')
    command('%d')
    command('0put a')
    command('$d')
    command('w!')

    expect([[
      This is the start
      This is the middle
      This is the end]])
  end)

  teardown(function()
    os.remove('test.out')
  end)
end)
