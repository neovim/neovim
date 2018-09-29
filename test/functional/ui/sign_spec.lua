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
  end)

  describe('signcolumn=number', function()
    it('show sign in number column', function()
      feed('ia<cr>b<cr>c<cr>d<cr><esc>')
      command('sign define piet text=>> texthl=Search')
      command('sign define pietx text=𠆤 texthl=Search')
      command('sign define pietxx text=X texthl=Search')
      command('sign place 1 line=1 name=piet buffer=1')
      command('sign place 2 line=3 name=pietx buffer=1')
      command('sign place 3 line=5 name=pietxx buffer=1')
      screen:expect([[
        {1:>>}a                                                  |
        {2:  }b                                                  |
        {1:𠆤}c                                                  |
        {2:  }d                                                  |
        {1:X }^                                                   |
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
      command('set number')
      screen:expect([[
        {1:>>}{6:  1 }a                                              |
        {2:  }{6:  2 }b                                              |
        {1:𠆤}{6:  3 }c                                              |
        {2:  }{6:  4 }d                                              |
        {1:X }{6:  5 }^                                               |
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
      command('set signcolumn=number')
      screen:expect([[
        {1: >> }a                                                |
        {6:  2 }b                                                |
        {1: 𠆤 }c                                                |
        {6:  4 }d                                                |
        {1: X  }^                                                 |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
      command('set numberwidth=2')
      screen:expect([[
        {1:>>}a                                                  |
        {6:2 }b                                                  |
        {1:𠆤}c                                                  |
        {6:4 }d                                                  |
        {1:X }^                                                   |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
    end)
  end)
end)
