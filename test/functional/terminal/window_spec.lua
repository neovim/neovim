local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local feed, clear = helpers.feed, helpers.clear
local wait = helpers.wait

describe('terminal window', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup()
  end)

  describe('with number set', function()
    before_each(function()
      feed('<c-\\><c-n>:set number<cr>i')
      screen:expect([[
        {7:  1 }tty ready                                     |
        {7:  2 }rows: 6, cols: 46                             |
        {7:  3 }{1: }                                             |
        {7:  4 }                                              |
        {7:  5 }                                              |
        {7:  6 }                                              |
        {3:-- TERMINAL --}                                    |
      ]])
    end)

    it('wraps text correctly', function()
      thelpers.feed_data({'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'})
      screen:expect([[
        {7:  1 }tty ready                                     |
        {7:  2 }rows: 6, cols: 46                             |
        {7:  3 }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST|
        {7:  4 }UVWXYZ{1: }                                       |
        {7:  5 }                                              |
        {7:  6 }                                              |
        {3:-- TERMINAL --}                                    |
      ]])
    end)
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
        {3:-- TERMINAL --}                                    |
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
        {3:-- TERMINAL --}                                    |
      ]])
    end)

    it('wont show any folds', function()
      feed('<c-\\><c-n>ggvGzf')
      wait()
      screen:expect([[
        ^tty ready                                         |
        line1                                             |
        line2                                             |
        line3                                             |
        line4                                             |
        {2: }                                                 |
                                                          |
      ]])
    end)
  end)
end)

