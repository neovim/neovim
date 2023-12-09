local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local exec = helpers.exec
local feed = helpers.feed

local expect_pos = function(row, col)
  return helpers.eq({row, col}, helpers.eval('[screenrow(), screencol()]'))
end

describe('Conceal', function()
  before_each(function()
    clear()
    command('set nohlsearch')
  end)

  -- oldtest: Test_conceal_two_windows()
  it('works', function()
    local screen = Screen.new(75, 12)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {bold = true, reverse = true},  -- StatusLine
      [2] = {reverse = true},  -- StatusLineNC, IncSearch
      [3] = {bold = true},  -- ModeMsg
    })
    screen:attach()
    exec([[
      let lines = ["one one one one one", "two |hidden| here", "three |hidden| three"]
      call setline(1, lines)
      syntax match test /|hidden|/ conceal
      set conceallevel=2
      set concealcursor=
      exe "normal /here\r"
      new
      call setline(1, lines)
      call setline(4, "Second window")
      syntax match test /|hidden|/ conceal
      set conceallevel=2
      set concealcursor=nc
      exe "normal /here\r"
    ]])

    -- Check that cursor line is concealed
    screen:expect([[
      one one one one one                                                        |
      two  ^here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      /here                                                                      |
    ]])

    -- Check that with concealed text vertical cursor movement is correct.
    feed('k')
    screen:expect([[
      one one one o^ne one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      /here                                                                      |
    ]])

    -- Check that with cursor line is not concealed
    feed('j')
    command('set concealcursor=')
    screen:expect([[
      one one one one one                                                        |
      two |hidden| ^here                                                          |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      /here                                                                      |
    ]])

    -- Check that with cursor line is not concealed when moving cursor down
    feed('j')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three |hidden^| three                                                       |
      Second window                                                              |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      /here                                                                      |
    ]])

    -- Check that with cursor line is not concealed when switching windows
    feed('<C-W><C-W>')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| ^here                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      /here                                                                      |
    ]])

    -- Check that with cursor line is only concealed in Normal mode
    command('set concealcursor=n')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  ^here                                                                  |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      /here                                                                      |
    ]])
    feed('a')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| h^ere                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      {3:-- INSERT --}                                                               |
    ]])
    feed('<Esc>/e')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| h{2:e}re                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      /e^                                                                         |
    ]])
    feed('<Esc>v')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| ^here                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      {3:-- VISUAL --}                                                               |
    ]])
    feed('<Esc>')

    -- Check that with cursor line is only concealed in Insert mode
    command('set concealcursor=i')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| ^here                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
                                                                                 |
    ]])
    feed('a')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  h^ere                                                                  |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      {3:-- INSERT --}                                                               |
    ]])
    feed('<Esc>/e')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| h{2:e}re                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      /e^                                                                         |
    ]])
    feed('<Esc>v')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| ^here                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      {3:-- VISUAL --}                                                               |
    ]])
    feed('<Esc>')

    -- Check that with cursor line is only concealed in Visual mode
    command('set concealcursor=v')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| ^here                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
                                                                                 |
    ]])
    feed('a')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| h^ere                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      {3:-- INSERT --}                                                               |
    ]])
    feed('<Esc>/e')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| h{2:e}re                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      /e^                                                                         |
    ]])
    feed('<Esc>v')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  ^here                                                                  |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      {3:-- VISUAL --}                                                               |
    ]])
    feed('<Esc>')

    -- Check moving the cursor while in insert mode.
    command('set concealcursor=')
    feed('a')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two |hidden| h^ere                                                          |
      three  three                                                               |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      {3:-- INSERT --}                                                               |
    ]])
    feed('<Down>')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  here                                                                  |
      three |hidden|^ three                                                       |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
      {3:-- INSERT --}                                                               |
    ]])
    feed('<Esc>')

    -- Check the "o" command
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  here                                                                  |
      three |hidden^| three                                                       |
      {0:~                                                                          }|
      {1:[No Name] [+]                                                              }|
                                                                                 |
    ]])
    feed('o')
    screen:expect([[
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      Second window                                                              |
      {0:~                                                                          }|
      {2:[No Name] [+]                                                              }|
      one one one one one                                                        |
      two  here                                                                  |
      three  three                                                               |
      ^                                                                           |
      {1:[No Name] [+]                                                              }|
      {3:-- INSERT --}                                                               |
    ]])
    feed('<Esc>')
  end)

  -- oldtest: Test_conceal_with_cursorcolumn()
  it('CursorColumn and ColorColumn on wrapped line', function()
    local screen = Screen.new(40, 10)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {background = Screen.colors.Grey90},  -- CursorColumn
      [2] = {background = Screen.colors.LightRed},  -- ColorColumn
    })
    screen:attach()
    -- Check that cursorcolumn and colorcolumn don't get broken in presence of
    -- wrapped lines containing concealed text
    -- luacheck: push ignore 613 (trailing whitespace in a string)
    exec([[
      let lines = ["one one one |hidden| one one one one one one one one",
            \ "two two two two |hidden| here two two",
            \ "three |hidden| three three three three three three three three"]
      call setline(1, lines)
      set wrap linebreak
      set showbreak=\ >>>\ 
      syntax match test /|hidden|/ conceal
      set conceallevel=2
      set concealcursor=
      exe "normal /here\r"
      set cursorcolumn
      set colorcolumn=50
    ]])
    -- luacheck: pop

    screen:expect([[
      one one one  one one one {1:o}ne            |
      {0: >>> }one {2:o}ne one one                    |
      two two two two |hidden| ^here two two   |
      three  three three three {1:t}hree          |
      {0: >>> }thre{2:e} three three three            |
      {0:~                                       }|*4
      /here                                   |
    ]])

    -- move cursor to the end of line (the cursor jumps to the next screen line)
    feed('$')
    screen:expect([[
      one one one  one one one one            |
      {0: >>> }one {2:o}ne one one                    |
      two two two two |hidden| here two tw^o   |
      three  three three three three          |
      {0: >>> }thre{2:e} three three three            |
      {0:~                                       }|*4
      /here                                   |
    ]])
  end)

  -- oldtest: Test_conceal_resize_term()
  it('resize editor', function()
    local screen = Screen.new(75, 6)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {foreground = Screen.colors.Blue},  -- Comment
    })
    screen:attach()
    exec([[
      call setline(1, '`one` `two` `three` `four` `five`, the backticks should be concealed')
      setl cocu=n cole=3
      syn region CommentCodeSpan matchgroup=Comment start=/`/ end=/`/ concealends
      normal fb
    ]])
    screen:expect([[
      one two three four five, the ^backticks should be concealed                 |
      {0:~                                                                          }|*4
                                                                                 |
    ]])

    screen:try_resize(75, 7)
    screen:expect([[
      one two three four five, the ^backticks should be concealed                 |
      {0:~                                                                          }|*5
                                                                                 |
    ]])
  end)

  -- oldtest: Test_conceal_linebreak()
  it('with linebreak', function()
    local screen = Screen.new(75, 8)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
    })
    screen:attach()
    exec([[
      let &wrap = v:true
      let &conceallevel = 2
      let &concealcursor = 'nc'
      let &linebreak = v:true
      let &showbreak = '+ '
      let line = 'a`a`a`a`'
          \ .. 'a'->repeat(&columns - 15)
          \ .. ' b`b`'
          \ .. 'b'->repeat(&columns - 10)
          \ .. ' cccccc'
      eval ['x'->repeat(&columns), '', line]->setline(1)
      syntax region CodeSpan matchgroup=Delimiter start=/\z(`\+\)/ end=/\z1/ concealends
    ]])
    screen:expect([[
      ^xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
                                                                                 |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa           |
      {0:+ }bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb      |
      {0:+ }cccccc                                                                   |
      {0:~                                                                          }|*2
                                                                                 |
    ]])
  end)

  -- Tests for correct display (cursor column position) with +conceal and tabulators.
  -- oldtest: Test_conceal_cursor_pos()
  it('cursor and column position with conceal and tabulators', function()
    exec([[
      let l = ['start:', '.concealed.     text', "|concealed|\ttext"]
      let l += ['', "\t.concealed.\ttext", "\t|concealed|\ttext", '']
      let l += [".a.\t.b.\t.c.\t.d.", "|a|\t|b|\t|c|\t|d|"]
      call append(0, l)
      call cursor(1, 1)
      " Conceal settings.
      set conceallevel=2
      set concealcursor=nc
      syntax match test /|/ conceal
    ]])
    feed('ztj')
    expect_pos(2, 1)
    -- We should end up in the same column when running these commands on the
    -- two lines.
    feed('ft')
    expect_pos(2, 17)
    feed('$')
    expect_pos(2, 20)
    feed('0j')
    expect_pos(3, 1)
    feed('ft')
    expect_pos(3, 17)
    feed('$')
    expect_pos(3, 20)
    feed('j0j')
    expect_pos(5, 8)
    -- Same for next test block.
    feed('ft')
    expect_pos(5, 25)
    feed('$')
    expect_pos(5, 28)
    feed('0j')
    expect_pos(6, 8)
    feed('ft')
    expect_pos(6, 25)
    feed('$')
    expect_pos(6, 28)
    feed('0j0j')
    expect_pos(8, 1)
    -- And check W with multiple tabs and conceals in a line.
    feed('W')
    expect_pos(8, 9)
    feed('W')
    expect_pos(8, 17)
    feed('W')
    expect_pos(8, 25)
    feed('$')
    expect_pos(8, 27)
    feed('0j')
    expect_pos(9, 1)
    feed('W')
    expect_pos(9, 9)
    feed('W')
    expect_pos(9, 17)
    feed('W')
    expect_pos(9, 25)
    feed('$')
    expect_pos(9, 26)
    command('set lbr')
    feed('$')
    expect_pos(9, 26)
    command('set list listchars=tab:>-')
    feed('0')
    expect_pos(9, 1)
    feed('W')
    expect_pos(9, 9)
    feed('W')
    expect_pos(9, 17)
    feed('W')
    expect_pos(9, 25)
    feed('$')
    expect_pos(9, 26)
  end)
end)
