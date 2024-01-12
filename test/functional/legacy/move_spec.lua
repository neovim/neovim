local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local feed = helpers.feed
local fn = helpers.fn

before_each(clear)

describe(':move', function()
  -- oldtest: Test_move_undo()
  it('redraws correctly when undone', function()
    local screen = Screen.new(60, 10)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    })
    screen:attach()

    fn.setline(1, { 'First', 'Second', 'Third', 'Fourth' })
    feed('gg:move +1<CR>')
    screen:expect([[
      Second                                                      |
      ^First                                                       |
      Third                                                       |
      Fourth                                                      |
      {0:~                                                           }|*5
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
      {0:~                                                           }|*5
                                                                  |
    ]])
  end)
end)
