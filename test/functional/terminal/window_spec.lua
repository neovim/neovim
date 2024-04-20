local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local tt = require('test.functional.terminal.testutil')
local feed_data = tt.feed_data
local feed, clear = n.feed, n.clear
local poke_eventloop = n.poke_eventloop
local command = n.command
local retry = t.retry
local eq = t.eq
local eval = n.eval
local skip = t.skip
local is_os = t.is_os

describe(':terminal window', function()
  local screen

  before_each(function()
    clear()
    screen = tt.screen_setup()
  end)

  it('sets topline correctly #8556', function()
    skip(is_os('win'))
    -- Test has hardcoded assumptions of dimensions.
    eq(7, eval('&lines'))
    feed_data('\n\n\n') -- Add blank lines.
    -- Terminal/shell contents must exceed the height of this window.
    command('topleft 1split')
    eq('terminal', eval('&buftype'))
    feed([[i<cr>]])
    -- Check topline _while_ in terminal-mode.
    retry(nil, nil, function()
      eq(6, eval('winsaveview()["topline"]'))
    end)
  end)

  describe("with 'number'", function()
    it('wraps text', function()
      skip(is_os('win')) -- todo(clason): unskip when reenabling reflow
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
      feed_data('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
      screen:expect([[
        {7:1 }tty ready                                       |
        {7:2 }rows: 6, cols: 48                               |
        {7:3 }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV|
        {7:4 }WXYZ{1: }                                           |
        {7:5 }                                                |
        {7:6 }                                                |
        {3:-- TERMINAL --}                                    |
      ]])

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
      feed_data(' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
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

  describe("with 'statuscolumn'", function()
    it('wraps text', function()
      skip(is_os('win')) -- todo(clason): unskip when reenabling reflow
      command([[set number statuscolumn=++%l\ \ ]])
      screen:expect([[
        {7:++1  }tty ready                                    |
        {7:++2  }rows: 6, cols: 45                            |
        {7:++3  }{1: }                                            |
        {7:++4  }                                             |
        {7:++5  }                                             |
        {7:++6  }                                             |
        {3:-- TERMINAL --}                                    |
      ]])
      feed_data('\n\n\n\n\nabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
      screen:expect([[
        {7:++4  }                                             |
        {7:++5  }                                             |
        {7:++6  }                                             |
        {7:++7  }                                             |
        {7:++8  }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRS|
        {7:++9  }TUVWXYZ{1: }                                     |
        {3:-- TERMINAL --}                                    |
      ]])
      feed_data('\nabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
      screen:expect([[
        {7:++7   }                                            |
        {7:++8   }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR|
        {7:++9   }TUVWXYZ                                     |
        {7:++10  }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR|
        {7:++11  }TUVWXYZrows: 6, cols: 44                    |
        {7:++12  }{1: }                                           |
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
                                                          |*5
      ]])
      feed(':set colorcolumn=20<CR>i')
    end)

    it('wont show the color column', function()
      screen:expect([[
        tty ready                                         |
        {1: }                                                 |
                                                          |*4
        {3:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  describe('with fold set', function()
    before_each(function()
      feed([[<C-\><C-N>:set foldenable foldmethod=manual<CR>i]])
      feed_data({ 'line1', 'line2', 'line3', 'line4', '' })
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
      poke_eventloop()
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
    screen = tt.screen_setup(0, nil, 50, nil, { ext_multigrid = true })
  end)

  it('resizes to requested size', function()
    screen:expect([[
    ## grid 1
      [2:--------------------------------------------------]|*6
      [3:--------------------------------------------------]|
    ## grid 2
      tty ready                                         |
      {1: }                                                 |
                                                        |*4
    ## grid 3
      {3:-- TERMINAL --}                                    |
    ]])

    screen:try_resize_grid(2, 20, 10)
    if is_os('win') then
      screen:expect { any = 'rows: 10, cols: 20' }
    else
      screen:expect([[
      ## grid 1
        [2:--------------------------------------------------]|*6
        [3:--------------------------------------------------]|
      ## grid 2
        tty ready           |
        rows: 10, cols: 20  |
        {1: }                   |
                            |*7
      ## grid 3
        {3:-- TERMINAL --}                                    |
      ]])
    end

    screen:try_resize_grid(2, 70, 3)
    if is_os('win') then
      screen:expect { any = 'rows: 3, cols: 70' }
    else
      screen:expect([[
      ## grid 1
        [2:--------------------------------------------------]|*6
        [3:--------------------------------------------------]|
      ## grid 2
        rows: 10, cols: 20                                                    |
        rows: 3, cols: 70                                                     |
        {1: }                                                                     |
      ## grid 3
        {3:-- TERMINAL --}                                    |
      ]])
    end

    screen:try_resize_grid(2, 0, 0)
    if is_os('win') then
      screen:expect { any = 'rows: 6, cols: 50' }
    else
      screen:expect([[
      ## grid 1
        [2:--------------------------------------------------]|*6
        [3:--------------------------------------------------]|
      ## grid 2
        tty ready                                         |
        rows: 10, cols: 20                                |
        rows: 3, cols: 70                                 |
        rows: 6, cols: 50                                 |
        {1: }                                                 |
                                                          |
      ## grid 3
        {3:-- TERMINAL --}                                    |
      ]])
    end
  end)
end)
