local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local t_lsp = require('test.functional.plugin.lsp.testutil')

local eq = t.eq
local tempname = t.tmpname

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

local api = n.api
local exec_lua = n.exec_lua
local insert = n.insert
local command = n.command
local feed = n.feed

describe('vim.lsp.folding_range', function()
  local text = [[// foldLevel() {{{2
/// @return  fold level at line number "lnum" in the current window.
static int foldLevel(linenr_T lnum)
{
  // While updating the folds lines between invalid_top and invalid_bot have
  // an undefined fold level.  Otherwise update the folds first.
  if (invalid_top == 0) {
    checkupdate(curwin);
  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {
    return prev_lnum_lvl;
  } else if (lnum >= invalid_top && lnum <= invalid_bot) {
    return -1;
  }

  // Return quickly when there is no folding at all in this window.
  if (!hasAnyFolding(curwin)) {
    return 0;
  }

  return foldLevelWin(curwin, lnum);
}]]

  local result = {
    {
      endLine = 19,
      kind = 'region',
      startCharacter = 1,
      startLine = 3,
    },
    {
      endCharacter = 2,
      endLine = 7,
      kind = 'region',
      startCharacter = 25,
      startLine = 6,
    },
    {
      endCharacter = 2,
      endLine = 9,
      kind = 'region',
      startCharacter = 55,
      startLine = 8,
    },
    {
      endCharacter = 2,
      endLine = 11,
      kind = 'region',
      startCharacter = 58,
      startLine = 10,
    },
    {
      endCharacter = 2,
      endLine = 16,
      kind = 'region',
      startCharacter = 31,
      startLine = 15,
    },
    {
      endCharacter = 68,
      endLine = 1,
      kind = 'comment',
      startCharacter = 2,
      startLine = 0,
    },
    {
      endCharacter = 64,
      endLine = 5,
      kind = 'comment',
      startCharacter = 4,
      startLine = 4,
    },
  }

  local bufnr ---@type integer
  local client_id ---@type integer

  clear_notrace()
  before_each(function()
    clear_notrace()

    exec_lua(create_server_definition)
    bufnr = n.api.nvim_get_current_buf()
    client_id = exec_lua(function()
      _G.server = _G._create_server({
        capabilities = {
          foldingRangeProvider = true,
        },
        handlers = {
          ['textDocument/foldingRange'] = function(_, _, callback)
            callback(nil, result)
          end,
        },
      })

      vim.api.nvim_win_set_buf(0, bufnr)

      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)
    command('set foldmethod=expr foldcolumn=1 foldlevel=999')
    insert(text)
  end)
  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  describe('setup()', function()
    ---@type integer
    local bufnr_set_expr
    ---@type integer
    local bufnr_never_set_expr

    local function buf_autocmd_num(bufnr_to_check)
      return exec_lua(function()
        return #vim.api.nvim_get_autocmds({ buffer = bufnr_to_check, event = 'LspNotify' })
      end)
    end

    before_each(function()
      command([[setlocal foldexpr=v:lua.vim.lsp.foldexpr()]])
      exec_lua(function()
        bufnr_set_expr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(bufnr_set_expr)
      end)
      insert(text)
      command('write ' .. tempname(false))
      command([[setlocal foldexpr=v:lua.vim.lsp.foldexpr()]])
      exec_lua(function()
        bufnr_never_set_expr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(bufnr_never_set_expr)
      end)
      insert(text)
      api.nvim_win_set_buf(0, bufnr_set_expr)
    end)

    it('only create event hooks where foldexpr has been set', function()
      eq(1, buf_autocmd_num(bufnr))
      eq(1, buf_autocmd_num(bufnr_set_expr))
      eq(0, buf_autocmd_num(bufnr_never_set_expr))
    end)

    it('does not create duplicate event hooks after reloaded', function()
      command('edit')
      eq(1, buf_autocmd_num(bufnr_set_expr))
    end)

    it('cleans up event hooks when buffer is unloaded', function()
      command('bdelete')
      eq(0, buf_autocmd_num(bufnr_set_expr))
    end)
  end)

  describe('expr()', function()
    --- @type test.functional.ui.screen
    local screen
    before_each(function()
      screen = Screen.new(80, 45)
      screen:set_default_attr_ids({
        [1] = { background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue },
        [2] = { bold = true, foreground = Screen.colors.Blue1 },
        [3] = { bold = true, reverse = true },
        [4] = { reverse = true },
      })
      command([[set foldexpr=v:lua.vim.lsp.foldexpr()]])
      command([[split]])
    end)

    it('can compute fold levels', function()
      ---@type table<integer, string>
      local foldlevels = {}
      for i = 1, 21 do
        foldlevels[i] = exec_lua('return vim.lsp.foldexpr(' .. i .. ')')
      end
      eq({
        [1] = '>1',
        [2] = '<1',
        [3] = '0',
        [4] = '>1',
        [5] = '>2',
        [6] = '<2',
        [7] = '>2',
        [8] = '<2',
        [9] = '>2',
        [10] = '<2',
        [11] = '>2',
        [12] = '<2',
        [13] = '1',
        [14] = '1',
        [15] = '1',
        [16] = '>2',
        [17] = '<2',
        [18] = '1',
        [19] = '1',
        [20] = '<1',
        [21] = '0',
      }, foldlevels)
    end)

    it('updates folds in all windows', function()
      screen:expect({
        grid = [[
{1:-}// foldLevel() {{{2                                                            |
{1:│}/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
{1:2}  // an undefined fold level.  Otherwise update the folds first.               |
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }^}                                                                              |
{3:[No Name] [+]                                                                   }|
{1:-}// foldLevel() {{{2                                                            |
{1:│}/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
{1:2}  // an undefined fold level.  Otherwise update the folds first.               |
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }}                                                                              |
{4:[No Name] [+]                                                                   }|
                                                                                |
  ]],
      })
    end)

    it('persists wherever foldexpr is set', function()
      command([[setlocal foldexpr=]])
      feed('<C-w><C-w>zx')
      screen:expect({
        grid = [[
{1: }// foldLevel() {{{2                                                            |
{1: }/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1: }{                                                                              |
{1: }  // While updating the folds lines between invalid_top and invalid_bot have   |
{1: }  // an undefined fold level.  Otherwise update the folds first.               |
{1: }  if (invalid_top == 0) {                                                      |
{1: }    checkupdate(curwin);                                                       |
{1: }  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1: }    return prev_lnum_lvl;                                                      |
{1: }  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1: }    return -1;                                                                 |
{1: }  }                                                                            |
{1: }                                                                               |
{1: }  // Return quickly when there is no folding at all in this window.            |
{1: }  if (!hasAnyFolding(curwin)) {                                                |
{1: }    return 0;                                                                  |
{1: }  }                                                                            |
{1: }                                                                               |
{1: }  return foldLevelWin(curwin, lnum);                                           |
{1: }}                                                                              |
{4:[No Name] [+]                                                                   }|
{1:-}// foldLevel() {{{2                                                            |
{1:│}/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
{1:2}  // an undefined fold level.  Otherwise update the folds first.               |
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }^}                                                                              |
{3:[No Name] [+]                                                                   }|
                                                                                |
  ]],
      })
    end)

    it('synchronizes changed rows with their previous foldlevels', function()
      command('1,2d')
      screen:expect({
        grid = [[
{1: }^static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
{1:2}  // an undefined fold level.  Otherwise update the folds first.               |
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }}                                                                              |
{2:~                                                                               }|*2
{3:[No Name] [+]                                                                   }|
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
{1:2}  // an undefined fold level.  Otherwise update the folds first.               |
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }}                                                                              |
{2:~                                                                               }|*2
{4:[No Name] [+]                                                                   }|
                                                                                |
]],
      })
    end)

    it('clears folds when sole client detaches', function()
      exec_lua(function()
        vim.lsp.buf_detach_client(bufnr, client_id)
      end)
      screen:expect({
        grid = [[
{1: }// foldLevel() {{{2                                                            |
{1: }/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1: }{                                                                              |
{1: }  // While updating the folds lines between invalid_top and invalid_bot have   |
{1: }  // an undefined fold level.  Otherwise update the folds first.               |
{1: }  if (invalid_top == 0) {                                                      |
{1: }    checkupdate(curwin);                                                       |
{1: }  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1: }    return prev_lnum_lvl;                                                      |
{1: }  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1: }    return -1;                                                                 |
{1: }  }                                                                            |
{1: }                                                                               |
{1: }  // Return quickly when there is no folding at all in this window.            |
{1: }  if (!hasAnyFolding(curwin)) {                                                |
{1: }    return 0;                                                                  |
{1: }  }                                                                            |
{1: }                                                                               |
{1: }  return foldLevelWin(curwin, lnum);                                           |
{1: }^}                                                                              |
{3:[No Name] [+]                                                                   }|
{1: }// foldLevel() {{{2                                                            |
{1: }/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1: }{                                                                              |
{1: }  // While updating the folds lines between invalid_top and invalid_bot have   |
{1: }  // an undefined fold level.  Otherwise update the folds first.               |
{1: }  if (invalid_top == 0) {                                                      |
{1: }    checkupdate(curwin);                                                       |
{1: }  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1: }    return prev_lnum_lvl;                                                      |
{1: }  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1: }    return -1;                                                                 |
{1: }  }                                                                            |
{1: }                                                                               |
{1: }  // Return quickly when there is no folding at all in this window.            |
{1: }  if (!hasAnyFolding(curwin)) {                                                |
{1: }    return 0;                                                                  |
{1: }  }                                                                            |
{1: }                                                                               |
{1: }  return foldLevelWin(curwin, lnum);                                           |
{1: }}                                                                              |
{4:[No Name] [+]                                                                   }|
                                                                                |
  ]],
      })
    end)

    it('remains valid after the client re-attaches.', function()
      exec_lua(function()
        vim.lsp.buf_detach_client(bufnr, client_id)
        vim.lsp.buf_attach_client(bufnr, client_id)
      end)
      screen:expect({
        grid = [[
{1:-}// foldLevel() {{{2                                                            |
{1:│}/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
{1:2}  // an undefined fold level.  Otherwise update the folds first.               |
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }^}                                                                              |
{3:[No Name] [+]                                                                   }|
{1:-}// foldLevel() {{{2                                                            |
{1:│}/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
{1:2}  // an undefined fold level.  Otherwise update the folds first.               |
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }}                                                                              |
{4:[No Name] [+]                                                                   }|
                                                                                |
  ]],
      })
    end)
  end)

  describe('foldtext()', function()
    --- @type test.functional.ui.screen
    local screen
    before_each(function()
      screen = Screen.new(80, 23)
      screen:set_default_attr_ids({
        [1] = { background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue },
        [2] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey },
        [3] = { bold = true, foreground = Screen.colors.Blue1 },
        [4] = { bold = true, reverse = true },
        [5] = { reverse = true },
      })
      command(
        [[set foldexpr=v:lua.vim.lsp.foldexpr() foldtext=v:lua.vim.lsp.foldtext() foldlevel=1]]
      )
    end)

    it('shows the first folded line if `collapsedText` does not exist', function()
      screen:expect({
        grid = [[
{1:-}// foldLevel() {{{2                                                            |
{1:│}/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:+}{2:  // While updating the folds lines between invalid_top and invalid_bot have···}|
{1:+}{2:  if (invalid_top == 0) {······················································}|
{1:+}{2:  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {························}|
{1:+}{2:  } else if (lnum >= invalid_top && lnum <= invalid_bot) {·····················}|
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:+}{2:  if (!hasAnyFolding(curwin)) {················································}|
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }^}                                                                              |
{3:~                                                                               }|*6
                                                                                |
  ]],
      })
    end)
  end)

  describe('foldclose()', function()
    --- @type test.functional.ui.screen
    local screen
    before_each(function()
      screen = Screen.new(80, 23)
      screen:set_default_attr_ids({
        [1] = { background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue },
        [2] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey },
        [3] = { bold = true, foreground = Screen.colors.Blue1 },
        [4] = { bold = true, reverse = true },
        [5] = { reverse = true },
      })
      command([[set foldexpr=v:lua.vim.lsp.foldexpr()]])
    end)

    it('closes all folds of one kind immediately', function()
      exec_lua(function()
        vim.lsp.foldclose('comment')
      end)
      screen:expect({
        grid = [[
{1:+}{2:+--  2 lines: foldLevel()······················································}|
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:+}{2:+---  2 lines: While updating the folds lines between invalid_top and invalid_b}|
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }^}                                                                              |
{3:~                                                                               }|*3
                                                                                |
  ]],
      })
    end)

    it('closes the smallest fold first', function()
      exec_lua(function()
        vim.lsp.foldclose('region')
      end)
      screen:expect({
        grid = [[
{1:-}// foldLevel() {{{2                                                            |
{1:│}/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:+}{2:+-- 17 lines: {································································}|
{1: }^}                                                                              |
{3:~                                                                               }|*17
                                                                                |
  ]],
      })
      command('4foldopen')
      screen:expect({
        grid = [[
{1:-}// foldLevel() {{{2                                                            |
{1:│}/// @return  fold level at line number "lnum" in the current window.           |
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
{1:2}  // an undefined fold level.  Otherwise update the folds first.               |
{1:+}{2:+---  2 lines: if (invalid_top == 0) {·········································}|
{1:+}{2:+---  2 lines: } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {···········}|
{1:+}{2:+---  2 lines: } else if (lnum >= invalid_top && lnum <= invalid_bot) {········}|
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:+}{2:+---  2 lines: if (!hasAnyFolding(curwin)) {···································}|
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }^}                                                                              |
{3:~                                                                               }|*5
                                                                                |
  ]],
      })
    end)

    it('is deferred when the buffer is not up-to-date', function()
      exec_lua(function()
        vim.lsp.foldclose('comment')
        vim.lsp.util.buf_versions[bufnr] = 0
      end)
      screen:expect({
        grid = [[
{1:+}{2:+--  2 lines: foldLevel()······················································}|
{1: }static int foldLevel(linenr_T lnum)                                            |
{1:-}{                                                                              |
{1:+}{2:+---  2 lines: While updating the folds lines between invalid_top and invalid_b}|
{1:-}  if (invalid_top == 0) {                                                      |
{1:2}    checkupdate(curwin);                                                       |
{1:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
{1:2}    return prev_lnum_lvl;                                                      |
{1:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
{1:2}    return -1;                                                                 |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  // Return quickly when there is no folding at all in this window.            |
{1:-}  if (!hasAnyFolding(curwin)) {                                                |
{1:2}    return 0;                                                                  |
{1:│}  }                                                                            |
{1:│}                                                                               |
{1:│}  return foldLevelWin(curwin, lnum);                                           |
{1: }^}                                                                              |
{3:~                                                                               }|*3
                                                                                |
  ]],
      })
    end)
  end)
end)
