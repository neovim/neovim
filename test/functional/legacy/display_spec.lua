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
    screen:attach()

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
    screen:attach()

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

  local function run_test_display_lastline(euro)
    local screen = Screen.new(75, 10)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [2] = { bold = true, reverse = true }, -- StatusLine
      [3] = { reverse = true }, -- StatusLineNC
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
      a│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*2
      b│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                   |
      b│{1:~                                                                        }|*3
      {1:@}│{1:~                                                                        }|
      {2:< }{3:[No Name] [+]                                                            }|
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
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*2
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
      bb│{1:~                                                                       }|*3
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

  -- oldtest: Test_display_long_lastline()
  it('"lastline" shows correct text when end of wrapped line is deleted', function()
    local screen = Screen.new(35, 14)
    screen:attach()
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
    screen:attach()
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
end)
