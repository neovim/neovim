-- Tests for adjusting window and contents

local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')

local poke_eventloop = t.poke_eventloop
local clear = t.clear
local insert = t.insert
local command = t.command

describe('107', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new()
    screen:attach()

    insert('start:')
    poke_eventloop()
    command('new')
    command('call setline(1, range(1,256))')
    command('let r=[]')
    command([[
      func! GetScreenStr(row)
         let str = ""
         for c in range(1,3)
             let str .= nr2char(screenchar(a:row, c))
         endfor
         return str
      endfunc
    ]])
    command([[exe ":norm! \<C-W>t\<C-W>=1Gzt\<C-W>w\<C-W>+"]])
    command('let s3=GetScreenStr(1)')
    command('wincmd p')
    command('call add(r, [line("w0"), s3])')
    command([[exe ":norm! \<C-W>t\<C-W>=50Gzt\<C-W>w\<C-W>+"]])
    command('let s3=GetScreenStr(1)')
    command('wincmd p')
    command('call add(r, [line("w0"), s3])')
    command([[exe ":norm! \<C-W>t\<C-W>=59Gzt\<C-W>w\<C-W>+"]])
    command('let s3=GetScreenStr(1)')
    command(':wincmd p')
    command('call add(r, [line("w0"), s3])')
    command('bwipeout!')
    command('$put=r')
    command('call garbagecollect(1)')

    screen:expect([[
      start:                                               |
      [1, '1  ']                                           |
      [50, '50 ']                                          |
      ^[59, '59 ']                                          |
      {1:~                                                    }|*9
      3 more lines                                         |
    ]])
  end)
end)
