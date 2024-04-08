-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Test for visual block shift and tab characters.

local t = require('test.functional.testutil')(after_each)
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

describe('visual block shift and tab characters', function()
  setup(clear)

  it('is working', function()
    insert([[
      one two three
      one two three
      one two three
      one two three
      one two three

      abcdefghijklmnopqrstuvwxyz
      abcdefghijklmnopqrstuvwxyz
      abcdefghijklmnopqrstuvwxyz
      abcdefghijklmnopqrstuvwxyz
      abcdefghijklmnopqrstuvwxyz]])

    feed('gg')
    feed([[fe<C-v>4jR<esc>ugvr1:'<lt>,'>yank A<cr>]])
    feed_command('/^abcdefgh')
    feed('<C-v>4jI    <esc>j<lt><lt>11|D')
    feed('j7|a		<esc>')
    feed('j7|a		   <esc>')
    feed('j7|a	       	<esc>4k13|<C-v>4j<lt>')
    feed_command('$-5,$yank A')
    feed_command([[$-4,$s/\s\+//g]])
    feed('<C-v>4kI    <esc>j<lt><lt>')
    feed('j7|a		<esc>')
    feed('j7|a					<esc>')
    feed('j7|a	       		<esc>4k13|<C-v>4j3<lt>')
    feed_command('$-4,$yank A')

    -- Put @a and clean empty lines
    feed_command('%d')
    feed_command('0put a')
    feed_command('$d')

    -- Assert buffer contents.
    expect([[
      on1 two three
      on1 two three
      on1 two three
      on1 two three
      on1 two three

          abcdefghijklmnopqrstuvwxyz
      abcdefghij
          abc	    defghijklmnopqrstuvwxyz
          abc	    defghijklmnopqrstuvwxyz
          abc	    defghijklmnopqrstuvwxyz
          abcdefghijklmnopqrstuvwxyz
      abcdefghij
          abc	    defghijklmnopqrstuvwxyz
          abc		defghijklmnopqrstuvwxyz
          abc	    defghijklmnopqrstuvwxyz]])
  end)
end)
