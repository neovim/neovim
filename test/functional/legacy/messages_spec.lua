local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local exec = helpers.exec
local feed = helpers.feed

before_each(clear)

describe('messages', function()
  local screen

  describe('more prompt', function()
    before_each(function()
      screen = Screen.new(75, 6)
      screen:set_default_attr_ids({
        [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
        [1] = {bold = true, foreground = Screen.colors.SeaGreen},  -- MoreMsg
        [2] = {foreground = Screen.colors.Brown},  -- LineNr
        [3] = {foreground = Screen.colors.Blue},  -- SpecialKey
      })
      screen:attach()
      command('set more')
    end)

    -- oldtest: Test_message_more()
    it('works', function()
      command('call setline(1, range(1, 100))')

      feed(':%pfoo<C-H><C-H><C-H>#')
      screen:expect([[
        1                                                                          |
        2                                                                          |
        3                                                                          |
        4                                                                          |
        5                                                                          |
        :%p#^                                                                       |
      ]])
      feed('\n')
      screen:expect([[
        {2:  1 }1                                                                      |
        {2:  2 }2                                                                      |
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        {1:-- More --}^                                                                 |
      ]])

      feed('?')
      screen:expect([[
        {2:  1 }1                                                                      |
        {2:  2 }2                                                                      |
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        {1:-- More -- SPACE/d/j: screen/page/line down, b/u/k: up, q: quit }^           |
      ]])

      -- Down a line with j, <CR>, <NL> or <Down>.
      feed('j')
      screen:expect([[
        {2:  2 }2                                                                      |
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        {2:  6 }6                                                                      |
        {1:-- More --}^                                                                 |
      ]])
      feed('<NL>')
      screen:expect([[
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        {2:  6 }6                                                                      |
        {2:  7 }7                                                                      |
        {1:-- More --}^                                                                 |
      ]])
      feed('<CR>')
      screen:expect([[
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        {2:  6 }6                                                                      |
        {2:  7 }7                                                                      |
        {2:  8 }8                                                                      |
        {1:-- More --}^                                                                 |
      ]])
      feed('<Down>')
      screen:expect([[
        {2:  5 }5                                                                      |
        {2:  6 }6                                                                      |
        {2:  7 }7                                                                      |
        {2:  8 }8                                                                      |
        {2:  9 }9                                                                      |
        {1:-- More --}^                                                                 |
      ]])

      -- Down a screen with <Space>, f, or <PageDown>.
      feed('f')
      screen:expect([[
        {2: 10 }10                                                                     |
        {2: 11 }11                                                                     |
        {2: 12 }12                                                                     |
        {2: 13 }13                                                                     |
        {2: 14 }14                                                                     |
        {1:-- More --}^                                                                 |
      ]])
      feed('<Space>')
      screen:expect([[
        {2: 15 }15                                                                     |
        {2: 16 }16                                                                     |
        {2: 17 }17                                                                     |
        {2: 18 }18                                                                     |
        {2: 19 }19                                                                     |
        {1:-- More --}^                                                                 |
      ]])
      feed('<PageDown>')
      screen:expect([[
        {2: 20 }20                                                                     |
        {2: 21 }21                                                                     |
        {2: 22 }22                                                                     |
        {2: 23 }23                                                                     |
        {2: 24 }24                                                                     |
        {1:-- More --}^                                                                 |
      ]])

      -- Down a page (half a screen) with d.
      feed('d')
      screen:expect([[
        {2: 23 }23                                                                     |
        {2: 24 }24                                                                     |
        {2: 25 }25                                                                     |
        {2: 26 }26                                                                     |
        {2: 27 }27                                                                     |
        {1:-- More --}^                                                                 |
      ]])

      -- Down all the way with 'G'.
      feed('G')
      screen:expect([[
        {2: 96 }96                                                                     |
        {2: 97 }97                                                                     |
        {2: 98 }98                                                                     |
        {2: 99 }99                                                                     |
        {2:100 }100                                                                    |
        {1:Press ENTER or type command to continue}^                                    |
      ]])

      -- Up a line k, <BS> or <Up>.
      feed('k')
      screen:expect([[
        {2: 95 }95                                                                     |
        {2: 96 }96                                                                     |
        {2: 97 }97                                                                     |
        {2: 98 }98                                                                     |
        {2: 99 }99                                                                     |
        {1:-- More --}^                                                                 |
      ]])
      feed('<BS>')
      screen:expect([[
        {2: 94 }94                                                                     |
        {2: 95 }95                                                                     |
        {2: 96 }96                                                                     |
        {2: 97 }97                                                                     |
        {2: 98 }98                                                                     |
        {1:-- More --}^                                                                 |
      ]])
      feed('<Up>')
      screen:expect([[
        {2: 93 }93                                                                     |
        {2: 94 }94                                                                     |
        {2: 95 }95                                                                     |
        {2: 96 }96                                                                     |
        {2: 97 }97                                                                     |
        {1:-- More --}^                                                                 |
      ]])

      -- Up a screen with b or <PageUp>.
      feed('b')
      screen:expect([[
        {2: 88 }88                                                                     |
        {2: 89 }89                                                                     |
        {2: 90 }90                                                                     |
        {2: 91 }91                                                                     |
        {2: 92 }92                                                                     |
        {1:-- More --}^                                                                 |
      ]])
      feed('<PageUp>')
      screen:expect([[
        {2: 83 }83                                                                     |
        {2: 84 }84                                                                     |
        {2: 85 }85                                                                     |
        {2: 86 }86                                                                     |
        {2: 87 }87                                                                     |
        {1:-- More --}^                                                                 |
      ]])

      -- Up a page (half a screen) with u.
      feed('u')
      screen:expect([[
        {2: 80 }80                                                                     |
        {2: 81 }81                                                                     |
        {2: 82 }82                                                                     |
        {2: 83 }83                                                                     |
        {2: 84 }84                                                                     |
        {1:-- More --}^                                                                 |
      ]])

      -- Up all the way with 'g'.
      feed('g')
      screen:expect([[
        :%p#                                                                       |
        {2:  1 }1                                                                      |
        {2:  2 }2                                                                      |
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {1:-- More --}^                                                                 |
      ]])

      -- All the way down. Pressing f should do nothing but pressing
      -- space should end the more prompt.
      feed('G')
      screen:expect([[
        {2: 96 }96                                                                     |
        {2: 97 }97                                                                     |
        {2: 98 }98                                                                     |
        {2: 99 }99                                                                     |
        {2:100 }100                                                                    |
        {1:Press ENTER or type command to continue}^                                    |
      ]])
      feed('f')
      screen:expect_unchanged()
      feed('<Space>')
      screen:expect([[
        96                                                                         |
        97                                                                         |
        98                                                                         |
        99                                                                         |
        ^100                                                                        |
                                                                                   |
      ]])

      -- Pressing g< shows the previous command output.
      feed('g<lt>')
      screen:expect([[
        {2: 96 }96                                                                     |
        {2: 97 }97                                                                     |
        {2: 98 }98                                                                     |
        {2: 99 }99                                                                     |
        {2:100 }100                                                                    |
        {1:Press ENTER or type command to continue}^                                    |
      ]])

      -- A command line that doesn't print text is appended to scrollback,
      -- even if it invokes a nested command line.
      feed([[:<C-R>=':'<CR>:<CR>g<lt>]])
      screen:expect([[
        {2: 97 }97                                                                     |
        {2: 98 }98                                                                     |
        {2: 99 }99                                                                     |
        {2:100 }100                                                                    |
        :::                                                                        |
        {1:Press ENTER or type command to continue}^                                    |
      ]])

      feed(':%p#\n')
      screen:expect([[
        {2:  1 }1                                                                      |
        {2:  2 }2                                                                      |
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        {1:-- More --}^                                                                 |
      ]])

      -- Stop command output with q, <Esc> or CTRL-C.
      feed('q')
      screen:expect([[
        96                                                                         |
        97                                                                         |
        98                                                                         |
        99                                                                         |
        ^100                                                                        |
                                                                                   |
      ]])

      -- Execute a : command from the more prompt
      feed(':%p#\n')
      screen:expect([[
        {2:  1 }1                                                                      |
        {2:  2 }2                                                                      |
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        {1:-- More --}^                                                                 |
      ]])
      feed(':')
      screen:expect([[
        {2:  1 }1                                                                      |
        {2:  2 }2                                                                      |
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        :^                                                                          |
      ]])
      feed("echo 'Hello'\n")
      screen:expect([[
        {2:  2 }2                                                                      |
        {2:  3 }3                                                                      |
        {2:  4 }4                                                                      |
        {2:  5 }5                                                                      |
        Hello                                                                      |
        {1:Press ENTER or type command to continue}^                                    |
      ]])
    end)

    -- oldtest: Test_quit_long_message()
    it('with control characters can be quit vim-patch:8.2.1844', function()
      screen:try_resize(40, 6)
      feed([[:echom range(9999)->join("\x01")<CR>]])
      screen:expect([[
        0{3:^A}1{3:^A}2{3:^A}3{3:^A}4{3:^A}5{3:^A}6{3:^A}7{3:^A}8{3:^A}9{3:^A}10{3:^A}11{3:^A}12|
        {3:^A}13{3:^A}14{3:^A}15{3:^A}16{3:^A}17{3:^A}18{3:^A}19{3:^A}20{3:^A}21{3:^A}22|
        {3:^A}23{3:^A}24{3:^A}25{3:^A}26{3:^A}27{3:^A}28{3:^A}29{3:^A}30{3:^A}31{3:^A}32|
        {3:^A}33{3:^A}34{3:^A}35{3:^A}36{3:^A}37{3:^A}38{3:^A}39{3:^A}40{3:^A}41{3:^A}42|
        {3:^A}43{3:^A}44{3:^A}45{3:^A}46{3:^A}47{3:^A}48{3:^A}49{3:^A}50{3:^A}51{3:^A}52|
        {1:-- More --}^                              |
      ]])
      feed('q')
      screen:expect([[
        ^                                        |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
                                                |
      ]])
    end)
  end)

  describe('mode is cleared when', function()
    before_each(function()
      screen = Screen.new(40, 6)
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
        [2] = {bold = true},  -- ModeMsg
        [3] = {bold = true, reverse=true},  -- StatusLine
      })
      screen:attach()
    end)

    -- oldtest: Test_mode_message_at_leaving_insert_by_ctrl_c()
    it('leaving Insert mode with Ctrl-C vim-patch:8.1.1189', function()
      exec([[
        func StatusLine() abort
          return ""
        endfunc
        set statusline=%!StatusLine()
        set laststatus=2
      ]])
      feed('i')
      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {3:                                        }|
        {2:-- INSERT --}                            |
      ]])
      feed('<C-C>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {3:                                        }|
                                                |
      ]])
    end)

    -- oldtest: Test_mode_message_at_leaving_insert_with_esc_mapped()
    it('leaving Insert mode with ESC in the middle of a mapping vim-patch:8.1.1192', function()
      exec([[
        set laststatus=2
        inoremap <Esc> <Esc>00
      ]])
      feed('i')
      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {3:[No Name]                               }|
        {2:-- INSERT --}                            |
      ]])
      feed('<Esc>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {3:[No Name]                               }|
                                                |
      ]])
    end)

    -- oldtest: Test_mode_updated_after_ctrl_c()
    it('pressing Ctrl-C in i_CTRL-O', function()
      feed('i<C-O>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {2:-- (insert) --}                          |
      ]])
      feed('<C-C>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
        {1:~                                       }|
                                                |
      ]])
    end)
  end)

  -- oldtest: Test_ask_yesno()
  it('y/n prompt works', function()
    screen = Screen.new(75, 6)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {bold = true, foreground = Screen.colors.SeaGreen},  -- MoreMsg
      [2] = {bold = true, reverse = true},  -- MsgSeparator
    })
    screen:attach()
    command('set noincsearch nohlsearch inccommand=')
    command('call setline(1, range(1, 2))')

    feed(':2,1s/^/n/\n')
    screen:expect([[
      1                                                                          |
      2                                                                          |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {1:Backwards range given, OK to swap (y/n)?}^                                   |
    ]])
    feed('n')
    screen:expect([[
      ^1                                                                          |
      2                                                                          |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {1:Backwards range given, OK to swap (y/n)?}n                                  |
    ]])

    feed(':2,1s/^/Esc/\n')
    screen:expect([[
      1                                                                          |
      2                                                                          |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {1:Backwards range given, OK to swap (y/n)?}^                                   |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^1                                                                          |
      2                                                                          |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {1:Backwards range given, OK to swap (y/n)?}n                                  |
    ]])

    feed(':2,1s/^/y/\n')
    screen:expect([[
      1                                                                          |
      2                                                                          |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {1:Backwards range given, OK to swap (y/n)?}^                                   |
    ]])
    feed('y')
    screen:expect([[
      y1                                                                         |
      ^y2                                                                         |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {1:Backwards range given, OK to swap (y/n)?}y                                  |
    ]])
  end)

  -- oldtest: Test_fileinfo_after_echo()
  it('fileinfo does not overwrite echo message vim-patch:8.2.4156', function()
    screen = Screen.new(40, 6)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
    })
    screen:attach()
    exec([[
      set shortmess-=F

      file a.txt

      hide edit b.txt
      call setline(1, "hi")
      setlocal modified

      hide buffer a.txt

      autocmd CursorHold * buf b.txt | w | echo "'b' written"
    ]])
    command('set updatetime=50')
    feed('0$')
    screen:expect([[
      ^hi                                      |
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
      'b' written                             |
    ]])
    os.remove('b.txt')
  end)
end)
