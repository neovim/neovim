-- Tests for folding.
local Screen = require('test.functional.ui.screen')

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, execute, expect_any =
  helpers.feed, helpers.insert, helpers.execute, helpers.expect_any

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
    execute('1')
    feed('zf2j')
    execute('call append("$", "manual " . getline(foldclosed(".")))')
    feed('zo')
    execute('call append("$", foldclosed("."))')
    feed(']z')
    execute('call append("$", getline("."))')
    feed('zc')
    execute('call append("$", getline(foldclosed(".")))')

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
    execute('set fdm=marker fdl=1')
    execute('2')
    execute('call append("$", "line 2 foldlevel=" . foldlevel("."))')
    feed('[z')
    execute('call append("$", foldlevel("."))')
    feed('jo{{ <esc>r{jj') -- writes '{{{' and moves 2 lines bot
    execute('call append("$", foldlevel("."))')
    feed('kYpj')
    execute('call append("$", foldlevel("."))')

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
    execute('set fdm=indent sw=2')
    insert([[
    aa
      bb
        cc
    last
    ]])
    execute('call append("$", "foldlevel line3=" . foldlevel(3))')
    execute('call append("$", foldlevel(2))')
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
    execute('set fdm=syntax fdl=0')
    execute('syn region Hup start="dd" end="ii" fold contains=Fd1,Fd2,Fd3')
    execute('syn region Fd1 start="ee" end="ff" fold contained')
    execute('syn region Fd2 start="gg" end="hh" fold contained')
    execute('syn region Fd3 start="commentstart" end="commentend" fold contained')
    feed('Gzk')
    execute('call append("$", "folding " . getline("."))')
    feed('k')
    execute('call append("$", getline("."))')
    feed('jAcommentstart  <esc>Acommentend<esc>')
    execute('set fdl=1')
    feed('3j')
    execute('call append("$", getline("."))')
    execute('set fdl=0')
    feed('zO<C-L>j') -- <C-L> redraws screen
    execute('call append("$", getline("."))')
    execute('set fdl=0')
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

    execute([[
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
    execute('set fdm=expr fde=Flvl()')
    execute('/bb$')
    execute('call append("$", "expr " . foldlevel("."))')
    execute('/hh$')
    execute('call append("$", foldlevel("."))')
    execute('/ii$')
    execute('call append("$", foldlevel("."))')
    execute('/kk$')
    execute('call append("$", foldlevel("."))')

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
    execute('set noai nosta ')
    execute('set fdm=indent')
    execute('1m1')
    feed('2jzc')
    execute('m0')
    feed('zR')

    expect_any([[
      	Test fdm=indent START
      	line3
      	line4
      Test fdm=indent and :move bug END
      line2]])
  end)
end)

