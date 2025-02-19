local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed, api = n.clear, n.feed, n.api
local insert, command = n.insert, n.command

describe('quickfix selection highlight', function()
  local screen

  before_each(function()
    clear()

    screen = Screen.new(25, 10)
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.Blue, bold = true },
      [2] = { reverse = true },
      [3] = { foreground = Screen.colors.Brown },
      [4] = { reverse = true, bold = true },
      [5] = { background = Screen.colors.WebGreen },
      [6] = { background = Screen.colors.WebGreen, foreground = Screen.colors.Brown },
      [7] = { background = Screen.colors.Red1 },
      [8] = { background = Screen.colors.Red1, foreground = Screen.colors.Brown },
      [9] = { background = Screen.colors.Magenta },
      [10] = { background = Screen.colors.Magenta, foreground = Screen.colors.Red1 },
      [11] = { foreground = Screen.colors.Red1 },
      [12] = { background = Screen.colors.Magenta, foreground = Screen.colors.Brown },
      [13] = { background = Screen.colors.WebGreen, foreground = Screen.colors.SlateBlue },
      [14] = { foreground = Screen.colors.SlateBlue },
      [15] = { foreground = Screen.colors.SlateBlue, background = Screen.colors.Red1 },
      [16] = { foreground = Screen.colors.SlateBlue, background = Screen.colors.Fuchsia },
    })

    api.nvim_set_option_value('errorformat', '%m %l', {})
    command('syntax on')
    command('highlight Search guibg=Green')

    insert([[
    Line 1
    Line 2
    Line 3
    Line 4
    Line 5
    ]])

    command('cad')
    feed('gg')

    screen:expect([[
      ^Line 1                   |
      Line 2                   |
      Line 3                   |
      Line 4                   |
      Line 5                   |
                               |
      {1:~                        }|*3
                               |
    ]])
  end)

  it('using default Search highlight group', function()
    command('copen')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {13:^|}{6:1}{13:|}{5: Line                 }|
      {14:|}{3:2}{14:|} Line                 |
      {14:|}{3:3}{14:|} Line                 |
      {14:|}{3:4}{14:|} Line                 |
      {14:|}{3:5}{14:|} Line                 |
      {14:||}                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    command('cnext')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {14:|}{3:1}{14:|} Line                 |
      {13:^|}{6:2}{13:|}{5: Line                 }|
      {14:|}{3:3}{14:|} Line                 |
      {14:|}{3:4}{14:|} Line                 |
      {14:|}{3:5}{14:|} Line                 |
      {14:||}                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)

  it('using QuickFixLine highlight group', function()
    command('highlight QuickFixLine guibg=Red guifg=NONE gui=NONE')

    command('copen')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {15:^|}{8:1}{15:|}{7: Line                 }|
      {14:|}{3:2}{14:|} Line                 |
      {14:|}{3:3}{14:|} Line                 |
      {14:|}{3:4}{14:|} Line                 |
      {14:|}{3:5}{14:|} Line                 |
      {14:||}                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    command('cnext')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {14:|}{3:1}{14:|} Line                 |
      {15:^|}{8:2}{15:|}{7: Line                 }|
      {14:|}{3:3}{14:|} Line                 |
      {14:|}{3:4}{14:|} Line                 |
      {14:|}{3:5}{14:|} Line                 |
      {14:||}                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)

  it('combines with CursorLine', function()
    command('set cursorline')
    command('highlight QuickFixLine guifg=Red guibg=NONE gui=NONE')
    command('highlight CursorLine guibg=Fuchsia')

    command('copen')

    screen:expect([[
      {9:Line 1                   }|
      {2:[No Name] [+]            }|
      {10:^|1| Line                 }|
      {14:|}{3:2}{14:|} Line                 |
      {14:|}{3:3}{14:|} Line                 |
      {14:|}{3:4}{14:|} Line                 |
      {14:|}{3:5}{14:|} Line                 |
      {14:||}                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    feed('j')

    screen:expect([[
      {9:Line 1                   }|
      {2:[No Name] [+]            }|
      {11:|1| Line                 }|
      {16:^|}{12:2}{16:|}{9: Line                 }|
      {14:|}{3:3}{14:|} Line                 |
      {14:|}{3:4}{14:|} Line                 |
      {14:|}{3:5}{14:|} Line                 |
      {14:||}                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)

  it('QuickFixLine background takes precedence over CursorLine', function()
    command('set cursorline')
    command('highlight QuickFixLine guibg=Red guifg=NONE gui=NONE')
    command('highlight CursorLine guibg=Fuchsia')

    command('copen')

    screen:expect([[
      {9:Line 1                   }|
      {2:[No Name] [+]            }|
      {15:^|}{8:1}{15:|}{7: Line                 }|
      {14:|}{3:2}{14:|} Line                 |
      {14:|}{3:3}{14:|} Line                 |
      {14:|}{3:4}{14:|} Line                 |
      {14:|}{3:5}{14:|} Line                 |
      {14:||}                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    feed('j')

    screen:expect([[
      {9:Line 1                   }|
      {2:[No Name] [+]            }|
      {15:|}{8:1}{15:|}{7: Line                 }|
      {16:^|}{12:2}{16:|}{9: Line                 }|
      {14:|}{3:3}{14:|} Line                 |
      {14:|}{3:4}{14:|} Line                 |
      {14:|}{3:5}{14:|} Line                 |
      {14:||}                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)
end)
