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
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {background = Screen.colors.LightGrey},  -- Visual
      [2] = {bold = true},  -- MoreMsg, TabLineSel
      [3] = {reverse = true},  -- TabLineFill
      [4] = {background = Screen.colors.LightGrey, underline = true},  -- TabLine
    })
    exec([[
      set showcmd
      set showtabline=2
      set showcmdloc=tabline
      call setline(1, ['a', 'b', 'c'])
    ]])
    feed('<C-V>Gl')
    screen:expect([[
      {2: + [No Name] }{3:                           }{4:3x2}{3:       }|
      {1:a}                                                 |
      {1:b}                                                 |
      {1:c}^                                                 |
      {0:~                                                 }|
      {0:~                                                 }|
      {2:-- VISUAL BLOCK --}                                |
    ]])
    feed('<Esc>1234')
    screen:expect([[
      {2: + [No Name] }{3:                           }{4:1234}{3:      }|
      a                                                 |
      b                                                 |
      ^c                                                 |
      {0:~                                                 }|
      {0:~                                                 }|
                                                        |
    ]])
  end)
end)
