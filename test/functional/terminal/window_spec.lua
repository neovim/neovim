local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local tt = require('test.functional.testterm')
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
  before_each(clear)

  it('sets local values of window options #29325', function()
    command('setglobal wrap list')
    command('terminal')
    eq({ 0, 0, 1 }, eval('[&l:wrap, &wrap, &g:wrap]'))
    eq({ 0, 0, 1 }, eval('[&l:list, &list, &g:list]'))
    command('enew')
    eq({ 1, 1, 1 }, eval('[&l:wrap, &wrap, &g:wrap]'))
    eq({ 1, 1, 1 }, eval('[&l:list, &list, &g:list]'))
    command('buffer #')
    eq({ 0, 0, 1 }, eval('[&l:wrap, &wrap, &g:wrap]'))
    eq({ 0, 0, 1 }, eval('[&l:list, &list, &g:list]'))
    command('new')
    eq({ 1, 1, 1 }, eval('[&l:wrap, &wrap, &g:wrap]'))
    eq({ 1, 1, 1 }, eval('[&l:list, &list, &g:list]'))
  end)
end)

describe(':terminal window', function()
  local screen

  before_each(function()
    clear()
    screen = tt.setup_screen()
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
      feed([[<C-\><C-N>]])
      feed([[:set numberwidth=1 number<CR>i]])
      screen:expect([[
        {121:1 }tty ready                                       |
        {121:2 }rows: 6, cols: 48                               |
        {121:3 }^                                                |
        {121:4 }                                                |
        {121:5 }                                                |
        {121:6 }                                                |
        {5:-- TERMINAL --}                                    |
      ]])
      feed_data('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
      screen:expect([[
        {121:1 }tty ready                                       |
        {121:2 }rows: 6, cols: 48                               |
        {121:3 }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV|
        {121:4 }WXYZ^                                            |
        {121:5 }                                                |
        {121:6 }                                                |
        {5:-- TERMINAL --}                                    |
      ]])

      -- numberwidth=9
      feed([[<C-\><C-N>]])
      feed([[:set numberwidth=9 number<CR>i]])
      screen:expect([[
        {121:       1 }tty ready                                |
        {121:       2 }rows: 6, cols: 48                        |
        {121:       3 }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO|
        {121:       4 }PQRSTUVWXYZrows: 6, cols: 41             |
        {121:       5 }^                                         |
        {121:       6 }                                         |
        {5:-- TERMINAL --}                                    |
      ]])
      feed_data(' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
      screen:expect([[
        {121:       1 }tty ready                                |
        {121:       2 }rows: 6, cols: 48                        |
        {121:       3 }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO|
        {121:       4 }PQRSTUVWXYZrows: 6, cols: 41             |
        {121:       5 } abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN|
        {121:       6 }OPQRSTUVWXYZ^                             |
        {5:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  describe("with 'statuscolumn'", function()
    it('wraps text', function()
      command([[set number statuscolumn=++%l\ \ ]])
      screen:expect([[
        {121:++1  }tty ready                                    |
        {121:++2  }rows: 6, cols: 45                            |
        {121:++3  }^                                             |
        {121:++4  }                                             |
        {121:++5  }                                             |
        {121:++6  }                                             |
        {5:-- TERMINAL --}                                    |
      ]])
      feed_data('\n\n\n\n\nabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
      screen:expect([[
        {121:++4  }                                             |
        {121:++5  }                                             |
        {121:++6  }                                             |
        {121:++7  }                                             |
        {121:++8  }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRS|
        {121:++9  }TUVWXYZ^                                      |
        {5:-- TERMINAL --}                                    |
      ]])
      feed_data('\nabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
      screen:expect([[
        {121:++ 7  }                                            |
        {121:++ 8  }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR|
        {121:++ 9  }STUVWXYZ                                    |
        {121:++10  }abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR|
        {121:++11  }STUVWXYZrows: 6, cols: 44                   |
        {121:++12  }^                                            |
        {5:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  describe("with 'colorcolumn'", function()
    before_each(function()
      feed([[<C-\><C-N>]])
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |*5
      ]])
      feed(':set colorcolumn=20<CR>i')
    end)

    it('wont show the color column', function()
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |*4
        {5:-- TERMINAL --}                                    |
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
        ^                                                  |
        {5:-- TERMINAL --}                                    |
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
                                                          |
                                                          |
      ]])
    end)
  end)
end)

describe(':terminal with multigrid', function()
  local screen

  before_each(function()
    clear()
    screen = tt.setup_screen(0, nil, 50, nil, { ext_multigrid = true })
  end)

  it('resizes to requested size', function()
    screen:expect([[
    ## grid 1
      [2:--------------------------------------------------]|*6
      [3:--------------------------------------------------]|
    ## grid 2
      tty ready                                         |
      ^                                                  |
                                                        |*4
    ## grid 3
      {5:-- TERMINAL --}                                    |
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
        ^                    |
                            |*7
      ## grid 3
        {5:-- TERMINAL --}                                    |
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
        ^                                                                      |
      ## grid 3
        {5:-- TERMINAL --}                                    |
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
        ^                                                  |
                                                          |
      ## grid 3
        {5:-- TERMINAL --}                                    |
      ]])
    end
  end)
end)
