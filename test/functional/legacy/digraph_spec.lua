local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local feed = n.feed

before_each(clear)

describe('digraph', function()
  -- oldtest: Test_entering_digraph()
  it('characters displayed on the screen', function()
    local screen = Screen.new(10, 6)
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
