local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute

describe('Signs', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ignore( {{}, {bold=true, foreground=255}} ) 
  end)

  after_each(function()
    screen:detach()
  end)

  describe(':sign place', function()
    it('shadows previously placed signs', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      execute('sign define piet text=>> texthl=Search')
      execute('sign define pietx text=>! texthl=Search')
      execute('sign place 1 line=1 name=piet buffer=1')
      execute('sign place 2 line=3 name=piet buffer=1')
      execute('sign place 3 line=1 name=pietx buffer=1')
      screen:expect([[
        >!a                                                  |
          b                                                  |
        >>c                                                  |
          ^                                                   |
          ~                                                  |
          ~                                                  |
          ~                                                  |
          ~                                                  |
          ~                                                  |
          ~                                                  |
          ~                                                  |
          ~                                                  |
          ~                                                  |
        :sign place 3 line=1 name=pietx buffer=1             |
      ]])
    end)
  end)
end)
