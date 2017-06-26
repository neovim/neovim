local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command

if helpers.pending_win32(pending) then return end

describe('Signs', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=255},
      [1] = {background = Screen.colors.Yellow},
      [2] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.Grey},
    } )
  end)

  after_each(function()
    screen:detach()
  end)

  describe(':sign place', function()
    it('shadows previously placed signs', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      command('sign define piet text=>> texthl=Search')
      command('sign define pietx text=>! texthl=Search')
      command('sign place 1 line=1 name=piet buffer=1')
      command('sign place 2 line=3 name=piet buffer=1')
      command('sign place 3 line=1 name=pietx buffer=1')
      screen:expect([[
        {1:>!}a                                                  |
        {2:  }b                                                  |
        {1:>>}c                                                  |
        {2:  }^                                                   |
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
                                                             |
      ]])
    end)
  end)
end)
