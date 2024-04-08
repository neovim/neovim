local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local command = t.command
local exec = t.exec
local feed = t.feed

before_each(clear)

describe('breakindent', function()
  -- oldtest: Test_cursor_position_with_showbreak()
  it('cursor shown at correct position with showbreak', function()
    local screen = Screen.new(75, 6)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue }, -- SignColumn
      [2] = { bold = true }, -- ModeMsg
    })
    screen:attach()
    exec([[
      set listchars=eol:$
      let &signcolumn = 'yes'
      let &showbreak = '++'
      let &breakindentopt = 'shift:2'
      let leftcol = win_getid()->getwininfo()->get(0, {})->get('textoff')
      eval repeat('x', &columns - leftcol - 1)->setline(1)
      eval 'second line'->setline(2)
    ]])

    feed('AX')
    screen:expect([[
      {1:  }xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxX|
      {1:  }^second line                                                              |
      {0:~                                                                          }|*3
      {2:-- INSERT --}                                                               |
    ]])
    -- No line wraps, so changing 'showbreak' should lead to the same screen.
    command('setlocal showbreak=+')
    screen:expect_unchanged()
    -- No line wraps, so setting 'breakindent' should lead to the same screen.
    command('setlocal breakindent')
    screen:expect_unchanged()
    -- The first line now wraps because of "eol" in 'listchars'.
    command('setlocal list')
    screen:expect([[
      {1:  }xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxX|
      {1:  }  {0:+^$}                                                                     |
      {1:  }second line{0:$}                                                             |
      {0:~                                                                          }|*2
      {2:-- INSERT --}                                                               |
    ]])
    command('setlocal nobreakindent')
    screen:expect([[
      {1:  }xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxX|
      {1:  }{0:+^$}                                                                       |
      {1:  }second line{0:$}                                                             |
      {0:~                                                                          }|*2
      {2:-- INSERT --}                                                               |
    ]])
  end)

  -- oldtest: Test_visual_starts_before_skipcol()
  it('Visual selection that starts before skipcol shows correctly', function()
    local screen = Screen.new(75, 6)
    exec([[
      1new
      setlocal breakindent
      call setline(1, "\t" .. join(range(100)))
    ]])
    screen:attach()

    feed('v$')
    screen:expect([[
      {1:<<<}     {17: 93 94 95 96 97 98 99}^                                              |
      {3:[No Name] [+]                                                              }|
                                                                                 |
      {1:~                                                                          }|
      {2:[No Name]                                                                  }|
      {5:-- VISUAL --}                                                               |
    ]])
    command('setlocal showbreak=+++')
    screen:expect([[
              {1:+++}{17: 90 91 92 93 94 95 96 97 98 99}^                                  |
      {3:[No Name] [+]                                                              }|
                                                                                 |
      {1:~                                                                          }|
      {2:[No Name]                                                                  }|
      {5:-- VISUAL --}                                                               |
    ]])
    command('setlocal breakindentopt+=sbr')
    screen:expect([[
      {1:+++}     {17: 93 94 95 96 97 98 99}^                                              |
      {3:[No Name] [+]                                                              }|
                                                                                 |
      {1:~                                                                          }|
      {2:[No Name]                                                                  }|
      {5:-- VISUAL --}                                                               |
    ]])
    command('setlocal nobreakindent')
    screen:expect([[
      {1:+++}{17: 98 99}^                                                                  |
      {3:[No Name] [+]                                                              }|
                                                                                 |
      {1:~                                                                          }|
      {2:[No Name]                                                                  }|
      {5:-- VISUAL --}                                                               |
    ]])
  end)
end)
