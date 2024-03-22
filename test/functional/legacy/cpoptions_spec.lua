local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed

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
