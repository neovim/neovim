-- Conceal-aware line wrapping (#14409): a wrapped line whose concealed cells are
-- fully hidden should reflow to occupy only its displayed width, instead of keeping
-- the pre-conceal wrap points (the historical "boguscols" behavior).
local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local api = n.api
local command = n.command
local exec_lua = n.exec_lua
local fn = n.fn
local eq = t.eq

local Screen = require('test.functional.ui.screen')

describe('conceal-aware wrapping (#14409)', function()
  local ns

  before_each(function()
    clear()
    -- 20-column window so the sample line wraps.
    Screen.new(20, 6)
    ns = api.nvim_create_namespace('conceal_wrap')
    -- Conceal in all modes so the cursor line is not revealed.
    command('set wrap conceallevel=2 concealcursor=nvic')
  end)

  it('fully hidden extmark conceal reflows a wrapped line', function()
    -- 25 raw cells: without conceal this wraps to two screen rows at width 20.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9) })
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Hide "HIDDEN" (cols 10..16, no replacement char): 19 displayed cells -> one row.
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    eq(1, api.nvim_win_text_height(0, {}).all)
  end)

  it('screenpos() reports the reflowed screen column', function()
    -- 10 a + HIDDEN(6) + 30 b = 46 raw; hide the 6 -> 40 cells -> 2 rows at width 20.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(30) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    -- Buffer col 26 (1-based 27) is the first 'b' of visual row 2: reflowed to row 2, col 1
    -- (pre-conceal it would report row 2, col 7).
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 27))
    -- First 'a' stays at row 1, col 1; a 'b' at buffer col 20 reflows onto row 1.
    eq({ row = 1, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 1))
    eq({ row = 1, col = 15, curscol = 15, endcol = 15 }, fn.screenpos(0, 1, 21))
  end)

  it('mouse click maps to the reflowed screen column', function()
    command('set mouse=a')
    -- 10 a + HIDDEN(6) + 30 b; reflowed: row 1 = a*10 + b*10 (buf 16..25), row 2 = b*20 (buf 26..45).
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(30) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    -- Click row 1 (0-based 0), cell 14: a 'b' at buffer col 20 (pre-conceal this cell was hidden).
    api.nvim_input_mouse('left', 'press', '', 0, 0, 14)
    eq({ 1, 20 }, api.nvim_win_get_cursor(0))

    -- Click row 2 (0-based 1), cell 0: first 'b' of visual row 2 = buffer col 26.
    api.nvim_input_mouse('left', 'press', '', 0, 1, 0)
    eq({ 1, 26 }, api.nvim_win_get_cursor(0))
  end)

  it('ephemeral (decoration-provider) conceal does not reflow', function()
    -- Ephemeral conceal is created during drawing and is not in the marktree, so the
    -- shared size/geometry path cannot see it off-draw. Reflowing it would make the
    -- draw disagree with cursor/scroll/mouse geometry, so ephemeral conceal keeps the
    -- historical boguscols behavior (no reflow) until it can be made off-draw-visible.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9) })
    exec_lua(function(nsid)
      vim.api.nvim_set_decoration_provider(nsid, {
        on_win = function()
          return true
        end,
        on_line = function(_, _, buf, row)
          if row == 0 then
            vim.api.nvim_buf_set_extmark(buf, nsid, 0, 10, {
              end_col = 16,
              conceal = '',
              ephemeral = true,
            })
          end
        end,
      })
    end, ns)

    -- The line still occupies two screen rows (pre-conceal wrap points kept).
    eq(2, api.nvim_win_text_height(0, {}).all)
  end)
end)
