local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local feed_data = thelpers.feed_data
local feed, clear = helpers.feed, helpers.clear
local wait = helpers.wait
local iswin = helpers.iswin
local command = helpers.command
local retry = helpers.retry
local eq = helpers.eq
local eval = helpers.eval

describe(':terminal window', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup()
  end)

  it('sets topline correctly #8556', function()
    -- Test has hardcoded assumptions of dimensions.
    eq(7, eval('&lines'))
    feed_data('\n\n\n')  -- Add blank lines.
    -- Terminal/shell contents must exceed the height of this window.
    command('topleft 1split')
    eq('terminal', eval('&buftype'))
    feed([[i<cr>]])
    -- Check topline _while_ in terminal-mode.
    retry(nil, nil, function() eq(6, eval('winsaveview()["topline"]')) end)
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
      feed_data({'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'})
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
      feed_data({' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'})
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
      feed_data({'line1', 'line2', 'line3', 'line4', ''})
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

describe(':terminal with multigrid', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup(0,nil,50,{ext_multigrid=true})
  end)

  it('resizes to requested size', function()
    screen:expect([[
    ## grid 1
      [2:--------------------------------------------------]|
      [2:--------------------------------------------------]|
      [2:--------------------------------------------------]|
      [2:--------------------------------------------------]|
      [2:--------------------------------------------------]|
      [2:--------------------------------------------------]|
      {3:-- TERMINAL --}                                    |
    ## grid 2
      tty ready                                         |
      {1: }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
    ]])

    screen:try_resize_grid(2, 20, 10)
    if iswin() then
      screen:expect{any="rows: 10, cols: 20"}
    else
      screen:expect([[
      ## grid 1
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        {3:-- TERMINAL --}                                    |
      ## grid 2
        tty ready           |
        rows: 10, cols: 20  |
        {1: }                   |
                            |
                            |
                            |
                            |
                            |
                            |
                            |
      ]])
    end

    screen:try_resize_grid(2, 70, 3)
    if iswin() then
      screen:expect{any="rows: 3, cols: 70"}
    else
      screen:expect([[
      ## grid 1
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        {3:-- TERMINAL --}                                    |
      ## grid 2
        rows: 10, cols: 20                                                    |
        rows: 3, cols: 70                                                     |
        {1: }                                                                     |
      ]])
    end

    screen:try_resize_grid(2, 0, 0)
    if iswin() then
      screen:expect{any="rows: 6, cols: 50"}
    else
      screen:expect([[
      ## grid 1
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        [2:--------------------------------------------------]|
        {3:-- TERMINAL --}                                    |
      ## grid 2
        tty ready                                         |
        rows: 10, cols: 20                                |
        rows: 3, cols: 70                                 |
        rows: 6, cols: 50                                 |
        {1: }                                                 |
                                                          |
      ]])
    end
  end)
end)
