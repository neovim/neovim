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

  -- oldtest: Test_smoothscroll_number()
  it("works 'number' and 'cpo'+=n", function()
    exec([[
      call setline(1, [ 'one ' .. 'word '->repeat(20), 'two ' .. 'long word '->repeat(7), 'line', 'line', 'line', ])
      set smoothscroll scrolloff=5
      set number cpo+=n
      :3
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
    -- moving cursor up - whole top line shows
    feed('2k')
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
      call setline(1, ['one', 'two', 'Line' .. (' with lots of text'->repeat(30))])
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
  end)
end)
