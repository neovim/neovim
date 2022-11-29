local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed
local command = helpers.command

describe('display', function()
  before_each(clear)

  -- oldtest: Test_display_scroll_at_topline()
  it('scroll when modified at topline vim-patch:8.2.1488', function()
    local screen = Screen.new(20, 4)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true},
    })

    command([[call setline(1, repeat('a', 21))]])
    feed('O')
    screen:expect([[
      ^                    |
      aaaaaaaaaaaaaaaaaaaa|
      a                   |
      {1:-- INSERT --}        |
    ]])
  end)

  -- oldtest: Test_display_scroll_update_visual()
  it('scrolling when modified at topline in Visual mode vim-patch:8.2.4626', function()
    local screen = Screen.new(60, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true},  -- ModeMsg
      [2] = {background = Screen.colors.LightGrey},  -- Visual
      [3] = {background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue},  -- SignColumn
    })

    exec([[
      set scrolloff=0
      call setline(1, repeat(['foo'], 10))
      call sign_define('foo', { 'text': '>' })
      call sign_place(1, 'bar', 'foo', bufnr(), { 'lnum': 2 })
      call sign_place(2, 'bar', 'foo', bufnr(), { 'lnum': 1 })
      autocmd CursorMoved * if getcurpos()[1] == 2 | call sign_unplace('bar', { 'id': 1 }) | endif
    ]])
    feed('VG7kk')
    screen:expect([[
      {3:  }^f{2:oo}                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {1:-- VISUAL LINE --}                                           |
    ]])
  end)

  -- oldtest: Test_matchparen_clear_highlight()
  it('matchparen highlight is cleared when switching buffer', function()
    local screen = Screen.new(20, 5)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {background = Screen.colors.Cyan},
    })
    screen:attach()

    local screen1 = [[
      {1:^()}                  |
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]]
    local screen2 = [[
      ^aa                  |
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]]

    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      set hidden
      call setline(1, ['()'])
      normal 0
    ]])
    screen:expect(screen1)

    exec([[
      enew
      exe "normal iaa\<Esc>0"
    ]])
    screen:expect(screen2)

    feed('<C-^>')
    screen:expect(screen1)

    feed('<C-^>')
    screen:expect(screen2)
  end)

  local function run_test_display_lastline(euro)
    local screen = Screen.new(75, 10)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [2] = {bold = true, reverse = true},  -- StatusLine
      [3] = {reverse = true},  -- StatusLineNC
    })
    screen:attach()
    exec([[
      call setline(1, ['aaa', 'b'->repeat(200)])
      set display=truncate

      vsplit
      100wincmd <
    ]])
    local fillchar = '@'
    if euro then
      command('set fillchars=lastline:€')
      fillchar = '€'
    end
    screen:expect((([[
      ^a│aaa                                                                      |
      a│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      a│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      b│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                   |
      b│{1:~                                                                        }|
      b│{1:~                                                                        }|
      b│{1:~                                                                        }|
      {1:@}│{1:~                                                                        }|
      {2:< }{3:[No Name] [+]                                                            }|
                                                                                 |
    ]]):gsub('@', fillchar)))

    command('set display=lastline')
    screen:expect_unchanged()

    command('100wincmd >')
    screen:expect((([[
      ^aaa                                                                      │a|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb│a|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb│a|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                   │b|
      {1:~                                                                        }│b|
      {1:~                                                                        }│b|
      {1:~                                                                        }│b|
      {1:~                                                                        }│{1:@}|
      {2:[No Name] [+]                                                             }{3:<}|
                                                                                 |
    ]]):gsub('@', fillchar)))

    command('set display=truncate')
    screen:expect_unchanged()

    command('close')
    command('3split')
    screen:expect((([[
      ^aaa                                                                        |
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      {1:@@@                                                                        }|
      {2:[No Name] [+]                                                              }|
      aaa                                                                        |
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                         |
      {3:[No Name] [+]                                                              }|
                                                                                 |
    ]]):gsub('@', fillchar)))

    command('close')
    command('2vsplit')
    screen:expect((([[
      ^aa│aaa                                                                     |
      a │bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bb│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bb│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                |
      bb│{1:~                                                                       }|
      bb│{1:~                                                                       }|
      bb│{1:~                                                                       }|
      {1:@@}│{1:~                                                                       }|
      {2:<  }{3:[No Name] [+]                                                           }|
                                                                                 |
    ]]):gsub('@', fillchar)))
  end

  -- oldtest: Test_display_lastline()
  it('display "lastline" works correctly', function()
    run_test_display_lastline()
  end)
  it('display "lastline" works correctly with multibyte fillchar', function()
    run_test_display_lastline(true)
  end)
end)
