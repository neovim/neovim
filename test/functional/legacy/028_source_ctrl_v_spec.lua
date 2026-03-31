-- Test for sourcing a file with CTRL-V's at the end of the line

local n = require('test.functional.testnvim')()

local clear, feed, insert = n.clear, n.feed, n.insert
local feed_command, expect = n.feed_command, n.expect

describe('028', function()
  before_each(clear)

  it('CTRL-V at the end of the line is working', function()
    insert([[
      firstline
      map __1 afirst
      map __2 asecond
      map __3 athird
      map __4 afourth
      map __5 afifth
      map __1 asdX
      map __2 asdXX
      map __3 asdXX
      map __4 asdXXX
      map __5 asdXXX
      lastline]])

    feed(':%s/X/<C-v><C-v>/g<cr>')
    feed(':/firstline/+1,/lastline/-1w! Xtestfile<cr>')
    feed_command('so Xtestfile')
    feed_command('%d')
    feed('Gmm__1<Esc><Esc>__2<Esc>__3<Esc><Esc>__4<Esc>__5<Esc>')
    feed(":'m,$s/<C-v><C-@>/0/g<cr>")

    expect([[
      sd
      map __2 asdsecondsdsd0map __5 asd0fifth]])
  end)

  it('CTRL-X/CTRL-A is working', function()
    insert([[
      12352

      12354]])
    feed_command('/12352')
    feed('<C-A>')
    feed_command('/12354')
    feed('<C-X>')
    expect([[
      12353

      12353]])
  end)

  teardown(function()
    os.remove('Xtestfile')
  end)
end)
