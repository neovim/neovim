local helpers = require('test.functional.helpers')
local thelpers = require('test.functional.terminal.helpers')
local feed, clear, nvim = helpers.feed, helpers.clear, helpers.nvim
local wait, eq = helpers.wait, helpers.eq


describe('terminal window', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup()
  end)

  describe('with colorcolumn set', function()
    before_each(function()
      feed('<c-\\><c-n>')
      screen:expect([[
        tty ready                                         |
        {2:^ }                                                 |
                                                          |
                                                          |
                                                          |
                                                          |
                                                          |
      ]])
      feed(':set colorcolumn=20<cr>i')
    end)

    it('wont show the color column', function()
      screen:expect([[
        tty ready                                         |
        {1: }                                                 |
                                                          |
                                                          |
                                                          |
                                                          |
        -- TERMINAL --                                    |
      ]])
    end)
  end)

  describe('with fold set', function()
    before_each(function()
      feed('<c-\\><c-n>:set foldenable foldmethod=manual<cr>i')
      thelpers.feed_data({'line1', 'line2', 'line3', 'line4', ''})
      screen:expect([[
        tty ready                                         |
        line1                                             |
        line2                                             |
        line3                                             |
        line4                                             |
        {1: }                                                 |
        -- TERMINAL --                                    |
      ]])
    end)

    it('will show folds', function()
      feed('<c-\\><c-n>ggvGzf')
      wait()
      screen:expect([[
      {3:^+--  6 lines: tty ready---------------------------}|
      ~                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
                                                        |
      ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {foreground = 4, background = 248}})
  end)
  end)
end)

