-- Tests for folding.
local Screen = require('test.functional.ui.screen')

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, feed_command, expect_any =
  helpers.feed, helpers.insert, helpers.feed_command, helpers.expect_any

describe('folding', function()
  local screen

  before_each(function()
    helpers.clear()

    screen = Screen.new(20, 8)
    screen:attach()
  end)
  after_each(function()
    screen:detach()
  end)

  it('creation, opening, moving (to the end) and closing', function()
    insert([[
      1 aa
      2 bb
      3 cc
      last
      ]])

    -- Basic test if a fold can be created, opened, moving to the end and
    -- closed.
    feed_command('1')
    feed('zf2j')
    feed_command('call append("$", "manual " . getline(foldclosed(".")))')
    feed('zo')
    feed_command('call append("$", foldclosed("."))')
    feed(']z')
    feed_command('call append("$", getline("."))')
    feed('zc')
    feed_command('call append("$", getline(foldclosed(".")))')

    expect_any([[
      manual 1 aa
      -1
      3 cc
      1 aa]])
  end)

  it("foldmethod=marker", function()
    screen:try_resize(20, 10)
    insert([[
      dd {{{
      ee {{{ }}}
      ff }}}
    ]])
    feed_command('set fdm=marker fdl=1')
    feed_command('2')
    feed_command('call append("$", "line 2 foldlevel=" . foldlevel("."))')
    feed('[z')
    feed_command('call append("$", foldlevel("."))')
    feed('jo{{ <esc>r{jj') -- writes '{{{' and moves 2 lines bot
    feed_command('call append("$", foldlevel("."))')
    feed('kYpj')
    feed_command('call append("$", foldlevel("."))')

    helpers.wait()
    screen:expect([[
        dd {{{            |
        ee {{{ }}}        |
      {{{                 |
        ff }}}            |
        ff }}}            |
      ^                    |
      line 2 foldlevel=2  |
      1                   |
      1                   |
                          |
    ]])

  end)

  it("foldmethod=indent", function()
    screen:try_resize(20, 8)
    feed_command('set fdm=indent sw=2')
    insert([[
    aa
      bb
        cc
    last
    ]])
    feed_command('call append("$", "foldlevel line3=" . foldlevel(3))')
    feed_command('call append("$", foldlevel(2))')
    feed('zR')

    helpers.wait()
    screen:expect([[
      aa                  |
        bb                |
          cc              |
      last                |
      ^                    |
      foldlevel line3=2   |
      1                   |
                          |
    ]])
  end)

  it("foldmethod=syntax", function()
    screen:try_resize(35, 15)
    insert([[
      1 aa
      2 bb
      3 cc
      4 dd {{{
      5 ee {{{ }}}
      6 ff }}}
      7 gg
      8 hh
      9 ii
      a jj
      b kk
      last]])
    feed_command('set fdm=syntax fdl=0')
    feed_command('syn region Hup start="dd" end="ii" fold contains=Fd1,Fd2,Fd3')
    feed_command('syn region Fd1 start="ee" end="ff" fold contained')
    feed_command('syn region Fd2 start="gg" end="hh" fold contained')
    feed_command('syn region Fd3 start="commentstart" end="commentend" fold contained')
    feed('Gzk')
    feed_command('call append("$", "folding " . getline("."))')
    feed('k')
    feed_command('call append("$", getline("."))')
    feed('jAcommentstart  <esc>Acommentend<esc>')
    feed_command('set fdl=1')
    feed('3j')
    feed_command('call append("$", getline("."))')
    feed_command('set fdl=0')
    feed('zO<C-L>j') -- <C-L> redraws screen
    feed_command('call append("$", getline("."))')
    feed_command('set fdl=0')
    expect_any([[
      folding 9 ii
      3 cc
      9 ii
      a jj]])
  end)

  it("foldmethod=expression", function()
    insert([[
      1 aa
      2 bb
      3 cc
      4 dd {{{
      5 ee {{{ }}}
      6 ff }}}
      7 gg
      8 hh
      9 ii
      a jj
      b kk
      last ]])

    feed_command([[
    fun Flvl()
     let l = getline(v:lnum)
     if l =~ "bb$"
       return 2
     elseif l =~ "gg$"
       return "s1"
     elseif l =~ "ii$"
       return ">2"
     elseif l =~ "kk$"
       return "0"
     endif
     return "="
    endfun
    ]])
    feed_command('set fdm=expr fde=Flvl()')
    feed_command('/bb$')
    feed_command('call append("$", "expr " . foldlevel("."))')
    feed_command('/hh$')
    feed_command('call append("$", foldlevel("."))')
    feed_command('/ii$')
    feed_command('call append("$", foldlevel("."))')
    feed_command('/kk$')
    feed_command('call append("$", foldlevel("."))')

    expect_any([[
      expr 2
      1
      2
      0]])
  end)

  it('can be opened after :move', function()
    -- luacheck: ignore
    screen:try_resize(35, 8)
    insert([[
      Test fdm=indent and :move bug END
      line2
      	Test fdm=indent START
      	line3
      	line4]])
    feed_command('set noai nosta ')
    feed_command('set fdm=indent')
    feed_command('1m1')
    feed('2jzc')
    feed_command('m0')
    feed('zR')

    expect_any([[
      	Test fdm=indent START
      	line3
      	line4
      Test fdm=indent and :move bug END
      line2]])
  end)
end)

