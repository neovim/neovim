local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, meths = helpers.clear, helpers.feed, helpers.meths
local insert, command = helpers.insert, helpers.command


describe('quickfix selection highlight', function()
  local screen

  before_each(function()
    clear()

    screen = Screen.new(25, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue },
      [2] = {reverse = true},
      [3] = {foreground = Screen.colors.Brown},
      [4] = {bold = true, reverse = true},
      [5] = {background = Screen.colors.Green},
      [6] = {foreground = Screen.colors.Brown, background = Screen.colors.Green},
      [7] = {background = Screen.colors.Red},
      [8] = {foreground = Screen.colors.Brown, background = Screen.colors.Red},
      [9] = {background = Screen.colors.Fuchsia},
      [10] = {foreground = Screen.colors.Red, background = Screen.colors.Fuchsia},
      [11] = {foreground = Screen.colors.Red},
      [12] = {foreground = Screen.colors.Brown, background = Screen.colors.Fuchsia},
      [13] = {foreground = Screen.colors.White, background = Screen.colors.Red},
      [14] = {foreground = Screen.colors.Blue, background = Screen.colors.Yellow},
    })

    meths.set_option('errorformat', '%m %l.%t%n')
    command('syntax on')
    command('highlight Search guibg=Green')

    insert([[
    Line 1.E12
    Line 2.W3
    Line 3.W112
    Line 4.E145
    Line 5.I20
    ]])

    command('cad')
    feed('gg')

    screen:expect([[
      ^Line 1.E12               |
      Line 2.W3                |
      Line 3.W112              |
      Line 4.E145              |
      Line 5.I20               |
                               |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]])
  end)

  it('using default Search highlight group', function()
    command('copen')

    screen:expect([[
      Line 1.E12               |
      {2:[No Name] [+]            }|
      {5:^|}{6:1 }{13:error}{6:  12}{5:| Line       }|
      |{3:2 warning   3}| Line     |
      |{3:3 warning 112}| Line     |
      |{3:4 }{13:error}{3: 145}| Line       |
      |{3:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    command('cnext')

    screen:expect([[
      Line 1.E12               |
      {2:[No Name] [+]            }|
      |{3:1 }{13:error}{3:  12}| Line       |
      {5:^|}{6:2 warning   3}{5:| Line     }|
      |{3:3 warning 112}| Line     |
      |{3:4 }{13:error}{3: 145}| Line       |
      |{3:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)

  it('using QuickFixLine highlight group', function()
    command('highlight QuickFixLine guibg=Red')

    command('copen')

    screen:expect([[
      Line 1.E12               |
      {2:[No Name] [+]            }|
      {7:^|}{8:1 }{13:error}{8:  12}{7:| Line       }|
      |{3:2 warning   3}| Line     |
      |{3:3 warning 112}| Line     |
      |{3:4 }{13:error}{3: 145}| Line       |
      |{3:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    command('cnext')

    screen:expect([[
      Line 1.E12               |
      {2:[No Name] [+]            }|
      |{3:1 }{13:error}{3:  12}| Line       |
      {7:^|}{8:2 warning   3}{7:| Line     }|
      |{3:3 warning 112}| Line     |
      |{3:4 }{13:error}{3: 145}| Line       |
      |{3:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)

  it('combines with CursorLine', function()
    command('set cursorline')
    command('highlight QuickFixLine guifg=Red')
    command('highlight CursorLine guibg=Fuchsia')

    command('copen')

    screen:expect([[
      {9:Line 1.E12               }|
      {2:[No Name] [+]            }|
      {10:^|}{12:1 }{13:error}{12:  12}{10:| Line       }|
      |{3:2 warning   3}| Line     |
      |{3:3 warning 112}| Line     |
      |{3:4 }{13:error}{3: 145}| Line       |
      |{3:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    feed('j')

    screen:expect([[
      {9:Line 1.E12               }|
      {2:[No Name] [+]            }|
      {11:|}{3:1 }{13:error}{3:  12}{11:| Line       }|
      {9:^|}{12:2 warning   3}{9:| Line     }|
      |{3:3 warning 112}| Line     |
      |{3:4 }{13:error}{3: 145}| Line       |
      |{3:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)

  it('QuickFixLine background takes precedence over CursorLine', function()
    command('set cursorline')
    command('highlight QuickFixLine guibg=Red')
    command('highlight CursorLine guibg=Fuchsia')

    command('copen')

    screen:expect([[
      {9:Line 1.E12               }|
      {2:[No Name] [+]            }|
      {7:^|}{8:1 }{13:error}{8:  12}{7:| Line       }|
      |{3:2 warning   3}| Line     |
      |{3:3 warning 112}| Line     |
      |{3:4 }{13:error}{3: 145}| Line       |
      |{3:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    feed('j')

    screen:expect([[
      {9:Line 1.E12               }|
      {2:[No Name] [+]            }|
      {7:|}{8:1 }{13:error}{8:  12}{7:| Line       }|
      {9:^|}{12:2 warning   3}{9:| Line     }|
      |{3:3 warning 112}| Line     |
      |{3:4 }{13:error}{3: 145}| Line       |
      |{3:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)

  it('Line numbers and errors take precedence over QuickFixLine', function()
    command('highlight LineNr guifg=Brown guibg=Fuchsia')

    command('copen')

    screen:expect([[
      Line 1.E12               |
      {2:[No Name] [+]            }|
      {5:^|}{12:1 }{13:error}{12:  12}{5:| Line       }|
      |{12:2 warning   3}| Line     |
      |{12:3 warning 112}| Line     |
      |{12:4 }{13:error}{12: 145}| Line       |
      |{12:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])

    command('highlight QuickFixLine guifg=Blue guibg=Yellow')

    screen:expect([[
      Line 1.E12               |
      {2:[No Name] [+]            }|
      {14:^|}{12:1 }{13:error}{12:  12}{14:| Line       }|
      |{12:2 warning   3}| Line     |
      |{12:3 warning 112}| Line     |
      |{12:4 }{13:error}{12: 145}| Line       |
      |{12:5 info  20}| Line        |
      ||                       |
      {4:[Quickfix List]          }|
                               |
    ]])
  end)
end)
