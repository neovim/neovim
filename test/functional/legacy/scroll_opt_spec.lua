local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed

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
    screen:expect({any = "  1 ^one"})
    feed('<C-E><C-E><C-E>')
    screen:expect({any = "  2 ^two"})
  end)

  -- oldtest: Test_smoothscroll_CtrlE_CtrlY()
  it('works with <C-E> and <C-E>', function()
    exec([[
      call setline(1, [ 'line one', 'word '->repeat(20), 'line three', 'long word '->repeat(7), 'line', 'line', 'line', ])
      set smoothscroll scrolloff=5
      :5
    ]])
    local s1 = [[
      word word word word word word word word |
      word word word word word word word word |
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      ^line                                    |
      line                                    |
      line                                    |
      ~                                       |
      ~                                       |
                                              |
    ]]
    local s2 = [[
      <<<d word word word word word word word |
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      ^line                                    |
      line                                    |
      line                                    |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]]
    local s3 = [[
      <<<d word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      ^line                                    |
      line                                    |
      line                                    |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]]
    local s4 = [[
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |
      line                                    |
      ^line                                    |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]]
    local s5 = [[
      <<<d word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |
      line                                    |
      ^line                                    |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]]
    local s6 = [[
      <<<d word word word word word word word |
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |
      line                                    |
      ^line                                    |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]]
    local s7 = [[
      word word word word word word word word |
      word word word word word word word word |
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |
      line                                    |
      ^line                                    |
      ~                                       |
      ~                                       |
                                              |
    ]]
    local s8 = [[
      line one                                |
      word word word word word word word word |
      word word word word word word word word |
      word word word word                     |
      line three                              |
      long word long word long word long word |
      long word long word long word           |
      line                                    |
      line                                    |
      ^line                                    |
      ~                                       |
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
      ~                                       |
      ~                                       |
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
        1 one word word word word word word wo|
      rd word word word word word word word wo|
      rd word word word word word             |
        2 two long word long word long word lo|
      ng word long word long word long word   |
        3 ^line                                |
        4 line                                |
        5 line                                |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
      <<<word word word word word word word wo|
      rd word word word word word             |
        2 two long word long word long word lo|
      ng word long word long word long word   |
        3 ^line                                |
        4 line                                |
        5 line                                |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
      <<<word word word word word             |
        2 two long word long word long word lo|
      ng word long word long word long word   |
        3 ^line                                |
        4 line                                |
        5 line                                |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
    exec('set cpo-=n')
    screen:expect([[
      <<< d word word word word word word     |
        2 two long word long word long word lo|
          ng word long word long word long wor|
          d                                   |
        3 ^line                                |
        4 line                                |
        5 line                                |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
    feed('<C-Y>')
    screen:expect([[
      <<< rd word word word word word word wor|
          d word word word word word word     |
        2 two long word long word long word lo|
          ng word long word long word long wor|
          d                                   |
        3 ^line                                |
        4 line                                |
        5 line                                |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
    feed('<C-Y>')
    screen:expect([[
        1 one word word word word word word wo|
          rd word word word word word word wor|
          d word word word word word word     |
        2 two long word long word long word lo|
          ng word long word long word long wor|
          d                                   |
        3 ^line                                |
        4 line                                |
        5 line                                |
      ~                                       |
      ~                                       |
                                              |
    ]])
    exec('botright split')
    feed('gg')
    screen:expect([[
        1 one word word word word word word wo|
          rd word word word word word word wor|
          d word word word word word word     |
        2 two long word long word long word@@@|
      [No Name] [+]                           |
        1 ^one word word word word word word wo|
          rd word word word word word word wor|
          d word word word word word word     |
        2 two long word long word long word lo|
          ng word long word long word long @@@|
      [No Name] [+]                           |
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
        1 one word word word word word word wo|
          rd word word word word word word wor|
          d word word word word word word     |
        2 two long word long word long word@@@|
      [No Name] [+]                           |
      <<< rd word word word word word word wor|
          d word word word word word word^     |
        2 two long word long word long word lo|
          ng word long word long word long wor|
          d                                   |
      [No Name] [+]                           |
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
        1 one word word word word word word wo|
          rd word word word word word word wor|
          d word word word word word word     |
        2 two long word long word long word@@@|
      [No Name] [+]                           |
      <<< d word word word word word word^     |
        2 two long word long word long word lo|
          ng word long word long word long wor|
          d                                   |
        3 line                                |
      [No Name] [+]                           |
                                              |
    ]])
    exec('close')
    exec('call DoRel()')
    screen:expect([[
      2<<<^ong text very long text very long te|
          xt very long text very long text ver|
          y long text very long text very long|
           text very long text very long text |
        1 three                               |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      --No lines in buffer--                  |
    ]])
  end)

  -- oldtest: Test_smoothscroll_list()
  it("works with list mode", function()
    screen:try_resize(40, 8)
    exec([[
      set smoothscroll scrolloff=0
      set list
      call setline(1, [ 'one', 'very long text '->repeat(12), 'three', ])
      exe "normal 2Gzt\<C-E>"
    ]])
    screen:expect([[
      <<<t very long text very long text very |
      ^long text very long text very long text |
      very long text very long text very long |
      text very long text-                    |
      three                                   |
      ~                                       |
      ~                                       |
                                              |
    ]])
    exec('set listchars+=precedes:#')
    screen:expect([[
      #ext very long text very long text very |
      ^long text very long text very long text |
      very long text very long text very long |
      text very long text-                    |
      three                                   |
      ~                                       |
      ~                                       |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_diff_mode()
  it("works with diff mode", function()
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
      - ^just some text here                   |
      ~                                       |
      ~                                       |
      [No Name] [+]                           |
      - just some text here                   |
      ~                                       |
      [No Name] [+]                           |
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
      <<<h some text with some text           |
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
      <<<^h some text with some text           |
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
      @                                       |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_wrap_long_line()
  it("adjusts the cursor position in a long line", function()
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
      <<<th lot^s of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text with lots of te|
      xt with lots of text with lots of text w|
                                              |
    ]])
    feed('5<C-E>')
    screen:expect([[
      <<< lots ^of text with lots of text with |
      lots of text with lots of text with lots|
       of text with lots of text with lots of |
      text with lots of text with lots of text|
       with lots of text with lots of text wit|
                                              |
    ]])
    -- scrolling down, cursor moves screen line up
    feed('5<C-Y>')
    screen:expect([[
      <<<th lots of text with lots of text wit|
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
      <<<th lots of text with lots of text wit|
      h lots of^ text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text with lots of te|
      xt with lots of text with lots of text w|
                                              |
    ]])
    -- 'scrolloff' set to 1, scrolling down, cursor moves screen line up
    feed('<C-E>gjgj<C-Y>')
    screen:expect([[
      <<<th lots of text with lots of text wit|
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
      <<<th lots of text with lots of text wit|
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
      <<<th lots of text with lots of text wit|
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
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
    feed('zz')
    screen:expect([[
      <<<of text with lots of text with lots o|
      f text with lots of text end            |
      ^four                                    |
      ~                                       |
      ~                                       |
                                              |
    ]])
    feed('zb')
    screen:expect([[
      <<<th lots of text with lots of text wit|
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
    exec("call setline(1, ['one', 'two', 'Line' .. (' with lots of text'->repeat(10)) .. ' end', 'four'])")
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
      <<<th lots of text with lots of text wit|
      h lots of text with lots of text with lo|
      ts of text with lots of text with lots o|
      f text with lots of text end            |
      fou^r                                    |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_one_long_line()
  it("scrolls correctly when moving the cursor", function()
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
      ~                                       |
                                              |
    ]]
    screen:expect(s1)
    feed('<C-E>')
    screen:expect([[
      <<<ts of text with lots of text with lot|
      ^s of text with lots of text with lots of|
       text                                   |
      ~                                       |
      ~                                       |
                                              |
    ]])
    feed('0')
    screen:expect(s1)
  end)

  -- oldtest: Test_smoothscroll_long_line_showbreak()
  it("cursor is not one screen line too far down", function()
    screen:try_resize(40, 6)
    -- a line that spans four screen lines
    exec("call setline(1, 'with lots of text in one line '->repeat(6))")
    exec('set smoothscroll scrolloff=0 showbreak=+++\\ ')
    local s1 = [[
      ^with lots of text in one line with lots |
      +++ of text in one line with lots of tex|
      +++ t in one line with lots of text in o|
      +++ ne line with lots of text in one lin|
      +++ e with lots of text in one line     |
                                              |
    ]]
    screen:expect(s1)
    feed('<C-E>')
    screen:expect([[
      +++ ^of text in one line with lots of tex|
      +++ t in one line with lots of text in o|
      +++ ne line with lots of text in one lin|
      +++ e with lots of text in one line     |
      ~                                       |
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
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
    feed('<C-E>')
    screen:expect([[
      <<< 口口口口口口口^口                    |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_zero_width()
  it("does not divide by zero with a narrow window", function()
    screen:try_resize(12, 2)
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.Brown},
      [2] = {foreground = Screen.colors.Blue1, bold = true},
    })
    exec([[
      call setline(1, ['a'->repeat(100)])
      set wrap smoothscroll number laststatus=0
      wincmd v
      wincmd v
      wincmd v
      wincmd v
    ]])
    screen:expect([[
      {1:  1^ }│{1: }│{1: }│{1: }│{1: }|
                  |
    ]])
    feed('llllllllll<C-W>o')
    screen:expect([[
      {2:<<<}{1: }aa^aaaaaa|
                  |
    ]])
  end)

  -- oldtest: Test_smoothscroll_ins_lines()
  it("does not unnecessarily insert lines", function()
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
      <<<lots of text in one line^             |
      line two                                |
      line three                              |
      line four                               |
      line five                               |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_cursormoved_line()
  it("does not place the cursor in the command line", function()
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
      <<<_____________________________________|
      ________________________________________|
      ______________________________________^xx|
      x______________________________________x|
      xx                                      |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_eob()
  it("does not scroll halfway at end of buffer", function()
    screen:try_resize(40, 10)
    exec([[
      set smoothscroll
      call setline(1, ['']->repeat(100))
      norm G
    ]])
    -- does not scroll halfway when scrolling to end of buffer
    screen:expect([[
                                              |
                                              |
                                              |
                                              |
                                              |
                                              |
                                              |
                                              |
      ^                                        |
                                              |
    ]])
    exec("call setline(92, 'a'->repeat(100))")
    feed('<C-B>G')
    -- cursor is not placed below window
    screen:expect([[
      <<<aaaaaaaaaaaaaaaaa                    |
                                              |
                                              |
                                              |
                                              |
                                              |
                                              |
                                              |
      ^                                        |
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_incsearch()
  it("does not reset skipcol when doing incremental search on the same word", function()
    screen:try_resize(40, 8)
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.Brown},
      [2] = {foreground = Screen.colors.Blue1, bold = true},
      [3] = {background = Screen.colors.Yellow1},
      [4] = {reverse = true},
    })
    exec([[
      set smoothscroll number scrolloff=0 incsearch
      call setline(1, repeat([''], 20))
      call setline(11, repeat('a', 100))
      call setline(14, 'bbbb')
    ]])
    feed('/b')
    screen:expect([[
      {2:<<<}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaa        |
      {1: 12 }                                    |
      {1: 13 }                                    |
      {1: 14 }{4:b}{3:bbb}                                |
      {1: 15 }                                    |
      {1: 16 }                                    |
      {1: 17 }                                    |
      /b^                                      |
    ]])
    feed('b')
    screen:expect([[
      {2:<<<}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaa        |
      {1: 12 }                                    |
      {1: 13 }                                    |
      {1: 14 }{4:bb}{3:bb}                                |
      {1: 15 }                                    |
      {1: 16 }                                    |
      {1: 17 }                                    |
      /bb^                                     |
    ]])
    feed('b')
    screen:expect([[
      {2:<<<}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaa        |
      {1: 12 }                                    |
      {1: 13 }                                    |
      {1: 14 }{4:bbb}b                                |
      {1: 15 }                                    |
      {1: 16 }                                    |
      {1: 17 }                                    |
      /bbb^                                    |
    ]])
    feed('b')
    screen:expect([[
      {2:<<<}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaa        |
      {1: 12 }                                    |
      {1: 13 }                                    |
      {1: 14 }{4:bbbb}                                |
      {1: 15 }                                    |
      {1: 16 }                                    |
      {1: 17 }                                    |
      /bbbb^                                   |
    ]])
  end)

  -- oldtest: Test_smoothscroll_multi_skipcol()
  it('scrolling mulitple lines and stopping at non-zero skipcol', function()
    screen:try_resize(40, 10)
    screen:set_default_attr_ids({
      [0] = {foreground = Screen.colors.Blue, bold = true},
      [1] = {background = Screen.colors.Grey90},
    })
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
      {1:^                                        }|
                                              |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaa                              |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaa                              |
                                              |
                                              |
      bbb                                     |
                                              |
    ]])
    feed('3<C-E>')
    screen:expect([[
      {0:<<<}{1:aaaaaa^a                              }|
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaa                              |
                                              |
                                              |
      bbb                                     |
      ccc                                     |
      {0:~                                       }|
      {0:~                                       }|
                                              |
    ]])
    feed('2<C-E>')
    screen:expect([[
      {0:<<<}{1:aaaaaa^a                              }|
                                              |
                                              |
      bbb                                     |
      ccc                                     |
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
                                              |
    ]])
  end)

  -- oldtest: Test_smoothscroll_zero_width_scroll_cursor_bot()
  it('does not divide by zero in zero-width window', function()
    screen:try_resize(40, 19)
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.Brown};  -- LineNr
      [2] = {bold = true, foreground = Screen.colors.Blue};  -- NonText
      [3] = {bold = true, reverse = true};  -- StatusLine
      [4] = {reverse = true};  -- StatusLineNC
    })
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
      {1: }│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:@}│                                      |
      {2:^@}│                                      |
      {3:< }{4:[No Name] [+]                         }|
                                              |
    ]])
  end)

  it("works with virt_lines above and below", function()
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
      <<<e text with some text with some text with some text |
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
      Line with some text with some text with some text wi@@@|
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
      <<<e text with some text with some text with some tex^t |
      virt_below2                                            |
      virt_above2                                            |
      Line with some text with some text with some text with |
      some text with some text with some text with some text |
      ~                                                      |
                                                             |
    ]])
  end)

  it('<<< marker shows with tabline, winbar and splits', function()
    screen:try_resize(40, 12)
    exec([[
      call setline(1, ['Line' .. (' with some text'->repeat(7))]->repeat(7))
      set smoothscroll scrolloff=0
      norm sj
    ]])
    screen:expect([[
      <<<e text with some text with some text |
      with some text with some text           |
      Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
      [No Name] [+]                           |
      <<<e text with some text with some text |
      ^with some text with some text           |
      Line with some text with some text with |
      some text with some text with some te@@@|
      [No Name] [+]                           |
                                              |
    ]])
    exec('set showtabline=2')
    feed('<C-E>')
    screen:expect([[
       2+ [No Name]                           |
      <<<e text with some text with some text |
      with some text with some text           |
      Line with some text with some text with |
      some text with some text with some text |
      with some text with some text           |
      [No Name] [+]                           |
      <<<e text with some text with some text |
      ^with some text with some text           |
      Line with some text with some text wi@@@|
      [No Name] [+]                           |
                                              |
    ]])
    exec('set winbar=winbar')
    feed('<C-w>k<C-E>')
    screen:expect([[
       2+ [No Name]                           |
      winbar                                  |
      <<<e text with some text with some text |
      ^with some text with some text           |
      Line with some text with some text with |
      some text with some text with some te@@@|
      [No Name] [+]                           |
      winbar                                  |
      <<<e text with some text with some text |
      with some text with some text           |
      [No Name] [+]                           |
                                              |
    ]])
  end)
end)
