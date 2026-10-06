local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local feed = n.feed
local exec = n.exec

before_each(clear)

describe('Visual highlight', function()
  local screen

  before_each(function()
    screen = Screen.new(50, 6)
  end)

  -- oldtest: Test_visual_block_with_virtualedit()
  it('shows selection correctly with virtualedit=block', function()
    exec([[
      call setline(1, ['aaaaaa', 'bbbb', 'cc'])
      set virtualedit=block
      normal G
    ]])

    feed('<C-V>gg$')
    screen:expect([[
      {17:aaaaaa^ }                                           |
      {17:bbbb   }                                           |
      {17:cc     }                                           |
      {1:~                                                 }|*2
      {5:-- VISUAL BLOCK --}                                |
    ]])

    feed('<Esc>gg<C-V>G$')
    screen:expect([[
      {17:aaaaaa }                                           |
      {17:bbbb   }                                           |
      {17:cc^     }                                           |
      {1:~                                                 }|*2
      {5:-- VISUAL BLOCK --}                                |
    ]])
  end)

  -- oldtest: Test_visual_hl_with_showbreak()
  it("with cursor at end of screen line and 'showbreak'", function()
    exec([[
      setlocal showbreak=+
      call setline(1, repeat('a', &columns + 10))
      normal g$v4lo
    ]])

    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{17:^a}|
      {1:+}{17:aaaa}aaaaaa                                       |
      {1:~                                                 }|*3
      {5:-- VISUAL --}                                      |
    ]])
  end)

  -- oldtest: Test_visual_update_lastline()
  it('with last line of window partially visible', function()
    screen:try_resize(50, 15)
    exec([[
      call setline(1, ['aaa', 'bbb', 'ccc', repeat('d', 500), 'eee'])
      split
    ]])
    local s1 = [[
      ^aaa                                               |
      bbb                                               |
      ccc                                               |
      dddddddddddddddddddddddddddddddddddddddddddddddddd|*2
      ddddddddddddddddddddddddddddddddddddddddddddddd{1:@@@}|
      {3:[No Name] [+]                                     }|
      aaa                                               |
      bbb                                               |
      ccc                                               |
      dddddddddddddddddddddddddddddddddddddddddddddddddd|*2
      ddddddddddddddddddddddddddddddddddddddddddddddd{1:@@@}|
      {2:[No Name] [+]                                     }|
                                                        |
    ]]
    screen:expect(s1)
    feed('vipo')
    screen:expect([[
      {17:^aaa}                                               |
      {17:bbb}                                               |
      {17:ccc}                                               |
      {17:dddddddddddddddddddddddddddddddddddddddddddddddddd}|*2
      {17:ddddddddddddddddddddddddddddddddddddddddddddddd}{1:@@@}|
      {3:[No Name] [+]                                     }|
      {17:aaa}                                               |
      {17:bbb}                                               |
      {17:ccc}                                               |
      {17:dddddddddddddddddddddddddddddddddddddddddddddddddd}|*2
      {17:ddddddddddddddddddddddddddddddddddddddddddddddd}{1:@@@}|
      {2:[No Name] [+]                                     }|
      {5:-- VISUAL LINE --}                                 |
    ]])
    feed('<Esc>')
    screen:expect(s1)
  end)
end)
