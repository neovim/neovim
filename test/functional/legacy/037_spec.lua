-- Test for 'scrollbind'. <eralston@computer.org>   Do not add a line below!

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

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
    feed('<C-W>t:<cr>')
    execute('resize 8')
    execute('/^start of window 1$/')
    feed('zt:<cr>')
    execute('set scrollbind')
    feed('<C-W>j:<cr>')
    execute('resize 7')
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
