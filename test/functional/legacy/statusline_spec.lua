local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local exec = t.exec
local feed = t.feed

before_each(clear)

describe('statusline', function()
  local screen

  before_each(function()
    screen = Screen.new(50, 7)
    screen:attach()
  end)

  it('is updated in cmdline mode when using window-local statusline vim-patch:8.2.2737', function()
    exec([[
      setlocal statusline=-%{mode()}-
      split
      setlocal statusline=+%{mode()}+
    ]])
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|
      {3:+n+                                               }|
                                                        |
      {1:~                                                 }|
      {2:-n-                                               }|
                                                        |
    ]])
    feed(':')
    screen:expect([[
                                                        |
      {1:~                                                 }|
      {3:+c+                                               }|
                                                        |
      {1:~                                                 }|
      {2:-c-                                               }|
      :^                                                 |
    ]])
  end)

  it('truncated item does not cause off-by-one highlight vim-patch:8.2.4929', function()
    exec([[
      set laststatus=2
      hi! link User1 Directory
      hi! link User2 ErrorMsg
      set statusline=%.5(%1*ABC%2*DEF%1*GHI%)
    ]])
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*4
      {9:<F}{18:GHI                                             }|
                                                        |
    ]])
  end)

  -- oldtest: Test_statusline_showcmd()
  it('showcmdloc=statusline works', function()
    exec([[
      func MyStatusLine()
        return '%S'
      endfunc

      set showcmd
      set laststatus=2
      set statusline=%S
      set showcmdloc=statusline
      call setline(1, ['a', 'b', 'c'])
      set foldopen+=jump
      1,2fold
      3
    ]])

    feed('g')
    screen:expect([[
      {13:+--  2 lines: a···································}|
      ^c                                                 |
      {1:~                                                 }|*3
      {3:g                                                 }|
                                                        |
    ]])

    -- typing "gg" should open the fold
    feed('g')
    screen:expect([[
      ^a                                                 |
      b                                                 |
      c                                                 |
      {1:~                                                 }|*2
      {3:                                                  }|
                                                        |
    ]])

    feed('<C-V>Gl')
    screen:expect([[
      {17:a}                                                 |
      {17:b}                                                 |
      {17:c}^                                                 |
      {1:~                                                 }|*2
      {3:3x2                                               }|
      {5:-- VISUAL BLOCK --}                                |
    ]])

    feed('<Esc>1234')
    screen:expect([[
      a                                                 |
      b                                                 |
      ^c                                                 |
      {1:~                                                 }|*2
      {3:1234                                              }|
                                                        |
    ]])

    feed('<Esc>:set statusline=<CR>')
    feed(':<CR>')
    feed('1234')
    screen:expect([[
      a                                                 |
      b                                                 |
      ^c                                                 |
      {1:~                                                 }|*2
      {3:[No Name] [+]                          1234       }|
      :                                                 |
    ]])
  end)
end)
