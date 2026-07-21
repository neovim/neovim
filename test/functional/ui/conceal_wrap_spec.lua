-- Conceal-aware line wrapping (#14409): a wrapped line whose concealed cells are fully hidden
-- should reflow to occupy only its displayed width, instead of keeping the pre-conceal wrap points
-- (the historical "boguscols" behavior).
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
  local screen0

  before_each(function()
    clear()
    -- 20-column window so the sample line wraps.
    screen0 = Screen.new(20, 6)
    ns = api.nvim_create_namespace('conceal_wrap')
    -- Conceal in all modes so the cursor line is not revealed.
    command('set wrap conceallevel=2 concealcursor=nvic')
  end)

  -- Most tests use this line: 10 a (buf 0-9) + HIDDEN (buf 10-15, concealed) + 30 b (buf 16-45).
  -- Reflowed at width 20 that is row 1 = a*10 + b*10 (buf 16-25), row 2 = b*20 (buf 26-45).
  local sample = ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(30)

  --- Sets line 1 to "text" and conceals the first occurrence of "hidden" in it.
  local function conceal_line(text, hidden)
    hidden = hidden or 'HIDDEN'
    api.nvim_buf_set_lines(0, 0, -1, true, { text })
    local col = assert(text:find(hidden, 1, true)) - 1
    api.nvim_buf_set_extmark(0, ns, 0, col, { end_col = col + #hidden, conceal = '' })
  end

  --- Feeds "keys" with the cursor at buffer column "col".
  --- @return integer column after the motion
  local function col_after(col, keys)
    api.nvim_win_set_cursor(0, { 1, col })
    feed(keys)
    return api.nvim_win_get_cursor(0)[2]
  end

  --- @return integer current cursor column
  local function cursor_col()
    return api.nvim_win_get_cursor(0)[2]
  end

  it('fully hidden extmark conceal reflows a wrapped line', function()
    -- 25 raw cells: without conceal this wraps to two screen rows at width 20.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9) })
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Hide "HIDDEN" (cols 10..16, no replacement char): 19 displayed cells -> one row.
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    eq(1, api.nvim_win_text_height(0, {}).all)
  end)

  it('mouse click maps to the reflowed screen column', function()
    command('set mouse=a')
    conceal_line(sample)

    -- Click row 1 (0-based 0), cell 14: a 'b' at buffer col 20 (pre-conceal this cell was hidden).
    api.nvim_input_mouse('left', 'press', '', 0, 0, 14)
    eq({ 1, 20 }, api.nvim_win_get_cursor(0))

    -- Click row 2 (0-based 1), cell 0: first 'b' of visual row 2 = buffer col 26.
    api.nvim_input_mouse('left', 'press', '', 0, 1, 0)
    eq({ 1, 26 }, api.nvim_win_get_cursor(0))
  end)

  it('winline()/wincol() report the reflowed cursor position', function()
    -- winline()/wincol() go through curs_columns(), not a redraw.
    conceal_line(sample)

    -- Buffer col 26 (first 'b' of visual row 2) sits at screen row 2, col 1.
    api.nvim_win_set_cursor(0, { 1, 26 })
    eq(2, fn.winline())
    eq(1, fn.wincol())

    -- Buffer col 20 reflows back onto row 1 at col 15 (pre-conceal it was row 2, col 1).
    api.nvim_win_set_cursor(0, { 1, 20 })
    eq(1, fn.winline())
    eq(15, fn.wincol())
  end)

  it("g0 and g$ ignore 'virtualedit' coladd when finding their own row", function()
    command('set virtualedit=all')
    conceal_line(sample)

    -- Cursor at buf 45 with 5 cells of 'virtualedit' coladd past it: w_virtcol includes that
    -- coladd, so it must be excluded when deriving the real position's screen row, or g0/g$ would
    -- treat the cursor as 5 cells further into a later row.
    fn.setpos('.', { 0, 1, 46, 5 })
    eq(5, fn.getcurpos()[4])

    feed('g0')
    eq({ 1, 26 }, api.nvim_win_get_cursor(0))
    eq(0, fn.getcurpos()[4])

    fn.setpos('.', { 0, 1, 46, 5 })
    feed('g$')
    eq({ 1, 45 }, api.nvim_win_get_cursor(0))
    eq(0, fn.getcurpos()[4])
  end)

  it('gj/gk move by the reflowed screen line', function()
    conceal_line(sample)

    -- gj from row 1 col 0 lands straight below on row 2 col 0 = buffer col 26 (pre-conceal it
    -- landed on the virtual row 2, buffer col 20).
    eq(26, col_after(0, 'gj'))
    -- gk returns to the same visible column on row 1.
    feed('gk')
    eq(0, cursor_col())

    -- gj keeps the screen column: from a 'b' at screen col 15 (buf 20) to row 2 col 15 (buf 40).
    eq(40, col_after(20, 'gj'))
  end)

  it('reflow and gj/gk are unaffected by an adjacent closed fold', function()
    -- Folds hide whole lines and are independent of this feature's intra-line conceal, but confirm
    -- they still compose without crashing or miscounting.
    conceal_line(sample)
    api.nvim_buf_set_lines(0, 1, -1, true, { 'fold2', 'fold3', 'last' })
    command('set foldmethod=manual')
    command('2,3fold')
    eq(2, fn.foldclosed(2))

    -- Line 1's own reflowed height is unaffected by the adjacent fold.
    eq(2, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)

    -- gj within line 1 still reflows normally up to its own last screen row (buf 45).
    eq(45, col_after(25, 'gj'))

    -- gj from line 1's last screen row crosses into the closed fold as a single unit.
    feed('gj')
    eq(2, api.nvim_win_get_cursor(0)[1])
  end)

  it('visual and operator-pending gj span the reflowed boundary', function()
    conceal_line(sample)

    -- Charwise visual selection with gj as the motion is inclusive of both endpoints (buf 0 through
    -- row 2's buf 26), deleting 10(a) + 6(HIDDEN) + 11(b, buf16-26) = 27 chars, leaving 19 b's.
    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('vgjd')
    eq(('b'):rep(19), api.nvim_buf_get_lines(0, 0, -1, true)[1])

    -- Unlike visual mode, gj as a plain operator-pending motion (curswant not yet MAXCOL) is
    -- exclusive, so dgj stops before row 2's first character (buf 26), leaving 20 b's.
    conceal_line(sample)
    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('dgj')
    eq(('b'):rep(20), api.nvim_buf_get_lines(0, 0, -1, true)[1])
  end)

  it('g0/g^/gm/g$ move within the reflowed screen line', function()
    -- Reflowed: row 1 = a*20 (buf 0..19), row 2 = '  ' + c*18 (buf 26..45).
    conceal_line(('a'):rep(20) .. 'HIDDEN' .. '  ' .. ('c'):rep(18))

    -- All four land within row 2 (pre-fix: raw-column math landed in the concealed region or short
    -- of the true row/line end).
    eq(26, col_after(35, 'g0'))
    eq(28, col_after(35, 'g^'))
    eq(36, col_after(35, 'gm'))
    eq(45, col_after(35, 'g$'))
  end)

  it("g0/g^/gm/g$ use the raw leftcol under 'nowrap', not a screen-layout column", function()
    -- 'nowrap' does not reflow, so w_leftcol is already the correct raw (virtual) column; it must
    -- not be run through the scol->vcol conversion meant for the wrapped case, or it overshoots by
    -- however much conceal is hidden before it.
    command('set nowrap')
    -- 20 a (buf 0..19, concealed) + 2 spaces (buf 20..21) + 30 c (buf 22..51).
    conceal_line(('a'):rep(20) .. '  ' .. ('c'):rep(30), ('a'):rep(20))
    -- Scroll past the concealed run: leftcol=20 shows the two spaces then 18 'c's. Set the cursor
    -- column and leftcol together so nvim doesn't re-center leftcol around the cursor before the
    -- forced scroll position takes effect.
    fn.winrestview({ lnum = 1, col = 35, leftcol = 20 })

    eq(20, col_after(35, 'g0')) -- leftcol itself
    eq(22, col_after(35, 'g^')) -- past the two leading spaces
    eq(30, col_after(35, 'gm')) -- leftcol + width/2
    eq(39, col_after(35, 'g$')) -- last visible raw column
  end)

  it('a line with nothing hidden keeps its virtual columns', function()
    -- Conceal options alone must not move the screen-line motions: the screen-layout column domain
    -- differs from the virtual one only where conceal actually removes cells. The two readings can
    -- disagree once 'linebreak' filler and 'showbreak' width both apply, so a line with nothing
    -- hidden must not be routed through the conversion at all.
    command('set linebreak showbreak=>>')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'b 界 \t\t\t\tb a ' })

    local function motions()
      local cols = {}
      for _, motion in ipairs({ 'g0', 'g^', 'gm', 'g$', 'gj', 'gk' }) do
        -- Character starts only; buf 3 and 4 are inside the double-width character.
        for _, col in ipairs({ 0, 1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13 }) do
          api.nvim_win_set_cursor(0, { 1, col })
          feed(motion)
          cols[#cols + 1] = api.nvim_win_get_cursor(0)[2]
        end
      end
      return cols
    end

    command('setlocal conceallevel=0')
    local unconcealed = motions()
    command('setlocal conceallevel=2')
    eq(unconcealed, motions())
  end)

  -- 'showbreak' and 'breakindent' both shrink every row after the first, so a row's first real
  -- character sits past a prefix with no buffer position of its own. Motions must land on that
  -- character, not on the prefix or one cell short of it.
  for _, case in ipairs({
    { name = 'showbreak', opts = 'showbreak=>>', text = sample, rows = { 26, 44 }, last = 43 },
    {
      name = 'breakindent',
      -- breakindentopt=min:0 disables the default minimum text width so the indent (4, matching the
      -- line's own) always applies in this narrow window.
      opts = 'breakindent breakindentopt=min:0',
      text = '    ' .. ('a'):rep(6) .. 'HIDDEN' .. ('b'):rep(30),
      rows = { 26, 42 },
      last = 41,
    },
  }) do
    it('reflow and motions account for ' .. case.name .. ' on a decorated row boundary', function()
      command('set ' .. case.opts)
      conceal_line(case.text)
      eq(3, api.nvim_win_text_height(0, {}).all)

      -- gj lands on each following row's first real character.
      eq(case.rows[1], col_after(0, 'gj'))
      feed('gj')
      eq(case.rows[2], cursor_col())

      -- g0/g$ from within row 2 reach its true first/last characters.
      eq(case.rows[1], col_after(30, 'g0'))
      eq(case.last, col_after(30, 'g$'))
      -- g$ pressed again while already on row 2's last character must stay there.
      feed('g$')
      eq(case.last, cursor_col())
    end)
  end

  it("reflow and motions account for 'showbreak' screen positions", function()
    command('set showbreak=>>')
    conceal_line(sample)
    -- Row 2 and row 3 both start 2 columns in, after the ">>" prefix.
    eq({ row = 2, col = 3, curscol = 3, endcol = 3 }, fn.screenpos(0, 1, 27))
    eq({ row = 3, col = 3, curscol = 3, endcol = 3 }, fn.screenpos(0, 1, 45))
  end)

  it("reflow agrees with 'linebreak' on whether a word fits the displayed width", function()
    -- 5 a (buf 0-4) + HIDDEN (buf 5-10, concealed) + 5 b (buf 11-15) + space (buf 16) + 9 c (buf
    -- 17-25): reflowed to 20 cells, exactly filling the 20-wide window in one row.
    command('set linebreak')
    api.nvim_buf_set_lines(0, 0, -1, true, {
      ('a'):rep(5) .. 'HIDDEN' .. ('b'):rep(5) .. ' ' .. ('c'):rep(9),
    })
    api.nvim_buf_set_extmark(0, ns, 0, 5, { end_col = 11, conceal = '' })
    eq(1, api.nvim_win_text_height(0, {}).all)

    screen0:expect([[
      ^aaaaabbbbb ccccccccc|
      {1:~                   }|*4
                          |
    ]])

    -- g$ reaches the line's true last character now that it fits on a single row.
    feed('g$')
    eq({ 1, 25 }, api.nvim_win_get_cursor(0))
  end)

  it("'linebreak' wraps a reflowed line at the correct word, not the raw column", function()
    -- 5 a (buf 0-4) + HIDDEN (buf 5-10, concealed) + 5 b (buf 11-15) + space (buf 16) + 10 c (buf
    -- 17-26): reflowed to 21 cells. 'linebreak' must push all 10 c's to row 2, since they don't fit
    -- after "aaaaabbbbb " (11 cells) on the 20-wide row.
    command('set linebreak')
    api.nvim_buf_set_lines(0, 0, -1, true, {
      ('a'):rep(5) .. 'HIDDEN' .. ('b'):rep(5) .. ' ' .. ('c'):rep(10),
    })
    api.nvim_buf_set_extmark(0, ns, 0, 5, { end_col = 11, conceal = '' })
    eq(2, api.nvim_win_text_height(0, {}).all)

    screen0:expect([[
      ^aaaaabbbbb          |
      cccccccccc          |
      {1:~                   }|*3
                          |
    ]])

    -- gj from row 1 lands on row 2's first character (buf 17): the wrapped word's own start.
    feed('gj')
    eq({ 1, 17 }, api.nvim_win_get_cursor(0))

    -- g0/g$ from within row 2 reach its true first/last characters.
    feed('g0')
    eq({ 1, 17 }, api.nvim_win_get_cursor(0))
    feed('g$')
    eq({ 1, 26 }, api.nvim_win_get_cursor(0))
  end)

  it("g$ stays on its own row when 'linebreak' pads the row with filler", function()
    -- 3 a (buf 0-2) + HIDDEN (buf 3-8, concealed) + 3 a (buf 9-11) + " bbbb cccc dddd eeee ffff
    -- gggggggg" (buf 12-45): reflowed to 39 cells over three 20-wide rows. Every row but the last
    -- ends in a 'linebreak' word push, so its last character carries filler cells (CharSize.tail)
    -- out to the row edge.
    command('set linebreak')
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'aaaHIDDENaaa bbbb cccc dddd eeee ffff gggggggg',
    })
    api.nvim_buf_set_extmark(0, ns, 0, 3, { end_col = 9, conceal = '' })

    screen0:expect([[
      ^aaaaaa bbbb cccc    |
      dddd eeee ffff      |
      gggggggg            |
      {1:~                   }|*2
                          |
    ]])

    -- A target landing in that filler is still the character it pads, not virtual space past the
    -- line: g$ must stop at each row's own last character rather than running to the line's end.
    feed('g$')
    eq({ 1, 22 }, api.nvim_win_get_cursor(0))
    feed('gjg0g$')
    eq({ 1, 37 }, api.nvim_win_get_cursor(0))
    -- The last row is short, so its target is genuinely past the end of the line: that overshoot
    -- must be measured in the same virtual space coladvance() uses, filler included, or it lands
    -- back inside the line.
    feed('gjg0g$')
    eq({ 1, 45 }, api.nvim_win_get_cursor(0))

    -- 'virtualedit' can reach those filler cells, so there g$ goes to the end of the screen line
    -- (|g$|) rather than stopping on the character that pads it.
    command('set virtualedit=all')
    eq(22, col_after(0, 'g$'))
    eq(3, fn.getcurpos()[4])
    eq(20, fn.wincol())
  end)

  it("g$ stays on its own row when a tab spans the row boundary under 'breakindent'", function()
    -- 6 a (buf 0-5) + HIDDEN (buf 6-11, concealed) + 12 b (buf 12-23) + TAB (buf 24) + 5 c (buf
    -- 25-29). Reflowed, the b run ends at cell 17 and the tab starts at cell 18, so the tab
    -- straddles the 20-wide row boundary. The cursor is drawn in a tab's last cell, so a
    -- row-boundary check reading the tab's first cell instead leaves the cursor on the tab, which
    -- is drawn on row 2.
    command('set breakindent breakindentopt=min:0 tabstop=8')
    conceal_line(('a'):rep(6) .. 'HIDDEN' .. ('b'):rep(12) .. '\t' .. ('c'):rep(5))

    -- Row 1's last character is the b at buf 23, not the tab that starts on it.
    eq(23, col_after(0, 'g$'))
    eq(1, fn.screenpos(0, 1, fn.getcurpos()[3]).row)
  end)

  it("'linebreak' measures a concealed tab from the line start at every word break", function()
    -- "aa bb" (buf 0-4) + concealed TAB (buf 5) + "cc" (buf 6-7) + space (buf 8) + 14 d (buf
    -- 9-22). The tab starts at raw vcol 5, so with tabstop=8 it hides 3 cells; measured from any
    -- other position it would hide a different number. Every word break re-runs the 'linebreak'
    -- lookahead, and each one must charge the tab those same 3 cells: displayed width is
    -- 25 - 3 = 22, so the 14-cell word does not fit the 20-wide first row and is pushed down.
    command('set linebreak')
    conceal_line('aa bb\tcc ' .. ('d'):rep(14), '\t')

    eq(2, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aa bbcc             |
      dddddddddddddd      |
      {1:~                   }|*3
                          |
    ]])
  end)

  it(
    "'linebreak' still treats a space as a break point when the concealed text right after it "
      .. "starts with a 'breakat' character",
    function()
      -- 14 a (buf 0-13) + space (buf 14) + concealed "**" (buf 15-16) + 6 b (buf 17-22): reflowed
      -- to 21 cells, 1 over the 20-wide window. "*" is itself in the default 'breakat', so the
      -- concealed run starts with a 'breakat' byte; the space at buf 14 is still the line's only
      -- break point and 'linebreak' must push all 6 b's to row 2, not split them across the row
      -- boundary.
      command('set linebreak')
      api.nvim_buf_set_lines(0, 0, -1, true, {
        ('a'):rep(14) .. ' **' .. ('b'):rep(6),
      })
      api.nvim_buf_set_extmark(0, ns, 0, 15, { end_col = 17, conceal = '' })
      eq(2, api.nvim_win_text_height(0, {}).all)

      screen0:expect([[
      ^aaaaaaaaaaaaaa      |
      bbbbbb              |
      {1:~                   }|*3
                          |
    ]])

      -- gj from row 1 lands on row 2's first character (buf 17): the wrapped word's own start.
      feed('gj')
      eq({ 1, 17 }, api.nvim_win_get_cursor(0))

      -- g0/g$ from within row 2 reach its true first/last characters.
      feed('g0')
      eq({ 1, 17 }, api.nvim_win_get_cursor(0))
      feed('g$')
      eq({ 1, 22 }, api.nvim_win_get_cursor(0))
    end
  )

  -- Reflowed width counts display cells, not bytes: 10 + 30 cells -> 2 rows of 20 either way.
  for _, case in ipairs({
    -- 15x 古 (3 bytes, 2 cells each, buf 16-60): 5 of them fill out row 1's remaining 10 cells.
    { name = 'double-width (CJK)', ch = '古', n = 15, row2 = 31, endcol = 2, last = 58 },
    -- 30x é (2 bytes, 1 cell each, buf 16-75): 10 of them fill out row 1's remaining 10 cells.
    { name = 'narrow multi-byte', ch = 'é', n = 30, row2 = 36, endcol = 1, last = 74 },
  }) do
    it('reflow and motions account for ' .. case.name .. ' characters', function()
      conceal_line(('a'):rep(10) .. 'HIDDEN' .. (case.ch):rep(case.n))
      eq(2, api.nvim_win_text_height(0, {}).all)

      -- curscol stays at the character's left cell; endcol covers its full width.
      eq({ row = 2, col = 1, curscol = 1, endcol = case.endcol }, fn.screenpos(0, 1, case.row2 + 1))

      eq(case.row2, col_after(0, 'gj'))
      eq(case.row2, col_after(case.row2 + 9, 'g0'))
      -- g$ lands on row 2's last character, at its start byte.
      eq(case.last, col_after(case.row2 + 9, 'g$'))
    end)
  end

  it('mouse click maps to a double-width character on the reflowed row', function()
    command('set mouse=a')
    conceal_line(('a'):rep(10) .. 'HIDDEN' .. ('古'):rep(15))
    -- Row 2's last cell is the 10th 古 of that row.
    api.nvim_input_mouse('left', 'press', '', 0, 1, 19)
    eq({ 1, 58 }, api.nvim_win_get_cursor(0))
  end)

  it('tab width uses raw (position-dependent) vcol through conceal', function()
    -- 5 a (buf0-4) + HIDDEN (buf5-10, concealed, 6 raw cols) + TAB (buf11) + 30 b (buf12-41). Raw
    -- vcol at the TAB is 11 (5 + 6 hidden), tabstop=8 -> tab expands to 5 cells (11->16), same as
    -- if the hidden text were still visible: conceal must not shrink tab stops.
    conceal_line(('a'):rep(5) .. 'HIDDEN' .. '\t' .. ('b'):rep(30))

    -- Reflowed: 5(a) + 5(tab) + 30(b) = 40 cells -> 2 rows of 20.
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Row 2 starts at buf 22 (10 of the 30 b fill out row 1's remaining 10 cells after a+tab=10).
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 23))

    -- Cross-check the actual rendered row against the geometry above: the concealed run must not
    -- leak through as extra blank filler alongside the tab's own (correct) padding.
    screen0:expect([[
      ^aaaaa     bbbbbbbbbb|
      bbbbbbbbbbbbbbbbbbbb|
      {1:~                   }|*3
                          |
    ]])

    eq(22, col_after(0, 'gj'))
    eq(22, col_after(30, 'g0'))
    eq(41, col_after(30, 'g$'))
  end)

  it(
    'tab expands to a full tabstop when the concealed run lands exactly on a tab boundary',
    function()
      -- 5 a (buf0-4) + XXX (buf5-7, concealed, 3 raw cols) + TAB (buf8) + 30 b (buf9-38). Raw vcol
      -- at the TAB is 8 (5 + 3 hidden), tabstop=8 -> vcol 8 is already a tab boundary, so the tab
      -- must expand to a FULL tabstop (8 cells), not 0: this is the exact-multiple edge case of
      -- "conceal must not shrink tab stops" above.
      conceal_line(('a'):rep(5) .. 'XXX' .. '\t' .. ('b'):rep(30), 'XXX')

      -- Reflowed: 5(a) + 8(tab) + 30(b) = 43 cells -> 3 rows (20+20+3).
      eq(3, api.nvim_win_text_height(0, {}).all)

      screen0:expect([[
      ^aaaaa        bbbbbbb|
      bbbbbbbbbbbbbbbbbbbb|
      bbb                 |
      {1:~                   }|*2
                          |
    ]])
    end
  )

  it("'list' with no 'tab:' in 'listchars' uses a fixed-width tab through conceal", function()
    -- With 'listchars' missing a 'tab:' entry, 'list' displays a TAB as a fixed 2 cells instead of
    -- expanding it to 'tabstop', flipping charsize's use_tabstop off.
    command('set list listchars=eol:$')
    -- 5 a (buf0-4) + HIDDEN (buf5-10, concealed) + TAB (buf11, 2 fixed cells) + 30 b (buf12-41).
    conceal_line(('a'):rep(5) .. 'HIDDEN' .. '\t' .. ('b'):rep(30))

    -- Reflowed: 5(a) + 2(tab) + 30(b) = 37 cells -> 2 rows (20 + 17).
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Row 2 starts at buf 25 (13 of the 30 b fill out row 1's remaining 13 cells after a+tab=7).
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 26))

    eq(25, col_after(0, 'gj'))
    eq(0, col_after(20, 'g0'))
    eq(24, col_after(20, 'g$'))
  end)

  it('reflow and motions compose with asymmetric width1/width2 (number, cpoptions+=n)', function()
    -- cpoptions+=n makes continuation rows not repeat the number column, so they are wider than the
    -- first row: width1 = 16 (20-4), width2 = 20 (16+4).
    command('set number numberwidth=4 cpoptions+=n')
    conceal_line(sample)

    -- Reflowed visible width 40 cells -> row1=16, row2=20, row3=4 (3 rows).
    eq(3, api.nvim_win_text_height(0, {}).all)

    -- g0/g$ independently compute each row's true start/end from the cursor's own row, so they land
    -- exactly on row 2's boundaries regardless of width1/width2 being unequal.
    eq(22, col_after(30, 'g0'))
    eq(41, col_after(30, 'g$'))

    -- gj (pre-existing nv_screengo logic, unchanged by this patch) instead accumulates the target
    -- column by width2 per row without realigning to each row's start when width1 != width2: from
    -- buf 0 it lands on buf 26, not row 2's start (buf 22). Same offset occurs with plain
    -- unconcealed text under the same options: a pre-existing 'cpoptions'+=n quirk, not a reflow
    -- regression.
    eq(26, col_after(0, 'gj'))
  end)

  it('reflow and motions account for inline virtual text width', function()
    -- 10 a (buf0-9) + HIDDEN (buf10-15, concealed) + 4 b (buf16-19) + inline virt_text (10 cells)
    -- anchored at buf20 (renders just before it) + the 5th 'b' (buf20).
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(5) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    api.nvim_buf_set_extmark(0, ns, 0, 20, {
      virt_text = { { ('X'):rep(10), 'Comment' } },
      virt_text_pos = 'inline',
    })

    -- Without the virt_text, concealed reflow (10 + 5 = 15 cells) would fit in one row; the
    -- virt_text's 10 cells push the total to 25, so it must be counted to get 2 rows.
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Row 1: 10(a) + 4(b) + 6(first part of virt_text) = 20 cells. Row 2: 4(remaining virt_text) +
    -- 1(last b, buf20) = 5 cells.

    -- gj from row 1 lands on the last 'b' (buf20), the only real buffer position on row 2.
    eq(20, col_after(0, 'gj'))

    -- g$ from row 1 lands on the last real buffer position on that row (buf19), not the virtual
    -- text that visually follows it.
    eq(19, col_after(0, 'g$'))

    -- Mouse clicks map through the virtual text correctly: row 2 cell 4 is the last 'b'.
    command('set mouse=a')
    api.nvim_input_mouse('left', 'press', '', 0, 1, 4)
    eq({ 1, 20 }, api.nvim_win_get_cursor(0))

    -- Not testing screenpos() here: it misreports the row for a position right after inline virtual
    -- text spanning a wrap boundary, even without conceal (pre-existing, unrelated).
  end)

  it(
    "reflow height counts inline virtual text anchored at a conceal region's start column, "
      .. "unaffected by 'linebreak'",
    function()
      -- 14 a (buf 0-13) + HIDDEN (buf 14-19, concealed) + 4 b (buf 20-23), with a 3-cell inline
      -- virt_text anchored at buf 14 -- the SAME column where the conceal region starts.
      api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(14) .. 'HIDDEN' .. ('b'):rep(4) })
      api.nvim_buf_set_extmark(0, ns, 0, 14, {
        virt_text = { { 'XXX', 'Comment' } },
        virt_text_pos = 'inline',
      })
      api.nvim_buf_set_extmark(0, ns, 0, 14, { end_col = 20, conceal = '' })

      -- The virt_text is drawn regardless of the conceal on the character it's anchored to (it is
      -- not itself hidden), so reflowed width is 14 + 3(virt) + 4(b) = 21 cells -> 2 rows, not 14 +
      -- 4 = 18 cells -> 1 row (which is what a buggy "hide the virt_text too" count would give).
      eq(2, api.nvim_win_text_height(0, {}).all)
      screen0:expect([[
      ^aaaaaaaaaaaaaa{18:XXX}bbb|
      b                   |
      {1:~                   }|*3
                          |
    ]])

      -- gj from row 1 lands on the last 'b' (buf23), the only real buffer position on row 2.
      eq(23, col_after(0, 'gj'))

      -- g$ from row 1 lands on the last real buffer position on that row (buf22): the virt_text
      -- anchored on the concealed buf14 still counts its own width toward the screen column, even
      -- though the character it's anchored to does not.
      eq(22, col_after(0, 'g$'))

      -- Pin down a bug where scol2col() undercounted this virt_text's width once 'linebreak'
      -- triggered the same lookup from a different caller. There is no 'breakat' character
      -- anywhere in this line, so 'linebreak' has no visible effect on the wrap point here; gj/g$
      -- must land the same as above.
      command('set linebreak')
      screen0:expect({ unchanged = true })

      eq(23, col_after(0, 'gj'))
      eq(22, col_after(0, 'g$'))
    end
  )

  it("'linebreak' counts inline virtual text width in its word-fit lookahead", function()
    -- 12 a (buf 0-11) + space (buf 12) + "bb" (buf 13-14) + a 6-cell inline virt_text anchored at
    -- buf 15 + "cc" (buf 15-16). No conceal at all (this test overrides the shared before_each's
    -- conceallevel so it exercises the lookahead's OWN blind spot for virt_text in isolation,
    -- independently of the conceal-hidden discount covered by the test above).
    command('set linebreak')
    command('setlocal conceallevel=0')
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(12) .. ' bb' .. 'cc' })
    api.nvim_buf_set_extmark(0, ns, 0, 15, {
      virt_text = { { ('X'):rep(6), 'Comment' } },
      virt_text_pos = 'inline',
    })

    -- True displayed width of "bb"+virt_text+"cc" is 2+6+2=10 cells; only 7 remain on row 1 after
    -- "aaaaaaaaaaaa " (13 cells). A lookahead blind to virt_text sees only the raw 4 cells of
    -- "bbcc", which fits, so it never pushes the word to row 2 -- splitting the virt_text itself
    -- mid-glyph once the raw render naturally reaches the window edge.
    eq(2, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aaaaaaaaaaaa        |
      bb{18:XXXXXX}cc          |
      {1:~                   }|*3
                          |
    ]])

    -- gj from row 1 lands on row 2's first character (buf 13): the wrapped word's own start, not on
    -- some byte in the middle of it.
    feed('gj')
    eq({ 1, 13 }, api.nvim_win_get_cursor(0))

    -- g$ from row 1 lands on the space (buf 12): the whole word (and its virt_text) was pushed to
    -- row 2, so the space is the last real buffer position left on row 1.
    eq(12, col_after(0, 'g$'))
  end)

  it('non-inline virtual text (eol/overlay/right_align) does not affect reflow', function()
    -- Unlike inline virtual text, these positions don't occupy in-line width, so they must not
    -- change the reflowed line's wrap point.
    conceal_line(('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(5))
    api.nvim_buf_set_extmark(0, ns, 0, 20, {
      virt_text = { { ('X'):rep(10), 'Comment' } },
      virt_text_pos = 'eol',
    })

    -- Concealed reflow is still 10 + 5 = 15 cells -> 1 row.
    eq(1, api.nvim_win_text_height(0, {}).all)
  end)

  it('ephemeral (decoration-provider) conceal does not reflow', function()
    -- Ephemeral conceal is created during drawing and is not in the marktree, so the shared
    -- size/geometry path cannot see it off-draw. Reflowing it would make the draw disagree with
    -- cursor/scroll/mouse geometry, so ephemeral conceal keeps the historical boguscols behavior
    -- (no reflow) until it can be made off-draw-visible.
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

  -- Insert-mode Up/Down move by logical line (cursor_up()/cursor_down()), unlike gj/gk's screen-row
  -- motion. A reflowed line's extra rows must not count as lines.
  it('insert-mode Up/Down move past a reflowed line as a single logical line', function()
    -- concealcursor= reveals the cursor line, so line 1's height changes as the cursor enters it.
    command('setlocal concealcursor=')
    conceal_line(sample)
    api.nvim_buf_set_lines(0, 1, -1, true, { 'short2', 'short3' })

    -- From line 2, insert-mode <Up> lands on line 1 directly (not some fractional row).
    api.nvim_win_set_cursor(0, { 2, 3 })
    feed('i<Up>')
    eq(1, api.nvim_win_get_cursor(0)[1])
    feed('<Esc>')

    -- From line 1 (the reflowed line), insert-mode <Down> lands on line 2 directly, not "stuck"
    -- partway through line 1's own second row.
    api.nvim_win_set_cursor(0, { 1, 5 })
    feed('i<Down>')
    eq(2, api.nvim_win_get_cursor(0)[1])
    feed('<Esc>')
  end)

  it('typing on a reflowed line keeps its geometry correct as it grows', function()
    -- 25 raw cells: concealed -> 19 displayed (1 row); typed text will grow it past 1 row.
    conceal_line(('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9))
    eq(1, api.nvim_win_text_height(0, {}).all)

    feed('i' .. ('c'):rep(15) .. '<Esc>')
    eq(
      ('c'):rep(15) .. ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9),
      api.nvim_buf_get_lines(0, 0, 1, true)[1]
    )
    -- Concealed width grew from 19 to 34 displayed cells: now needs 2 rows.
    eq(2, api.nvim_win_text_height(0, {}).all)
  end)

  it("':substitute' on a reflowed line updates its height to match the new content", function()
    -- ':substitute' operates on raw buffer columns, not screen position, so it must be unaffected
    -- by the reflowed geometry while still updating the height.
    conceal_line(('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(20))
    eq(2, api.nvim_win_text_height(0, {}).all)

    command([[%s/b\{20}/X/]])
    eq({ ('a'):rep(10) .. 'HIDDENX' }, api.nvim_buf_get_lines(0, 0, -1, true))
    -- Concealed width shrank to 5 displayed cells: now needs only 1 row.
    eq(1, api.nvim_win_text_height(0, {}).all)
  end)
end)

-- Revealing/concealing a wrapped line changes its height, so cursor moves must force a full redraw
-- (extconceal_line_changes_height()) to avoid stale cells from the TUI's scroll optimisation.
describe('conceal-aware wrapping redraw (#14409)', function()
  before_each(clear)

  -- 'conceallevel=1' shows a 1-cell replacement character rather than fully hiding, but that still
  -- changes a line's reflowed height when revealed/concealed.
  for _, case in ipairs({
    {
      level = 2,
      cchar = '',
      expected = [[
      L07-AAA-t07-BBBBBBBBBB        |
      L08-AAA-t08-BBBBBBBBBB        |
      L09-AAA-t09-BBBBBBBBBB        |
      L10-AAA-t10-BBBBBBBBBB        |
      ^L11-AAACCCCCCCCCCCC-t11-BBBBBB|
      BBBB                          |
      L12-AAA-t12-BBBBBBBBBB        |
                                    |
    ]],
    },
    {
      level = 1,
      cchar = '#',
      expected = [[
      L07-AAA{14:#}-t07-BBBBBBBBBB       |
      L08-AAA{14:#}-t08-BBBBBBBBBB       |
      L09-AAA{14:#}-t09-BBBBBBBBBB       |
      L10-AAA{14:#}-t10-BBBBBBBBBB       |
      ^L11-AAACCCCCCCCCCCC-t11-BBBBBB|
      BBBB                          |
      L12-AAA{14:#}-t12-BBBBBBBBBB       |
                                    |
    ]],
    },
  }) do
    it('keeps geometry correct scrolling with conceallevel=' .. case.level, function()
      local screen = Screen.new(30, 8)
      local ns = api.nvim_create_namespace('conceal_wrap_redraw')
      -- concealcursor= reveals the cursor line, so moving the cursor changes that line's height.
      command('set wrap conceallevel=' .. case.level .. ' concealcursor= scrolloff=1')
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
        api.nvim_buf_set_extmark(0, ns, i, c - 1, { end_col = c - 1 + 12, conceal = case.cchar })
      end

      -- Scroll into the middle, then walk the cursor down through several reflowing lines.
      api.nvim_win_set_cursor(0, { 8, 0 })
      feed('zzjjj')

      -- Cursor is on line 11 (revealed: 2 rows, C's visible); the other visible lines are concealed
      -- (1 row). Every line's geometry must be correct after the height-changing moves.
      screen:expect(case.expected)
    end)
  end
end)

-- Materialized conceal lives in the shared buffer marktree, not per-window state; verify no
-- cross-window leakage when two windows share a buffer with different 'conceallevel'.
describe('conceal-aware wrapping with multiple windows on one buffer (#14409)', function()
  before_each(clear)

  it("a window with 'conceallevel=0' shows the raw (non-reflowed) height independently", function()
    local screen = Screen.new(41, 8)
    local ns = api.nvim_create_namespace('conceal_wrap_multiwin')
    command('set wrap')
    -- 25 raw cells: concealed -> 19 displayed (1 row at width 20); unconcealed -> 25 raw (2 rows).
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    command('setlocal conceallevel=2 concealcursor=nvic')
    local concealwin = api.nvim_get_current_win()
    -- :vsplit opens the new window on the left (with 'nosplitright') and moves focus to it.
    command('vsplit')
    command('setlocal conceallevel=0')
    local plainwin = api.nvim_get_current_win()
    api.nvim_win_set_width(plainwin, 20)

    eq(1, api.nvim_win_text_height(concealwin, { start_row = 0, end_row = 0 }).all)
    eq(2, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
    screen:expect([[
      ^aaaaaaaaaaHIDDENbbbb│aaaaaaaaaabbbbbbbbb |
      bbbbb               │{1:~                   }|
      {1:~                   }│{1:~                   }|*4
      {3:[No Name] [+]        }{2:[No Name] [+]       }|
                                               |
    ]])

    -- Redrawing each window repeatedly must not leak conceal state across them.
    for _ = 1, 3 do
      api.nvim_set_current_win(concealwin)
      command('redraw')
      api.nvim_set_current_win(plainwin)
      command('redraw')
    end
    eq(1, api.nvim_win_text_height(concealwin, { start_row = 0, end_row = 0 }).all)
    eq(2, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
  end)
end)
