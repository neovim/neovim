local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed, api = n.clear, n.feed, n.api
local insert, command = n.insert, n.command

describe('quickfix', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 10)
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.SlateBlue, background = Screen.colors.WebGreen },
      [101] = { foreground = Screen.colors.Brown, background = Screen.colors.WebGreen },
      [102] = { background = Screen.colors.WebGreen },
      [103] = { background = Screen.colors.Red, foreground = Screen.colors.SlateBlue },
      [104] = { background = Screen.colors.Red, foreground = Screen.colors.Brown },
      [105] = { background = Screen.colors.Fuchsia },
      [106] = { foreground = Screen.colors.Red, background = Screen.colors.Fuchsia },
      [107] = { foreground = Screen.colors.SlateBlue, background = Screen.colors.Fuchsia },
      [108] = { foreground = Screen.colors.Brown, background = Screen.colors.Fuchsia },
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

  it('Search selection highlight', function()
    command('copen')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {100:^|}{101:1}{100:|}{102: Line                 }|
      {16:|}{8:2}{16:|} Line                 |
      {16:|}{8:3}{16:|} Line                 |
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])

    command('cnext')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {16:|}{8:1}{16:|} Line                 |
      {100:^|}{101:2}{100:|}{102: Line                 }|
      {16:|}{8:3}{16:|} Line                 |
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])
  end)

  it('QuickFixLine selection highlight', function()
    command('highlight QuickFixLine guibg=Red guifg=NONE gui=NONE')

    command('copen')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {103:^|}{104:1}{103:|}{30: Line                 }|
      {16:|}{8:2}{16:|} Line                 |
      {16:|}{8:3}{16:|} Line                 |
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])

    command('cnext')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {16:|}{8:1}{16:|} Line                 |
      {103:^|}{104:2}{103:|}{30: Line                 }|
      {16:|}{8:3}{16:|} Line                 |
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])
  end)

  it('selection highlight combines with CursorLine', function()
    command('set cursorline')
    command('highlight QuickFixLine guifg=Red guibg=NONE gui=NONE')
    command('highlight CursorLine guibg=Fuchsia')

    command('copen')

    screen:expect([[
      {105:Line 1                   }|
      {2:[No Name] [+]            }|
      {106:^|1| Line                 }|
      {16:|}{8:2}{16:|} Line                 |
      {16:|}{8:3}{16:|} Line                 |
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])

    feed('j')

    screen:expect([[
      {105:Line 1                   }|
      {2:[No Name] [+]            }|
      {19:|1| Line                 }|
      {107:^|}{108:2}{107:|}{105: Line                 }|
      {16:|}{8:3}{16:|} Line                 |
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])
  end)

  it('QuickFixLine selection highlight background takes precedence over CursorLine', function()
    command('set cursorline')
    command('highlight QuickFixLine guibg=Red guifg=NONE gui=NONE')
    command('highlight CursorLine guibg=Fuchsia')

    command('copen')

    screen:expect([[
      {105:Line 1                   }|
      {2:[No Name] [+]            }|
      {103:^|}{104:1}{103:|}{30: Line                 }|
      {16:|}{8:2}{16:|} Line                 |
      {16:|}{8:3}{16:|} Line                 |
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])

    feed('j')

    screen:expect([[
      {105:Line 1                   }|
      {2:[No Name] [+]            }|
      {103:|}{104:1}{103:|}{30: Line                 }|
      {107:^|}{108:2}{107:|}{105: Line                 }|
      {16:|}{8:3}{16:|} Line                 |
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])
  end)

  it('does not inherit from non-current floating window', function()
    api.nvim_open_win(0, true, { width = 6, height = 2, relative = 'win', bufpos = { 3, 0 } })
    api.nvim_set_option_value('rightleft', true, { win = 0 })
    command('wincmd w | copen')
    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      {100:^|}{101:1}{100:|}{102: Line                 }|
      {16:|}{8:2}{16:|} Line           {4:1 eniL}|
      {16:|}{8:3}{16:|} Line           {4:2 eniL}|
      {16:|}{8:4}{16:|} Line                 |
      {16:|}{8:5}{16:|} Line                 |
      {16:||}                       |
      {3:[Quickfix List] [-]      }|
                               |
    ]])
  end)
end)
