local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command
local source = helpers.source

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
      [3] = {background = Screen.colors.Gray90},
      [4] = {bold = true, reverse = true},
      [5] = {reverse = true},
      [6] = {foreground = Screen.colors.Brown},
      [7] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
      [8] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [9] = {bold = true, foreground = Screen.colors.Magenta},
      [10] = {foreground = Screen.colors.Blue1},
      [11] = {bold = true, foreground = Screen.colors.SeaGreen4},
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

    it('can be called right after :split', function()
      feed('ia<cr>b<cr>c<cr><esc>gg')
      -- This used to cause a crash due to :sign using a special redraw
      -- (not updating nvim's specific highlight data structures)
      -- without proper redraw first, as split just flags for redraw later.
      source([[
        set cursorline
        sign define piet text=>> texthl=Search
        split
        sign place 3 line=2 name=piet buffer=1
      ]])
      screen:expect([[
        {2:  }{3:^a                                                  }|
        {1:>>}b                                                  |
        {2:  }c                                                  |
        {2:  }                                                   |
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {4:[No Name] [+]                                        }|
        {2:  }{3:a                                                  }|
        {1:>>}b                                                  |
        {2:  }c                                                  |
        {2:  }                                                   |
        {2:  }{0:~                                                  }|
        {5:[No Name] [+]                                        }|
                                                             |
      ]])
    end)

    it('can combine text, linehl and numhl', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      command('set number')
      command('sign define piet text=>> texthl=Search')
      command('sign define pietx linehl=ErrorMsg')
      command('sign define pietxx numhl=Folded')
      command('sign place 1 line=1 name=piet buffer=1')
      command('sign place 2 line=2 name=pietx buffer=1')
      command('sign place 3 line=3 name=pietxx buffer=1')
      command('sign place 4 line=4 name=piet buffer=1')
      command('sign place 5 line=4 name=pietx buffer=1')
      command('sign place 6 line=4 name=pietxx buffer=1')
      screen:expect([[
        {1:>>}{6:  1 }a                                              |
        {2:  }{6:  2 }{8:b                                              }|
        {2:  }{7:  3 }c                                              |
        {1:>>}{7:  4 }{8:^                                               }|
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

    it('can have 32bit sign IDs', function()
      command('sign define piet text=>> texthl=Search')
      command('sign place 100000 line=1 name=piet buffer=1')
      feed(':sign place<cr>')
      screen:expect([[
        {1:>>}                                                   |
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {4:                                                     }|
        :sign place                                          |
        {9:--- Signs ---}                                        |
        {10:Signs for [NULL]:}                                    |
            line=1  id=100000  name=piet                     |
                                                             |
        {11:Press ENTER or type command to continue}^              |
      ]])

      feed('<cr>')
      screen:expect([[
        {1:>>}^                                                   |
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
        {2:  }{0:~                                                  }|
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
