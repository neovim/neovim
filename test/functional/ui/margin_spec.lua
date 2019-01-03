local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

describe('margin option', function()
  it('works for margin=2', function()
    helpers.clear()
    local screen = Screen.new(25, 3)
    screen:attach()
    helpers.feed_command('set nu')
    helpers.feed_command('set margin=2')
    helpers.insert('hello\ngoodbye')
    screen:expect([[
      {1:  1 }  hello              |
      {1:  2 }  goodby^e            |
                               |
    ]], {{foreground = Screen.colors.Brown}})
  end)

  it('works for margin=3', function()
    helpers.clear()
    local screen = Screen.new(25, 3)
    screen:attach()
    helpers.feed_command('set nu')
    helpers.feed_command('set margin=3')
    helpers.insert('hello\ngoodbye')
    screen:expect([[
      {1:  1 }   hello             |
      {1:  2 }   goodby^e           |
                               |
    ]], {{foreground = Screen.colors.Brown}})
  end)
end)
