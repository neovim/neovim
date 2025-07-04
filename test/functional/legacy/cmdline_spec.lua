local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local feed = n.feed
local feed_command = n.feed_command
local exec = n.exec
local api = n.api
local pesc = vim.pesc

describe('cmdline', function()
  before_each(clear)

  -- oldtest: Test_cmdlineclear_tabenter()
  it('is cleared when switching tabs', function()
    local screen = Screen.new(30, 10)

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

  -- oldtest: Test_wildmenu_with_input_func()
  it('wildmenu works with input() function', function()
    local screen = Screen.new(60, 8)
    screen:add_extra_attr_ids({
      [100] = { background = Screen.colors.Yellow, foreground = Screen.colors.Black },
    })

    feed(":call input('Command? ', '', 'command')<CR>")
    screen:expect([[
                                                                  |
      {1:~                                                           }|*6
      Command? ^                                                   |
    ]])
    feed('ech<Tab>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      {100:echo}{3:  echoerr  echohl  echomsg  echon                       }|
      Command? echo^                                               |
    ]])
    feed('<Space>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*6
      Command? echo ^                                              |
    ]])
    feed('bufn<Tab>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      {100:bufname(}{3:  bufnr(                                            }|
      Command? echo bufname(^                                      |
    ]])
    feed('<CR>')

    command('set wildoptions+=pum')

    feed(":call input('Command? ', '', 'command')<CR>")
    screen:expect([[
                                                                  |
      {1:~                                                           }|*6
      Command? ^                                                   |
    ]])
    feed('ech<Tab>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|
      {1:~       }{12: echo           }{1:                                    }|
      {1:~       }{4: echoerr        }{1:                                    }|
      {1:~       }{4: echohl         }{1:                                    }|
      {1:~       }{4: echomsg        }{1:                                    }|
      {1:~       }{4: echon          }{1:                                    }|
      Command? echo^                                               |
    ]])
    feed('<Space>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*6
      Command? echo ^                                              |
    ]])
    feed('bufn<Tab>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*4
      {1:~            }{12: bufname(       }{1:                               }|
      {1:~            }{4: bufnr(         }{1:                               }|
      Command? echo bufname(^                                      |
    ]])
    feed('<CR>')
  end)

  -- oldtest: Test_redraw_in_autocmd()
  it('cmdline cursor position is correct after :redraw with cmdheight=2', function()
    local screen = Screen.new(30, 6)
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

  -- oldtest: Test_changing_cmdheight()
  it("changing 'cmdheight'", function()
    local screen = Screen.new(60, 8)
    exec([[
      set cmdheight=1 laststatus=2
      func EchoOne()
        set laststatus=2 cmdheight=1
        echo 'foo'
        echo 'bar'
        set cmdheight=2
      endfunc
      func EchoTwo()
        set laststatus=2
        set cmdheight=5
        echo 'foo'
        echo 'bar'
        set cmdheight=1
      endfunc
    ]])

    feed(':resize -3<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*2
      {3:[No Name]                                                   }|
                                                                  |*4
    ]])

    -- :resize now also changes 'cmdheight' accordingly
    feed(':set cmdheight+=1<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |*5
    ]])

    -- using more space moves the status line up
    feed(':set cmdheight+=1<CR>')
    screen:expect([[
      ^                                                            |
      {3:[No Name]                                                   }|
                                                                  |*6
    ]])

    -- reducing cmdheight moves status line down
    feed(':set cmdheight-=3<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*3
      {3:[No Name]                                                   }|
                                                                  |*3
    ]])

    -- reducing window size and then setting cmdheight
    feed(':resize -1<CR>')
    feed(':set cmdheight=1<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*5
      {3:[No Name]                                                   }|
                                                                  |
    ]])

    -- setting 'cmdheight' works after outputting two messages
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

    -- increasing 'cmdheight' doesn't clear the messages that need hit-enter
    feed(':call EchoOne()<CR>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*3
      {3:                                                            }|
      foo                                                         |
      bar                                                         |
      {6:Press ENTER or type command to continue}^                     |
    ]])

    -- window commands do not reduce 'cmdheight' to value lower than :set by user
    feed('<CR>:wincmd _<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
      {3:[No Name]                                                   }|
      :wincmd _                                                   |
                                                                  |
    ]])
  end)

  -- oldtest: Test_cmdheight_tabline()
  it("changing 'cmdheight' when there is a tabline", function()
    local screen = Screen.new(60, 8)
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

  -- oldtest: Test_rulerformat_function()
  it("'rulerformat' can use %!", function()
    local screen = Screen.new(40, 2)
    exec([[
      func TestRulerFn()
        return '10,20%=30%%'
      endfunc
    ]])
    api.nvim_set_option_value('ruler', true, {})
    api.nvim_set_option_value('rulerformat', '%!TestRulerFn()', {})
    screen:expect([[
      ^                                        |
                            10,20         30% |
    ]])
  end)

  -- oldtest: Test_search_wildmenu_screendump()
  it('wildmenu for search completion', function()
    local screen = Screen.new(60, 10)
    screen:add_extra_attr_ids({
      [100] = { background = Screen.colors.Yellow, foreground = Screen.colors.Black },
    })
    exec([[
      set wildmenu wildcharm=<f5> wildoptions-=pum
      call setline(1, ['the', 'these', 'the', 'foobar', 'thethe', 'thethere'])
    ]])

    -- Pattern has newline at EOF
    feed('gg2j/e\\n<f5>')
    screen:expect([[
      the                                                         |
      these                                                       |
      the                                                         |
      foobar                                                      |
      thethe                                                      |
      thethere                                                    |
      {1:~                                                           }|*2
      {100:e\nfoobar}{3:  e\nthethere  e\nthese  e\nthe                    }|
      /e\nfoobar^                                                  |
    ]])

    -- longest:full
    feed('<esc>')
    command('set wim=longest,full')
    feed('gg/t<f5>')
    screen:expect([[
      the                                                         |
      these                                                       |
      the                                                         |
      foobar                                                      |
      thethe                                                      |
      thethere                                                    |
      {1:~                                                           }|*3
      /the^                                                        |
    ]])

    -- list:full
    feed('<esc>')
    command('set wim=list,full')
    feed('gg/t<f5>')
    screen:expect([[
      {10:t}he                                                         |
      {10:t}hese                                                       |
      {10:t}he                                                         |
      foobar                                                      |
      {10:t}he{10:t}he                                                      |
      {10:t}he{10:t}here                                                    |
      {3:                                                            }|
      /t                                                          |
      these     the       thethe    thethere  there               |
      /t^                                                          |
    ]])

    -- noselect:full
    feed('<esc>')
    command('set wim=noselect,full')
    feed('gg/t<f5>')
    screen:expect([[
      the                                                         |
      these                                                       |
      the                                                         |
      foobar                                                      |
      thethe                                                      |
      thethere                                                    |
      {1:~                                                           }|*2
      {3:these  the  thethe  thethere  there                         }|
      /t^                                                          |
    ]])

    -- Multiline
    feed('<esc>gg/t.*\\n.*\\n.<tab>')
    screen:expect([[
      the                                                         |
      these                                                       |
      the                                                         |
      foobar                                                      |
      thethe                                                      |
      thethere                                                    |
      {1:~                                                           }|*2
      {3:t.*\n.*\n.oobar  t.*\n.*\n.hethe  t.*\n.*\n.he              }|
      /t.*\n.*\n.^                                                 |
    ]])

    feed('<esc>')
  end)
end)

describe('cmdwin', function()
  before_each(clear)

  -- oldtest: Test_cmdwin_interrupted()
  it('still uses a new buffer when interrupting more prompt on open', function()
    local screen = Screen.new(30, 16)
    command('set more')
    command('autocmd WinNew * highlight')
    feed('q:')
    screen:expect({ any = pesc('{6:-- More --}^') })
    feed('q')
    screen:expect([[
                                    |
      {1:~                             }|*5
      {2:[No Name]                     }|
      {1::}^                             |
      {1:~                             }|*6
      {3:[Command Line]                }|
                                    |
    ]])
    feed([[aecho 'done']])
    screen:expect([[
                                    |
      {1:~                             }|*5
      {2:[No Name]                     }|
      {1::}echo 'done'^                  |
      {1:~                             }|*6
      {3:[Command Line]                }|
      {5:-- INSERT --}                  |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                              |
      {1:~                             }|*14
      done                          |
    ]])
  end)
end)
