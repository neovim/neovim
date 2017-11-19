local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local feed, clear = helpers.feed, helpers.clear
local wait = helpers.wait
local iswin = helpers.iswin

describe('terminal window', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup()
  end)

  describe("with 'number'", function()
    it('wraps text', function()
      feed([[<C-\><C-N>]])
      feed([[:set numberwidth=1 number<CR>i]])
      screen:expect([[
        {7:1 }tty ready                                       |
        {7:2 }rows: 6, cols: 48                               |
        {7:3 }{1: }                                               |
        {7:4 }                                                |
        {7:5 }                                                |
        {7:6 }                                                |
        {3:-- TERMINAL --}                                    |
      ]])
      thelpers.feed_data({'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'})
      screen:expect([[
        {7:1 }tty ready                                       |
        {7:2 }rows: 6, cols: 48                               |
        {7:3 }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV|
        {7:4 }WXYZ{1: }                                           |
        {7:5 }                                                |
        {7:6 }                                                |
        {3:-- TERMINAL --}                                    |
      ]])

      if iswin() then
        return  -- win: :terminal resize is unreliable #7007
      end

      -- numberwidth=9
      feed([[<C-\><C-N>]])
      feed([[:set numberwidth=9 number<CR>i]])
      screen:expect([[
        {7:       1 }tty ready                                |
        {7:       2 }rows: 6, cols: 48                        |
        {7:       3 }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO|
        {7:       4 }WXYZrows: 6, cols: 41                    |
        {7:       5 }{1: }                                        |
        {7:       6 }                                         |
        {3:-- TERMINAL --}                                    |
      ]])
      thelpers.feed_data({' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'})
      screen:expect([[
        {7:       1 }tty ready                                |
        {7:       2 }rows: 6, cols: 48                        |
        {7:       3 }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO|
        {7:       4 }WXYZrows: 6, cols: 41                    |
        {7:       5 } abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN|
        {7:       6 }OPQRSTUVWXYZ{1: }                            |
        {3:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  describe("with 'colorcolumn'", function()
    before_each(function()
      feed([[<C-\><C-N>]])
      screen:expect([[
        tty ready                                         |
        {2:^ }                                                 |
                                                          |
                                                          |
                                                          |
                                                          |
                                                          |
      ]])
      feed(':set colorcolumn=20<CR>i')
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
      feed([[<C-\><C-N>:set foldenable foldmethod=manual<CR>i]])
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
      feed([[<C-\><C-N>ggvGzf]])
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

