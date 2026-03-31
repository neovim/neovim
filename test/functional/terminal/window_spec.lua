local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local tt = require('test.functional.testterm')
local feed_data = tt.feed_data
local feed_csi = tt.feed_csi
local feed, clear = n.feed, n.clear
local poke_eventloop = n.poke_eventloop
local exec_lua = n.exec_lua
local command = n.command
local retry = t.retry
local eq = t.eq
local eval = n.eval
local skip = t.skip
local is_os = t.is_os
local testprg = n.testprg

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

  it('resets horizontal scroll on resize #35331', function()
    skip(is_os('win'), 'Too flaky on Windows')
    local screen = tt.setup_screen(0, { testprg('shell-test'), 'INTERACT' })
    command('set statusline=%{win_getid()} splitright')
    screen:expect([[
      interact $ ^                                       |
                                                        |*5
      {5:-- TERMINAL --}                                    |
    ]])
    feed_data(('A'):rep(30))
    screen:expect([[
      interact $ AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA^         |
                                                        |*5
      {5:-- TERMINAL --}                                    |
    ]])
    command('vnew | wincmd p')
    screen:expect([[
      interact $ AAAAAAAAAAAAA│                         |
      AAAAAAAAAAAAAAAAA^       │{100:~                        }|
                              │{100:~                        }|*3
      {120:1000                     }{2:1001                     }|
      {5:-- TERMINAL --}                                    |
    ]])

    feed([[<C-\><C-N><C-W>o]])
    screen:expect([[
      interact $ AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA         |
      ^                                                  |
                                                        |*5
    ]])
    -- Window with less room scrolls anyway to keep its cursor in-view.
    feed('gg$20<C-W>v')
    screen:expect([[
      interact $ AAAAAAAAAAAAAAAAAA│$ AAAAAAAAAAAAAAAAA^A|
      AAAAAAAAAAAA                 │AAA                 |
                                   │                    |*3
      {119:1000                          }{120:1002                }|
                                                        |
    ]])
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
                                                          |*2
      ]])
    end)
  end)

  it('redrawn when restoring cursorline/column', function()
    screen:set_default_attr_ids({
      [1] = { bold = true },
      [2] = { foreground = 130 },
      [3] = { foreground = 130, underline = true },
      [12] = { underline = true },
      [19] = { background = 7 },
    })

    feed([[<C-\><C-N>]])
    command('setlocal cursorline')
    screen:expect([[
      tty ready                                         |
      {12:^                                                  }|
                                                        |*5
    ]])
    feed('i')
    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*4
      {1:-- TERMINAL --}                                    |
    ]])
    feed([[<C-\><C-N>]])
    screen:expect([[
      tty ready                                         |
      {12:^                                                  }|
                                                        |*5
    ]])

    command('setlocal number')
    screen:expect([[
      {2:  1 }tty ready                                     |
      {3:  2 }{12:^rows: 6, cols: 46                             }|
      {2:  3 }                                              |
      {2:  4 }                                              |
      {2:  5 }                                              |
      {2:  6 }                                              |
                                                        |
    ]])
    feed('i')
    screen:expect([[
      {2:  1 }tty ready                                     |
      {2:  2 }rows: 6, cols: 46                             |
      {3:  3 }^                                              |
      {2:  4 }                                              |
      {2:  5 }                                              |
      {2:  6 }                                              |
      {1:-- TERMINAL --}                                    |
    ]])
    feed([[<C-\><C-N>]])
    screen:expect([[
      {2:  1 }tty ready                                     |
      {2:  2 }rows: 6, cols: 46                             |
      {3:  3 }{12:^                                              }|
      {2:  4 }                                              |
      {2:  5 }                                              |
      {2:  6 }                                              |
                                                        |
    ]])

    command('setlocal nonumber nocursorline cursorcolumn')
    screen:expect([[
      {19:t}ty ready                                         |
      {19:r}ows: 6, cols: 46                                 |
      ^rows: 6, cols: 50                                 |
      {19: }                                                 |*3
                                                        |
    ]])
    feed('i')
    screen:expect([[
      tty ready                                         |
      rows: 6, cols: 46                                 |
      rows: 6, cols: 50                                 |
      ^                                                  |
                                                        |*2
      {1:-- TERMINAL --}                                    |
    ]])
    feed([[<C-\><C-N>]])
    screen:expect([[
      {19:t}ty ready                                         |
      {19:r}ows: 6, cols: 46                                 |
      {19:r}ows: 6, cols: 50                                 |
      ^                                                  |
      {19: }                                                 |*2
                                                        |
    ]])
  end)

  it('redraws cursor info in terminal mode', function()
    command('file AMOGUS | set laststatus=2 ruler')
    screen:expect([[
      tty ready                                         |
      rows: 5, cols: 50                                 |
      ^                                                  |
                                                        |*2
      {120:AMOGUS [-]                      3,0-1          All}|
      {5:-- TERMINAL --}                                    |
    ]])
    feed_data('you are the imposter')
    screen:expect([[
      tty ready                                         |
      rows: 5, cols: 50                                 |
      you are the imposter^                              |
                                                        |*2
      {120:AMOGUS [-]                      3,21           All}|
      {5:-- TERMINAL --}                                    |
    ]])
    feed([[<C-\><C-N>]])
    screen:expect([[
      tty ready                                         |
      rows: 5, cols: 50                                 |
      you are the imposte^r                              |
                                                        |*2
      {120:AMOGUS [-]                      3,20           All}|
                                                        |
    ]])
  end)

  it('redraws stale statuslines and mode when not updating screen', function()
    command('file foo | set ruler | vsplit')
    screen:expect([[
      tty ready                │tty ready               |
      rows: 5, cols: 25        │rows: 5, cols: 25       |
      ^                         │                        |
                               │                        |*2
      {120:<o [-] 3,0-1          All }{119:< [-] 2,0-1          Top}|
      {5:-- TERMINAL --}                                    |
    ]])
    command("call win_execute(win_getid(winnr('#')), 'call cursor(1, 1)')")
    screen:expect([[
      tty ready                │tty ready               |
      rows: 5, cols: 25        │rows: 5, cols: 25       |
      ^                         │                        |
                               │                        |*2
      {120:<o [-] 3,0-1          All }{119:< [-] 1,1            All}|
      {5:-- TERMINAL --}                                    |
    ]])
    command('echo ""')
    screen:expect_unchanged()
  end)

  it('has correct topline if scrolled by events', function()
    local lines = {}
    for i = 1, 10 do
      table.insert(lines, 'cool line ' .. i)
    end
    feed_data(lines)
    feed_csi('1;1H') -- Cursor to 1,1 (after any scrollback)

    -- :sleep (with leeway) until the refresh_terminal uv timer event triggers before we move the
    -- cursor. Check that the next terminal_check tails topline correctly.
    command('set ruler | sleep 20m | call nvim_win_set_cursor(0, [1, 0])')
    screen:expect([[
      ^cool line 5                                       |
      cool line 6                                       |
      cool line 7                                       |
      cool line 8                                       |
      cool line 9                                       |
      cool line 10                                      |
      {5:-- TERMINAL --}                  6,1           Bot |
    ]])
    command('call nvim_win_set_cursor(0, [1, 0])')
    screen:expect_unchanged()

    feed_csi('2;5H') -- Cursor to 2,5 (after any scrollback)
    screen:expect([[
      cool line 5                                       |
      cool^ line 6                                       |
      cool line 7                                       |
      cool line 8                                       |
      cool line 9                                       |
      cool line 10                                      |
      {5:-- TERMINAL --}                  7,5           Bot |
    ]])
    -- Check topline correct after leaving terminal mode.
    -- The new cursor position is one column left of the terminal's actual cursor position.
    command('stopinsert | call nvim_win_set_cursor(0, [1, 0])')
    screen:expect([[
      cool line 5                                       |
      coo^l line 6                                       |
      cool line 7                                       |
      cool line 8                                       |
      cool line 9                                       |
      cool line 10                                      |
                                      7,4           Bot |
    ]])
  end)

  it('updates terminal size', function()
    skip(is_os('win'), "Windows doesn't show all lines?")
    screen:set_default_attr_ids({
      [1] = { reverse = true },
      [2] = { background = 225, foreground = Screen.colors.Gray0 },
      [3] = { bold = true },
      [4] = { foreground = 12 },
      [5] = { reverse = true, bold = true },
      [17] = { background = 2, foreground = Screen.colors.Grey0 },
      [18] = { background = 2, foreground = 8 },
      [19] = { underline = true, foreground = Screen.colors.Grey0, background = 7 },
      [20] = { underline = true, foreground = 5, background = 7 },
    })

    command('file foo | vsplit')
    screen:expect([[
      tty ready                │tty ready               |
      rows: 5, cols: 25        │rows: 5, cols: 25       |
      ^                         │                        |
                               │                        |*2
      {17:foo [-]                   }{18:foo [-]                 }|
      {3:-- TERMINAL --}                                    |
    ]])
    command('tab split')
    screen:expect([[
      {19: }{20:2}{19: foo }{3: foo }{1:                                     }{19:X}|
      tty ready                                         |
      rows: 5, cols: 25                                 |
      rows: 5, cols: 50                                 |
      ^                                                  |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])

    command('quit | botright split')
    -- NOTE: right window's cursor not on the last line, so it's not tailing.
    screen:expect([[
      rows: 5, cols: 50        │rows: 5, cols: 25       |
      rows: 2, cols: 50        │rows: 5, cols: 50       |
      {18:foo [-]                   foo [-]                 }|
      rows: 2, cols: 50                                 |
      ^                                                  |
      {17:foo [-]                                           }|
      {3:-- TERMINAL --}                                    |
    ]])
    command('quit')
    screen:expect([[
      rows: 5, cols: 25        │tty ready               |
      rows: 5, cols: 50        │rows: 5, cols: 25       |
      rows: 2, cols: 50        │rows: 5, cols: 50       |
      rows: 5, cols: 25        │rows: 2, cols: 50       |
      ^                         │rows: 5, cols: 25       |
      {17:foo [-]                   }{18:foo [-]                 }|
      {3:-- TERMINAL --}                                    |
    ]])
    command('call nvim_open_win(0, 0, #{relative: "editor", row: 0, col: 0, width: 40, height: 3})')
    screen:expect([[
      {2:rows: 5, cols: 25                       }          |
      {2:rows: 5, cols: 40                       } 25       |
      {2:                                        } 50       |
      rows: 5, cols: 40        │rows: 2, cols: 50       |
      ^                         │rows: 5, cols: 25       |
      {17:foo [-]                   }{18:foo [-]                 }|
      {3:-- TERMINAL --}                                    |
    ]])
    command('fclose!')
    screen:expect([[
      rows: 2, cols: 50        │tty ready               |
      rows: 5, cols: 25        │rows: 5, cols: 25       |
      rows: 5, cols: 40        │rows: 5, cols: 50       |
      rows: 5, cols: 25        │rows: 2, cols: 50       |
      ^                         │rows: 5, cols: 25       |
      {17:foo [-]                   }{18:foo [-]                 }|
      {3:-- TERMINAL --}                                    |
    ]])
    command('tab split')
    screen:expect([[
      {19: }{20:2}{19: foo }{3: foo }{1:                                     }{19:X}|
      rows: 5, cols: 25                                 |
      rows: 5, cols: 40                                 |
      rows: 5, cols: 25                                 |
      rows: 5, cols: 50                                 |
      ^                                                  |
      {3:-- TERMINAL --}                                    |
    ]])
    command('tabfirst | tabonly')
    screen:expect([[
      rows: 5, cols: 40        │tty ready               |
      rows: 5, cols: 25        │rows: 5, cols: 25       |
      rows: 5, cols: 50        │rows: 5, cols: 50       |
      rows: 5, cols: 25        │rows: 2, cols: 50       |
      ^                         │rows: 5, cols: 25       |
      {17:foo [-]                   }{18:foo [-]                 }|
      {3:-- TERMINAL --}                                    |
    ]])

    -- Sizing logic should only consider the final buffer shown in a window, even if autocommands
    -- changed it at the last moment.
    exec_lua(function()
      vim.g.fired = 0
      vim.api.nvim_create_autocmd('BufHidden', {
        callback = function(ev)
          vim.api.nvim_win_set_buf(vim.fn.win_findbuf(ev.buf)[1], vim.fn.bufnr('foo'))
          vim.g.fired = vim.g.fired + 1
          return vim.g.fired == 2
        end,
      })
    end)
    command('botright new')
    screen:expect([[
      rows: 2, cols: 25        │rows: 5, cols: 25       |
                               │rows: 5, cols: 50       |
      {18:foo [-]                   foo [-]                 }|
      ^                                                  |
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
    ]])
    command('quit')
    eq(1, eval('g:fired'))
    screen:expect([[
      rows: 5, cols: 50        │tty ready               |
      rows: 5, cols: 25        │rows: 5, cols: 25       |
      rows: 2, cols: 25        │rows: 5, cols: 50       |
      rows: 5, cols: 25        │rows: 2, cols: 50       |
      ^                         │rows: 5, cols: 25       |
      {17:foo [-]                   }{18:foo [-]                 }|
                                                        |
    ]])
    -- Check it doesn't use the size of the closed window in the other tab page; size should only
    -- change via the :wincmd below. Hide tabline so it doesn't affect sizes.
    command('set showtabline=0 | tabnew | tabprevious | wincmd > | tabonly')
    eq(2, eval('g:fired'))
    screen:expect([[
      rows: 5, cols: 25         │tty ready              |
      rows: 2, cols: 25         │rows: 5, cols: 25      |
      rows: 5, cols: 25         │rows: 5, cols: 50      |
      rows: 5, cols: 26         │rows: 2, cols: 50      |
      ^                          │rows: 5, cols: 25      |
      {17:foo [-]                    }{18:foo [-]                }|
                                                        |
    ]])
    n.expect([[
      tty ready
      rows: 5, cols: 25
      rows: 5, cols: 50
      rows: 2, cols: 50
      rows: 5, cols: 25
      rows: 5, cols: 40
      rows: 5, cols: 25
      rows: 5, cols: 50
      rows: 5, cols: 25
      rows: 2, cols: 25
      rows: 5, cols: 25
      rows: 5, cols: 26
      ]])
  end)

  it('restores window options when switching terminals', function()
    -- Make this a screen test to also check for proper redrawing.
    screen:set_default_attr_ids({
      [1] = { bold = true },
      [2] = { foreground = Screen.colors.Gray0, background = 7, underline = true },
      [3] = { foreground = 5, background = 7, underline = true },
      [4] = { reverse = true },
      [5] = { bold = true, foreground = 5 },
      [6] = { foreground = 12 },
      [7] = { reverse = true, bold = true },
      [12] = { underline = true },
      [17] = { foreground = Screen.colors.Gray0, background = 2 },
      [18] = { foreground = 8, background = 2 },
      [19] = { background = 7 },
    })

    feed([[<C-\><C-N>]])
    command([[
      file foo
      setlocal cursorline
      vsplit
      setlocal nocursorline cursorcolumn cursorlineopt=number
    ]])
    screen:expect([[
      {19:t}ty ready                │tty ready               |
      ^rows: 5, cols: 25        │{12:rows: 5, cols: 25       }|
      {19: }                        │                        |*3
      {17:foo [-]                   }{18:foo [-]                 }|
                                                        |
    ]])

    feed('i')
    screen:expect([[
      tty ready                │tty ready               |
      rows: 5, cols: 25        │{12:rows: 5, cols: 25       }|
      ^                         │                        |
                               │                        |*2
      {17:foo [-]                   }{18:foo [-]                 }|
      {1:-- TERMINAL --}                                    |
    ]])
    command('wincmd p')
    screen:expect([[
      {19:t}ty ready                │tty ready               |
      {19:r}ows: 5, cols: 25        │rows: 5, cols: 25       |
                               │^                        |
      {19: }                        │                        |*2
      {18:foo [-]                   }{17:foo [-]                 }|
      {1:-- TERMINAL --}                                    |
    ]])
    feed([[<C-\><C-N>]])
    screen:expect([[
      {19:t}ty ready                │tty ready               |
      {19:r}ows: 5, cols: 25        │rows: 5, cols: 25       |
                               │{12:^                        }|
      {19: }                        │                        |*2
      {18:foo [-]                   }{17:foo [-]                 }|
                                                        |
    ]])

    -- Ensure things work when switching tabpages.
    command('tab split | setlocal cursorline cursorcolumn')
    screen:expect([[
      {2: }{3:2}{2: foo }{1: foo }{4:                                     }{2:X}|
      {19:t}ty ready                                         |
      {19:r}ows: 5, cols: 25                                 |
      {12:^rows: 5, cols: 50                                 }|
      {19: }                                                 |*2
                                                        |
    ]])
    feed('i')
    screen:expect([[
      {2: }{3:2}{2: foo }{1: foo }{4:                                     }{2:X}|
      tty ready                                         |
      rows: 5, cols: 25                                 |
      rows: 5, cols: 50                                 |
      ^                                                  |
                                                        |
      {1:-- TERMINAL --}                                    |
    ]])
    command('tabprevious')
    screen:expect([[
      {1: }{5:2}{1: foo }{2: foo }{4:                                     }{2:X}|
      {19:r}ows: 5, cols: 25        │rows: 5, cols: 25       |
      rows: 5, cols: 50        │rows: 5, cols: 50       |
      {19: }                        │^                        |
      {19: }                        │                        |
      {18:foo [-]                   }{17:foo [-]                 }|
      {1:-- TERMINAL --}                                    |
    ]])
    feed([[<C-\><C-N>]])
    screen:expect([[
      {1: }{5:2}{1: foo }{2: foo }{4:                                     }{2:X}|
      {19:r}ows: 5, cols: 25        │rows: 5, cols: 25       |
      rows: 5, cols: 50        │rows: 5, cols: 50       |
      {19: }                        │{12:^                        }|
      {19: }                        │                        |
      {18:foo [-]                   }{17:foo [-]                 }|
                                                        |
    ]])
    command('tabnext')
    screen:expect([[
      {2: }{3:2}{2: foo }{1: foo }{4:                                     }{2:X}|
      {19:t}ty ready                                         |
      {19:r}ows: 5, cols: 25                                 |
      {19:r}ows: 5, cols: 50                                 |
      {12:^                                                  }|
      {19: }                                                 |
                                                        |
    ]])

    -- Closing windows shouldn't break things.
    command('tabprevious')
    feed('i')
    screen:expect([[
      {1: }{5:2}{1: foo }{2: foo }{4:                                     }{2:X}|
      {19:r}ows: 5, cols: 25        │rows: 5, cols: 25       |
      rows: 5, cols: 50        │rows: 5, cols: 50       |
      {19: }                        │^                        |
      {19: }                        │                        |
      {18:foo [-]                   }{17:foo [-]                 }|
      {1:-- TERMINAL --}                                    |
    ]])
    command('quit')
    screen:expect([[
      {1: foo }{2: foo }{4:                                       }{2:X}|
      tty ready                                         |
      rows: 5, cols: 25                                 |
      rows: 5, cols: 50                                 |
      ^                                                  |
                                                        |
      {1:-- TERMINAL --}                                    |
    ]])
    feed([[<C-\><C-N>]])
    screen:expect([[
      {1: foo }{2: foo }{4:                                       }{2:X}|
      {19:t}ty ready                                         |
      {19:r}ows: 5, cols: 25                                 |
      {19:r}ows: 5, cols: 50                                 |
      ^                                                  |
      {19: }                                                 |
                                                        |
    ]])

    -- Switching to a non-terminal.
    command('vnew')
    feed([[<C-W>pi]])
    screen:expect([[
      {1: }{5:2}{1: foo }{2: foo }{4:                                     }{2:X}|
                               │rows: 5, cols: 25       |
      {6:~                        }│rows: 5, cols: 50       |
      {6:~                        }│^                        |
      {6:~                        }│                        |
      {4:[No Name]                 }{17:foo [-]                 }|
      {1:-- TERMINAL --}                                    |
    ]])
    command('wincmd p')
    screen:expect([[
      {1: }{5:2}{1: [No Name] }{2: foo }{4:                               }{2:X}|
      ^                         │{19:r}ows: 5, cols: 25       |
      {6:~                        }│{19:r}ows: 5, cols: 50       |
      {6:~                        }│                        |
      {6:~                        }│{19: }                       |
      {7:[No Name]                 }{18:foo [-]                 }|
                                                        |
    ]])

    command('wincmd l | enew | setlocal cursorline nocursorcolumn')
    screen:expect([[
      {1: }{5:2}{1: [No Name] }{2: foo }{4:                               }{2:X}|
                               │{12:^                        }|
      {6:~                        }│{6:~                       }|*3
      {4:[No Name]                 }{7:[No Name]               }|
                                                        |
    ]])
    command('buffer # | startinsert')
    screen:expect([[
      {1: }{5:2}{1: foo }{2: foo }{4:                                     }{2:X}|
                               │rows: 5, cols: 25       |
      {6:~                        }│rows: 5, cols: 50       |
      {6:~                        }│^                        |
      {6:~                        }│                        |
      {4:[No Name]                 }{17:foo [-]                 }|
      {1:-- TERMINAL --}                                    |
    ]])
    -- Switching to another buffer shouldn't change window options there. #37484
    command('buffer # | call setline(1, ["aaa", "bbb", "ccc"]) | normal! jl')
    screen:expect([[
      {1: }{5:2}{1:+ [No Name] }{2: foo }{4:                              }{2:X}|
                               │aaa                     |
      {6:~                        }│{12:b^bb                     }|
      {6:~                        }│ccc                     |
      {6:~                        }│{6:~                       }|
      {4:[No Name]                 }{7:[No Name] [+]           }|
                                                        |
    ]])
    -- Window options are restored when switching back to the terminal buffer.
    command('buffer #')
    screen:expect([[
      {1: }{5:2}{1: foo }{2: foo }{4:                                     }{2:X}|
                               │{19:r}ows: 5, cols: 25       |
      {6:~                        }│{19:r}ows: 5, cols: 50       |
      {6:~                        }│^                        |
      {6:~                        }│{19: }                       |
      {4:[No Name]                 }{17:foo [-]                 }|
                                                        |
    ]])
    -- 'cursorlineopt' should still be "number".
    eq('number', eval('&l:cursorlineopt'))
  end)

  it('not unnecessarily redrawn by events', function()
    eq('t', eval('mode()'))
    exec_lua(function()
      _G.redraws = {}
      local ns = vim.api.nvim_create_namespace('test')
      vim.api.nvim_set_decoration_provider(ns, {
        on_start = function()
          table.insert(_G.redraws, 'start')
        end,
        on_win = function(_, win)
          table.insert(_G.redraws, 'win ' .. win)
        end,
        on_end = function()
          table.insert(_G.redraws, 'end')
        end,
      })
      -- Setting a decoration provider typically causes an initial redraw.
      vim.cmd.redraw()
      _G.redraws = {}
    end)

    -- The event we sent above to set up the test shouldn't have caused a redraw.
    -- For good measure, also poke the event loop.
    poke_eventloop()
    eq({}, exec_lua('return _G.redraws'))

    -- Redraws if we do something useful, of course.
    feed_data('foo')
    screen:expect { any = 'foo' }
    eq({ 'start', 'win 1000', 'end' }, exec_lua('return _G.redraws'))
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
