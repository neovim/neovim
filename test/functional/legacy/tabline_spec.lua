local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed

before_each(clear)

describe('tabline', function()
  local screen

  before_each(function()
    screen = Screen.new(50, 7)
    screen:attach()
  end)

  -- oldtest: Test_tabline_showcmd()
  it('showcmdloc=tabline works', function()
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Black }, -- Visual
      [2] = { bold = true }, -- MoreMsg, TabLineSel
      [3] = { reverse = true }, -- TabLineFill
      [4] = { background = Screen.colors.LightGrey, underline = true }, -- TabLine
      [5] = { background = Screen.colors.LightGrey, foreground = Screen.colors.DarkBlue }, -- Folded
    })
    exec([[
      func MyTabLine()
        return '%S'
      endfunc

      set showcmd
      set showtabline=2
      set tabline=%!MyTabLine()
      set showcmdloc=tabline
      call setline(1, ['a', 'b', 'c'])
      set foldopen+=jump
      1,2fold
      3
    ]])

    feed('g')
    screen:expect([[
      {3:g                                                 }|
      {5:+--  2 lines: a···································}|
      ^c                                                 |
      {0:~                                                 }|*3
                                                        |
    ]])

    -- typing "gg" should open the fold
    feed('g')
    screen:expect([[
      {3:                                                  }|
      ^a                                                 |
      b                                                 |
      c                                                 |
      {0:~                                                 }|*2
                                                        |
    ]])

    feed('<C-V>Gl')
    screen:expect([[
      {3:3x2                                               }|
      {1:a}                                                 |
      {1:b}                                                 |
      {1:c}^                                                 |
      {0:~                                                 }|*2
      {2:-- VISUAL BLOCK --}                                |
    ]])

    feed('<Esc>1234')
    screen:expect([[
      {3:1234                                              }|
      a                                                 |
      b                                                 |
      ^c                                                 |
      {0:~                                                 }|*2
                                                        |
    ]])

    feed('<Esc>:set tabline=<CR>')
    feed(':<CR>')
    feed('1234')
    screen:expect([[
      {2: + [No Name] }{3:                           }{4:1234}{3:      }|
      a                                                 |
      b                                                 |
      ^c                                                 |
      {0:~                                                 }|*2
      :                                                 |
    ]])
  end)
end)
