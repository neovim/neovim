local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local exec = t.exec
local feed = t.feed
local assert_alive = t.assert_alive

before_each(clear)

describe('smoothscroll', function()
  local screen

  before_each(function()
    screen = Screen.new(40, 12)
    screen:attach()
  end)

  -- oldtest: Test_CtrlE_CtrlY_stop_at_end()
  it('disabled does not break <C-E> and <C-Y> stop at end', function()
    exec([[
      enew
      call setline(1, ['one', 'two'])
      set number
    ]])
    feed('<C-Y>')
    screen:expect({ any = '{8:  1 }^one' })
    feed('<C-E><C-E><C-E>')
    screen:expect({ any = '{8:  2 }^two' })
  end)

  -- oldtest: Test_smoothscroll_CtrlE_CtrlY()
  it('works with <C-E> and <C-E>', function()
    exec([[
      call setline(1, [ 'line one', 'word '->repeat(20), 'line three', 'long word '->repeat(7), 'line', 'line', 'line', ])
      set smoothscroll scrolloff=5
      :5
    ]])
    local s1 = [[
      word word word word word word word word |*2
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      ^line                                    |
      line                                    |*2
      {1:~                                       }|*2
                                              |
    ]]
    local s2 = [[
      {1:<<<}d word word word word word word word |
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      ^line                                    |
      line                                    |*2
      {1:~                                       }|*3
                                              |
    ]]
    local s3 = [[
      {1:<<<}d word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      ^line                                    |
      line                                    |*2
      {1:~                                       }|*4
                                              |
    ]]
    local s4 = [[
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |*2
      ^line                                    |
      {1:~                                       }|*5
                                              |
    ]]
    local s5 = [[
      {1:<<<}d word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |*2
      ^line                                    |
      {1:~                                       }|*4
                                              |
    ]]
    local s6 = [[
      {1:<<<}d word word word word word word word |
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |*2
      ^line                                    |
      {1:~                                       }|*3
                                              |
    ]]
    local s7 = [[
      word word word word word word word word |*2
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |*2
      ^line                                    |
      {1:~                                       }|*2
                                              |
    ]]
    local s8 = [[
      line one                                |
      word word word word word word word word |*2
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |*2
      ^line                                    |
      {1:~                                       }|
                                              |
    ]]
    feed('<C-E>')
    screen:expect(s1)
    feed('<C-E>')
    screen:expect(s2)
    feed('<C-E>')
    screen:expect(s3)
    feed('<C-E>')
    screen:expect(s4)
    feed('<C-Y>')
    screen:expect(s5)
    feed('<C-Y>')
    screen:expect(s6)
    feed('<C-Y>')
    screen:expect(s7)
    feed('<C-Y>')
    screen:expect(s8)
    exec('set foldmethod=indent')
    -- move the cursor so we can reuse the same dumps
    feed('5G<C-E>')
    screen:expect(s1)
    feed('<C-E>')
    screen:expect(s2)
    feed('7G<C-Y>')
    screen:expect(s7)
    feed('<C-Y>')
    screen:expect(s8)
  end)

  -- oldtest: Test_smoothscroll_multibyte()
  it('works with multibyte characters', function()
    screen:try_resize(40, 6)
    exec([[
      set scrolloff=0 smoothscroll
      call setline(1, [repeat('ϛ', 45), repeat('2', 36)])
      exe "normal G35l\<C-E>k"
    ]])
    screen:expect([[
      ϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛϛ^ϛϛϛϛϛ|
      ϛϛϛϛϛ                                   |
      222222222222222222222222222222222222    |
      {1:~                                       }|*2
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_number()
  it("works 'number' and 'cpo'+=n", function()
    exec([[
      call setline(1, [ 'one ' .. 'word '->repeat(20), 'two ' .. 'long word '->repeat(7), 'line', 'line', 'line', ])
      set smoothscroll scrolloff=5
      set splitkeep=topline
      set number cpo+=n
      :3
      func g:DoRel()
        set number relativenumber scrolloff=0
        :%del
        call setline(1, [ 'one', 'very long text '->repeat(12), 'three', ])
        exe "normal 2Gzt\<C-E>"
      endfunc
    ]])
    screen:expect([[
      {8:  1 }one word word word word word word wo|
      rd word word word word word word word wo|
      rd word word word word word             |
      {8:  2 }two long word long word long word lo|
      ng word long word long word long word   |
      {8:  3 }^line                                |
      {8:  4 }line                                |
      {8:  5 }line                                |
      {1:~                                       }|*3
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
      {1:<<<}word word word word word word word wo|
      rd word word word word word             |
      {8:  2 }two long word long word long word lo|
      ng word long word long word long word   |
      {8:  3 }^line                                |
      {8:  4 }line                                |
      {8:  5 }line                                |
      {1:~                                       }|*4
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
      {1:<<<}word word word word word             |
      {8:  2 }two long word long word long word lo|
      ng word long word long word long word   |
      {8:  3 }^line                                |
      {8:  4 }line                                |
      {8:  5 }line                                |
      {1:~                                       }|*5
                                              |
    ]])
    exec('set cpo-=n')
    screen:expect([[
      {1:<<<}{8: }d word word word word word word     |
      {8:  2 }two long word long word long word lo|
      {8:    }ng word long word long word long wor|
      {8:    }d                                   |
      {8:  3 }^line                                |
      {8:  4 }line                                |
      {8:  5 }line                                |
      {1:~                                       }|*4
                                              |
    ]])
    feed('<C-Y>')
    screen:expect([[
      {1:<<<}{8: }rd word word word word word word wor|
      {8:    }d word word word word word word     |
      {8:  2 }two long word long word long word lo|
      {8:    }ng word long word long word long wor|
      {8:    }d                                   |
      {8:  3 }^line                                |
      {8:  4 }line                                |
      {8:  5 }line                                |
      {1:~                                       }|*3
                                              |
    ]])
    feed('<C-Y>')
    screen:expect([[
      {8:  1 }one word word word word word word wo|
      {8:    }rd word word word word word word wor|
      {8:    }d word word word word word word     |
      {8:  2 }two long word long word long word lo|
      {8:    }ng word long word long word long wor|
      {8:    }d                                   |
      {8:  3 }^line                                |
      {8:  4 }line                                |
      {8:  5 }line                                |
      {1:~                                       }|*2
                                              |
    ]])
    exec('botright split')
    feed('gg')
    screen:expect([[
      {8:  1 }one word word word word word word wo|
      {8:    }rd word word word word word word wor|
      {8:    }d word word word word word word     |
      {8:  2 }two long word long word long word{1:@@@}|
      {2:[No Name] [+]                           }|
      {8:  1 }^one word word word word word word wo|
      {8:    }rd word word word word word word wor|
      {8:    }d word word word word word word     |
      {8:  2 }two long word long word long word lo|
      {8:    }ng word long word long word long {1:@@@}|
      {3:[No Name] [+]                           }|
                                              |
    ]])

    feed('<C-E>')
    screen:expect([[
      {8:  1 }one word word word word word word wo|
      {8:    }rd word word word word word word wor|
      {8:    }d word word word word word word     |
      {8:  2 }two long word long word long word{1:@@@}|
      {2:[No Name] [+]                           }|
      {1:<<<}{8: }rd word word word word word word wor|
      {8:    }d word word word word word word^     |
      {8:  2 }two long word long word long word lo|
      {8:    }ng word long word long word long wor|
      {8:    }d                                   |
      {3:[No Name] [+]                           }|
                                              |
    ]])

    feed('<C-E>')
    screen:expect([[
      {8:  1 }one word word word word word word wo|
      {8:    }rd word word word word word word wor|
      {8:    }d word word word word word word     |
      {8:  2 }two long word long word long word{1:@@@}|
      {2:[No Name] [+]                           }|
      {1:<<<}{8: }d word word word word word word^     |
      {8:  2 }two long word long word long word lo|
      {8:    }ng word long word long word long wor|
      {8:    }d                                   |
      {8:  3 }line                                |
      {3:[No Name] [+]                           }|
                                              |
    ]])
    exec('close')
    exec('call DoRel()')
    screen:expect([[
      {8:2}{1:<<<}^ong text very long text very long te|
      {8:    }xt very long text very long text ver|
      {8:    }y long text very long text very long|
      {8:    } text very long text very long text |
      {8:  1 }three                               |
      {1:~                                       }|*6
      --No lines in buffer--                  |
    ]])
  end)

  -- oldtest: Test_smoothscroll_list()
  it('works with list mode', function()
    screen:try_resize(40, 8)
    exec([[
      set smoothscroll scrolloff=0
      set list
      call setline(1, [ 'one', 'very long text '->repeat(12), 'three', ])
      exe "normal 2Gzt\<C-E>"
    ]])
    screen:expect([[
      {1:<<<}t very long text very long text very |
      ^long text very long text very long text |
      very long text very long text very long |
      text very long text{1:-}                    |
      three                                   |
      {1:~                                       }|*2
                                              |
    ]])
    exec('set listchars+=precedes:#')
    screen:expect([[
      {1:#}ext very long text very long text very |
      ^long text very long text very long text |
      very long text very long text very long |
      text very long text{1:-}                    |
      three                                   |
      {1:~                                       }|*2
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_diff_mode()
  it('works with diff mode', function()
    screen:try_resize(40, 8)
    exec([[
      let text = 'just some text here'
      call setline(1, text)
      set smoothscroll
      diffthis
      new
      call setline(1, text)
      set smoothscroll
      diffthis
    ]])

    screen:expect([[
      {7:- }^just some text here                   |
      {1:~                                       }|*2
      {3:[No Name] [+]                           }|
      {7:- }just some text here                   |
      {1:~                                       }|
      {2:[No Name] [+]                           }|
                                              |
    ]])
    feed('<C-Y>')
    screen:expect_unchanged()
    feed('<C-E>')
    screen:expect_unchanged()
  end)

  -- oldtest: Test_smoothscroll_wrap_scrolloff_zero()
  it("works with zero 'scrolloff'", function()
    screen:try_resize(40, 8)
    exec([[
      call setline(1, ['Line' .. (' with some text'->repeat(7))]->repeat(7))
      set smoothscroll scrolloff=0 display=
      :3
    ]])
    screen:expect([[
      {1:<<<}h some text with some text           |
      Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
      ^Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
                                              |
    ]])
    feed('j')
    screen:expect_unchanged()
    -- moving cursor down - whole bottom line shows
    feed('<C-E>j')
    screen:expect_unchanged()
    feed('G')
    screen:expect_unchanged()
    feed('4<C-Y>G')
    screen:expect_unchanged()
    -- moving cursor up right after the <<< marker - no need to show whole line
    feed('2gj3l2k')
    screen:expect([[
      {1:<<<}^h some text with some text           |
      Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
      Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
                                              |
    ]])
    -- moving cursor up where the <<< marker is - whole top line shows
    feed('2j02k')
    screen:expect([[
      ^Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
      Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
      {1:@                                       }|
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_wrap_long_line()
  it('adjusts the cursor position in a long line', function()
    screen:try_resize(40, 6)
    exec([[
      call setline(1, ['one', 'two', 'Line' .. (' with lots of text'->repeat(30)) .. ' end', 'four'])
      set smoothscroll scrolloff=0
      normal 3G10|zt
    ]])
    -- scrolling up, cursor moves screen line down
    screen:expect([[
      Line with^ lots of text with lots of text|
       with lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text with lots of te|
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
      {1:<<<}th lot^s of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text with lots of te|
      xt with lots of text with lots of text w|
                                              |
    ]])
    feed('5<C-E>')
    screen:expect([[
      {1:<<<} lots ^of text with lots of text with |
      lots of text with lots of text with lots|
       of text with lots of text with lots of |
      text with lots of text with lots of text|
       with lots of text with lots of text wit|
                                              |
    ]])
    -- scrolling down, cursor moves screen line up
    feed('5<C-Y>')
    screen:expect([[
      {1:<<<}th lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text with lots of te|
      xt with l^ots of text with lots of text w|
                                              |
    ]])
    feed('<C-Y>')
    screen:expect([[
      Line with lots of text with lots of text|
       with lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text wi^th lots of text with lots of te|
                                              |
    ]])
    -- 'scrolloff' set to 1, scrolling up, cursor moves screen line down
    exec('set scrolloff=1')
    feed('10|<C-E>')
    screen:expect([[
      {1:<<<}th lots of text with lots of text wit|
      h lots of^ text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text with lots of te|
      xt with lots of text with lots of text w|
                                              |
    ]])
    -- 'scrolloff' set to 1, scrolling down, cursor moves screen line up
    feed('<C-E>gjgj<C-Y>')
    screen:expect([[
      {1:<<<}th lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text wi^th lots of text with lots of te|
      xt with lots of text with lots of text w|
                                              |
    ]])
    -- 'scrolloff' set to 2, scrolling up, cursor moves screen line down
    exec('set scrolloff=2')
    feed('10|<C-E>')
    screen:expect([[
      {1:<<<}th lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of tex^t with lots of text with lots o|
      f text with lots of text with lots of te|
      xt with lots of text with lots of text w|
                                              |
    ]])
    -- 'scrolloff' set to 2, scrolling down, cursor moves screen line up
    feed('<C-E>gj<C-Y>')
    screen:expect_unchanged()
    -- 'scrolloff' set to 0, move cursor down one line. Cursor should move properly,
    -- and since this is a really long line, it will be put on top of the screen.
    exec('set scrolloff=0')
    feed('0j')
    screen:expect([[
      {1:<<<}th lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text end            |
      ^four                                    |
                                              |
    ]])
    -- Test zt/zz/zb that they work properly when a long line is above it
    feed('zt')
    screen:expect([[
      ^four                                    |
      {1:~                                       }|*4
                                              |
    ]])
    feed('zz')
    screen:expect([[
      {1:<<<}of text with lots of text with lots o|
      f text with lots of text end            |
      ^four                                    |
      {1:~                                       }|*2
                                              |
    ]])
    feed('zb')
    screen:expect([[
      {1:<<<}th lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text end            |
      ^four                                    |
                                              |
    ]])
    -- Repeat the step and move the cursor down again.
    -- This time, use a shorter long line that is barely long enough to span more
    -- than one window. Note that the cursor is at the bottom this time because
    -- Vim prefers to do so if we are scrolling a few lines only.
    exec(
      "call setline(1, ['one', 'two', 'Line' .. (' with lots of text'->repeat(10)) .. ' end', 'four'])"
    )
    -- Currently visible lines were replaced, test that the lines and cursor
    -- are correctly displayed.
    screen:expect_unchanged()
    feed('3Gztj')
    screen:expect_unchanged()
    -- Repeat the step but this time start it when the line is smooth-scrolled by
    -- one line. This tests that the offset calculation is still correct and
    -- still end up scrolling down to the next line with cursor at bottom of
    -- screen.
    feed('3Gzt<C-E>j')
    screen:expect([[
      {1:<<<}th lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text end            |
      fou^r                                    |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_one_long_line()
  it('scrolls correctly when moving the cursor', function()
    screen:try_resize(40, 6)
    exec([[
      call setline(1, 'with lots of text '->repeat(7))
      set smoothscroll scrolloff=0
    ]])
    local s1 = [[
      ^with lots of text with lots of text with|
       lots of text with lots of text with lot|
      s of text with lots of text with lots of|
       text                                   |
      {1:~                                       }|
                                              |
    ]]
    screen:expect(s1)
    feed('<C-E>')
    screen:expect([[
      {1:<<<}ts of text with lots of text with lot|
      ^s of text with lots of text with lots of|
       text                                   |
      {1:~                                       }|*2
                                              |
    ]])
    feed('0')
    screen:expect(s1)
  end)

  -- oldtest: Test_smoothscroll_long_line_showbreak()
  it('cursor is not one screen line too far down', function()
    screen:try_resize(40, 6)
    -- a line that spans four screen lines
    exec("call setline(1, 'with lots of text in one line '->repeat(6))")
    exec('set smoothscroll scrolloff=0 showbreak=+++\\ ')
    local s1 = [[
      ^with lots of text in one line with lots |
      {1:+++ }of text in one line with lots of tex|
      {1:+++ }t in one line with lots of text in o|
      {1:+++ }ne line with lots of text in one lin|
      {1:+++ }e with lots of text in one line     |
                                              |
    ]]
    screen:expect(s1)
    feed('<C-E>')
    screen:expect([[
      {1:+++ }^of text in one line with lots of tex|
      {1:+++ }t in one line with lots of text in o|
      {1:+++ }ne line with lots of text in one lin|
      {1:+++ }e with lots of text in one line     |
      {1:~                                       }|
                                              |
    ]])
    feed('0')
    screen:expect(s1)
  end)

  -- oldtest: Test_smoothscroll_marker_over_double_width_dump()
  it('marker is drawn over double-width char correctly', function()
    screen:try_resize(40, 6)
    exec([[
      call setline(1, 'a'->repeat(&columns) .. '口'->repeat(10))
      setlocal smoothscroll
    ]])
    screen:expect([[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      口口口口口口口口口口                    |
      {1:~                                       }|*3
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
      {1:<<<} 口口口口口口口^口                    |
      {1:~                                       }|*4
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_zero_width()
  it('does not divide by zero with a narrow window', function()
    screen:try_resize(12, 2)
    exec([[
      call setline(1, ['a'->repeat(100)])
      set wrap smoothscroll number laststatus=0
      wincmd v
      wincmd v
      wincmd v
      wincmd v
    ]])
    screen:expect([[
      {8:  1^ }│{8: }│{8: }│{8: }│{8: }|
                  |
    ]])
    feed('llllllllll<C-W>o')
    screen:expect([[
      {1:<<<}{8: }aa^aaaaaa|
                  |
    ]])
  end)

  -- oldtest: Test_smoothscroll_ins_lines()
  it('does not unnecessarily insert lines', function()
    screen:try_resize(40, 6)
    exec([=[
      set wrap smoothscroll scrolloff=0 conceallevel=2 concealcursor=nc
      call setline(1, [
        \'line one' .. 'with lots of text in one line '->repeat(2),
        \'line two',
        \'line three',
        \'line four',
        \'line five'
      \])
    ]=])
    feed('<C-E>gjgk')
    screen:expect([[
      {1:<<<}lots of text in one line^             |
      line two                                |
      line three                              |
      line four                               |
      line five                               |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_cursormoved_line()
  it('does not place the cursor in the command line', function()
    screen:try_resize(40, 6)
    exec([=[
      set smoothscroll
      call setline(1, [
        \'',
        \'_'->repeat(&lines * &columns),
        \(('_')->repeat(&columns - 2) .. 'xxx')->repeat(2)
      \])
      autocmd CursorMoved * eval [line('w0'), line('w$')]
      call search('xxx')
    ]=])
    screen:expect([[
      {1:<<<}_____________________________________|
      ________________________________________|
      ______________________________________^xx|
      x______________________________________x|
      xx                                      |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_eob()
  it('does not scroll halfway at end of buffer', function()
    screen:try_resize(40, 10)
    exec([[
      set smoothscroll
      call setline(1, ['']->repeat(100))
      norm G
    ]])
    -- does not scroll halfway when scrolling to end of buffer
    screen:expect([[
                                              |*8
      ^                                        |
                                              |
    ]])
    exec("call setline(92, 'a'->repeat(100))")
    feed('<C-L><C-B>G')
    -- cursor is not placed below window
    screen:expect([[
      {1:<<<}aaaaaaaaaaaaaaaaa                    |
                                              |*7
      ^                                        |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_incsearch()
  it('does not reset skipcol when doing incremental search on the same word', function()
    screen:try_resize(40, 8)
    exec([[
      set smoothscroll number scrolloff=0 incsearch
      call setline(1, repeat([''], 20))
      call setline(11, repeat('a', 100))
      call setline(14, 'bbbb')
    ]])
    feed('/b')
    screen:expect([[
      {1:<<<}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaa        |
      {8: 12 }                                    |
      {8: 13 }                                    |
      {8: 14 }{2:b}{10:bbb}                                |
      {8: 15 }                                    |
      {8: 16 }                                    |
      {8: 17 }                                    |
      /b^                                      |
    ]])
    feed('b')
    screen:expect([[
      {1:<<<}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaa        |
      {8: 12 }                                    |
      {8: 13 }                                    |
      {8: 14 }{2:bb}{10:bb}                                |
      {8: 15 }                                    |
      {8: 16 }                                    |
      {8: 17 }                                    |
      /bb^                                     |
    ]])
    feed('b')
    screen:expect([[
      {1:<<<}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaa        |
      {8: 12 }                                    |
      {8: 13 }                                    |
      {8: 14 }{2:bbb}b                                |
      {8: 15 }                                    |
      {8: 16 }                                    |
      {8: 17 }                                    |
      /bbb^                                    |
    ]])
    feed('b')
    screen:expect([[
      {1:<<<}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaa        |
      {8: 12 }                                    |
      {8: 13 }                                    |
      {8: 14 }{2:bbbb}                                |
      {8: 15 }                                    |
      {8: 16 }                                    |
      {8: 17 }                                    |
      /bbbb^                                   |
    ]])
  end)

  -- oldtest: Test_smoothscroll_multi_skipcol()
  it('scrolling multiple lines and stopping at non-zero skipcol', function()
    screen:try_resize(40, 10)
    exec([[
      setlocal cursorline scrolloff=0 smoothscroll
      call setline(1, repeat([''], 8))
      call setline(3, repeat('a', 50))
      call setline(4, repeat('a', 50))
      call setline(7, 'bbb')
      call setline(8, 'ccc')
      redraw
    ]])
    screen:expect([[
      {21:^                                        }|
                                              |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaa                              |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaa                              |
                                              |*2
      bbb                                     |
                                              |
    ]])
    feed('3<C-E>')
    screen:expect([[
      {1:<<<}{21:aaaaaa^a                              }|
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaa                              |
                                              |*2
      bbb                                     |
      ccc                                     |
      {1:~                                       }|*2
                                              |
    ]])
    feed('2<C-E>')
    screen:expect([[
      {1:<<<}{21:aaaaaa^a                              }|
                                              |*2
      bbb                                     |
      ccc                                     |
      {1:~                                       }|*4
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_zero_width_scroll_cursor_bot()
  it('does not divide by zero in zero-width window', function()
    screen:try_resize(40, 19)
    exec([[
      silent normal yy
      silent normal 19p
      set cpoptions+=n
      vsplit
      vertical resize 0
      set foldcolumn=1
      set number
      set smoothscroll
      silent normal 20G
    ]])
    screen:expect([[
      {8: }│                                      |
      {1:@}│                                      |*15
      {1:^@}│                                      |
      {3:< }{2:[No Name] [+]                         }|
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_cursor_top()
  it('resets skipcol when scrolling cursor to top', function()
    screen:try_resize(40, 12)
    exec([[
      set smoothscroll scrolloff=2
      new | 11resize | wincmd j
      call setline(1, ['line1', 'line2', 'line3'->repeat(20), 'line4'])
      exe "norm G3\<C-E>k"
    ]])
    screen:expect([[
                                              |
      {2:[No Name]                               }|
      line1                                   |
      line2                                   |
      ^line3line3line3line3line3line3line3line3|
      line3line3line3line3line3line3line3line3|
      line3line3line3line3                    |
      line4                                   |
      {1:~                                       }|*2
      {3:[No Name] [+]                           }|
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_crash()
  it('does not crash with small window and cpo+=n', function()
    screen:try_resize(40, 12)
    exec([[
      20 new
      vsp
      put =repeat('aaaa', 20)
      set nu fdc=1  smoothscroll cpo+=n
      vert resize 0
      exe "norm! 0\<c-e>"
    ]])
    feed('2<C-E>')
    assert_alive()
  end)

  it('works with virt_lines above and below', function()
    screen:try_resize(55, 7)
    exec([=[
      call setline(1, ['Line' .. (' with some text'->repeat(7))]->repeat(3))
      set smoothscroll
      let ns = nvim_create_namespace('')
      call nvim_buf_set_extmark(0, ns, 0, 0, {'virt_lines':[[['virt_below1']]]})
      call nvim_buf_set_extmark(0, ns, 1, 0, {'virt_lines':[[['virt_above1']]],'virt_lines_above':1})
      call nvim_buf_set_extmark(0, ns, 1, 0, {'virt_lines':[[['virt_below2']]]})
      call nvim_buf_set_extmark(0, ns, 2, 0, {'virt_lines':[[['virt_above2']]],'virt_lines_above':1})
      norm ggL
    ]=])
    screen:expect([[
      Line with some text with some text with some text with |
      some text with some text with some text with some text |
      virt_below1                                            |
      virt_above1                                            |
      ^Line with some text with some text with some text with |
      some text with some text with some text with some text |
                                                             |
    ]])
    feed('<C-E>')
    screen:expect([[
      {1:<<<}e text with some text with some text with some text |
      virt_below1                                            |
      virt_above1                                            |
      ^Line with some text with some text with some text with |
      some text with some text with some text with some text |
      virt_below2                                            |
                                                             |
    ]])
    feed('<C-E>')
    screen:expect([[
      virt_below1                                            |
      virt_above1                                            |
      ^Line with some text with some text with some text with |
      some text with some text with some text with some text |
      virt_below2                                            |
      virt_above2                                            |
                                                             |
    ]])
    feed('<C-E>')
    screen:expect([[
      virt_above1                                            |
      ^Line with some text with some text with some text with |
      some text with some text with some text with some text |
      virt_below2                                            |
      virt_above2                                            |
      Line with some text with some text with some text wi{1:@@@}|
                                                             |
    ]])
    feed('<C-E>')
    screen:expect([[
      ^Line with some text with some text with some text with |
      some text with some text with some text with some text |
      virt_below2                                            |
      virt_above2                                            |
      Line with some text with some text with some text with |
      some text with some text with some text with some text |
                                                             |
    ]])
    feed('<C-E>')
    screen:expect([[
      {1:<<<}e text with some text with some text with some tex^t |
      virt_below2                                            |
      virt_above2                                            |
      Line with some text with some text with some text with |
      some text with some text with some text with some text |
      {1:~                                                      }|
                                                             |
    ]])
  end)

  it('works in Insert mode at bottom of window', function()
    screen:try_resize(40, 9)
    exec([[
      call setline(1, repeat([repeat('A very long line ...', 10)], 5))
      set wrap smoothscroll scrolloff=0
    ]])
    feed('Go123456789<CR>')
    screen:expect([[
      {1:<<<}ery long line ...A very long line ...|
      A very long line ...A very long line ...|*5
      123456789                               |
      ^                                        |
      {5:-- INSERT --}                            |
    ]])
  end)

  it('<<< marker shows with tabline, winbar and splits', function()
    screen:try_resize(40, 12)
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.Blue1, bold = true },
      [2] = { reverse = true },
      [3] = { bold = true, reverse = true },
      [4] = { background = Screen.colors.LightMagenta },
      [5] = { bold = true },
      [31] = { foreground = Screen.colors.Fuchsia, bold = true },
    })
    exec([[
      call setline(1, ['Line' .. (' with some text'->repeat(7))]->repeat(7))
      set smoothscroll scrolloff=0
      norm sj
    ]])
    screen:expect([[
      {1:<<<}e text with some text with some text |
      with some text with some text           |
      Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
      {2:[No Name] [+]                           }|
      {1:<<<}e text with some text with some text |
      ^with some text with some text           |
      Line with some text with some text with |
      some text with some text with some te{1:@@@}|
      {3:[No Name] [+]                           }|
                                              |
    ]])
    exec('set showtabline=2')
    feed('<C-E>')
    screen:expect([[
      {5: }{31:2}{5:+ [No Name] }{2:                          }|
      {1:<<<}e text with some text with some text |
      with some text with some text           |
      Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
      {2:[No Name] [+]                           }|
      {1:<<<}e text with some text with some text |
      ^with some text with some text           |
      Line with some text with some text wi{1:@@@}|
      {3:[No Name] [+]                           }|
                                              |
    ]])
    exec('set winbar=winbar')
    feed('<C-w>k<C-E>')
    screen:expect([[
      {5: }{31:2}{5:+ [No Name] }{2:                          }|
      {5:winbar                                  }|
      {1:<<<}e text with some text with some text |
      ^with some text with some text           |
      Line with some text with some text with |
      some text with some text with some te{1:@@@}|
      {3:[No Name] [+]                           }|
      {5:winbar                                  }|
      {1:<<<}e text with some text with some text |
      with some text with some text           |
      {2:[No Name] [+]                           }|
                                              |
    ]])
  end)

  it('works with very long line', function()
    exec([[
      edit test/functional/fixtures/bigfile_oneline.txt
      setlocal smoothscroll number
    ]])
    screen:expect([[
      {8:  1 }^0000;<control>;Cc;0;BN;;;;;N;NULL;;;|
      {8:    }; 0001;<control>;Cc;0;BN;;;;;N;START|
      {8:    } OF HEADING;;;; 0002;<control>;Cc;0;|
      {8:    }BN;;;;;N;START OF TEXT;;;; 0003;<con|
      {8:    }trol>;Cc;0;BN;;;;;N;END OF TEXT;;;; |
      {8:    }0004;<control>;Cc;0;BN;;;;;N;END OF |
      {8:    }TRANSMISSION;;;; 0005;<control>;Cc;0|
      {8:    };BN;;;;;N;ENQUIRY;;;; 0006;<control>|
      {8:    };Cc;0;BN;;;;;N;ACKNOWLEDGE;;;; 0007;|
      {8:    }<control>;Cc;0;BN;;;;;N;BELL;;;; 000|
      {8:    }8;<control>;Cc;0;BN;;;;;N;BACKSPACE;|
                                              |
    ]])
    feed('j')
    screen:expect([[
      {1:<<<}{8: }CJK COMPATIBILITY IDEOGRAPH-2F91F;Lo|
      {8:    };0;L;243AB;;;;N;;;;; 2F920;CJK COMPA|
      {8:    }TIBILITY IDEOGRAPH-2F920;Lo;0;L;7228|
      {8:    };;;;N;;;;; 2F921;CJK COMPATIBILITY I|
      {8:    }DEOGRAPH-2F921;Lo;0;L;7235;;;;N;;;;;|
      {8:    } 2F922;CJK COMPATIBILITY IDEOGRAPH-2|
      {8:    }F922;Lo;0;L;7250;;;;N;;;;;          |
      {8:  2 }^2F923;CJK COMPATIBILITY IDEOGRAPH-2F|
      {8:    }923;Lo;0;L;24608;;;;N;;;;;          |
      {8:  3 }2F924;CJK COMPATIBILITY IDEOGRAPH-2F|
      {8:    }924;Lo;0;L;7280;;;;N;;;;;           |
                                              |
    ]])
  end)
end)
