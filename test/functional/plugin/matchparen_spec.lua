local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local command = n.command
local api = n.api
local feed = n.feed
local eq = t.eq

describe('matchparen', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    clear { args = { '-u', 'NORC' } }
    screen = Screen.new(20, 5)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = 255 },
      [1] = { bold = true },
    })
  end)

  it('uses correct column after i_<Up>. Vim patch 7.4.1296', function()
    command('set noautoindent nosmartindent nocindent laststatus=0')
    eq(1, api.nvim_get_var('loaded_matchparen'))
    feed('ivoid f_test()<cr>')
    feed('{<cr>')
    feed('}')

    -- critical part: up + cr should result in an empty line in between the
    -- brackets... if the bug is there, the empty line will be before the '{'
    feed('<up>')
    feed('<cr>')

    screen:expect([[
      void f_test()       |
      {                   |
      ^                    |
      }                   |
      {1:-- INSERT --}        |
    ]])
  end)

  it('skips treesitter strings in another window', function()
    api.nvim_buf_set_lines(0, 0, -1, false, { 'print(")")' })
    n.exec_lua(function()
      vim.treesitter.start(0, 'lua')
    end)
    api.nvim_win_set_cursor(0, { 1, 5 })
    local win = api.nvim_get_current_win()
    command('new')
    eq(
      { { 1, 6, 1 }, { 1, 10, 1 } },
      n.exec_lua(function(target_win)
        require('nvim.matchparen').highlight_matching_pair(target_win)
        local match = vim.fn.getmatches(target_win)[1]
        return { match.pos1, match.pos2 }
      end, win)
    )
  end)
end)
