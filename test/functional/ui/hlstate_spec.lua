local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, insert = helpers.clear, helpers.insert
local command = helpers.command
local api = helpers.api
local testprg = helpers.testprg
local thelpers = require('test.functional.terminal.helpers')
local skip = helpers.skip
local is_os = helpers.is_os

describe('ext_hlstate detailed highlights', function()
  local screen

  before_each(function()
    clear()
    command('syntax on')
    command('hi VertSplit gui=reverse')
    screen = Screen.new(40, 8)
    screen:attach({ ext_hlstate = true })
  end)

  after_each(function()
    screen:detach()
  end)

  it('work with combined UI and syntax highlights', function()
    insert([[
      these are some lines
      with colorful text]])
    api.nvim_buf_add_highlight(0, -1, 'String', 0, 10, 14)
    api.nvim_buf_add_highlight(0, -1, 'Statement', 1, 5, -1)
    command('/th co')

    screen:expect(
      [[
      these are {1:some} lines                    |
      ^wi{2:th }{4:co}{3:lorful text}                      |
      {5:~                                       }|*5
      {8:search hit BOTTOM, continuing at TOP}{7:    }|
    ]],
      {
        [1] = {
          { foreground = Screen.colors.Magenta },
          { { hi_name = 'Constant', kind = 'syntax' } },
        },
        [2] = {
          { background = Screen.colors.Yellow },
          { { hi_name = 'Search', ui_name = 'Search', kind = 'ui' } },
        },
        [3] = {
          { bold = true, foreground = Screen.colors.Brown },
          { { hi_name = 'Statement', kind = 'syntax' } },
        },
        [4] = {
          { bold = true, background = Screen.colors.Yellow, foreground = Screen.colors.Brown },
          { 3, 2 },
        },
        [5] = {
          { bold = true, foreground = Screen.colors.Blue1 },
          { { hi_name = 'NonText', ui_name = 'EndOfBuffer', kind = 'ui' } },
        },
        [6] = {
          { foreground = Screen.colors.Red },
          { { hi_name = 'WarningMsg', ui_name = 'WarningMsg', kind = 'ui' } },
        },
        [7] = { {}, { { hi_name = 'MsgArea', ui_name = 'MsgArea', kind = 'ui' } } },
        [8] = { { foreground = Screen.colors.Red }, { 7, 6 } },
      }
    )
  end)

  it('work with cleared UI highlights', function()
    screen:set_default_attr_ids({
      [1] = { {}, { { hi_name = 'Normal', ui_name = 'WinSeparator', kind = 'ui' } } },
      [2] = {
        { bold = true, foreground = Screen.colors.Blue1 },
        { { hi_name = 'NonText', ui_name = 'EndOfBuffer', kind = 'ui' } },
      },
      [3] = {
        { bold = true, reverse = true },
        { { hi_name = 'StatusLine', ui_name = 'StatusLine', kind = 'ui' } },
      },
      [4] = {
        { reverse = true },
        { { hi_name = 'StatusLineNC', ui_name = 'StatusLineNC', kind = 'ui' } },
      },
      [5] = { {}, { { hi_name = 'StatusLine', ui_name = 'StatusLine', kind = 'ui' } } },
      [6] = { {}, { { hi_name = 'StatusLineNC', ui_name = 'StatusLineNC', kind = 'ui' } } },
      [7] = { {}, { { hi_name = 'MsgArea', ui_name = 'MsgArea', kind = 'ui' } } },
    })
    command('hi clear WinSeparator')
    command('vsplit')

    screen:expect([[
      ^                    {1:│}                   |
      {2:~                   }{1:│}{2:~                  }|*5
      {3:[No Name]            }{4:[No Name]          }|
      {7:                                        }|
    ]])

    command('hi clear StatusLine | hi clear StatuslineNC')
    screen:expect([[
      ^                    {1:│}                   |
      {2:~                   }{1:│}{2:~                  }|*5
      {5:[No Name]            }{6:[No Name]          }|
      {7:                                        }|
    ]])

    -- redrawing is done even if visible highlights didn't change
    command('wincmd w')
    screen:expect([[
                         {1:│}^                    |
      {2:~                  }{1:│}{2:~                   }|*5
      {6:[No Name]           }{5:[No Name]           }|
      {7:                                        }|
    ]])
  end)

  it('work with window-local highlights', function()
    screen:set_default_attr_ids({
      [1] = {
        { foreground = Screen.colors.Brown },
        { { hi_name = 'LineNr', ui_name = 'LineNr', kind = 'ui' } },
      },
      [2] = {
        { bold = true, foreground = Screen.colors.Blue1 },
        { { hi_name = 'NonText', ui_name = 'EndOfBuffer', kind = 'ui' } },
      },
      [3] = {
        { bold = true, reverse = true },
        { { hi_name = 'StatusLine', ui_name = 'StatusLine', kind = 'ui' } },
      },
      [4] = {
        { reverse = true },
        { { hi_name = 'StatusLineNC', ui_name = 'StatusLineNC', kind = 'ui' } },
      },
      [5] = {
        { background = Screen.colors.Red, foreground = Screen.colors.Grey100 },
        { { hi_name = 'ErrorMsg', ui_name = 'LineNr', kind = 'ui' } },
      },
      [6] = {
        { bold = true, reverse = true },
        { { hi_name = 'Normal', ui_name = 'Normal', kind = 'ui' } },
      },
      [7] = { { foreground = Screen.colors.Brown, bold = true, reverse = true }, { 6, 1 } },
      [8] = { { foreground = Screen.colors.Blue1, bold = true, reverse = true }, { 6, 14 } },
      [9] = {
        { bold = true, foreground = Screen.colors.Brown },
        { { hi_name = 'NormalNC', ui_name = 'NormalNC', kind = 'ui' } },
      },
      [10] = { { bold = true, foreground = Screen.colors.Brown }, { 9, 1 } },
      [11] = { { bold = true, foreground = Screen.colors.Blue1 }, { 9, 14 } },
      [12] = { {}, { { hi_name = 'MsgArea', ui_name = 'MsgArea', kind = 'ui' } } },
      [13] = {
        { background = Screen.colors.Red1, foreground = Screen.colors.Gray100 },
        { { ui_name = 'LineNr', kind = 'ui', hi_name = 'LineNr' } },
      },
      [14] = {
        { bold = true, foreground = Screen.colors.Blue },
        { { ui_name = 'EndOfBuffer', kind = 'ui', hi_name = 'EndOfBuffer' } },
      },
    })

    command('set number')
    command('split')
    -- NormalNC is not applied if not set, to avoid spurious redraws
    screen:expect([[
      {1:  1 }^                                    |
      {2:~                                       }|*2
      {3:[No Name]                               }|
      {1:  1 }                                    |
      {2:~                                       }|
      {4:[No Name]                               }|
      {12:                                        }|
    ]])

    command('set winhl=LineNr:ErrorMsg')
    screen:expect {
      grid = [[
      {13:  1 }^                                    |
      {14:~                                       }|*2
      {3:[No Name]                               }|
      {1:  1 }                                    |
      {2:~                                       }|
      {4:[No Name]                               }|
      {12:                                        }|
    ]],
    }

    command('set winhl=Normal:MsgSeparator,NormalNC:Statement')
    screen:expect([[
      {7:  1 }{6:^                                    }|
      {8:~                                       }|*2
      {3:[No Name]                               }|
      {1:  1 }                                    |
      {2:~                                       }|
      {4:[No Name]                               }|
      {12:                                        }|
    ]])

    command('wincmd w')
    screen:expect([[
      {10:  1 }{9:                                    }|
      {11:~                                       }|*2
      {4:[No Name]                               }|
      {1:  1 }^                                    |
      {2:~                                       }|
      {3:[No Name]                               }|
      {12:                                        }|
    ]])
  end)

  it('work with :terminal', function()
    skip(is_os('win'))

    screen:set_default_attr_ids({
      [1] = { {}, { { hi_name = 'TermCursorNC', ui_name = 'TermCursorNC', kind = 'ui' } } },
      [2] = { { foreground = tonumber('0x00ccff'), fg_indexed = true }, { { kind = 'term' } } },
      [3] = {
        { bold = true, foreground = tonumber('0x00ccff'), fg_indexed = true },
        {
          { kind = 'term' },
        },
      },
      [4] = { { foreground = tonumber('0x00ccff'), fg_indexed = true }, { 2, 1 } },
      [5] = { { foreground = tonumber('0x40ffff'), fg_indexed = true }, { { kind = 'term' } } },
      [6] = { { foreground = tonumber('0x40ffff'), fg_indexed = true }, { 5, 1 } },
      [7] = { {}, { { hi_name = 'MsgArea', ui_name = 'MsgArea', kind = 'ui' } } },
    })
    command(("enew | call termopen(['%s'])"):format(testprg('tty-test')))
    screen:expect([[
      ^tty ready                               |
      {1: }                                       |
                                              |*5
      {7:                                        }|
    ]])

    thelpers.feed_data('x ')
    thelpers.set_fg(45)
    thelpers.feed_data('y ')
    thelpers.set_bold()
    thelpers.feed_data('z\n')
    -- TODO(bfredl): check if this distinction makes sense
    if is_os('win') then
      screen:expect([[
        ^tty ready                               |
        x {5:y z}                                   |
        {1: }                                       |
                                                |*4
        {7:                                        }|
      ]])
    else
      screen:expect([[
        ^tty ready                               |
        x {2:y }{3:z}                                   |
        {1: }                                       |
                                                |*4
        {7:                                        }|
      ]])
    end

    thelpers.feed_termcode('[A')
    thelpers.feed_termcode('[2C')
    if is_os('win') then
      screen:expect([[
        ^tty ready                               |
        x {6:y}{5: z}                                   |
                                                |*5
        {7:                                        }|
      ]])
    else
      screen:expect([[
        ^tty ready                               |
        x {4:y}{2: }{3:z}                                   |
                                                |*5
        {7:                                        }|
      ]])
    end
  end)

  it('can use independent cterm and rgb colors', function()
    -- tell test module to save all attributes (doesn't change nvim options)
    screen:set_rgb_cterm(true)

    screen:set_default_attr_ids({
      [1] = {
        { bold = true, foreground = Screen.colors.Blue1 },
        { foreground = 12 },
        { { hi_name = 'NonText', ui_name = 'EndOfBuffer', kind = 'ui' } },
      },
      [2] = {
        { reverse = true, foreground = Screen.colors.Red },
        { foreground = 10, italic = true },
        { { hi_name = 'NonText', ui_name = 'EndOfBuffer', kind = 'ui' } },
      },
      [3] = { {}, {}, { { hi_name = 'MsgArea', ui_name = 'MsgArea', kind = 'ui' } } },
    })
    screen:expect([[
      ^                                        |
      {1:~                                       }|*6
      {3:                                        }|
    ]])

    command('hi NonText guifg=Red gui=reverse ctermfg=Green cterm=italic')
    screen:expect([[
      ^                                        |
      {2:~                                       }|*6
      {3:                                        }|
    ]])
  end)
end)
