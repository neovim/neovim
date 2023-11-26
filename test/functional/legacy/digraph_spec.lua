local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local feed = helpers.feed

before_each(clear)

describe('digraph', function()
  -- oldtest: Test_entering_digraph()
  it('characters displayed on the screen', function()
    local screen = Screen.new(10, 6)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {foreground = Screen.colors.Blue},  -- SpecialKey
      [2] = {bold = true},  -- ModeMsg
    })
    screen:attach()
    feed('i<C-K>')
    screen:expect([[
      {1:^?}           |
      {0:~           }|
      {0:~           }|
      {0:~           }|
      {0:~           }|
      {2:-- INSERT --}|
    ]])
    feed('1')
    screen:expect([[
      {1:^1}           |
      {0:~           }|
      {0:~           }|
      {0:~           }|
      {0:~           }|
      {2:-- INSERT --}|
    ]])
    feed('2')
    screen:expect([[
      ½^           |
      {0:~           }|
      {0:~           }|
      {0:~           }|
      {0:~           }|
      {2:-- INSERT --}|
    ]])
  end)
end)
