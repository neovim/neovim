local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local feed = t.feed

before_each(clear)

describe('digraph', function()
  -- oldtest: Test_entering_digraph()
  it('characters displayed on the screen', function()
    local screen = Screen.new(10, 6)
    screen:attach()
    feed('i<C-K>')
    screen:expect([[
      {18:^?}           |
      {1:~           }|*4
      {5:-- INSERT --}|
    ]])
    feed('1')
    screen:expect([[
      {18:^1}           |
      {1:~           }|*4
      {5:-- INSERT --}|
    ]])
    feed('2')
    screen:expect([[
      ½^           |
      {1:~           }|*4
      {5:-- INSERT --}|
    ]])
  end)
end)
