local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute = helpers.execute


describe('Screen rendering', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 7)
    screen:attach()
    screen:set_default_attr_ids( {
      [1] = {foreground = Screen.colors.Brown},
      [2] = {bold = true, foreground = Screen.colors.Brown},
      [3] = {},
      [4] = {background = Screen.colors.LightGrey},
      [5] = {background = Screen.colors.LightGrey, bold = true, foreground = Screen.colors.Blue},
      [6] = {bold = true, foreground = Screen.colors.Blue},
      [7] = {bold = true}
    })
    insert("line 1\n")
    insert("line 2\n")
    insert("line 3\n")
    insert("line 4\n")
    insert("line 5\n")
    insert("line 6")
    feed("gg")
  end)

  it('works with number and relative line number', function()
    execute('set number')
    screen:expect([[
      {1:  1 }{3:^line 1                              }|
      {1:  2 }{3:line 2                              }|
      {1:  3 }{3:line 3                              }|
      {1:  4 }{3:line 4                              }|
      {1:  5 }{3:line 5                              }|
      {1:  6 }{3:line 6                              }|
      {3::set number                             }|
    ]])

    execute('set nonumber')
    execute('set relativenumber')
    feed("4gg")
    screen:expect([[
      {1:  3 }{3:line 1                              }|
      {1:  2 }{3:line 2                              }|
      {1:  1 }{3:line 3                              }|
      {2:  0 }{3:^line 4                              }|
      {1:  1 }{3:line 5                              }|
      {1:  2 }{3:line 6                              }|
      {3::set relativenumber                     }|
    ]])

    execute('set number')
    execute('set relativenumber')
    screen:expect([[
      {1:  3 }{3:line 1                              }|
      {1:  2 }{3:line 2                              }|
      {1:  1 }{3:line 3                              }|
      {2:4   }{3:^line 4                              }|
      {1:  1 }{3:line 5                              }|
      {1:  2 }{3:line 6                              }|
      {3::set relativenumber                     }|
    ]])
  end)

  it('works with line-wise visual-mode', function()
    execute('set list listchars=')
    execute('set lcs+=conceal:.,eol:¬')
    execute('set lcs+=tab:\\ ,nbsp:―,trail:·')
    execute('set lcs+=precedes:,extends:')

    screen:expect([[
      {3:^line 1}{6:¬}{3:                                 }|
      {3:line 2}{6:¬}{3:                                 }|
      {3:line 3}{6:¬}{3:                                 }|
      {3:line 4}{6:¬}{3:                                 }|
      {3:line 5}{6:¬}{3:                                 }|
      {3:line 6}{6:¬}{3:                                 }|
      {3::set lcs+=precedes:,extends:          }|
    ]])

    feed('V')
    screen:expect([[
      {3:^l}{4:ine 1}{5:¬}{3:                                 }|
      {3:line 2}{6:¬}{3:                                 }|
      {3:line 3}{6:¬}{3:                                 }|
      {3:line 4}{6:¬}{3:                                 }|
      {3:line 5}{6:¬}{3:                                 }|
      {3:line 6}{6:¬}{3:                                 }|
      {7:-- VISUAL LINE --}{3:                       }|
    ]])

    feed('dd<esc>O<esc>45a=<esc>')
    screen:expect([[
      {3:========================================}|
      {3:====^=}{6:¬}{3:                                  }|
      {3:line 2}{6:¬}{3:                                 }|
      {3:line 3}{6:¬}{3:                                 }|
      {3:line 4}{6:¬}{3:                                 }|
      {3:line 5}{6:¬}{3:                                 }|
      {3:                                        }|
    ]])

    execute('set nowrap')
    feed('ggzl')

    screen:expect([[
      {6:^}{3:======================================}{6:}|
      {6:}{3:ne 2}{6:¬}{3:                                  }|
      {6:}{3:ne 3}{6:¬}{3:                                  }|
      {6:}{3:ne 4}{6:¬}{3:                                  }|
      {6:}{3:ne 5}{6:¬}{3:                                  }|
      {6:}{3:ne 6}{6:¬}{3:                                  }|
      {3::set nowrap                             }|
    ]])

    feed('10zl')
    screen:expect([[
      {6:^}{3:=================================}{6:¬}{3:     }|
      {6:}{3:                                       }|
      {6:}{3:                                       }|
      {6:}{3:                                       }|
      {6:}{3:                                       }|
      {6:}{3:                                       }|
      {3::set nowrap                             }|
    ]])

    feed('V')
    screen:expect([[
      {6:^}{4:=================================}{5:¬}{3:     }|
      {6:}{3:                                       }|
      {6:}{3:                                       }|
      {6:}{3:                                       }|
      {6:}{3:                                       }|
      {6:}{3:                                       }|
      {7:-- VISUAL LINE --}{3:                       }|
    ]])
  end)

  it('works with block-wise visual-mode')

  it('works with character-wise visual-mode')

  it('conceals :match matches')

  -- TODO describe sign-column
  -- TODO describe fold-column
  -- TODO describe diff-rendering
  -- TODO describe syntax-rendering
  -- TODO describe spell-rendering
  -- TODO describe utf8-rendering

end)

