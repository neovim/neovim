local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local command = t.command
local feed = t.feed

before_each(clear)

describe('cpoptions', function()
  it('$', function()
    local screen = Screen.new(30, 6)
    screen:attach()
    command('set cpo+=$')
    command([[call setline(1, 'one two three')]])
    feed('c2w')
    screen:expect([[
      ^one tw$ three                 |
      {1:~                             }|*4
      {5:-- INSERT --}                  |
    ]])
    feed('vim<Esc>')
    screen:expect([[
      vi^m three                     |
      {1:~                             }|*4
                                    |
    ]])
  end)
end)
