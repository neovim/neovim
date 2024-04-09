local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local exec = t.exec
local exec_lua = t.exec_lua
local command = t.command
local feed = t.feed

-- oldtest: Test_window_cmd_ls0_split_scrolling()
it('scrolling with laststatus=0 and :botright split', function()
  clear('--cmd', 'set ruler')
  local screen = Screen.new(40, 10)
  screen:attach()
  exec([[
    set laststatus=0
    call setline(1, range(1, 100))
    normal! G
  ]])
  command('botright split')
  screen:expect([[
    97                                      |
    98                                      |
    99                                      |
    100                                     |
    {2:[No Name] [+]         100,1          Bot}|
    97                                      |
    98                                      |
    99                                      |
    ^100                                     |
                          100,1         Bot |
  ]])
end)

describe('splitkeep', function()
  local screen

  before_each(function()
    clear('--cmd', 'set splitkeep=screen')
    screen = Screen.new()
    screen:attach()
  end)

  -- oldtest: Test_splitkeep_cursor()
  it('does not adjust cursor in window that did not change size', function()
    screen:try_resize(75, 8)
    -- FIXME: bottom window is different without the "vsplit | close"
    exec([[
      vsplit | close
      set scrolloff=5
      set splitkeep=screen
      autocmd CursorMoved * wincmd p | wincmd p
      call setline(1, range(1, 200))
      func CursorEqualize()
        call cursor(100, 1)
        wincmd =
      endfunc
      wincmd s
      call CursorEqualize()
    ]])

    screen:expect([[
      99                                                                         |
      ^100                                                                        |
      101                                                                        |
      {3:[No Name] [+]                                                              }|
      5                                                                          |
      6                                                                          |
      {2:[No Name] [+]                                                              }|
                                                                                 |
    ]])

    feed('j')
    screen:expect([[
      100                                                                        |
      ^101                                                                        |
      102                                                                        |
      {3:[No Name] [+]                                                              }|
      5                                                                          |
      6                                                                          |
      {2:[No Name] [+]                                                              }|
                                                                                 |
    ]])

    command('set scrolloff=0')
    feed('G')
    screen:expect([[
      198                                                                        |
      199                                                                        |
      ^200                                                                        |
      {3:[No Name] [+]                                                              }|
      5                                                                          |
      6                                                                          |
      {2:[No Name] [+]                                                              }|
                                                                                 |
    ]])
  end)

  -- oldtest: Test_splitkeep_callback()
  it('does not scroll when split in callback', function()
    exec([[
      call setline(1, range(&lines))
      function C1(a, b, c)
        split | wincmd p
      endfunction
      function C2(a, b, c)
        close | split
      endfunction
    ]])
    exec_lua([[
      vim.api.nvim_set_keymap("n", "j", "", { callback = function()
        vim.cmd("call jobstart([&sh, &shcf, 'true'], { 'on_exit': 'C1' })")
      end
    })]])
    exec_lua([[
      vim.api.nvim_set_keymap("n", "t", "", { callback = function()
        vim.api.nvim_set_current_win(
          vim.api.nvim_open_win(vim.api.nvim_create_buf(false, {}), false, {
          width = 10,
            relative = "cursor",
            height = 4,
            row = 0,
            col = 0,
          }))
          vim.cmd("call termopen([&sh, &shcf, 'true'], { 'on_exit': 'C2' })")
      end
    })]])
    feed('j')
    screen:expect([[
      0                                                    |
      1                                                    |
      2                                                    |
      3                                                    |
      4                                                    |
      5                                                    |
      {2:[No Name] [+]                                        }|
      ^7                                                    |
      8                                                    |
      9                                                    |
      10                                                   |
      11                                                   |
      {3:[No Name] [+]                                        }|
                                                           |
    ]])
    feed(':quit<CR>Ht')
    screen:expect([[
      ^0                                                    |
      1                                                    |
      2                                                    |
      3                                                    |
      4                                                    |
      5                                                    |
      {3:[No Name] [+]                                        }|
      7                                                    |
      8                                                    |
      9                                                    |
      10                                                   |
      11                                                   |
      {2:[No Name] [+]                                        }|
      :quit                                                |
    ]])
    feed(':set sb<CR>:quit<CR>Gj')
    screen:expect([[
      1                                                    |
      2                                                    |
      3                                                    |
      4                                                    |
      ^5                                                    |
      {3:[No Name] [+]                                        }|
      7                                                    |
      8                                                    |
      9                                                    |
      10                                                   |
      11                                                   |
      12                                                   |
      {2:[No Name] [+]                                        }|
      :quit                                                |
    ]])
    feed(':quit<CR>Gt')
    screen:expect([[
      1                                                    |
      2                                                    |
      3                                                    |
      4                                                    |
      5                                                    |
      {2:[No Name] [+]                                        }|
      7                                                    |
      8                                                    |
      9                                                    |
      10                                                   |
      11                                                   |
      ^12                                                   |
      {3:[No Name] [+]                                        }|
      :quit                                                |
    ]])
  end)

  -- oldtest: Test_splitkeep_fold()
  it('does not scroll when window has closed folds', function()
    exec([[
      set commentstring=/*%s*/
      set splitkeep=screen
      set foldmethod=marker
      set number
      let line = 1
      for n in range(1, &lines)
        call setline(line, ['int FuncName() {/*{{{*/', 1, 2, 3, 4, 5, '}/*}}}*/',
              \ 'after fold'])
        let line += 8
      endfor
    ]])
    feed('L:wincmd s<CR>')
    screen:expect([[
      {8:  1 }{13:+--  7 lines: int FuncName() {···················}|
      {8:  8 }after fold                                       |
      {8:  9 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 16 }after fold                                       |
      {8: 17 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 24 }^after fold                                       |
      {3:[No Name] [+]                                        }|
      {8: 32 }after fold                                       |
      {8: 33 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 40 }after fold                                       |
      {8: 41 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 48 }after fold                                       |
      {2:[No Name] [+]                                        }|
      :wincmd s                                            |
    ]])
    feed(':quit<CR>')
    screen:expect([[
      {8:  1 }{13:+--  7 lines: int FuncName() {···················}|
      {8:  8 }after fold                                       |
      {8:  9 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 16 }after fold                                       |
      {8: 17 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 24 }after fold                                       |
      {8: 25 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 32 }after fold                                       |
      {8: 33 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 40 }after fold                                       |
      {8: 41 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 48 }after fold                                       |
      {8: 49 }{13:^+--  7 lines: int FuncName() {···················}|
      :quit                                                |
    ]])
    feed('H:below split<CR>')
    screen:expect([[
      {8:  1 }{13:+--  7 lines: int FuncName() {···················}|
      {8:  8 }after fold                                       |
      {8:  9 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 16 }after fold                                       |
      {8: 17 }{13:+--  7 lines: int FuncName() {···················}|
      {2:[No Name] [+]                                        }|
      {8: 25 }{13:^+--  7 lines: int FuncName() {···················}|
      {8: 32 }after fold                                       |
      {8: 33 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 40 }after fold                                       |
      {8: 41 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 48 }after fold                                       |
      {3:[No Name] [+]                                        }|
      :below split                                         |
    ]])
    feed(':wincmd k<CR>:quit<CR>')
    screen:expect([[
      {8:  1 }{13:+--  7 lines: int FuncName() {···················}|
      {8:  8 }after fold                                       |
      {8:  9 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 16 }after fold                                       |
      {8: 17 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 24 }after fold                                       |
      {8: 25 }{13:^+--  7 lines: int FuncName() {···················}|
      {8: 32 }after fold                                       |
      {8: 33 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 40 }after fold                                       |
      {8: 41 }{13:+--  7 lines: int FuncName() {···················}|
      {8: 48 }after fold                                       |
      {8: 49 }{13:+--  7 lines: int FuncName() {···················}|
      :quit                                                |
    ]])
  end)

  -- oldtest: Test_splitkeep_status()
  it('does not scroll when split in callback', function()
    exec([[
      call setline(1, ['a', 'b', 'c'])
      set nomodified
      set splitkeep=screen
      let win = winnr()
      wincmd s
      wincmd j
    ]])
    feed(':call win_move_statusline(win, 1)<CR>')
    screen:expect([[
      a                                                    |
      b                                                    |
      c                                                    |
      {1:~                                                    }|*4
      {2:[No Name]                                            }|
      ^a                                                    |
      b                                                    |
      c                                                    |
      {1:~                                                    }|
      {3:[No Name]                                            }|
                                                           |
    ]])
  end)

  -- oldtest: Test_splitkeep_skipcol()
  it('skipcol is not reset unnecessarily and is copied to new window', function()
    screen:try_resize(40, 12)
    exec([[
      set splitkeep=topline smoothscroll splitbelow scrolloff=0
      call setline(1, 'with lots of text in one line '->repeat(6))
      norm 2
      wincmd s
    ]])
    screen:expect([[
      {1:<<<}e line with lots of text in one line |
      with lots of text in one line with lots |
      of text in one line                     |
      {1:~                                       }|
      {2:[No Name] [+]                           }|
      {1:<<<}e line with lots of text in one line |
      ^with lots of text in one line with lots |
      of text in one line                     |
      {1:~                                       }|*2
      {3:[No Name] [+]                           }|
                                              |
    ]])
  end)
end)
