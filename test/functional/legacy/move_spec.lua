local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local feed = n.feed
local fn = n.fn

before_each(clear)

describe(':move', function()
  -- oldtest: Test_move_undo()
  it('redraws correctly when undone', function()
    local screen = Screen.new(60, 10)

    fn.setline(1, { 'First', 'Second', 'Third', 'Fourth' })
    feed('gg:move +1<CR>')
    screen:expect([[
      Second                                                      |
      ^First                                                       |
      Third                                                       |
      Fourth                                                      |
      {1:~                                                           }|*5
      :move +1                                                    |
    ]])

    -- here the display would show the last few lines scrolled down
    feed('u')
    feed(':<Esc>')
    screen:expect([[
      ^First                                                       |
      Second                                                      |
      Third                                                       |
      Fourth                                                      |
      {1:~                                                           }|*5
                                                                  |
    ]])
  end)
end)
