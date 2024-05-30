-- Test for t movement command and 'cpo-;' setting

local n = require('test.functional.testnvim')()

local clear, feed, insert = n.clear, n.feed, n.insert
local feed_command, expect = n.feed_command, n.expect

describe('coptions', function()
  setup(clear)

  -- luacheck: ignore 613 (Trailing whitespace in a string)
  it('is working', function()
    insert([[
      aaa two three four
          zzz
      yyy   
      bbb yee yoo four
      ccc two three four
      ddd yee yoo four]])

    feed_command('set cpo-=;')

    feed('gg0tt;D')
    feed('j0fz;D')
    feed('j$Fy;D')
    feed('j$Ty;D')

    feed_command('set cpo+=;')

    feed('j0tt;;D')
    feed('j$Ty;;D')

    expect([[
      aaa two
          z
      y
      bbb y
      ccc
      ddd yee y]])
  end)
end)
