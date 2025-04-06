local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local tt = require('test.functional.testterm')
local clear, eq, api = n.clear, t.eq, n.api
local feed = n.feed
local feed_data = tt.feed_data
local enter_altscreen = tt.enter_altscreen
local exit_altscreen = tt.exit_altscreen

if t.skip(t.is_os('win')) then
  return
end

describe(':terminal altscreen', function()
  local screen

  before_each(function()
    clear()
    screen = tt.setup_screen()
    feed_data({
      'line1',
      'line2',
      'line3',
      'line4',
      'line5',
      'line6',
      'line7',
      'line8',
      '',
    })
    screen:expect([[
      line4                                             |
      line5                                             |
      line6                                             |
      line7                                             |
      line8                                             |
      ^                                                  |
      {3:-- TERMINAL --}                                    |
    ]])
    enter_altscreen()
    screen:expect([[
                                                        |*5
      ^                                                  |
      {3:-- TERMINAL --}                                    |
    ]])
    eq(10, api.nvim_buf_line_count(0))
  end)

  it('wont clear lines already in the scrollback', function()
    feed('<c-\\><c-n>gg')
    screen:expect([[
      ^tty ready                                         |
      line1                                             |
      line2                                             |
      line3                                             |
                                                        |*3
    ]])
  end)

  describe('on exit', function()
    before_each(exit_altscreen)

    it('restores buffer state', function()
      screen:expect([[
        line4                                             |
        line5                                             |
        line6                                             |
        line7                                             |
        line8                                             |
        ^                                                  |
        {3:-- TERMINAL --}                                    |
      ]])
      feed('<c-\\><c-n>gg')
      screen:expect([[
        ^tty ready                                         |
        line1                                             |
        line2                                             |
        line3                                             |
        line4                                             |
        line5                                             |
                                                          |
      ]])
    end)
  end)

  describe('with lines printed after the screen height limit', function()
    before_each(function()
      feed_data({
        'line9',
        'line10',
        'line11',
        'line12',
        'line13',
        'line14',
        'line15',
        'line16',
        '',
      })
      screen:expect([[
        line12                                            |
        line13                                            |
        line14                                            |
        line15                                            |
        line16                                            |
        ^                                                  |
        {3:-- TERMINAL --}                                    |
      ]])
    end)

    it('wont modify line count', function()
      eq(10, api.nvim_buf_line_count(0))
    end)

    it('wont modify lines in the scrollback', function()
      feed('<c-\\><c-n>gg')
      screen:expect([[
        ^tty ready                                         |
        line1                                             |
        line2                                             |
        line3                                             |
        line12                                            |
        line13                                            |
                                                          |
      ]])
    end)
  end)

  describe('after height is decreased by 2', function()
    local function wait_removal()
      screen:try_resize(screen._width, screen._height - 2)
      screen:expect([[
                                                          |*2
        rows: 4, cols: 50                                 |
        ^                                                  |
        {3:-- TERMINAL --}                                    |
      ]])
    end

    it('removes 2 lines from the bottom of the visible buffer', function()
      wait_removal()
      feed('<c-\\><c-n>4k')
      screen:expect([[
        ^                                                  |
                                                          |*2
        rows: 4, cols: 50                                 |
                                                          |
      ]])
      eq(9, api.nvim_buf_line_count(0))
    end)

    describe('and after exit', function()
      before_each(function()
        wait_removal()
        exit_altscreen()
      end)

      it('restore buffer state', function()
        screen:expect([[
          line5                                             |
          line6                                             |
          line7                                             |
          ^line8                                             |
          {3:-- TERMINAL --}                                    |
        ]])
      end)
    end)
  end)
end)
