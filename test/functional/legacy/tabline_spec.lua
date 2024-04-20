local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed

before_each(clear)

describe('tabline', function()
  local screen

  before_each(function()
    screen = Screen.new(50, 7)
    screen:attach()
  end)

  -- oldtest: Test_tabline_showcmd()
  it('showcmdloc=tabline works', function()
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
      {2:g                                                 }|
      {13:+--  2 lines: a···································}|
      ^c                                                 |
      {1:~                                                 }|*3
                                                        |
    ]])

    -- typing "gg" should open the fold
    feed('g')
    screen:expect([[
      {2:                                                  }|
      ^a                                                 |
      b                                                 |
      c                                                 |
      {1:~                                                 }|*2
                                                        |
    ]])

    feed('<C-V>Gl')
    screen:expect([[
      {2:3x2                                               }|
      {17:a}                                                 |
      {17:b}                                                 |
      {17:c}^                                                 |
      {1:~                                                 }|*2
      {5:-- VISUAL BLOCK --}                                |
    ]])

    feed('<Esc>1234')
    screen:expect([[
      {2:1234                                              }|
      a                                                 |
      b                                                 |
      ^c                                                 |
      {1:~                                                 }|*2
                                                        |
    ]])

    feed('<Esc>:set tabline=<CR>')
    feed(':<CR>')
    feed('1234')
    screen:expect([[
      {5: + [No Name] }{2:                           }{24:1234}{2:      }|
      a                                                 |
      b                                                 |
      ^c                                                 |
      {1:~                                                 }|*2
      :                                                 |
    ]])
  end)
end)
