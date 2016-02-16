-- Test for 'scrollbind'. <eralston@computer.org>   Do not add a line below!

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local eq, eval, wait = helpers.eq, helpers.eval, helpers.wait

local function expect_scroll_pos(cursor, top, bottom)
  wait()
  eq(cursor, eval('line(".")'))
  eq(top, eval('line("w0")'))
  eq(bottom, eval('line("w$")'))
end

local function expect_winnr(winnr)
  eq(winnr, eval('winnr()'))
end

describe('37', function()
  setup(clear)

  it('is working', function()
    insert([[
      start of window 1
      . line 01 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 01
      . line 02 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02
      . line 03 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 03
      . line 04 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 04
      . line 05 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 05
      . line 06 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 06
      . line 07 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 07
      . line 08 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 08
      . line 09 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 09
      . line 10 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 10
      . line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11
      . line 12 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 12
      . line 13 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 13
      . line 14 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 14
      . line 15 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 15
      end of window 1
      
      
      start of window 2
      . line 01 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 01
      . line 02 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 02
      . line 03 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 03
      . line 04 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 04
      . line 05 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 05
      . line 06 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 06
      . line 07 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 07
      . line 08 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 08
      . line 09 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 09
      . line 10 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 10
      . line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11
      . line 12 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 12
      . line 13 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 13
      . line 14 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 14
      . line 15 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 15
      . line 16 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 16
      end of window 2
      
      end of test37.in (please don't delete this line)]])

    execute('set noscrollbind')
    execute('set scrollopt=ver,jump')
    execute('set scrolloff=2')
    execute('set nowrap')
    execute('set noequalalways')
    execute('set splitbelow')
    -- TEST using two windows open to one buffer, one extra empty window.
    execute('split')
    execute('new')
    feed('<C-W>t')
    execute('resize 8')
    -- Intermediate check: Window height is really 8.
    eq(7, eval('line("w$") - line("w0")'))
    execute('/^start of window 1$/')
    feed('zt')
    -- Intermediate check: 'scrolloff' has no effect if we are at the top of
    -- the buffer.
    expect_winnr(1)
    expect_scroll_pos(1, 1, 8)
    execute('set scrollbind')
    feed('<C-W>j')
    execute('resize 7')
    -- Intermediate check: Window height is really 7.
    expect_winnr(2)
    eq(6, eval('line("w$") - line("w0")'))
    execute('/^start of window 2$/')
    feed('zt')
    -- Intermediate check: 'scrolloff' has an effect here.
    expect_scroll_pos(20, 18, 24)
    execute('set scrollbind')
    -- -- start of tests --.
    -- TEST scrolling down.
    feed('L')
    expect_scroll_pos(22, 18, 24)
    feed('5j')
    expect_scroll_pos(27, 23, 29)
    feed('H')
    expect_scroll_pos(25, 23, 29)
    feed('yy')
    feed('<C-W>b')
    expect_winnr(3)
    feed('p')
    feed('r0')
    feed('<C-W>t')
    expect_winnr(1)
    feed('H')
    expect_scroll_pos(25, 23, 29)
    feed('yy')
    feed('<C-W>b')
    feed('p')
    feed('r1')
    feed('<C-W>t')
    feed('L')
    feed('6j')
    feed('H')
    feed('yy')
    feed('<C-W>b')
    feed('p')
    feed('r2')
    feed('<C-W>k')
    feed('H')
    feed('yy')
    feed('<C-W>b')
    feed('p')
    feed('r3')
    -- TEST scrolling up.
    feed('<C-W>tH4k<C-W>jH<C-W>tHyy<C-W>bpr4<C-W>kHyy<C-W>bpr5<C-W>k3k<C-W>tH<C-W>jHyy<C-W>bpr6<C-W>tHyy<C-W>bpr7:<cr>')
    -- TEST horizontal scrolling.
    execute('set scrollopt+=hor')
    feed('gg"zyyG"zpG<C-W>t015zly$<C-W>bp"zpG<C-W>ky$<C-W>bp"zpG:<cr>')
    feed('<C-W>k10jH7zhg0y$<C-W>bp"zpG<C-W>tHg0y$<C-W>bp"zpG:<cr>')
    execute('set scrollopt-=hor')
    -- ****** tests using two different buffers *****.
    feed('<C-W>t<C-W>j:<cr>')
    execute('close')
    feed('<C-W>t:<cr>')
    execute('set noscrollbind')
    execute('/^start of window 2$/,/^end of window 2$/y')
    execute('new')
    -- ZpGp:.
    feed('<C-W>t<C-W>j4<cr>')
    feed('<C-W>t/^start of window 1$/<cr>')
    feed('zt:<cr>')
    execute('set scrollbind')
    feed('<C-W>j:<cr>')
    execute('/^start of window 2$/')
    feed('zt:<cr>')
    execute('set scrollbind')
    -- -- start of tests --.
    -- TEST scrolling down.
    feed('L5jHyy<C-W>bpr0<C-W>tHyy<C-W>bpr1<C-W>tL6jHyy<C-W>bpr2<C-W>kHyy<C-W>bpr3:<cr>')
    -- TEST scrolling up.
    feed('<C-W>tH4k<C-W>jH<C-W>tHyy<C-W>bpr4<C-W>kHyy<C-W>bpr5<C-W>k3k<C-W>tH<C-W>jHyy<C-W>bpr6<C-W>tHyy<C-W>bpr7:<cr>')
    -- TEST horizontal scrolling.
    execute('set scrollopt+=hor')
    feed('gg"zyyG"zpG<C-W>t015zly$<C-W>bp"zpG<C-W>ky$<C-W>bp"zpG:<cr>')
    feed('<C-W>k10jH7zhg0y$<C-W>bp"zpG<C-W>tHg0y$<C-W>bp"zpG:<cr>')
    execute('set scrollopt-=hor')
    -- TEST syncbind.
    feed('<C-W>t:set noscb<cr>')
    feed('ggL<C-W>j:set noscb<cr>')
    feed('ggL:set scb<cr>')
    feed('<C-W>t:set scb<cr>')
    feed('G<C-W>jG:syncbind<cr>')
    feed('Hk<C-W>tH<C-W>jHyy<C-W>bp<C-W>tyy<C-W>bp:<cr>')
    feed('<C-W>t:set noscb<cr>')
    feed('ggL<C-W>j:set noscb<cr>')
    feed('ggL:set scb<cr>')
    feed('<C-W>t:set scb<cr>')
    feed('<C-W>tG<C-W>jG<C-W>t:syncbind<cr>')
    feed('Hk<C-W>jH<C-W>tHyy<C-W>bp<C-W>t<C-W>jyy<C-W>bp:<cr>')
    feed('<C-W>tH3k<C-W>jH<C-W>tHyy<C-W>bp<C-W>t<C-W>jyy<C-W>bp:<cr>')

    -- Assert buffer contents.
    expect([[
      
      0 line 05 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 05
      1 line 05 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 05
      2 line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11
      3 line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11
      4 line 06 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 06
      5 line 06 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 06
      6 line 02 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 02
      7 line 02 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02
      56789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02
      UTSRQPONMLKJIHGREDCBA9876543210 02
      . line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11
      . line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11
      
      0 line 05 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 05
      1 line 05 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 05
      2 line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11
      3 line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11
      4 line 06 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 06
      5 line 06 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 06
      6 line 02 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 02
      7 line 02 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02
      56789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02
      UTSRQPONMLKJIHGREDCBA9876543210 02
      . line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11
      . line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11
      
      . line 16 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 16
      :set scrollbind
      :set scrollbind
      . line 16 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 16
      ]]..'\x17'..[[j:
      . line 12 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 12]])
  end)
end)
