local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed
local command = n.command

describe('display', function()
  before_each(clear)

  -- oldtest: Test_display_scroll_at_topline()
  it('scroll when modified at topline vim-patch:8.2.1488', function()
    local screen = Screen.new(20, 4)
    command([[call setline(1, repeat('a', 21))]])
    feed('O')
    screen:expect([[
      ^                    |
      aaaaaaaaaaaaaaaaaaaa|
      a                   |
      {5:-- INSERT --}        |
    ]])
  end)

  -- oldtest: Test_display_scroll_update_visual()
  it('scrolling when modified at topline in Visual mode vim-patch:8.2.4626', function()
    local screen = Screen.new(60, 8)
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
      {7:  }^f{17:oo}                                                       |
      {7:  }foo                                                       |*6
      {5:-- VISUAL LINE --}                                           |
    ]])
  end)

  -- oldtest: Test_display_scroll_setline()
  it('scrolling with sign_unplace() and setline() in CursorMoved', function()
    local screen = Screen.new(20, 15)
    exec([[
      setlocal scrolloff=5 signcolumn=yes
      call setline(1, range(1, 100))
      call sign_define('foo', #{text: '>'})
      call sign_place(1, 'bar', 'foo', bufnr(), #{lnum: 73})
      call sign_place(2, 'bar', 'foo', bufnr(), #{lnum: 74})
      call sign_place(3, 'bar', 'foo', bufnr(), #{lnum: 75})
      normal! G
      autocmd CursorMoved * if line('.') == 79
                        \ |   call sign_unplace('bar', #{id: 2})
                        \ |   call setline(80, repeat('foo', 15))
                        \ | endif
    ]])
    screen:expect([[
      {7:  }87                |
      {7:  }88                |
      {7:  }89                |
      {7:  }90                |
      {7:  }91                |
      {7:  }92                |
      {7:  }93                |
      {7:  }94                |
      {7:  }95                |
      {7:  }96                |
      {7:  }97                |
      {7:  }98                |
      {7:  }99                |
      {7:  }^100               |
                          |
    ]])
    feed('19k')
    screen:expect([[
      {7:> }75                |
      {7:  }76                |
      {7:  }77                |
      {7:  }78                |
      {7:  }79                |
      {7:  }80                |
      {7:  }^81                |
      {7:  }82                |
      {7:  }83                |
      {7:  }84                |
      {7:  }85                |
      {7:  }86                |
      {7:  }87                |
      {7:  }88                |
                          |
    ]])
    feed('k')
    screen:expect([[
      {7:> }75                |
      {7:  }76                |
      {7:  }77                |
      {7:  }78                |
      {7:  }79                |
      {7:  }^80                |
      {7:  }81                |
      {7:  }82                |
      {7:  }83                |
      {7:  }84                |
      {7:  }85                |
      {7:  }86                |
      {7:  }87                |
      {7:  }88                |
                          |
    ]])
    feed('k')
    screen:expect([[
      {7:  }74                |
      {7:> }75                |
      {7:  }76                |
      {7:  }77                |
      {7:  }78                |
      {7:  }^79                |
      {7:  }foofoofoofoofoofoo|*2
      {7:  }foofoofoo         |
      {7:  }81                |
      {7:  }82                |
      {7:  }83                |
      {7:  }84                |
      {7:  }85                |
                          |
    ]])
    feed('k')
    screen:expect([[
      {7:> }73                |
      {7:  }74                |
      {7:> }75                |
      {7:  }76                |
      {7:  }77                |
      {7:  }^78                |
      {7:  }79                |
      {7:  }foofoofoofoofoofoo|*2
      {7:  }foofoofoo         |
      {7:  }81                |
      {7:  }82                |
      {7:  }83                |
      {7:  }84                |
                          |
    ]])
  end)

  local function run_test_display_lastline(euro)
    local screen = Screen.new(75, 10)
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
      a│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*2
      b│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                   |
      b│{1:~                                                                        }|*3
      {1:@}│{1:~                                                                        }|
      {3:< }{2:[No Name] [+]                                                            }|
                                                                                 |
    ]]):gsub('@', fillchar)))

    command('set display=lastline')
    screen:expect_unchanged()

    command('100wincmd >')
    screen:expect((([[
      ^aaa                                                                      │a|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb│a|*2
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                   │b|
      {1:~                                                                        }│b|*3
      {1:~                                                                        }│{1:@}|
      {3:[No Name] [+]                                                             }{2:<}|
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
      {3:[No Name] [+]                                                              }|
      aaa                                                                        |
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*2
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                         |
      {2:[No Name] [+]                                                              }|
                                                                                 |
    ]]):gsub('@', fillchar)))

    command('close')
    command('2vsplit')
    screen:expect((([[
      ^aa│aaa                                                                     |
      a │bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bb│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bb│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                |
      bb│{1:~                                                                       }|*3
      {1:@@}│{1:~                                                                       }|
      {3:<  }{2:[No Name] [+]                                                           }|
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

  -- oldtest: Test_display_long_lastline()
  it('"lastline" shows correct text when end of wrapped line is deleted', function()
    local screen = Screen.new(35, 14)
    exec([[
      set display=lastline smoothscroll scrolloff=0
      call setline(1, [
        \'aaaaa'->repeat(150),
        \'bbbbb '->repeat(7) .. 'ccccc '->repeat(7) .. 'ddddd '->repeat(7)
      \])
    ]])
    feed('736|')
    screen:expect([[
      {1:<<<}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|*11
      ^aaaaaaaaaaaaaaa                    |
                                         |
    ]])
    -- The correct part of the last line is moved into view.
    feed('D')
    screen:expect([[
      {1:<<<}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|*10
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^a|
      bbbbb bbbbb bbbbb bbbbb bbbbb bb{1:@@@}|
                                         |
    ]])
    -- "w_skipcol" does not change because the topline is still long enough
    -- to maintain the current skipcol.
    feed('g04l11gkD')
    screen:expect([[
      {1:<<<}^a                               |
      bbbbb bbbbb bbbbb bbbbb bbbbb bbbbb|
       bbbbb ccccc ccccc ccccc ccccc cccc|
      c ccccc ccccc ddddd ddddd ddddd ddd|
      dd ddddd ddddd ddddd               |
      {1:~                                  }|*8
                                         |
    ]])
    -- "w_skipcol" is reset to bring the entire topline into view because
    -- the line length is now smaller than the current skipcol + marker.
    feed('x')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|*9
      aa^a                                |
      bbbbb bbbbb bbbbb bbbbb bbbbb bbbbb|
       bbbbb ccccc ccccc ccccc ccccc cccc|
      c ccccc ccccc ddddd ddddd ddddd {1:@@@}|
                                         |
    ]])
  end)

  -- oldtest: Test_display_cursor_long_line()
  it("correctly shows line that doesn't fit in the window", function()
    local screen = Screen.new(75, 8)
    exec([[
      call setline(1, ['a', 'b ' .. 'bbbbb'->repeat(150), 'c'])
      norm $j
    ]])
    screen:expect([[
      {1:<<<}bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*5
      b^b                                                                         |
                                                                                 |
    ]])
    -- FIXME: moving the cursor above the topline does not set w_skipcol
    -- correctly with cpo+=n and zero scrolloff (curs_columns() extra == 1).
    exec('set number cpo+=n scrolloff=0')
    feed('$0')
    screen:expect([[
      {1:<<<}b^bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*6
                                                                                 |
    ]])
    -- Going to the start of the line with "b" did not set w_skipcol correctly with 'smoothscroll'.
    exec('set smoothscroll')
    feed('$b')
    screen:expect([[
      {8:  2 }b ^bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*6
                                                                                 |
    ]])
    -- Same for "ge".
    feed('$ge')
    screen:expect([[
      {8:  2 }^b bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*6
                                                                                 |
    ]])
  end)

  -- oldtest: Test_change_wrapped_line_cpo_dollar()
  it('changing wrapped line with cpo+=$', function()
    local screen = Screen.new(45, 10)
    exec([[
      set cpoptions+=$ laststatus=0
      call setline(1, ['foo', 'bar',
            \ repeat('x', 25) .. '!!()!!' .. repeat('y', 25),
            \ 'FOO', 'BAR'])
      inoremap <F2> <Cmd>call setline(1, repeat('z', 30))<CR>
      inoremap <F3> <Cmd>call setline(1, 'foo')<CR>
      vsplit
      call cursor(3, 1)
    ]])

    local s1 = [[
      foo                   │foo                   |
      bar                   │bar                   |
      ^xxxxxxxxxxxxxxxxxxxxxx│xxxxxxxxxxxxxxxxxxxxxx|
      xxx!!()!!yyyyyyyyyyyyy│xxx!!()!!yyyyyyyyyyyyy|
      yyyyyyyyyyyy          │yyyyyyyyyyyy          |
      FOO                   │FOO                   |
      BAR                   │BAR                   |
      {1:~                     }│{1:~                     }|*2
                                                   |
    ]]
    screen:expect(s1)
    feed('ct!')
    local s2 = [[
      foo                   │foo                   |
      bar                   │bar                   |
      ^xxxxxxxxxxxxxxxxxxxxxx│!!()!!yyyyyyyyyyyyyyyy|
      xx$!!()!!yyyyyyyyyyyyy│yyyyyyyyy             |
      yyyyyyyyyyyy          │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|*2
      {5:-- INSERT --}                                 |
    ]]
    screen:expect(s2)
    feed('<F2>')
    screen:expect([[
      zzzzzzzzzzzzzzzzzzzzzz│zzzzzzzzzzzzzzzzzzzzzz|
      zzzzzzzz              │zzzzzzzz              |
      bar                   │bar                   |
      ^xxxxxxxxxxxxxxxxxxxxxx│!!()!!yyyyyyyyyyyyyyyy|
      xx$!!()!!yyyyyyyyyyyyy│yyyyyyyyy             |
      yyyyyyyyyyyy          │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|
      {5:-- INSERT --}                                 |
    ]])
    feed('<F3>')
    screen:expect(s2)
    feed('y')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      y^xxxxxxxxxxxxxxxxxxxxx│y!!()!!yyyyyyyyyyyyyyy|
      xx$!!()!!yyyyyyyyyyyyy│yyyyyyyyyy            |
      yyyyyyyyyyyy          │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|*2
      {5:-- INSERT --}                                 |
    ]])
    feed('y')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      yy^xxxxxxxxxxxxxxxxxxxx│yy!!()!!yyyyyyyyyyyyyy|
      xx$!!()!!yyyyyyyyyyyyy│yyyyyyyyyyy           |
      yyyyyyyyyyyy          │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|*2
      {5:-- INSERT --}                                 |
    ]])
    feed('<Esc>')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      y^y!!()!!yyyyyyyyyyyyyy│yy!!()!!yyyyyyyyyyyyyy|
      yyyyyyyyyyy           │yyyyyyyyyyy           |
      FOO                   │FOO                   |
      BAR                   │BAR                   |
      {1:~                     }│{1:~                     }|*3
                                                   |
    ]])

    command('silent undo')
    screen:expect(s1)
    command('source test/old/testdir/samples/matchparen.vim')
    feed('ct(')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      ^xxxxxxxxxxxxxxxxxxxxxx│()!!yyyyyyyyyyyyyyyyyy|
      xxx!$()!!yyyyyyyyyyyyy│yyyyyyy               |
      yyyyyyyyyyyy          │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|*2
      {5:-- INSERT --}                                 |
    ]])
    feed('y')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      y^xxxxxxxxxxxxxxxxxxxxx│y()!!yyyyyyyyyyyyyyyyy|
      xxx!$()!!yyyyyyyyyyyyy│yyyyyyyy              |
      yyyyyyyyyyyy          │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|*2
      {5:-- INSERT --}                                 |
    ]])
    feed('y')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      yy^xxxxxxxxxxxxxxxxxxxx│yy()!!yyyyyyyyyyyyyyyy|
      xxx!$()!!yyyyyyyyyyyyy│yyyyyyyyy             |
      yyyyyyyyyyyy          │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|*2
      {5:-- INSERT --}                                 |
    ]])
    feed('<Esc>')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      y^y()!!yyyyyyyyyyyyyyyy│yy()!!yyyyyyyyyyyyyyyy|
      yyyyyyyyy             │yyyyyyyyy             |
      FOO                   │FOO                   |
      BAR                   │BAR                   |
      {1:~                     }│{1:~                     }|*3
                                                   |
    ]])

    command('silent undo')
    screen:expect(s1)
    feed('f(azz<CR>zz<Esc>k0')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      ^xxxxxxxxxxxxxxxxxxxxxx│xxxxxxxxxxxxxxxxxxxxxx|
      xxx!!(zz              │xxx!!(zz              |
      zz)!!yyyyyyyyyyyyyyyyy│zz)!!yyyyyyyyyyyyyyyyy|
      yyyyyyyy              │yyyyyyyy              |
      FOO                   │FOO                   |
      BAR                   │BAR                   |
      {1:~                     }│{1:~                     }|
                                                   |
    ]])
    feed('ct(')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      ^xxxxxxxxxxxxxxxxxxxxxx│(zz                   |
      xxx!$(zz              │zz)!!yyyyyyyyyyyyyyyyy|
      zz)!!yyyyyyyyyyyyyyyyy│yyyyyyyy              |
      yyyyyyyy              │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|
      {5:-- INSERT --}                                 |
    ]])
    feed('y')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      y^xxxxxxxxxxxxxxxxxxxxx│y(zz                  |
      xxx!$(zz              │zz)!!yyyyyyyyyyyyyyyyy|
      zz)!!yyyyyyyyyyyyyyyyy│yyyyyyyy              |
      yyyyyyyy              │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|
      {5:-- INSERT --}                                 |
    ]])
    feed('y')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      yy^xxxxxxxxxxxxxxxxxxxx│yy(zz                 |
      xxx!$(zz              │zz)!!yyyyyyyyyyyyyyyyy|
      zz)!!yyyyyyyyyyyyyyyyy│yyyyyyyy              |
      yyyyyyyy              │FOO                   |
      FOO                   │BAR                   |
      BAR                   │{1:~                     }|
      {1:~                     }│{1:~                     }|
      {5:-- INSERT --}                                 |
    ]])
    feed('<Esc>')
    screen:expect([[
      foo                   │foo                   |
      bar                   │bar                   |
      y^y(zz                 │yy(zz                 |
      zz)!!yyyyyyyyyyyyyyyyy│zz)!!yyyyyyyyyyyyyyyyy|
      yyyyyyyy              │yyyyyyyy              |
      FOO                   │FOO                   |
      BAR                   │BAR                   |
      {1:~                     }│{1:~                     }|*2
                                                   |
    ]])
  end)
end)
