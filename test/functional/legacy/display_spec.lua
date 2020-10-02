local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local wait = helpers.wait
local feed = helpers.feed
local feed_command = helpers.feed_command

describe('display', function()
  local screen

  it('scroll when modified at topline', function()
    clear()
    screen = Screen.new(20, 4)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true},
    })

    feed_command([[call setline(1, repeat('a', 21))]])
    wait()
    feed('O')
    screen:expect([[
      ^                    |
      aaaaaaaaaaaaaaaaaaaa|
      a                   |
      {1:-- INSERT --}        |
    ]])
  end)
end)

