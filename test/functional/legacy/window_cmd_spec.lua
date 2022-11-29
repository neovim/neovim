local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local exec_lua = helpers.exec_lua
local feed = helpers.feed

describe('splitkeep', function()
  local screen

  before_each(function()
    clear('--cmd', 'set splitkeep=screen')
    screen = Screen.new()
    screen:attach()
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
      [No Name] [+]                                        |
      ^7                                                    |
      8                                                    |
      9                                                    |
      10                                                   |
      11                                                   |
      [No Name] [+]                                        |
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
      [No Name] [+]                                        |
      7                                                    |
      8                                                    |
      9                                                    |
      10                                                   |
      11                                                   |
      [No Name] [+]                                        |
      :quit                                                |
    ]])
    feed(':set sb<CR>:quit<CR>Gj')
    screen:expect([[
      1                                                    |
      2                                                    |
      3                                                    |
      4                                                    |
      ^5                                                    |
      [No Name] [+]                                        |
      7                                                    |
      8                                                    |
      9                                                    |
      10                                                   |
      11                                                   |
      12                                                   |
      [No Name] [+]                                        |
      :quit                                                |
    ]])
    feed(':quit<CR>Gt')
    screen:expect([[
      1                                                    |
      2                                                    |
      3                                                    |
      4                                                    |
      5                                                    |
      [No Name] [+]                                        |
      7                                                    |
      8                                                    |
      9                                                    |
      10                                                   |
      11                                                   |
      ^12                                                   |
      [No Name] [+]                                        |
      :quit                                                |
    ]])
  end)

  -- oldtest: Test_splitkeep_fold()
  it('does not scroll when window has closed folds', function()
    exec([[
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
        1 +--  7 lines: int FuncName() {···················|
        8 after fold                                       |
        9 +--  7 lines: int FuncName() {···················|
       16 after fold                                       |
       17 +--  7 lines: int FuncName() {···················|
       24 ^after fold                                       |
      [No Name] [+]                                        |
       32 after fold                                       |
       33 +--  7 lines: int FuncName() {···················|
       40 after fold                                       |
       41 +--  7 lines: int FuncName() {···················|
       48 after fold                                       |
      [No Name] [+]                                        |
      :wincmd s                                            |
    ]])
    feed(':quit<CR>')
    screen:expect([[
        1 +--  7 lines: int FuncName() {···················|
        8 after fold                                       |
        9 +--  7 lines: int FuncName() {···················|
       16 after fold                                       |
       17 +--  7 lines: int FuncName() {···················|
       24 after fold                                       |
       25 +--  7 lines: int FuncName() {···················|
       32 after fold                                       |
       33 +--  7 lines: int FuncName() {···················|
       40 after fold                                       |
       41 +--  7 lines: int FuncName() {···················|
       48 after fold                                       |
       49 ^+--  7 lines: int FuncName() {···················|
      :quit                                                |
    ]])
    feed('H:below split<CR>')
    screen:expect([[
        1 +--  7 lines: int FuncName() {···················|
        8 after fold                                       |
        9 +--  7 lines: int FuncName() {···················|
       16 after fold                                       |
       17 +--  7 lines: int FuncName() {···················|
      [No Name] [+]                                        |
       25 ^+--  7 lines: int FuncName() {···················|
       32 after fold                                       |
       33 +--  7 lines: int FuncName() {···················|
       40 after fold                                       |
       41 +--  7 lines: int FuncName() {···················|
       48 after fold                                       |
      [No Name] [+]                                        |
      :below split                                         |
    ]])
    feed(':wincmd k<CR>:quit<CR>')
    screen:expect([[
        1 +--  7 lines: int FuncName() {···················|
        8 after fold                                       |
        9 +--  7 lines: int FuncName() {···················|
       16 after fold                                       |
       17 +--  7 lines: int FuncName() {···················|
       24 after fold                                       |
       25 ^+--  7 lines: int FuncName() {···················|
       32 after fold                                       |
       33 +--  7 lines: int FuncName() {···················|
       40 after fold                                       |
       41 +--  7 lines: int FuncName() {···················|
       48 after fold                                       |
       49 +--  7 lines: int FuncName() {···················|
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
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      [No Name]                                            |
      ^a                                                    |
      b                                                    |
      c                                                    |
      ~                                                    |
      [No Name]                                            |
                                                           |
    ]])
  end)
end)
