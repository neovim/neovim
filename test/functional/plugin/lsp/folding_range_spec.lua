local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local t_lsp = require('test.functional.plugin.lsp.testutil')

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local dedent = t.dedent
local eq = t.eq
local matches = t.matches
local retry = t.retry

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

  describe('expr()', function()
    --- @type test.functional.ui.screen
    local screen
    before_each(function()
      screen = Screen.new(80, 45)
      command([[set foldexpr=v:lua.vim.lsp.foldexpr()]])
      command([[split]])
    end)

    it('controls whether folding range is enabled', function()
      eq(
        true,
        exec_lua(function()
          return vim.lsp._capability.is_enabled('folding_range', { bufnr = 0 })
        end)
      )
      command [[setlocal foldexpr=]]
      eq(
        false,
        exec_lua(function()
          return vim.lsp._capability.is_enabled('folding_range', { bufnr = 0 })
        end)
      )
      command([[set foldexpr=v:lua.vim.lsp.foldexpr()]])
      eq(
        true,
        exec_lua(function()
          return vim.lsp._capability.is_enabled('folding_range', { bufnr = 0 })
        end)
      )
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
  {7:-}// foldLevel() {{{2                                                            |
  {7:│}/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7:2}  // an undefined fold level.  Otherwise update the folds first.               |
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }^}                                                                              |
  {3:[No Name] [+]                                                                   }|
  {7:-}// foldLevel() {{{2                                                            |
  {7:│}/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7:2}  // an undefined fold level.  Otherwise update the folds first.               |
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }}                                                                              |
  {2:[No Name] [+]                                                                   }|
                                                                                  |
  ]],
      })
    end)

    it('persists wherever foldexpr is set', function()
      command([[setlocal foldexpr=]])
      feed('<C-w><C-w>zx')
      screen:expect({
        grid = [[
  {7: }// foldLevel() {{{2                                                            |
  {7: }/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7: }{                                                                              |
  {7: }  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7: }  // an undefined fold level.  Otherwise update the folds first.               |
  {7: }  if (invalid_top == 0) {                                                      |
  {7: }    checkupdate(curwin);                                                       |
  {7: }  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7: }    return prev_lnum_lvl;                                                      |
  {7: }  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7: }    return -1;                                                                 |
  {7: }  }                                                                            |
  {7: }                                                                               |
  {7: }  // Return quickly when there is no folding at all in this window.            |
  {7: }  if (!hasAnyFolding(curwin)) {                                                |
  {7: }    return 0;                                                                  |
  {7: }  }                                                                            |
  {7: }                                                                               |
  {7: }  return foldLevelWin(curwin, lnum);                                           |
  {7: }}                                                                              |
  {2:[No Name] [+]                                                                   }|
  {7:-}// foldLevel() {{{2                                                            |
  {7:│}/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7:2}  // an undefined fold level.  Otherwise update the folds first.               |
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }^}                                                                              |
  {3:[No Name] [+]                                                                   }|
                                                                                  |
  ]],
      })
    end)

    it('synchronizes changed rows with their previous foldlevels', function()
      command('1,2d')
      screen:expect({
        grid = [[
  {7: }^static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7:2}  // an undefined fold level.  Otherwise update the folds first.               |
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }}                                                                              |
  {1:~                                                                               }|*2
  {3:[No Name] [+]                                                                   }|
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7:2}  // an undefined fold level.  Otherwise update the folds first.               |
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }}                                                                              |
  {1:~                                                                               }|*2
  {2:[No Name] [+]                                                                   }|
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
  {7: }// foldLevel() {{{2                                                            |
  {7: }/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7: }{                                                                              |
  {7: }  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7: }  // an undefined fold level.  Otherwise update the folds first.               |
  {7: }  if (invalid_top == 0) {                                                      |
  {7: }    checkupdate(curwin);                                                       |
  {7: }  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7: }    return prev_lnum_lvl;                                                      |
  {7: }  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7: }    return -1;                                                                 |
  {7: }  }                                                                            |
  {7: }                                                                               |
  {7: }  // Return quickly when there is no folding at all in this window.            |
  {7: }  if (!hasAnyFolding(curwin)) {                                                |
  {7: }    return 0;                                                                  |
  {7: }  }                                                                            |
  {7: }                                                                               |
  {7: }  return foldLevelWin(curwin, lnum);                                           |
  {7: }^}                                                                              |
  {3:[No Name] [+]                                                                   }|
  {7: }// foldLevel() {{{2                                                            |
  {7: }/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7: }{                                                                              |
  {7: }  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7: }  // an undefined fold level.  Otherwise update the folds first.               |
  {7: }  if (invalid_top == 0) {                                                      |
  {7: }    checkupdate(curwin);                                                       |
  {7: }  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7: }    return prev_lnum_lvl;                                                      |
  {7: }  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7: }    return -1;                                                                 |
  {7: }  }                                                                            |
  {7: }                                                                               |
  {7: }  // Return quickly when there is no folding at all in this window.            |
  {7: }  if (!hasAnyFolding(curwin)) {                                                |
  {7: }    return 0;                                                                  |
  {7: }  }                                                                            |
  {7: }                                                                               |
  {7: }  return foldLevelWin(curwin, lnum);                                           |
  {7: }}                                                                              |
  {2:[No Name] [+]                                                                   }|
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
  {7:-}// foldLevel() {{{2                                                            |
  {7:│}/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7:2}  // an undefined fold level.  Otherwise update the folds first.               |
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }^}                                                                              |
  {3:[No Name] [+]                                                                   }|
  {7:-}// foldLevel() {{{2                                                            |
  {7:│}/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7:2}  // an undefined fold level.  Otherwise update the folds first.               |
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }}                                                                              |
  {2:[No Name] [+]                                                                   }|
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
      command(
        [[set foldexpr=v:lua.vim.lsp.foldexpr() foldtext=v:lua.vim.lsp.foldtext() foldlevel=1]]
      )
    end)

    it('shows the first folded line if `collapsedText` does not exist', function()
      screen:expect({
        grid = [[
  {7:-}// foldLevel() {{{2                                                            |
  {7:│}/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:+}{13:  // While updating the folds lines between invalid_top and invalid_bot have···}|
  {7:+}{13:  if (invalid_top == 0) {······················································}|
  {7:+}{13:  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {························}|
  {7:+}{13:  } else if (lnum >= invalid_top && lnum <= invalid_bot) {·····················}|
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:+}{13:  if (!hasAnyFolding(curwin)) {················································}|
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }^}                                                                              |
  {1:~                                                                               }|*6
                                                                                  |
  ]],
      })
    end)

    it('shows the foldtext by virt line', function()
      command([[set filetype=c]])
      eq(
        {
          { '  ' },
          { 'if', { '@keyword.conditional.c' } },
          { ' ' },
          { '(', { '@punctuation.bracket.c' } },
          { '!', { '@operator.c' } },
          { 'hasAnyFolding', { '@variable.c', '@function.call.c' } },
          { '(', { '@punctuation.bracket.c' } },
          { 'curwin', { '@variable.c' } },
          { ')', { '@punctuation.bracket.c' } },
          { ')', { '@punctuation.bracket.c' } },
          { ' ' },
          { '{', { '@punctuation.bracket.c' } },
        },
        exec_lua(function()
          return vim.lsp.foldtext(16)
        end)
      )
    end)
  end)

  describe('foldclose()', function()
    --- @type test.functional.ui.screen
    local screen
    before_each(function()
      screen = Screen.new(80, 23)
      command([[set foldexpr=v:lua.vim.lsp.foldexpr()]])
    end)

    it('closes all folds of one kind immediately', function()
      exec_lua(function()
        vim.lsp.foldclose('comment')
      end)
      screen:expect({
        grid = [[
  {7:+}{13:+--  2 lines: foldLevel()······················································}|
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:+}{13:+---  2 lines: While updating the folds lines between invalid_top and invalid_b}|
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }^}                                                                              |
  {1:~                                                                               }|*3
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
  {7:-}// foldLevel() {{{2                                                            |
  {7:│}/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:+}{13:+-- 17 lines: {································································}|
  {7: }^}                                                                              |
  {1:~                                                                               }|*17
                                                                                  |
  ]],
      })
      command('4foldopen')
      screen:expect({
        grid = [[
  {7:-}// foldLevel() {{{2                                                            |
  {7:│}/// @return  fold level at line number "lnum" in the current window.           |
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:-}  // While updating the folds lines between invalid_top and invalid_bot have   |
  {7:2}  // an undefined fold level.  Otherwise update the folds first.               |
  {7:+}{13:+---  2 lines: if (invalid_top == 0) {·········································}|
  {7:+}{13:+---  2 lines: } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {···········}|
  {7:+}{13:+---  2 lines: } else if (lnum >= invalid_top && lnum <= invalid_bot) {········}|
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:+}{13:+---  2 lines: if (!hasAnyFolding(curwin)) {···································}|
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }^}                                                                              |
  {1:~                                                                               }|*5
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
  {7:+}{13:+--  2 lines: foldLevel()······················································}|
  {7: }static int foldLevel(linenr_T lnum)                                            |
  {7:-}{                                                                              |
  {7:+}{13:+---  2 lines: While updating the folds lines between invalid_top and invalid_b}|
  {7:-}  if (invalid_top == 0) {                                                      |
  {7:2}    checkupdate(curwin);                                                       |
  {7:-}  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {                        |
  {7:2}    return prev_lnum_lvl;                                                      |
  {7:-}  } else if (lnum >= invalid_top && lnum <= invalid_bot) {                     |
  {7:2}    return -1;                                                                 |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  // Return quickly when there is no folding at all in this window.            |
  {7:-}  if (!hasAnyFolding(curwin)) {                                                |
  {7:2}    return 0;                                                                  |
  {7:│}  }                                                                            |
  {7:│}                                                                               |
  {7:│}  return foldLevelWin(curwin, lnum);                                           |
  {7: }^}                                                                              |
  {1:~                                                                               }|*3
                                                                                  |
  ]],
      })
    end)
  end)
end)

describe('vim.lsp nested folding ranges', function()
  local bufnr ---@type integer

  local function start_server(text, ranges)
    insert(text)
    exec_lua(function(ranges)
      _G.server = _G._create_server({
        capabilities = {
          foldingRangeProvider = true,
        },
        handlers = {
          ['textDocument/foldingRange'] = function(_, _, callback)
            callback(nil, ranges)
          end,
        },
      })

      vim.api.nvim_win_set_buf(0, bufnr)
      vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end, ranges)
    command(
      [[set foldmethod=expr foldexpr=v:lua.vim.lsp.foldexpr() foldtext=v:lua.vim.lsp.foldtext() foldminlines=0]]
    )
  end

  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)
    bufnr = api.nvim_get_current_buf()
  end)
  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  it('uses the outermost level when nested ranges end on the same row', function()
    start_server(
      dedent([=[
        local function first()
          return {
            child = {
              value = true,
            } } end; local function second() return {
          child = {
            value = false,
          },
        }
        end
      ]=]),
      {
        { startLine = 0, endLine = 3, kind = 'region' },
        { startLine = 4, endLine = 8, kind = 'region' },
        { startLine = 1, endLine = 3, kind = 'region' },
        { startLine = 4, endLine = 7, kind = 'region' },
        { startLine = 2, endLine = 3, kind = 'region' },
        { startLine = 5, endLine = 6, kind = 'region' },
      }
    )

    retry(nil, nil, function()
      eq(
        { '>1', '>2', '>3', '<1', '>2', '>3', '<3', '<2', '<1', '0' },
        exec_lua(function()
          local levels = {}
          for lnum = 1, 10 do
            levels[lnum] = vim.lsp.foldexpr(lnum)
          end
          return levels
        end)
      )
    end)

    exec_lua(function()
      vim._foldupdate(vim.api.nvim_get_current_win(), 0, vim.api.nvim_buf_line_count(0))
    end)
    command('normal! zM')
    eq(
      { 1, 4, 5, 9 },
      exec_lua(function()
        return {
          vim.fn.foldclosed(1),
          vim.fn.foldclosedend(1),
          vim.fn.foldclosed(5),
          vim.fn.foldclosedend(5),
        }
      end)
    )
  end)

  it('prefers a fold start when ranges end and start on the same row', function()
    start_server('one\ntwo\nthree\nfour\nfive', {
      { startLine = 0, endLine = 4 },
      { startLine = 2, endLine = 4 },
      { startLine = 0, endLine = 2 },
    })

    retry(nil, nil, function()
      eq(
        { '>2', '2', '>3', '2', '<1' },
        exec_lua(function()
          local levels = {}
          for lnum = 1, 5 do
            levels[lnum] = vim.lsp.foldexpr(lnum)
          end
          return levels
        end)
      )
    end)
  end)
end)

describe('vim.lsp folding updates while editing', function()
  local bufnr ---@type integer
  local client_id ---@type integer

  local function set_mode(mode)
    exec_lua(function()
      if not _G.original_get_mode then
        _G.original_get_mode = vim.api.nvim_get_mode
        vim.api.nvim_get_mode = function()
          return { mode = _G.test_mode, blocking = false }
        end
      end
      _G.test_mode = mode
    end)
  end

  local function request_ranges()
    exec_lua(function()
      vim.api.nvim_exec_autocmds('LspNotify', {
        buffer = bufnr,
        data = {
          client_id = client_id,
          method = 'textDocument/didChange',
        },
      })
    end)
    retry(nil, nil, function()
      eq(true, exec_lua('return #_G.fold_callbacks > 0'))
    end)
  end

  local function respond_ranges(ranges)
    exec_lua(function()
      local callback = table.remove(_G.fold_callbacks, 1)
      callback(nil, ranges)
    end)
  end

  local function respond(end_line)
    respond_ranges({ { startLine = 0, endLine = end_line } })
  end

  local function foldclosed(lnum)
    return exec_lua('return vim.fn.foldclosed(...)', lnum)
  end

  local function cursor_folds(windows)
    return exec_lua(function(windows)
      local result = {}
      for i, winid in ipairs(windows) do
        result[i] = vim._with({ win = winid }, function()
          return vim.fn.foldclosed('.')
        end)
      end
      return result
    end, windows)
  end

  local function settle()
    set_mode('n')
    exec_lua(function()
      vim.api.nvim_exec_autocmds('ModeChanged', {
        buffer = bufnr,
        data = { old_mode = 's', new_mode = 'n' },
      })
    end)
  end

  before_each(function()
    clear_notrace()
    exec_lua(create_server_definition)
    bufnr = api.nvim_get_current_buf()
    insert('one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine')
    client_id = exec_lua(function()
      _G.fold_callbacks = {}
      _G.server = _G._create_server({
        capabilities = {
          foldingRangeProvider = true,
          textDocumentSync = vim.lsp.protocol.TextDocumentSyncKind.Full,
        },
        handlers = {
          ['textDocument/foldingRange'] = function(_, _, callback)
            table.insert(_G.fold_callbacks, callback)
          end,
        },
      })
      return vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
    end)
    command([[set foldmethod=expr foldexpr=v:lua.vim.lsp.foldexpr() foldlevel=999]])

    retry(nil, nil, function()
      eq(true, exec_lua('return #_G.fold_callbacks > 0'))
    end)
    respond(0)
    retry(nil, nil, function()
      eq('0', exec_lua('return vim.lsp.foldexpr(1)'))
    end)
    exec_lua(function()
      _G.fold_update_count = 0
      _G.original_foldupdate = vim._foldupdate
      vim._foldupdate = function(...)
        _G.fold_update_count = _G.fold_update_count + 1
        return _G.original_foldupdate(...)
      end
      _G.foldopen_cursor_count = 0
      _G.original_foldopen_cursor = vim._foldopen_cursor
      vim._foldopen_cursor = function(...)
        _G.foldopen_cursor_count = _G.foldopen_cursor_count + 1
        return _G.original_foldopen_cursor(...)
      end
    end)
  end)

  after_each(function()
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  it('defers row evaluation and fold updates in every editing mode', function()
    local modes = { 'i', 'R', 'r', 's', 'S', '\19' }
    for index, mode in ipairs(modes) do
      set_mode(mode)
      request_ranges()
      respond(index + 1)

      eq('0', exec_lua('return vim.lsp.foldexpr(...)', index + 2))
      eq(index - 1, exec_lua('return _G.fold_update_count'))

      settle()
      retry(nil, nil, function()
        eq('<1', exec_lua('return vim.lsp.foldexpr(...)', index + 2))
        eq(index, exec_lua('return _G.fold_update_count'))
      end)
    end
  end)

  it('coalesces accepted responses until editing settles', function()
    set_mode('s')
    request_ranges()
    respond(2)
    request_ranges()
    respond(5)

    eq('0', exec_lua('return vim.lsp.foldexpr(1)'))
    eq(0, exec_lua('return _G.fold_update_count'))

    settle()
    retry(nil, nil, function()
      eq('<1', exec_lua('return vim.lsp.foldexpr(6)'))
      eq(1, exec_lua('return _G.fold_update_count'))
    end)
  end)

  it('settles after leaving Select mode without InsertLeave', function()
    command('normal! gg0gh')
    eq('s', exec_lua('return vim.api.nvim_get_mode().mode'))
    request_ranges()
    respond(3)

    eq('0', exec_lua('return vim.lsp.foldexpr(1)'))
    eq(0, exec_lua('return _G.fold_update_count'))

    feed('<Esc>')
    retry(nil, nil, function()
      eq('>1', exec_lua('return vim.lsp.foldexpr(1)'))
      eq(1, exec_lua('return _G.fold_update_count'))
    end)
  end)

  it('settles after leaving Replace mode', function()
    command('normal! gg0')
    command('startreplace')
    eq('R', exec_lua('return vim.api.nvim_get_mode().mode'))
    request_ranges()
    respond(3)

    eq('0', exec_lua('return vim.lsp.foldexpr(1)'))
    eq(0, exec_lua('return _G.fold_update_count'))

    feed('<Esc>')
    retry(nil, nil, function()
      eq('>1', exec_lua('return vim.lsp.foldexpr(1)'))
      eq(1, exec_lua('return _G.fold_update_count'))
    end)
  end)

  it('keeps a newly expanded snippet on the previous fold snapshot', function()
    exec_lua([[vim.snippet.expand('${1:title}\nbody\nend')]])
    retry(nil, nil, function()
      eq('s', exec_lua('return vim.api.nvim_get_mode().mode'))
      eq(true, exec_lua('return #_G.fold_callbacks > 0'))
    end)
    respond(2)

    eq('0', exec_lua('return vim.lsp.foldexpr(1)'))
    eq(0, exec_lua('return _G.fold_update_count'))

    feed('<Esc>')
    retry(nil, nil, function()
      eq('>1', exec_lua('return vim.lsp.foldexpr(1)'))
      eq(1, exec_lua('return _G.fold_update_count'))
    end)
  end)

  it('applies a response that arrives after editing has settled', function()
    set_mode('i')
    request_ranges()
    settle()
    exec_lua(function()
      vim.schedule(function()
        _G.mode_settled = true
      end)
    end)
    retry(nil, nil, function()
      eq(true, exec_lua('return _G.mode_settled == true'))
    end)

    respond(3)
    eq('>1', exec_lua('return vim.lsp.foldexpr(1)'))
    eq(1, exec_lua('return _G.fold_update_count'))
  end)

  it('opens a deferred fold that newly hides the cursor', function()
    command('set foldlevel=0')
    api.nvim_win_set_cursor(0, { 2, 0 })
    set_mode('s')
    request_ranges()
    respond(3)

    eq(-1, foldclosed('.'))
    settle()
    retry(nil, nil, function()
      eq(-1, foldclosed('.'))
      eq(1, exec_lua('return _G.foldopen_cursor_count'))
    end)
  end)

  it('does not open a cursor fold during an immediate update', function()
    command('set foldlevel=0')
    api.nvim_win_set_cursor(0, { 2, 0 })
    request_ranges()
    respond(3)

    eq(1, foldclosed('.'))
    eq(0, exec_lua('return _G.foldopen_cursor_count'))
  end)

  it('restores cursor visibility independently in each window', function()
    command('set foldlevel=0')
    request_ranges()
    respond_ranges({ { startLine = 5, endLine = 7 } })

    local visible_win = api.nvim_get_current_win()
    command('split')
    local closed_win = api.nvim_get_current_win()
    api.nvim_win_set_cursor(visible_win, { 2, 0 })
    api.nvim_win_set_cursor(closed_win, { 6, 0 })
    eq({ -1, 6 }, cursor_folds({ visible_win, closed_win }))

    set_mode('s')
    request_ranges()
    respond_ranges({
      { startLine = 0, endLine = 3 },
      { startLine = 5, endLine = 7 },
    })
    settle()
    retry(nil, nil, function()
      eq({ -1, 6 }, cursor_folds({ visible_win, closed_win }))
      eq(1, exec_lua('return _G.foldopen_cursor_count'))
    end)
  end)

  it('applies pending ranges before an explicit foldclose', function()
    set_mode('s')
    request_ranges()
    respond_ranges({ { startLine = 0, endLine = 3, kind = 'comment' } })

    exec_lua(function()
      vim.lsp.foldclose('comment')
    end)
    eq('>1', exec_lua('return vim.lsp.foldexpr(1)'))
    eq(1, foldclosed(1))
    eq(1, exec_lua('return _G.fold_update_count'))
  end)

  it('discards a deferred update when the client detaches', function()
    set_mode('s')
    request_ranges()
    respond(3)

    exec_lua(function()
      vim.lsp.stop_client(client_id)
    end)
    retry(nil, nil, function()
      eq({}, exec_lua('return vim.lsp.get_clients({ bufnr = ... })', bufnr))
      eq(1, exec_lua('return _G.fold_update_count'))
    end)

    settle()
    exec_lua(function()
      vim.schedule(function()
        _G.detach_settled = true
      end)
    end)
    retry(nil, nil, function()
      eq(true, exec_lua('return _G.detach_settled == true'))
    end)
    eq(1, exec_lua('return _G.fold_update_count'))
  end)

  it('rejects an invalid window when opening the cursor fold', function()
    local ok, err = exec_lua(function()
      return pcall(vim._foldopen_cursor, 999999)
    end)
    eq(false, ok)
    matches('invalid window', err)
  end)

  it('does not defer a response for a non-current buffer', function()
    set_mode('i')
    exec_lua(function()
      local other = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(other)
    end)
    request_ranges()
    respond(3)

    exec_lua(function()
      vim.api.nvim_set_current_buf(bufnr)
    end)
    eq('>1', exec_lua('return vim.lsp.foldexpr(1)'))
  end)
end)
