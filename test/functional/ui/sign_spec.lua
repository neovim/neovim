local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command
local source = helpers.source
local meths = helpers.meths

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
      -- Check that 'statuscolumn' correctly applies numhl
      command('set statuscolumn=%s%=%l\\ ')
      screen:expect_unchanged()
    end)

    it('highlights the cursorline sign with culhl', function()
      feed('ia<cr>b<cr>c<esc>')
      command('sign define piet text=>> texthl=Search culhl=ErrorMsg')
      command('sign place 1 line=1 name=piet buffer=1')
      command('sign place 2 line=2 name=piet buffer=1')
      command('sign place 3 line=3 name=piet buffer=1')
      command('set cursorline')
      screen:expect([[
        {1:>>}a                                                  |
        {1:>>}b                                                  |
        {8:>>}{3:^c                                                  }|
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
      feed('k')
      screen:expect([[
        {1:>>}a                                                  |
        {8:>>}{3:^b                                                  }|
        {1:>>}c                                                  |
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
      command('set nocursorline')
      screen:expect([[
        {1:>>}a                                                  |
        {1:>>}^b                                                  |
        {1:>>}c                                                  |
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
      command('set cursorline cursorlineopt=line')
      screen:expect([[
        {1:>>}a                                                  |
        {1:>>}{3:^b                                                  }|
        {1:>>}c                                                  |
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
      command('set cursorlineopt=number')
      command('hi! link SignColumn IncSearch')
      feed('Go<esc>2G')
      screen:expect([[
        {1:>>}a                                                  |
        {8:>>}^b                                                  |
        {1:>>}c                                                  |
        {5:  }                                                   |
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
      -- Check that 'statuscolumn' cursorline/signcolumn highlights are the same (#21726)
      command('set statuscolumn=%s')
      screen:expect_unchanged()
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
      command('sign place 6 line=3 name=pietSearch buffer=1')
      command('sign place 7 line=3 name=pietWarn buffer=1')
      command('sign place 5 line=3 name=pietError buffer=1')
      screen:expect([[
        {1:>>}{8:XX}{6:  1 }a                                            |
        {8:XX}{1:>>}{6:  2 }b                                            |
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
        {8:XX}{6:  1 }a                                              |
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
        {1:>>}{8:XX}{2:  }{6:  1 }a                                          |
        {8:XX}{1:>>}{2:  }{6:  2 }b                                          |
        {8:XX}{1:>>}WW{6:  3 }c                                          |
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
        {1:>>}{8:XX}{2:              }{6:  1 }a                              |
        {8:XX}{1:>>}{2:              }{6:  2 }b                              |
        {8:XX}{1:>>}WW{2:            }{6:  3 }c                              |
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
        {1:>>}{8:XX}{2:  }{6:  1 }a                                          |
        {8:XX}{1:>>}{2:  }{6:  2 }b                                          |
        {8:XX}{1:>>}WW{6:  3 }c                                          |
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
        {1:>>}{8:XX}{2:  }{6:  1 }a                                          |
        {8:XX}{1:>>}WW{6:  2 }^c                                          |
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
        {2:        }{6:  4 }^                                         |
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
        {2:          }{6:  4 }^                                       |
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

    it('ignores signs with no icon and text when calculating the signcolumn width', function()
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
    end)

    it('shows the line number when signcolumn=number but no marks on a line have text', function()
      feed('ia<cr>b<cr>c<cr><esc>')
      command('set number signcolumn=number')
      command('sign define pietSearch text=>> texthl=Search numhl=Error')
      command('sign define pietError text=    texthl=Search numhl=Error')
      command('sign place 1 line=1 name=pietSearch buffer=1')
      command('sign place 2 line=2 name=pietError  buffer=1')
      -- no signcolumn, line number for "a" is Search, for "b" is Error, for "c" is LineNr
      screen:expect([[
        {1: >> }a                                                |
        {8:  2 }b                                                |
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

  it('signcolumn width is updated when removing all signs after deleting lines', function()
    meths.buf_set_lines(0, 0, 1, true, {'a', 'b', 'c', 'd', 'e'})
    command('sign define piet text=>>')
    command('sign place 10001 line=1 name=piet')
    command('sign place 10002 line=5 name=piet')
    command('2delete')
    command('sign unplace 10001')
    screen:expect([[
      {2:  }a                                                  |
      {2:  }^c                                                  |
      {2:  }d                                                  |
      >>e                                                  |
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
    command('sign unplace 10002')
    screen:expect([[
      a                                                    |
      ^c                                                    |
      d                                                    |
      e                                                    |
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

  it('signcolumn width is updated when removing all signs after inserting lines', function()
    meths.buf_set_lines(0, 0, 1, true, {'a', 'b', 'c', 'd', 'e'})
    command('sign define piet text=>>')
    command('sign place 10001 line=1 name=piet')
    command('sign place 10002 line=5 name=piet')
    command('copy .')
    command('sign unplace 10001')
    screen:expect([[
      {2:  }a                                                  |
      {2:  }^a                                                  |
      {2:  }b                                                  |
      {2:  }c                                                  |
      {2:  }d                                                  |
      >>e                                                  |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]])
    command('sign unplace 10002')
    screen:expect([[
      a                                                    |
      ^a                                                    |
      b                                                    |
      c                                                    |
      d                                                    |
      e                                                    |
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
