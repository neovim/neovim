local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed

before_each(clear)

describe('statusline', function()
  local screen

  before_each(function()
    screen = Screen.new(50, 7)
    screen:attach()
  end)

  it('is updated in cmdline mode when using window-local statusline vim-patch:8.2.2737', function()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [2] = { bold = true, reverse = true }, -- StatusLine
      [3] = { reverse = true }, -- StatusLineNC
    })
    exec([[
      setlocal statusline=-%{mode()}-
      split
      setlocal statusline=+%{mode()}+
    ]])
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|
      {2:+n+                                               }|
                                                        |
      {1:~                                                 }|
      {3:-n-                                               }|
                                                        |
    ]])
    feed(':')
    screen:expect([[
                                                        |
      {1:~                                                 }|
      {2:+c+                                               }|
                                                        |
      {1:~                                                 }|
      {3:-c-                                               }|
      :^                                                 |
    ]])
  end)

  it('truncated item does not cause off-by-one highlight vim-patch:8.2.4929', function()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [2] = { foreground = Screen.colors.Blue }, -- User1
      [3] = { background = Screen.colors.Red, foreground = Screen.colors.White }, -- User2
    })
    exec([[
      set laststatus=2
      hi! link User1 Directory
      hi! link User2 ErrorMsg
      set statusline=%.5(%1*ABC%2*DEF%1*GHI%)
    ]])
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*4
      {3:<F}{2:GHI                                             }|
                                                        |
    ]])
  end)

  -- oldtest: Test_statusline_showcmd()
  it('showcmdloc=statusline works', function()
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Black }, -- Visual
      [2] = { bold = true }, -- MoreMsg
      [3] = { bold = true, reverse = true }, -- StatusLine
      [5] = { background = Screen.colors.LightGrey, foreground = Screen.colors.DarkBlue }, -- Folded
    })
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
      {5:+--  2 lines: a···································}|
      ^c                                                 |
      {0:~                                                 }|*3
      {3:g                                                 }|
                                                        |
    ]])

    -- typing "gg" should open the fold
    feed('g')
    screen:expect([[
      ^a                                                 |
      b                                                 |
      c                                                 |
      {0:~                                                 }|*2
      {3:                                                  }|
                                                        |
    ]])

    feed('<C-V>Gl')
    screen:expect([[
      {1:a}                                                 |
      {1:b}                                                 |
      {1:c}^                                                 |
      {0:~                                                 }|*2
      {3:3x2                                               }|
      {2:-- VISUAL BLOCK --}                                |
    ]])

    feed('<Esc>1234')
    screen:expect([[
      a                                                 |
      b                                                 |
      ^c                                                 |
      {0:~                                                 }|*2
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
      {0:~                                                 }|*2
      {3:[No Name] [+]                          1234       }|
      :                                                 |
    ]])
  end)
end)
