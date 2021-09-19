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

  describe(':sign place', function()
    it('allows signs with combining characters', function()
      feed('ia<cr>b<cr><esc>')
      command('sign define piet1 text=𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄ texthl=Search')
      command('sign define piet2 text=𠜎̀́̂̃̄̅ texthl=Search')
      command('sign place 1 line=1 name=piet1 buffer=1')
      command('sign place 2 line=2 name=piet2 buffer=1')
      screen:expect([[
        {1:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}a                                                  |
        {1:𠜎̀́̂̃̄̅}b                                                  |
        {2:  }^                                                   |
        {0:~                                                    }|
        {0:~                                                    }|
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
        {0:~                                                    }|
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

    it('allows signs with no text', function()
      feed('ia<cr>b<cr><esc>')
      command('sign define piet1 text= texthl=Search')
      command('sign place 1 line=1 name=piet1 buffer=1')
      screen:expect([[
        a                                                    |
        b                                                    |
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
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
        {0:~                                                    }|
        {0:~                                                    }|
        {4:[No Name] [+]                                        }|
        {2:  }{3:a                                                  }|
        {1:>>}b                                                  |
        {2:  }c                                                  |
        {2:  }                                                   |
        {0:~                                                    }|
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
        {0:~                                                    }|
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

    it('multiple signs #9295', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      command('set number')
      command('set signcolumn=yes:2')
      command('sign define pietSearch text=>> texthl=Search')
      command('sign define pietError text=XX texthl=Error')
      command('sign define pietWarn text=WW texthl=Warning')
      command('sign place 1 line=1 name=pietSearch buffer=1')
      command('sign place 2 line=1 name=pietError buffer=1')
      -- Line 2 helps checking that signs in the same line are ordered by Id.
      command('sign place 4 line=2 name=pietSearch buffer=1')
      command('sign place 3 line=2 name=pietError buffer=1')
      -- Line 3 checks that with a limit over the maximum number
      -- of signs, the ones with the highest Ids are being picked,
      -- and presented by their sorted Id order.
      command('sign place 4 line=3 name=pietSearch buffer=1')
      command('sign place 5 line=3 name=pietWarn buffer=1')
      command('sign place 3 line=3 name=pietError buffer=1')
      screen:expect([[
        {1:>>}XX{6:  1 }a                                            |
        XX{1:>>}{6:  2 }b                                            |
        {1:>>}WW{6:  3 }c                                            |
        {2:    }{6:  4 }^                                             |
        {0:~                                                    }|
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
      -- With the default setting, we get the sign with the top id.
      command('set signcolumn=yes:1')
      screen:expect([[
        XX{6:  1 }a                                              |
        {1:>>}{6:  2 }b                                              |
        WW{6:  3 }c                                              |
        {2:  }{6:  4 }^                                               |
        {0:~                                                    }|
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
      -- "auto:3" accommodates all the signs we defined so far.
      command('set signcolumn=auto:3')
      screen:expect([[
        {1:>>}XX{2:  }{6:  1 }a                                          |
        XX{1:>>}{2:  }{6:  2 }b                                          |
        XX{1:>>}WW{6:  3 }c                                          |
        {2:      }{6:  4 }^                                           |
        {0:~                                                    }|
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
      -- Check "yes:9".
      command('set signcolumn=yes:9')
      screen:expect([[
        {1:>>}XX{2:              }{6:  1 }a                              |
        XX{1:>>}{2:              }{6:  2 }b                              |
        XX{1:>>}WW{2:            }{6:  3 }c                              |
        {2:                  }{6:  4 }^                               |
        {0:~                                                    }|
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
      -- Check "auto:N" larger than the maximum number of signs defined in
      -- a single line (same result as "auto:3").
      command('set signcolumn=auto:4')
      screen:expect{grid=[[
        {1:>>}XX{2:  }{6:  1 }a                                          |
        XX{1:>>}{2:  }{6:  2 }b                                          |
        XX{1:>>}WW{6:  3 }c                                          |
        {2:      }{6:  4 }^                                           |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]]}
      -- line deletion deletes signs.
      command('2d')
      screen:expect([[
        {1:>>}XX{2:  }{6:  1 }a                                          |
        XX{1:>>}WW{6:  2 }^c                                          |
        {2:      }{6:  3 }                                           |
        {0:~                                                    }|
        {0:~                                                    }|
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

    it('auto-resize sign column with minimum size (#13783)', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      command('set number')
      -- sign column should always accommodate at the minimum size
      command('set signcolumn=auto:1-3')
      screen:expect([[
        {2:  }{6:  1 }a                                              |
        {2:  }{6:  2 }b                                              |
        {2:  }{6:  3 }c                                              |
        {2:  }{6:  4 }^                                               |
        {0:~                                                    }|
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
      -- should support up to 8 signs at minimum
      command('set signcolumn=auto:8-9')
      screen:expect([[
        {2:                }{6:  1 }a                                |
        {2:                }{6:  2 }b                                |
        {2:                }{6:  3 }c                                |
        {2:                }{6:  4 }^                                 |
        {0:~                                                    }|
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
      -- should keep the same sign size when signs are not exceeding
      -- the minimum
      command('set signcolumn=auto:2-5')
      command('sign define pietSearch text=>> texthl=Search')
      command('sign place 1 line=1 name=pietSearch buffer=1')
      screen:expect([[
        {1:>>}{2:  }{6:  1 }a                                            |
        {2:    }{6:  2 }b                                            |
        {2:    }{6:  3 }c                                            |
        {2:    }{6:  4 }^                                             |
        {0:~                                                    }|
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
      -- should resize itself when signs are exceeding minimum but
      -- not over the maximum
      command('sign place 2 line=1 name=pietSearch buffer=1')
      command('sign place 3 line=1 name=pietSearch buffer=1')
      command('sign place 4 line=1 name=pietSearch buffer=1')
      screen:expect([[
        {1:>>>>>>>>}{6:  1 }a                                        |
        {2:        }{6:  2 }b                                        |
        {2:        }{6:  3 }c                                        |
        {2:        }{6:^  4 }                                         |
        {0:~                                                    }|
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
      -- should keep the column at maximum size when signs are
      -- exceeding the maximum
      command('sign place 5 line=1 name=pietSearch buffer=1')
      command('sign place 6 line=1 name=pietSearch buffer=1')
      command('sign place 7 line=1 name=pietSearch buffer=1')
      command('sign place 8 line=1 name=pietSearch buffer=1')
      screen:expect([[
        {1:>>>>>>>>>>}{6:  1 }a                                      |
        {2:          }{6:  2 }b                                      |
        {2:          }{6:  3 }c                                      |
        {2:        ^  }{6:  4 }                                       |
        {0:~                                                    }|
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

    it('ignores signs with no icon and text when calculting the signcolumn width', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      command('set number')
      command('set signcolumn=auto:2')
      command('sign define pietSearch text=>> texthl=Search')
      command('sign define pietError text= texthl=Error')
      command('sign place 2 line=1 name=pietError buffer=1')
      -- no signcolumn with only empty sign
      screen:expect([[
        {6:  1 }a                                                |
        {6:  2 }b                                                |
        {6:  3 }c                                                |
        {6:  4 }^                                                 |
        {0:~                                                    }|
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
      -- single column with 1 sign with text and one sign without
      command('sign place 1 line=1 name=pietSearch buffer=1')
      screen:expect([[
        {1:>>}{6:  1 }a                                              |
        {2:  }{6:  2 }b                                              |
        {2:  }{6:  3 }c                                              |
        {2:  }{6:  ^4 }                                               |
        {0:~                                                    }|
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

    it('can have 32bit sign IDs', function()
      command('sign define piet text=>> texthl=Search')
      command('sign place 100000 line=1 name=piet buffer=1')
      feed(':sign place<cr>')
      screen:expect([[
        {1:>>}                                                   |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {4:                                                     }|
        :sign place                                          |
        {9:--- Signs ---}                                        |
        {10:Signs for [NULL]:}                                    |
            line=1  id=100000  name=piet  priority=10        |
                                                             |
        {11:Press ENTER or type command to continue}^              |
      ]])

      feed('<cr>')
      screen:expect([[
        {1:>>}^                                                   |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
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
