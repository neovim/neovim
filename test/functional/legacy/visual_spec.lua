local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

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
      {17:aaaaaa}^                                            |
      {17:bbbb   }                                           |
      {17:cc     }                                           |
      {1:~                                                 }|*2
      {5:-- VISUAL BLOCK --}                                |
    ]])

    feed('<Esc>gg<C-V>G$')
    screen:expect([[
      {17:aaaaaa }                                           |
      {17:bbbb   }                                           |
      {17:cc}^ {17:    }                                           |
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
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^a|
      {1:+}{17:aaaa}aaaaaa                                       |
      {1:~                                                 }|*3
      {5:-- VISUAL --}                                      |
    ]])
  end)
end)

describe('Visual percent motion', function()
  it('allows percent match % on matching brackets in visual line mode', function()
    local fn = n.fn
    local t = require('test.testutil')
    local eq = t.eq

    exec([[
      call setline(1, ['object(', ') {', '},'])
    ]])

    -- Start at line 1, column 1
    eq({ 0, 1, 1, 0 }, fn.getpos('.'))

    -- Go into line selection mode using V
    -- Move to ( using $
    -- Jump to matching ) using %
    -- Press $ to go to {
    -- Press % again to jump to matching }
    feed('V$%$%')

    -- Cursor should be on the matching '}' on line 3, column 1
    eq({ 0, 3, 1, 0 }, fn.getpos('.'))
  end)
end)
