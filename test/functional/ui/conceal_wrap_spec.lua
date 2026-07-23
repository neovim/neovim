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
local feed = n.feed
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

  it('winline()/wincol() report the reflowed cursor position', function()
    -- Same reflowed line; winline()/wincol() go through curs_columns(), not a redraw.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(30) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    -- Buffer col 26 (first 'b' of visual row 2) sits at screen row 2, col 1.
    api.nvim_win_set_cursor(0, { 1, 26 })
    eq(2, fn.winline())
    eq(1, fn.wincol())

    -- Buffer col 20 reflows back onto row 1 at col 15 (pre-conceal it was row 2, col 1).
    api.nvim_win_set_cursor(0, { 1, 20 })
    eq(1, fn.winline())
    eq(15, fn.wincol())
  end)

  it('gj/gk move by the reflowed screen line', function()
    -- Reflowed: row 1 = a*10 + b*10 (buf 16..25), row 2 = b*20 (buf 26..45).
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(30) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    -- gj from row 1 col 0 lands straight below on row 2 col 0 = buffer col 26
    -- (pre-conceal it landed on the virtual row 2, buffer col 20).
    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('gj')
    eq({ 1, 26 }, api.nvim_win_get_cursor(0))
    -- gk returns to the same visible column on row 1.
    feed('gk')
    eq({ 1, 0 }, api.nvim_win_get_cursor(0))

    -- gj keeps the screen column: from a 'b' at screen col 15 (buf 20) to row 2 col 15 (buf 40).
    api.nvim_win_set_cursor(0, { 1, 20 })
    feed('gj')
    eq({ 1, 40 }, api.nvim_win_get_cursor(0))
  end)

  it('g0/g^/gm/g$ move within the reflowed screen line', function()
    -- Reflowed: row 1 = a*20 (buf 0..19), row 2 = '  ' + c*18 (buf 26..45).
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(20) .. 'HIDDEN' .. '  ' .. ('c'):rep(18) })
    api.nvim_buf_set_extmark(0, ns, 0, 20, { end_col = 26, conceal = '' })

    -- All four land within row 2 (pre-fix: raw-column math landed in the concealed
    -- region or short of the true row/line end).
    api.nvim_win_set_cursor(0, { 1, 35 })
    feed('g0')
    eq({ 1, 26 }, api.nvim_win_get_cursor(0))

    api.nvim_win_set_cursor(0, { 1, 35 })
    feed('g^')
    eq({ 1, 28 }, api.nvim_win_get_cursor(0))

    api.nvim_win_set_cursor(0, { 1, 35 })
    feed('gm')
    eq({ 1, 36 }, api.nvim_win_get_cursor(0))

    api.nvim_win_set_cursor(0, { 1, 35 })
    feed('g$')
    eq({ 1, 45 }, api.nvim_win_get_cursor(0))
  end)

  it('reflow and motions account for double-width (CJK) characters', function()
    -- 10 a (buf 0-9) + HIDDEN (buf 10-15, concealed) + 15x 古 (3 bytes, 2 cells each, buf 16-60).
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('古'):rep(15) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    -- Reflowed width counts 古 as 2 cells: 10 + 15*2 = 40 cells -> 2 rows of 20.
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Row 2 starts at buf 31 (5 of the 15 古 fill out row 1's remaining 10 cells).
    -- endcol=2 because 古 is double-width; curscol stays at its left cell.
    eq({ row = 2, col = 1, curscol = 1, endcol = 2 }, fn.screenpos(0, 1, 32))

    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('gj')
    eq({ 1, 31 }, api.nvim_win_get_cursor(0))

    api.nvim_win_set_cursor(0, { 1, 40 })
    feed('g0')
    eq({ 1, 31 }, api.nvim_win_get_cursor(0))

    -- g$ lands on row 2's last (10th) 古, at its start byte.
    api.nvim_win_set_cursor(0, { 1, 40 })
    feed('g$')
    eq({ 1, 58 }, api.nvim_win_get_cursor(0))

    -- A mouse click on row 2's last cell maps to that same 古.
    api.nvim_input_mouse('left', 'press', '', 0, 1, 19)
    eq({ 1, 58 }, api.nvim_win_get_cursor(0))
  end)

  it('reflow and motions account for narrow multi-byte characters', function()
    -- 10 a (buf 0-9) + HIDDEN (buf 10-15, concealed) + 30x 'é' (2 bytes, 1 cell each, buf 16-75).
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('é'):rep(30) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    -- Reflowed width: 10 + 30 = 40 cells -> 2 rows of 20 (byte count would wrongly suggest more).
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Row 2 starts at buf 36 (10 of the 30 'é' fill out row 1's remaining 10 cells).
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 37))

    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('gj')
    eq({ 1, 36 }, api.nvim_win_get_cursor(0))

    api.nvim_win_set_cursor(0, { 1, 50 })
    feed('g0')
    eq({ 1, 36 }, api.nvim_win_get_cursor(0))

    -- g$ lands on row 2's last 'é', at its start byte.
    api.nvim_win_set_cursor(0, { 1, 50 })
    feed('g$')
    eq({ 1, 74 }, api.nvim_win_get_cursor(0))
  end)

  it('tab width uses raw (position-dependent) vcol through conceal', function()
    -- 5 a (buf0-4) + HIDDEN (buf5-10, concealed, 6 raw cols) + TAB (buf11) + 30 b (buf12-41).
    -- Raw vcol at the TAB is 11 (5 + 6 hidden), tabstop=8 -> tab expands to 5 cells (11->16),
    -- same as if the hidden text were still visible: conceal must not shrink tab stops.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(5) .. 'HIDDEN' .. '\t' .. ('b'):rep(30) })
    api.nvim_buf_set_extmark(0, ns, 0, 5, { end_col = 11, conceal = '' })

    -- Reflowed: 5(a) + 5(tab) + 30(b) = 40 cells -> 2 rows of 20.
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Row 2 starts at buf 22 (10 of the 30 b fill out row 1's remaining 10 cells after a+tab=10).
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 23))

    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('gj')
    eq({ 1, 22 }, api.nvim_win_get_cursor(0))

    api.nvim_win_set_cursor(0, { 1, 30 })
    feed('g0')
    eq({ 1, 22 }, api.nvim_win_get_cursor(0))

    api.nvim_win_set_cursor(0, { 1, 30 })
    feed('g$')
    eq({ 1, 41 }, api.nvim_win_get_cursor(0))
  end)

  it('reflow and motions compose with asymmetric width1/width2 (number, cpoptions+=n)', function()
    -- cpoptions+=n makes continuation rows not repeat the number column, so they are wider
    -- than the first row: width1 = 16 (20-4), width2 = 20 (16+4).
    command('set number numberwidth=4 cpoptions+=n')
    -- 10 a (buf0-9) + HIDDEN (buf10-15, concealed) + 30 b (buf16-45).
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(30) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    -- Reflowed visible width 40 cells -> row1=16, row2=20, row3=4 (3 rows).
    eq(3, api.nvim_win_text_height(0, {}).all)

    -- g0/g$ (this patch's fix) independently compute each row's true start/end from the
    -- cursor's own row, so they land exactly on row 2's boundaries regardless of width1/width2
    -- being unequal: start = buf 22, end = buf 41.
    api.nvim_win_set_cursor(0, { 1, 30 })
    feed('g0')
    eq({ 1, 22 }, api.nvim_win_get_cursor(0))

    api.nvim_win_set_cursor(0, { 1, 30 })
    feed('g$')
    eq({ 1, 41 }, api.nvim_win_get_cursor(0))

    -- gj (pre-existing nv_screengo logic, unchanged by this patch) instead accumulates the
    -- target column by width2 per row without realigning to each row's start when width1 !=
    -- width2: from buf 0 it lands on buf 26, not row 2's start (buf 22). Verified this exact
    -- offset also happens with plain unconcealed text and the same options, so it is a
    -- pre-existing 'cpoptions'+=n quirk unrelated to conceal, not a reflow regression.
    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('gj')
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

  it('_on_conceal provider conceal reflows (materialized into the marktree)', function()
    -- A provider that materializes intra-line conceal on demand via the _on_conceal callback
    -- (as an ordinary marktree extmark) DOES reflow, because the off-draw geometry can read it.
    -- This is how tree-sitter @conceal becomes wrap-aware.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(30) })
    exec_lua(function(nsid)
      local materialized = {}
      vim.api.nvim_set_decoration_provider(nsid, {
        _on_conceal = function(_, _, buf, row)
          if row == 0 and not materialized[row] then
            materialized[row] = true
            vim.api.nvim_buf_set_extmark(buf, nsid, 0, 10, { end_col = 16, conceal = '' })
          end
        end,
      })
    end, ns)

    -- 46 raw -> hide 6 -> 40 cells -> 2 rows (would be 3 without the materialized conceal).
    eq(2, api.nvim_win_text_height(0, {}).all)
    -- Geometry follows: first 'b' of visual row 2 (buffer col 26) is at row 2, col 1.
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 27))
    -- gj follows the reflowed layout.
    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('gj')
    eq({ 1, 26 }, api.nvim_win_get_cursor(0))
  end)

  it('tree-sitter @conceal reflows a wrapped line and updates on edit', function()
    -- End-to-end through the tree-sitter highlighter: intra-line @conceal is
    -- ephemeral, but the highlighter now also materializes it on demand (via
    -- _on_conceal) as a marktree mark, so the off-draw geometry can see it and
    -- the wrapped line reflows. "int HIDDENIDENTIFIER = b;" is 25 raw
    -- cells -> two rows at width 20.
    api.nvim_buf_set_lines(0, 0, -1, true, { 'int HIDDENIDENTIFIER = b;' })
    exec_lua(function()
      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, 'c'), {
        queries = {
          c = [[
            ((identifier) @conceal
             (#eq? @conceal "HIDDENIDENTIFIER")
             (#set! conceal ""))
          ]],
        },
      })
    end)

    -- The 16-char identifier is concealed to nothing: 25 - 16 = 9 displayed cells -> one row.
    eq(1, api.nvim_win_text_height(0, {}).all)
    -- Geometry follows the reflow: buffer col 21 (space before '=') sits at screen col 5
    -- (4 visible cells of "int " + 0 for the concealed identifier), still on row 1.
    eq({ row = 1, col = 5, curscol = 5, endcol = 5 }, fn.screenpos(0, 1, 21))
    eq({ row = 1, col = 9, curscol = 9, endcol = 9 }, fn.screenpos(0, 1, 25))

    -- Edit the identifier so it no longer matches the #eq? predicate. Same raw width (25), but now
    -- nothing is concealed, so the materialized conceal must be invalidated and the line re-wraps.
    api.nvim_buf_set_lines(0, 0, 1, true, { 'int VISIBLEIDENTIFIE = b;' })
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Restore the concealed identifier: the line reflows back to one row.
    api.nvim_buf_set_lines(0, 0, 1, true, { 'int HIDDENIDENTIFIER = b;' })
    eq(1, api.nvim_win_text_height(0, {}).all)
  end)
end)

-- Revealing/concealing a wrapped line via 'concealcursor' changes its height, so cursor moves must
-- force a full redraw (like the existing 'conceal_lines' guard) to avoid stale cells from the TUI's
-- grid_scroll optimisation. The Screen harness can't observe that TUI effect directly, so this
-- verifies geometry stays correct while walking the cursor through a scrolled, height-changing
-- region (exercising conceal_line_changes_height()).
describe('conceal-aware wrapping redraw (#14409)', function()
  before_each(clear)

  it(
    'keeps geometry correct moving through a scrolled reflowing region with a revealed cursor line',
    function()
      local screen = Screen.new(30, 8)
      local ns = api.nvim_create_namespace('conceal_wrap_redraw')
      -- concealcursor= reveals the cursor line, so moving the cursor changes that line's height.
      command('set wrap conceallevel=2 concealcursor= scrolloff=1')
      -- Each line reflows: revealed is 34 cells (2 rows at width 30), concealed is 22 (1 row).
      local lines = {}
      for i = 1, 20 do
        lines[i] = ('L%02d-AAA'):format(i)
          .. ('C'):rep(12)
          .. ('-t%02d-'):format(i)
          .. ('B'):rep(10)
      end
      api.nvim_buf_set_lines(0, 0, -1, true, lines)
      for i = 0, 19 do
        local c = lines[i + 1]:find('C')
        api.nvim_buf_set_extmark(0, ns, i, c - 1, { end_col = c - 1 + 12, conceal = '' })
      end

      -- Scroll into the middle, then walk the cursor down through several reflowing lines.
      api.nvim_win_set_cursor(0, { 8, 0 })
      feed('zzjjj')

      -- Cursor is on line 11 (revealed: 2 rows, C's visible); the other visible lines are concealed
      -- (1 row, C's hidden). Every line's geometry must be correct after the height-changing moves.
      screen:expect([[
      L07-AAA-t07-BBBBBBBBBB        |
      L08-AAA-t08-BBBBBBBBBB        |
      L09-AAA-t09-BBBBBBBBBB        |
      L10-AAA-t10-BBBBBBBBBB        |
      ^L11-AAACCCCCCCCCCCC-t11-BBBBBB|
      BBBB                          |
      L12-AAA-t12-BBBBBBBBBB        |
                                    |
    ]])
    end
  )
end)
