-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Tests for setting the '[,'] marks when joining lines.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('autoformat join', function()
  setup(clear)

  it('is working', function()
    insert([[
		O sodales, ludite, vos qui
attamen consulite per voster honur. Tua pulchra facies me fay planszer milies

This line.
Should be joined with the next line
and with this line

Results:]])

    feed('gg')
    feed('0gqj<cr>')

    execute([[let a=string(getpos("'[")).'/'.string(getpos("']"))]])
    execute("g/^This line/;'}-join")
    execute([[let b=string(getpos("'[")).'/'.string(getpos("']"))]])
    execute("$put ='First test: Start/End '.string(a)")
    execute("$put ='Second test: Start/End '.string(b)")

    expect([[
		O sodales, ludite, vos qui attamen consulite per voster honur.
Tua pulchra facies me fay planszer milies

This line.  Should be joined with the next line and with this line

Results:
First test: Start/End '[0, 1, 1, 0]/[0, 2, 1, 0]'
Second test: Start/End '[0, 4, 11, 0]/[0, 4, 67, 0]']])
  end)
end)
