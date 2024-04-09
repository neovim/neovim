local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear, feed, api = t.clear, t.feed, t.api
local insert, command = t.insert, t.command

describe('quickfix selection highlight', function()
  local screen

  before_each(function()
    clear()

    screen = Screen.new(25, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue },
      [2] = { reverse = true },
      [3] = { foreground = Screen.colors.Brown },
      [4] = { bold = true, reverse = true },
      [5] = { background = Screen.colors.Green },
      [6] = { foreground = Screen.colors.Brown, background = Screen.colors.Green },
      [7] = { background = Screen.colors.Red },
      [8] = { foreground = Screen.colors.Brown, background = Screen.colors.Red },
      [9] = { background = Screen.colors.Fuchsia },
      [10] = { foreground = Screen.colors.Red, background = Screen.colors.Fuchsia },
      [11] = { foreground = Screen.colors.Red },
      [12] = { foreground = Screen.colors.Brown, background = Screen.colors.Fuchsia },
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
      {5:^|}{6:1}{5:| Line                 }|
      |{3:2}| Line                 |
      |{3:3}| Line                 |
      |{3:4}| Line                 |
      |{3:5}| Line                 |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    command('cnext')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      |{3:1}| Line                 |
      {5:^|}{6:2}{5:| Line                 }|
      |{3:3}| Line                 |
      |{3:4}| Line                 |
      |{3:5}| Line                 |
      ||                       |
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
      {7:^|}{8:1}{7:| Line                 }|
      |{3:2}| Line                 |
      |{3:3}| Line                 |
      |{3:4}| Line                 |
      |{3:5}| Line                 |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    command('cnext')

    screen:expect([[
      Line 1                   |
      {2:[No Name] [+]            }|
      |{3:1}| Line                 |
      {7:^|}{8:2}{7:| Line                 }|
      |{3:3}| Line                 |
      |{3:4}| Line                 |
      |{3:5}| Line                 |
      ||                       |
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
      |{3:2}| Line                 |
      |{3:3}| Line                 |
      |{3:4}| Line                 |
      |{3:5}| Line                 |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    feed('j')

    screen:expect([[
      {9:Line 1                   }|
      {2:[No Name] [+]            }|
      {11:|1| Line                 }|
      {9:^|}{12:2}{9:| Line                 }|
      |{3:3}| Line                 |
      |{3:4}| Line                 |
      |{3:5}| Line                 |
      ||                       |
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
      {7:^|}{8:1}{7:| Line                 }|
      |{3:2}| Line                 |
      |{3:3}| Line                 |
      |{3:4}| Line                 |
      |{3:5}| Line                 |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    feed('j')

    screen:expect([[
      {9:Line 1                   }|
      {2:[No Name] [+]            }|
      {7:|}{8:1}{7:| Line                 }|
      {9:^|}{12:2}{9:| Line                 }|
      |{3:3}| Line                 |
      |{3:4}| Line                 |
      |{3:5}| Line                 |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)
end)
