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

  -- oldtest: Test_smoothscroll_CtrlE_CtrlY()
  it('works with <C-E> and <C-E>', function()
    exec([[
      call setline(1, [ 'line one', 'word '->repeat(20), 'line three', 'long word '->repeat(7), 'line', 'line', 'line', ])
      set smoothscroll
      :5
    ]])
    local s0 = [[
      line one                                |
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
                                              |
    ]]
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
      ^line                                    |
      line                                    |
      line                                    |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
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
    screen:expect(s3)
    feed('<C-Y>')
    screen:expect(s2)
    feed('<C-Y>')
    screen:expect(s1)
    feed('<C-Y>')
    screen:expect(s0)
  end)
end)
