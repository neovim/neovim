local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, insert = helpers.clear, helpers.insert
local command = helpers.command
local meths = helpers.meths
local iswin = helpers.iswin
local nvim_dir = helpers.nvim_dir
local thelpers = require('test.functional.terminal.helpers')

describe('ext_hlstate detailed highlights', function()
  local screen

  before_each(function()
    clear()
    command('syntax on')
    screen = Screen.new(40, 8)
    screen:attach({ext_hlstate=true})
  end)

  after_each(function()
    screen:detach()
  end)


  it('work with combined UI and syntax highlights', function()
    insert([[
      these are some lines
      with colorful text]])
    meths.buf_add_highlight(0, -1, "String", 0 , 10, 14)
    meths.buf_add_highlight(0, -1, "Statement", 1 , 5, -1)
    command("/th co")

    screen:expect([[
      these are {1:some} lines                    |
      ^wi{2:th }{4:co}{3:lorful text}                      |
      {5:~                                       }|
      {5:~                                       }|
      {5:~                                       }|
      {5:~                                       }|
      {5:~                                       }|
      {6:search hit BOTTOM, continuing at TOP}    |
    ]], {
    [1] = {{foreground = Screen.colors.Magenta},
           {{hi_name = "Constant", kind = "syntax"}}},
    [2] = {{background = Screen.colors.Yellow},
           {{hi_name = "Search", ui_name = "Search", kind = "ui"}}},
    [3] = {{bold = true, foreground = Screen.colors.Brown},
           {{hi_name = "Statement", kind = "syntax"}}},
    [4] = {{bold = true, background = Screen.colors.Yellow, foreground = Screen.colors.Brown}, {3, 2}},
    [5] = {{bold = true, foreground = Screen.colors.Blue1},
           {{hi_name = "NonText", ui_name = "EndOfBuffer", kind = "ui"}}},
    [6] = {{foreground = Screen.colors.Red},
           {{hi_name = "WarningMsg", ui_name = "WarningMsg", kind = "ui"}}},
    })
  end)

  it('work with cleared UI highlights', function()
    screen:set_default_attr_ids({
      [1] = {{}, {{hi_name = "VertSplit", ui_name = "VertSplit", kind = "ui"}}},
      [2] = {{bold = true, foreground = Screen.colors.Blue1},
             {{hi_name = "NonText", ui_name = "EndOfBuffer", kind = "ui"}}},
      [3] = {{bold = true, reverse = true},
            {{hi_name = "StatusLine", ui_name = "StatusLine", kind = "ui"}}} ,
      [4] = {{reverse = true},
            {{hi_name = "StatusLineNC", ui_name = "StatusLineNC" , kind = "ui"}}},
      [5] = {{}, {{hi_name = "StatusLine", ui_name = "StatusLine", kind = "ui"}}},
      [6] = {{}, {{hi_name = "StatusLineNC", ui_name = "StatusLineNC", kind = "ui"}}},
    })
    command("hi clear VertSplit")
    command("vsplit")

    screen:expect([[
      ^                    {1:│}                   |
      {2:~                   }{1:│}{2:~                  }|
      {2:~                   }{1:│}{2:~                  }|
      {2:~                   }{1:│}{2:~                  }|
      {2:~                   }{1:│}{2:~                  }|
      {2:~                   }{1:│}{2:~                  }|
      {3:[No Name]            }{4:[No Name]          }|
                                              |
    ]])

    command("hi clear StatusLine | hi clear StatuslineNC")
    screen:expect([[
      ^                    {1:│}                   |
      {2:~                   }{1:│}{2:~                  }|
      {2:~                   }{1:│}{2:~                  }|
      {2:~                   }{1:│}{2:~                  }|
      {2:~                   }{1:│}{2:~                  }|
      {2:~                   }{1:│}{2:~                  }|
      {5:[No Name]            }{6:[No Name]          }|
                                              |
    ]])

    -- redrawing is done even if visible highlights didn't change
    command("wincmd w")
    screen:expect([[
                         {1:│}^                    |
      {2:~                  }{1:│}{2:~                   }|
      {2:~                  }{1:│}{2:~                   }|
      {2:~                  }{1:│}{2:~                   }|
      {2:~                  }{1:│}{2:~                   }|
      {2:~                  }{1:│}{2:~                   }|
      {6:[No Name]           }{5:[No Name]           }|
                                              |
    ]])

  end)

  it("work with window-local highlights", function()
    screen:set_default_attr_ids({
        [1] = {{foreground = Screen.colors.Brown}, {{hi_name = "LineNr", ui_name = "LineNr", kind = "ui"}}},
        [2] = {{bold = true, foreground = Screen.colors.Blue1}, {{hi_name = "NonText", ui_name = "EndOfBuffer", kind = "ui"}}},
        [3] = {{bold = true, reverse = true}, {{hi_name = "StatusLine", ui_name = "StatusLine", kind = "ui"}}},
        [4] = {{reverse = true}, {{hi_name = "StatusLineNC", ui_name = "StatusLineNC", kind = "ui"}}},
        [5] = {{background = Screen.colors.Red, foreground = Screen.colors.Grey100}, {{hi_name = "ErrorMsg", ui_name = "LineNr", kind = "ui"}}},
        [6] = {{bold = true, reverse = true}, {{hi_name = "MsgSeparator", ui_name = "Normal", kind = "ui"}}},
        [7] = {{foreground = Screen.colors.Brown, bold = true, reverse = true}, {6, 1}},
        [8] = {{foreground = Screen.colors.Blue1, bold = true, reverse = true}, {6, 2}},
        [9] = {{bold = true, foreground = Screen.colors.Brown}, {{hi_name = "Statement", ui_name = "NormalNC", kind = "ui"}}},
        [10] = {{bold = true, foreground = Screen.colors.Brown}, {9, 1}},
        [11] = {{bold = true, foreground = Screen.colors.Blue1}, {9, 2}}
    })

    command("set number")
    command("split")
    -- NormalNC is not applied if not set, to avoid spurious redraws
    screen:expect([[
      {1:  1 }^                                    |
      {2:~                                       }|
      {2:~                                       }|
      {3:[No Name]                               }|
      {1:  1 }                                    |
      {2:~                                       }|
      {4:[No Name]                               }|
                                              |
    ]])

    command("set winhl=LineNr:ErrorMsg")
    screen:expect([[
      {5:  1 }^                                    |
      {2:~                                       }|
      {2:~                                       }|
      {3:[No Name]                               }|
      {1:  1 }                                    |
      {2:~                                       }|
      {4:[No Name]                               }|
                                              |
    ]])

    command("set winhl=Normal:MsgSeparator,NormalNC:Statement")
    screen:expect([[
      {7:  1 }{6:^                                    }|
      {8:~                                       }|
      {8:~                                       }|
      {3:[No Name]                               }|
      {1:  1 }                                    |
      {2:~                                       }|
      {4:[No Name]                               }|
                                              |
    ]])

    command("wincmd w")
    screen:expect([[
      {10:  1 }{9:                                    }|
      {11:~                                       }|
      {11:~                                       }|
      {4:[No Name]                               }|
      {1:  1 }^                                    |
      {2:~                                       }|
      {3:[No Name]                               }|
                                              |
    ]])
  end)

  it("work with :terminal", function()
    screen:set_default_attr_ids({
      [1] = {{}, {{hi_name = "TermCursorNC", ui_name = "TermCursorNC", kind = "ui"}}},
      [2] = {{foreground = 52479}, {{kind = "term"}}},
      [3] = {{bold = true, foreground = 52479}, {{kind = "term"}}},
      [4] = {{foreground = 52479}, {2, 1}},
      [5] = {{foreground = 4259839}, {{kind = "term"}}},
      [6] = {{foreground = 4259839}, {5, 1}},
    })
    command('enew | call termopen(["'..nvim_dir..'/tty-test"])')
    screen:expect([[
      ^tty ready                               |
      {1: }                                       |
                                              |
                                              |
                                              |
                                              |
                                              |
                                              |
    ]])

    thelpers.feed_data('x ')
    thelpers.set_fg(45)
    thelpers.feed_data('y ')
    thelpers.set_bold()
    thelpers.feed_data('z\n')
    -- TODO(bfredl): check if this distinction makes sense
    if iswin() then
      screen:expect([[
        ^tty ready                               |
        x {5:y z}                                   |
        {1: }                                       |
                                                |
                                                |
                                                |
                                                |
                                                |
      ]])
    else
      screen:expect([[
        ^tty ready                               |
        x {2:y }{3:z}                                   |
        {1: }                                       |
                                                |
                                                |
                                                |
                                                |
                                                |
      ]])
    end

    thelpers.feed_termcode("[A")
    thelpers.feed_termcode("[2C")
    if iswin() then
      screen:expect([[
        ^tty ready                               |
        x {6:y}{5: z}                                   |
                                                |
                                                |
                                                |
                                                |
                                                |
                                                |
      ]])
    else
      screen:expect([[
        ^tty ready                               |
        x {4:y}{2: }{3:z}                                   |
                                                |
                                                |
                                                |
                                                |
                                                |
                                                |
      ]])
    end
  end)

  it("can use independent cterm and rgb colors", function()
    -- tell test module to save all attributes (doesn't change nvim options)
    screen:set_hlstate_cterm(true)

    screen:set_default_attr_ids({
        [1] = {{bold = true, foreground = Screen.colors.Blue1}, {foreground = 12}, {{hi_name = "NonText", ui_name = "EndOfBuffer", kind = "ui"}}},
        [2] = {{reverse = true, foreground = Screen.colors.Red}, {foreground = 10, italic=true}, {{hi_name = "NonText", ui_name = "EndOfBuffer", kind = "ui"}}},
    })
    screen:expect([[
      ^                                        |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    command("hi NonText guifg=Red gui=reverse ctermfg=Green cterm=italic")
    screen:expect([[
      ^                                        |
      {2:~                                       }|
      {2:~                                       }|
      {2:~                                       }|
      {2:~                                       }|
      {2:~                                       }|
      {2:~                                       }|
                                              |
    ]])

  end)
end)
