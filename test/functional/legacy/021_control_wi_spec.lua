-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Tests for [ CTRL-I with a count and CTRL-W CTRL-I with a count

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

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

    -- Search for the second occurence of start and append to register
    execute('/start')
    feed('2[<C-i>')
    execute('yank A')

    -- Same as above but using different keystrokes.
    feed('?start<cr>')
    feed('2<C-w><Tab>')
    execute('yank A')

    -- Clean buffer and put register
    feed('ggdG"ap')
    execute('1d')

    -- The buffer should now contain:
    expect([[
      start OK if found this line
      start OK if found this line]])
  end)
end)
