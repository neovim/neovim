-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Test for visual block shift and tab characters.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

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
    execute('/^abcdefgh')
    feed('<C-v>4jI    <esc>j<lt><lt>11|D')
    feed('j7|a		<esc>')
    feed('j7|a		   <esc>')
    feed('j7|a	       	<esc>4k13|<C-v>4j<lt>')
    execute('$-5,$yank A')
    execute([[$-4,$s/\s\+//g]])
    feed('<C-v>4kI    <esc>j<lt><lt>')
    feed('j7|a		<esc>')
    feed('j7|a					<esc>')
    feed('j7|a	       		<esc>4k13|<C-v>4j3<lt>')
    execute('$-4,$yank A')

    -- Put @a and clean empty lines
    execute('%d')
    execute('0put a')
    execute('$d')

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
