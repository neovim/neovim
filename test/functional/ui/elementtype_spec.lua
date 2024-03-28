local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local api = helpers.api

describe('ext_elementtype returns the correct information with', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 8)
    screen:attach({ ext_elementtype = true })
    command('set laststatus=2')
  end)

  after_each(function()
    screen:detach()
  end)

  it('default element types', function()
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|*5
      {2:[No Name]                               }|
                                              |
    ]],
      attr_ids = {
        [1] = { { foreground = Screen.colors.Blue, bold = true }, {} },
        [2] = { { reverse = true, bold = true }, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('custom highlight', function()
    api.nvim_set_option_value('statusline', 'hello %#Normal#world', {})
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|*5
      {2:hello }{3:world                             }|
                                              |
    ]],
      attr_ids = {
        [1] = { { foreground = Screen.colors.Blue, bold = true }, {} },
        [2] = { { reverse = true, bold = true }, { 'StatusBar', 'HSplit' } },
        [3] = { {}, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('vertical split without statusbar', function()
    command('set laststatus=3')
    command('split')
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|*2
      {2:────────────────────────────────────────}|
                                              |
      {1:~                                       }|
      {3:[No Name]                               }|
                                              |
    ]],
      attr_ids = {
        [1] = { { foreground = Screen.colors.Blue1, bold = true }, {} },
        [2] = { {}, { 'VSplit' } },
        [3] = { { reverse = true, bold = true }, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('vertical and horizontal split without statusbar', function()
    command('set laststatus=3')
    command('split')
    command('vsplit')
    screen:expect {
      grid = [[
    ^                    {1:│}                   |
    {2:~                   }{1:│}{2:~                  }|*2
    {1:────────────────────}{3:┴}{1:───────────────────}|
                                            |
    {2:~                                       }|
    {4:[No Name]                               }|
                                            |
  ]],
      attr_ids = {
        [1] = { {}, { 'VSplit' } },
        [2] = { { bold = true, foreground = Screen.colors.Blue1 }, {} },
        [3] = { {}, { 'HSplit', 'VSplit' } },
        [4] = { { reverse = true, bold = true }, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('split and two statusbars', function()
    command('split')
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|*2
      {2:[No Name]                               }|
                                              |
      {1:~                                       }|
      {3:[No Name]                               }|
                                              |
    ]],
      attr_ids = {
        [1] = { { foreground = Screen.colors.Blue1, bold = true }, {} },
        [2] = { { bold = true, reverse = true }, { 'StatusBar', 'HSplit' } },
        [3] = { { reverse = true }, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('vsplit and two statusbars', function()
    command('vsplit')
    screen:expect {
      grid = [[
      ^                    {1:│}                   |
      {2:~                   }{1:│}{2:~                  }|*5
      {3:[No Name]           }{4: }{5:[No Name]          }|
                                              |
    ]],
      attr_ids = {
        [1] = { {}, { 'VSplit' } },
        [2] = { { bold = true, foreground = Screen.colors.Blue1 }, {} },
        [3] = { { bold = true, reverse = true }, { 'StatusBar', 'HSplit' } },
        [4] = { { bold = true, reverse = true }, { 'StatusBar', 'HSplit', 'VSplit' } },
        [5] = { { reverse = true }, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('vsplit and two statusbars with custom highlight', function()
    api.nvim_set_option_value('statusline', 'hello %#Normal#world', {})
    command('vsplit')
    screen:expect {
      grid = [[
      ^                    {1:│}                   |
      {2:~                   }{1:│}{2:~                  }|*5
      {3:hello }{4:world         }{5: }{6:hello }{4:world        }|
                                              |
    ]],
      attr_ids = {
        [1] = { {}, { 'VSplit' } },
        [2] = { { foreground = Screen.colors.Blue1, bold = true }, {} },
        [3] = { { bold = true, reverse = true }, { 'StatusBar', 'HSplit' } },
        [4] = { {}, { 'StatusBar', 'HSplit' } },
        [5] = { { bold = true, reverse = true }, { 'StatusBar', 'HSplit', 'VSplit' } },
        [6] = { { reverse = true }, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('winbar', function()
    api.nvim_set_option_value('winbar', 'hello', {})
    screen:expect {
      grid = [[
      {1:hello                                   }|
      ^                                        |
      {2:~                                       }|*4
      {3:[No Name]                               }|
                                              |
    ]],
      attr_ids = {
        [1] = { { bold = true }, { 'WinBar' } },
        [2] = { { bold = true, foreground = Screen.colors.Blue1 }, {} },
        [3] = { { bold = true, reverse = true }, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('winbar with custom highlights', function()
    api.nvim_set_option_value('winbar', 'hello %#Normal#world', {})
    screen:expect {
      grid = [[
      {1:hello }{2:world                             }|
      ^                                        |
      {3:~                                       }|*4
      {4:[No Name]                               }|
                                              |
    ]],
      attr_ids = {
        [1] = { { bold = true }, { 'WinBar' } },
        [2] = { {}, { 'WinBar' } },
        [3] = { { bold = true, foreground = Screen.colors.Blue1 }, {} },
        [4] = { { reverse = true, bold = true }, { 'StatusBar', 'HSplit' } },
      },
    }
  end)

  it('floating window borders and titles', function()
    api.nvim_open_win(0, true, {
      relative = 'editor',
      width = 20,
      height = 3,
      row = 2,
      col = 5,
      border = 'single',
      title = 'Title',
      footer = 'Footer',
    })

    command('hi FloatBorder guibg=Red guifg=Blue')
    screen:expect {
      grid = [[
                                              |
      {1:~                                       }|
      {1:~    }{2:┌}{3:Title}{4:───────────────}{5:┐}{1:             }|
      {1:~    }{6:│}{7:^                    }{8:│}{1:             }|
      {1:~    }{6:│}{9:~                   }{8:│}{1:             }|*2
      {10:[No N}{11:└}{12:Footer}{13:──────────────}{14:┘}{10:             }|
                                              |
    ]],
      attr_ids = {
        [1] = { { foreground = Screen.colors.Blue1, bold = true }, {} },
        [2] = {
          { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Top', 'Left' },
        },
        [3] = {
          { foreground = Screen.colors.Magenta1, bold = true },
          { 'FloatBorder', 'FloatTitle', 'Top' },
        },
        [4] = {
          { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Top' },
        },
        [5] = {
          { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Top', 'Right' },
        },
        [6] = {
          { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Left' },
        },
        [7] = { { background = Screen.colors.LightMagenta }, {} },
        [8] = {
          { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Right' },
        },
        [9] = {
          {
            foreground = Screen.colors.Blue1,
            background = Screen.colors.LightMagenta,
            bold = true,
          },
          {},
        },
        [10] = { { reverse = true }, { 'StatusBar', 'HSplit' } },
        [11] = {
          { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Bottom', 'Left' },
        },
        [12] = {
          { foreground = Screen.colors.Magenta1, bold = true },
          { 'FloatBorder', 'FloatTitle', 'Bottom' },
        },
        [13] = {
          { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Bottom' },
        },
        [14] = {
          { background = Screen.colors.Red1, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Bottom', 'Right' },
        },
      },
    }
  end)

  it('floating window borders and titles with custom highlights', function()
    api.nvim_open_win(0, true, {
      relative = 'editor',
      width = 20,
      height = 3,
      row = 2,
      col = 5,
      border = { { '+', 'MyCorner' }, { 'x', 'MyBorder' } },
      title = { { 'Title', 'MyTitle' } },
      footer = { { 'Footer', 'MyFooter' } },
    })

    command('hi MyCorner guibg=Red guifg=Blue')
    command('hi MyBorder guibg=Blue guifg=Red')
    command('hi MyTitle guibg=Red guifg=Yellow')
    command('hi MyFooter guibg=Blue guifg=Green')
    screen:expect {
      grid = [[
                                              |
      {1:~                                       }|
      {1:~    }{2:+}{3:Title}{4:xxxxxxxxxxxxxxx}{5:+}{1:             }|
      {1:~    }{6:x}{7:^                    }{8:x}{1:             }|
      {1:~    }{6:x}{9:~                   }{8:x}{1:             }|*2
      {10:[No N}{11:+}{12:Footer}{13:xxxxxxxxxxxxxx}{14:+}{10:             }|
                                              |
    ]],
      attr_ids = {
        [1] = { { foreground = Screen.colors.Blue1, bold = true }, {} },
        [2] = {
          { background = Screen.colors.Red, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Top', 'Left' },
        },
        [3] = {
          { background = Screen.colors.Red, foreground = Screen.colors.Yellow },
          { 'FloatBorder', 'FloatTitle', 'Top' },
        },
        [4] = {
          { background = Screen.colors.Blue1, foreground = Screen.colors.Red },
          { 'FloatBorder', 'Top' },
        },
        [5] = {
          { background = Screen.colors.Red, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Top', 'Right' },
        },
        [6] = {
          { background = Screen.colors.Blue1, foreground = Screen.colors.Red },
          { 'FloatBorder', 'Left' },
        },
        [7] = { { background = Screen.colors.Plum1 }, {} },
        [8] = {
          { background = Screen.colors.Blue1, foreground = Screen.colors.Red },
          { 'FloatBorder', 'Right' },
        },
        [9] = {
          { background = Screen.colors.Plum1, bold = true, foreground = Screen.colors.Blue1 },
          {},
        },
        [10] = { { reverse = true }, { 'StatusBar', 'HSplit' } },
        [11] = {
          { background = Screen.colors.Red, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Bottom', 'Left' },
        },
        [12] = {
          { background = Screen.colors.Blue1, foreground = Screen.colors.WebGreen },
          { 'FloatBorder', 'FloatTitle', 'Bottom' },
        },
        [13] = {
          { background = Screen.colors.Blue1, foreground = Screen.colors.Red },
          { 'FloatBorder', 'Bottom' },
        },
        [14] = {
          { background = Screen.colors.Red, foreground = Screen.colors.Blue1 },
          { 'FloatBorder', 'Bottom', 'Right' },
        },
      },
    }
  end)
end)
