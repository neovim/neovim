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
      ~                                       |
                                              |
    ]]
    local s3 = [[
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
      ~                                       |
                                              |
    ]]
    local s6 = [[
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
end)
