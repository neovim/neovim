-- Tests for [ CTRL-I with a count and CTRL-W CTRL-I with a count

local t = require('test.functional.testutil')()
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

describe('CTRL-W CTRL-I', function()
  setup(clear)

  it('is working', function()
    insert([[
      #include test21.in

      /* test text test tex start here
      some text
      test text
      start OK if found this line
      start found wrong line
      test text]])

    -- Search for the second occurrence of start and append to register
    feed_command('/start')
    feed('2[<C-i>')
    feed_command('yank A')

    -- Same as above but using different keystrokes.
    feed('?start<cr>')
    feed('2<C-w><Tab>')
    feed_command('yank A')

    -- Clean buffer and put register
    feed('ggdG"ap')
    feed_command('1d')

    -- The buffer should now contain:
    expect([[
      start OK if found this line
      start OK if found this line]])
  end)
end)
