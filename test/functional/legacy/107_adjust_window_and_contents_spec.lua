-- Tests for adjusting window and contents

local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local insert = helpers.insert
local clear, execute = helpers.clear, helpers.execute

describe('107', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new()
    screen:attach()

    insert('start:')
    execute('new')
    execute('call setline(1, range(1,256))')
    execute('let r=[]')
    execute('func! GetScreenStr(row)')
    execute('   let str = ""')
    execute('   for c in range(1,3)')
    execute('       let str .= nr2char(screenchar(a:row, c))')
    execute('   endfor')
    execute('   return str')
    execute('endfunc')
    execute([[exe ":norm! \<C-W>t\<C-W>=1Gzt\<C-W>w\<C-W>+"]])
    execute('let s3=GetScreenStr(1)')
    execute('wincmd p')
    execute('call add(r, [line("w0"), s3])')
    execute([[exe ":norm! \<C-W>t\<C-W>=50Gzt\<C-W>w\<C-W>+"]])
    execute('let s3=GetScreenStr(1)')
    execute('wincmd p')
    execute('call add(r, [line("w0"), s3])')
    execute([[exe ":norm! \<C-W>t\<C-W>=59Gzt\<C-W>w\<C-W>+"]])
    execute('let s3=GetScreenStr(1)')
    execute(':wincmd p')
    execute('call add(r, [line("w0"), s3])')
    execute('bwipeout!')
    execute('$put=r')
    execute('call garbagecollect(1)')

    screen:expect([[
      start:                                               |
      [1, '1  ']                                           |
      [50, '50 ']                                          |
      ^[59, '59 ']                                          |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      :call garbagecollect(1)                              |
    ]])
  end)
end)
