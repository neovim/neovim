local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local feed = helpers.feed
local exec = helpers.exec

before_each(clear)

describe('Visual highlight', function()
  local screen

  before_each(function()
    screen = Screen.new(50, 6)
    screen:set_default_attr_ids({
      [0] = { foreground = Screen.colors.Blue, bold = true }, -- NonText
      [1] = { bold = true }, -- ModeMsg
      [2] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Black }, -- Visual
    })
    screen:attach()
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
      {2:aaaaaa}^                                            |
      {2:bbbb   }                                           |
      {2:cc     }                                           |
      {0:~                                                 }|*2
      {1:-- VISUAL BLOCK --}                                |
    ]])

    feed('<Esc>gg<C-V>G$')
    screen:expect([[
      {2:aaaaaa }                                           |
      {2:bbbb   }                                           |
      {2:cc}^ {2:    }                                           |
      {0:~                                                 }|*2
      {1:-- VISUAL BLOCK --}                                |
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
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^a|
      {0:+}{2:aaaa}aaaaaa                                       |
      {0:~                                                 }|*3
      {1:-- VISUAL --}                                      |
    ]])
  end)
end)
