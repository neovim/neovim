-- Test for t movement command and 'cpo-;' setting

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('coptions', function()
  setup(clear)

  it('is working', function()
    insert([[
      aaa two three four
          zzz
      yyy   
      bbb yee yoo four
      ccc two three four
      ddd yee yoo four]])

    execute('set cpo-=;')

    feed('gg0tt;D')
    feed('j0fz;D')
    feed('j$Fy;D')
    feed('j$Ty;D')

    execute('set cpo+=;')

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
