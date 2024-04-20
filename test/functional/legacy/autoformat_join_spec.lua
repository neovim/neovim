-- Tests for setting the '[,'] marks when joining lines.

local n = require('test.functional.testnvim')()

local clear, feed, insert = n.clear, n.feed, n.insert
local command, expect = n.command, n.expect
local poke_eventloop = n.poke_eventloop

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
    poke_eventloop()

    command([[let a=string(getpos("'[")).'/'.string(getpos("']"))]])
    command("g/^This line/;'}-join")
    command([[let b=string(getpos("'[")).'/'.string(getpos("']"))]])
    command("$put ='First test: Start/End '.string(a)")
    command("$put ='Second test: Start/End '.string(b)")

    expect([[
		O sodales, ludite, vos qui attamen consulite per voster honur.
Tua pulchra facies me fay planszer milies

This line.  Should be joined with the next line and with this line

Results:
First test: Start/End '[0, 1, 1, 0]/[0, 2, 1, 0]'
Second test: Start/End '[0, 4, 11, 0]/[0, 4, 67, 0]']])
  end)
end)
