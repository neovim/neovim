local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local command = t.command
local feed = t.feed
local feed_command = t.feed_command
local exec = t.exec
local api = t.api
local pesc = vim.pesc

describe('cmdline', function()
  before_each(clear)

  -- oldtest: Test_cmdlineclear_tabenter()
  it('is cleared when switching tabs', function()
    local screen = Screen.new(30, 10)
    screen:attach()

    feed_command([[call setline(1, range(30))]])
    screen:expect([[
      ^0                             |
      1                             |
      2                             |
      3                             |
      4                             |
      5                             |
      6                             |
      7                             |
      8                             |
      :call setline(1, range(30))   |
    ]])

    feed [[:tabnew<cr>]]
    screen:expect {
      grid = [[
      {24: + [No Name] }{5: [No Name] }{2:     }{24:X}|
      ^                              |
      {1:~                             }|*7
      :tabnew                       |
    ]],
    }

    feed [[<C-w>-<C-w>-]]
    screen:expect {
      grid = [[
      {24: + [No Name] }{5: [No Name] }{2:     }{24:X}|
      ^                              |
      {1:~                             }|*5
                                    |*3
    ]],
    }

    feed [[gt]]
    screen:expect {
      grid = [[
      {5: + [No Name] }{24: [No Name] }{2:     }{24:X}|
      ^0                             |
      1                             |
      2                             |
      3                             |
      4                             |
      5                             |
      6                             |
      7                             |
                                    |
    ]],
    }

    feed [[gt]]
    screen:expect([[
      {24: + [No Name] }{5: [No Name] }{2:     }{24:X}|
      ^                              |
      {1:~                             }|*5
                                    |*3
    ]])
  end)

  -- oldtest: Test_verbose_option()
  it('prints every executed Ex command if verbose >= 16', function()
    local screen = Screen.new(60, 12)
    screen:attach()
    exec([[
      command DoSomething echo 'hello' |set ts=4 |let v = '123' |echo v
      call feedkeys("\r", 't') " for the hit-enter prompt
      set verbose=20
    ]])
    feed_command('DoSomething')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*2
      {3:                                                            }|
      Executing: DoSomething                                      |
      Executing: echo 'hello' |set ts=4 |let v = '123' |echo v    |
      hello                                                       |
      Executing: set ts=4 |let v = '123' |echo v                  |
      Executing: let v = '123' |echo v                            |
      Executing: echo v                                           |
      123                                                         |
      {6:Press ENTER or type command to continue}^                     |
    ]])
  end)

  -- oldtest: Test_cmdline_redraw_tabline()
  it('tabline is redrawn on entering cmdline', function()
    local screen = Screen.new(30, 6)
    screen:attach()
    exec([[
      set showtabline=2
      autocmd CmdlineEnter * set tabline=foo
    ]])
    feed(':')
    screen:expect([[
      {2:foo                           }|
                                    |
      {1:~                             }|*3
      :^                             |
    ]])
  end)

  -- oldtest: Test_redraw_in_autocmd()
  it('cmdline cursor position is correct after :redraw with cmdheight=2', function()
    local screen = Screen.new(30, 6)
    screen:attach()
    exec([[
      set cmdheight=2
      autocmd CmdlineChanged * redraw
    ]])
    feed(':for i in range(3)<CR>')
    screen:expect([[
                                    |
      {1:~                             }|*3
      :for i in range(3)            |
      :  ^                           |
    ]])
    feed(':let i =')
    -- Note: this may still be considered broken, ref #18140
    screen:expect([[
                                    |
      {1:~                             }|*3
      :  :let i =^                   |
                                    |
    ]])
  end)

  it("setting 'cmdheight' works after outputting two messages vim-patch:9.0.0665", function()
    local screen = Screen.new(60, 8)
    screen:attach()
    exec([[
      set cmdheight=1 laststatus=2
      func EchoTwo()
        set laststatus=2
        set cmdheight=5
        echo 'foo'
        echo 'bar'
        set cmdheight=1
      endfunc
    ]])
    feed(':call EchoTwo()')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      {3:[No Name]                                                   }|
      :call EchoTwo()^                                             |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*5
      {3:[No Name]                                                   }|
                                                                  |
    ]])
  end)

  -- oldtest: Test_cmdheight_tabline()
  it("changing 'cmdheight' when there is a tabline", function()
    local screen = Screen.new(60, 8)
    screen:attach()
    api.nvim_set_option_value('laststatus', 2, {})
    api.nvim_set_option_value('showtabline', 2, {})
    api.nvim_set_option_value('cmdheight', 1, {})
    screen:expect([[
      {5: [No Name] }{2:                                                 }|
      ^                                                            |
      {1:~                                                           }|*4
      {3:[No Name]                                                   }|
                                                                  |
    ]])
  end)

  -- oldtest: Test_rulerformat_position()
  it("ruler has correct position with 'rulerformat' set", function()
    local screen = Screen.new(20, 3)
    screen:attach()
    api.nvim_set_option_value('ruler', true, {})
    api.nvim_set_option_value('rulerformat', 'longish', {})
    api.nvim_set_option_value('laststatus', 0, {})
    api.nvim_set_option_value('winwidth', 1, {})
    feed [[<C-W>v<C-W>|<C-W>p]]
    screen:expect [[
                        │^ |
      {1:~                 }│{1:~}|
                longish   |
    ]]
  end)
end)

describe('cmdwin', function()
  before_each(clear)

  -- oldtest: Test_cmdwin_interrupted()
  it('still uses a new buffer when interrupting more prompt on open', function()
    local screen = Screen.new(30, 16)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { bold = true, reverse = true }, -- StatusLine
      [2] = { reverse = true }, -- StatusLineNC
      [3] = { bold = true, foreground = Screen.colors.SeaGreen }, -- MoreMsg
      [4] = { bold = true }, -- ModeMsg
    })
    screen:attach()
    command('set more')
    command('autocmd WinNew * highlight')
    feed('q:')
    screen:expect({ any = pesc('{3:-- More --}^') })
    feed('q')
    screen:expect([[
                                    |
      {0:~                             }|*5
      {2:[No Name]                     }|
      {0::}^                             |
      {0:~                             }|*6
      {1:[Command Line]                }|
                                    |
    ]])
    feed([[aecho 'done']])
    screen:expect([[
                                    |
      {0:~                             }|*5
      {2:[No Name]                     }|
      {0::}echo 'done'^                  |
      {0:~                             }|*6
      {1:[Command Line]                }|
      {4:-- INSERT --}                  |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                              |
      {0:~                             }|*14
      done                          |
    ]])
  end)
end)
