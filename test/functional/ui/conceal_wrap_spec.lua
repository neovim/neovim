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

  local function screen_lines(count)
    command('redraw!')
    return exec_lua(function(nrows)
      local rows = {}
      for row = 1, nrows do
        local cells = {}
        for col = 1, vim.o.columns do
          cells[#cells + 1] = vim.fn.screenstring(row, col)
        end
        rows[row] = table.concat(cells):gsub('%s+$', '')
      end
      return rows
    end, count)
  end

  it('fully hidden extmark conceal reflows a wrapped line', function()
    -- 25 raw cells: without conceal this wraps to two screen rows at width 20.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9) })
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Hide "HIDDEN" (cols 10..16, no replacement char): 19 displayed cells -> one row.
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    eq(1, api.nvim_win_text_height(0, {}).all)
  end)

  it('partial text height maps raw virtual columns to reflowed rows', function()
    api.nvim_buf_set_lines(0, 0, -1, true, {
      ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9),
    })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    -- Raw vcol 20 is displayed at column 14 on the only screen row.
    eq(1, api.nvim_win_text_height(0, { start_row = 0, start_vcol = 20 }).all)

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, {
      ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(29),
    })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })

    -- Raw vcol 25 is displayed at column 19, still on the first screen row.
    eq(
      1,
      api.nvim_win_text_height(0, { start_row = 0, start_vcol = 0, end_row = 0, end_vcol = 25 }).all
    )
    eq(26, api.nvim_win_text_height(0, { max_height = 1 }).end_vcol)

    screen0:try_resize(12, 6)
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('A'):rep(11) .. '古' .. ('B'):rep(5) })
    api.nvim_buf_set_extmark(0, ns, 0, 11, { end_col = 14, conceal = '' })
    for vcol = 11, 14 do
      eq(2, api.nvim_win_text_height(0, { start_row = 0, start_vcol = vcol }).all)
    end

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('A'):rep(11) .. 'X' .. 'B' })
    api.nvim_buf_set_extmark(0, ns, 0, 11, { end_col = 12, conceal = '' })
    api.nvim_buf_set_extmark(0, ns, 0, 11, {
      virt_text = { { 'III' } },
      virt_text_pos = 'inline',
    })
    eq(
      2,
      api.nvim_win_text_height(0, { start_row = 0, start_vcol = 0, end_row = 0, end_vcol = 13 }).all
    )
    eq(12, api.nvim_win_text_height(0, { max_height = 1 }).end_vcol)
  end)

  it('conceal extmark changes invalidate cached geometry', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(10) })
    api.nvim_win_set_cursor(0, { 1, 20 })
    command('redraw')

    local raw = { 2, 1 }
    local hidden = { 1, 15 }
    eq(
      { raw, hidden, raw, hidden, raw, hidden, raw },
      exec_lua(function(nsid)
        local function pos()
          return { vim.fn.winline(), vim.fn.wincol() }
        end

        local function set(conceal, id)
          return vim.api.nvim_buf_set_extmark(
            0,
            nsid,
            0,
            10,
            { id = id, end_col = 16, conceal = conceal }
          )
        end

        local positions = { pos() }
        local id = set('')
        positions[#positions + 1] = pos()
        set(false, id)
        positions[#positions + 1] = pos()
        set('', id)
        positions[#positions + 1] = pos()
        vim.api.nvim_buf_del_extmark(0, nsid, id)
        positions[#positions + 1] = pos()
        set('')
        positions[#positions + 1] = pos()
        vim.api.nvim_buf_clear_namespace(0, nsid, 0, -1)
        positions[#positions + 1] = pos()
        return positions
      end, ns)
    )
  end)

  it('conceal replacement width reports correct geometry before redraw', function()
    for _, case in ipairs({
      { level = 1, cchar = '', tabs = 'tabstop=32 vartabstop=', text = '\tX', height = 1 },
      { level = 2, cchar = 'X', tabs = 'tabstop=8 vartabstop=32', text = '\tX', height = 1 },
      { level = 3, cchar = '', tabs = 'tabstop=32 vartabstop=', text = '\tX', height = 1 },
      {
        level = 2,
        cchar = '界',
        tabs = 'tabstop=8 vartabstop=',
        text = 'X' .. ('a'):rep(19),
        height = 2,
      },
    }) do
      command('enew!')
      command(('setlocal conceallevel=%d %s'):format(case.level, case.tabs))
      eq(
        { case.height, 1, 1 },
        exec_lua(function(nsid, cchar, text)
          vim.api.nvim_buf_set_lines(0, 0, -1, true, { text })
          vim.api.nvim_buf_clear_namespace(0, nsid, 0, -1)
          vim.api.nvim_buf_set_extmark(0, nsid, 0, 0, { end_col = 1, conceal = cchar })
          vim.api.nvim_win_set_cursor(0, { 1, 0 })
          return {
            vim.api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all,
            vim.fn.winline(),
            vim.fn.wincol(),
          }
        end, ns, case.cchar, case.text)
      )
    end

    screen0:try_resize(18, 6)
    command('enew! | setlocal conceallevel=2 linebreak breakindent breakindentopt=shift:2,min:0')
    command('set breakat=\\ ')
    api.nvim_buf_set_lines(0, 0, -1, true, { '- **Alpha** Beta Gamma Delta Epsilon Lambda' })
    api.nvim_buf_set_extmark(0, ns, 0, 2, { end_col = 4, conceal = '界' })
    api.nvim_buf_set_extmark(0, ns, 0, 9, { end_col = 11, conceal = '界' })
    eq(3, api.nvim_win_text_height(0, {}).all)
    eq({ row = 1, col = 3, curscol = 3, endcol = 4 }, fn.screenpos(0, 1, 3))
    command('set virtualedit=all mouse=a')
    for col = 2, 3 do
      api.nvim_input_mouse('left', 'press', '', 0, 0, col)
      eq({ 1, 2 }, api.nvim_win_get_cursor(0))
      eq(0, fn.getcurpos()[4])
    end
    screen0:expect([[
      - {14:^界}Alpha{14:界} Beta  |
        Gamma Delta     |
        Epsilon Lambda  |
      {1:~                 }|*2
                        |
    ]])

    api.nvim_buf_set_lines(0, 0, -1, true, { 'AX\tB' })
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_extmark(0, ns, 0, 1, { end_col = 2, conceal = '界' })
    eq({ row = 1, col = 10, curscol = 10, endcol = 10 }, fn.screenpos(0, 1, 4))
  end)

  it('screenpos(), winline() and wincol() report reflowed positions', function()
    conceal_line(sample)
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 27))
    eq({ row = 1, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 1))
    eq({ row = 1, col = 15, curscol = 15, endcol = 15 }, fn.screenpos(0, 1, 21))

    api.nvim_win_set_cursor(0, { 1, 26 })
    eq(2, fn.winline())
    eq(1, fn.wincol())

    api.nvim_win_set_cursor(0, { 1, 20 })
    eq(1, fn.winline())
    eq(15, fn.wincol())
  end)

  it('replacement characters do not retain the source tab or wide character width', function()
    command('set tabstop=32')
    for _, case in ipairs({
      { '\tX', 0, 1, 'X', 'XX' },
      { ('a'):rep(18) .. '界Z', 18, 21, 'X', ('a'):rep(18) .. 'XZ' },
      { '界Z', 0, 3, '界', '界Z' },
      { 'XZ', 0, 1, '界', '界Z' },
      { '\tZ', 0, 1, '界', '界Z' },
      { '\tX', 0, 1, '', ' X', level = 1 },
      { '\tX', 0, 1, '', 'X', level = 3 },
      { '界\tZ', 0, 3, '界', '界' .. (' '):rep(18), (' '):rep(12) .. 'Z' },
      { ('a'):rep(19) .. 'XZ', 19, 20, '界', ('a'):rep(19) .. '>', '界Z' },
      { ('a'):rep(19) .. '\tZ', 19, 20, '界', ('a'):rep(19) .. '>', '界Z' },
      { ('a'):rep(19) .. '界Z', 19, 22, 'X', ('a'):rep(19) .. 'X', 'Z' },
    }) do
      command('set conceallevel=' .. (case.level or 2))
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      api.nvim_buf_set_lines(0, 0, -1, true, { case[1], 'NEXT' })
      api.nvim_buf_set_extmark(0, ns, 0, case[2], { end_col = case[3], conceal = case[4] })
      api.nvim_win_set_cursor(0, { 2, 0 })
      local height = case[6] and 2 or 1
      eq(height, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
      local rows = case[6] and { case[5], case[6], 'NEXT' } or { case[5], 'NEXT' }
      for i, row in ipairs(rows) do
        rows[i] = row:gsub('%s+$', '')
      end
      eq(rows, screen_lines(height + 1))
      eq({ row = height + 1, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 2, 1))
      local pos = case[2] == 19 and case[4] == '界' and { 2, 1 } or { 1, case[2] + 1 }
      eq(
        { pos, pos, pos, pos, pos, pos },
        exec_lua(function(col)
          local positions = {}
          for _, ve in ipairs({ '', 'all' }) do
            vim.wo.virtualedit = ve
            vim.api.nvim_win_set_cursor(0, { 1, col })
            positions[#positions + 1] = { vim.fn.winline(), vim.fn.wincol() }
            local p = vim.fn.screenpos(0, 1, col + 1)
            positions[#positions + 1] = { p.row, p.curscol }
            vim.cmd('redraw!')
            positions[#positions + 1] = { vim.fn.winline(), vim.fn.wincol() }
          end
          vim.wo.virtualedit = ''
          return positions
        end, case[2])
      )
    end
  end)

  it('resizing on a tab is independent of unrelated conceal marks', function()
    local positions = {}
    for _, marked in ipairs({ false, true }) do
      screen0:try_resize(20, 14)
      local before = exec_lua(function(nsid, add_mark)
        vim.cmd('enew!')
        local lines = {}
        for i = 1, 100 do
          lines[i] = 'line' .. i
        end
        lines[50] = ('a'):rep(15) .. '\t' .. ('b'):rep(30)
        vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
        vim.api.nvim_buf_clear_namespace(0, nsid, 0, -1)
        if add_mark then
          vim.api.nvim_buf_set_extmark(0, nsid, 0, 0, { end_col = 1, conceal = '' })
        end
        vim.api.nvim_win_set_cursor(0, { 50, 15 })
        vim.cmd('normal! zz')
        vim.cmd('redraw!')
        return { vim.fn.winline(), vim.fn.wincol(), vim.fn.winsaveview() }
      end, ns, marked)
      screen0:try_resize(20, 10)
      local after = exec_lua(function()
        vim.cmd('redraw!')
        return { vim.fn.winline(), vim.fn.wincol(), vim.fn.winsaveview() }
      end)
      positions[#positions + 1] = { before, after }
    end
    eq(positions[1], positions[2])
  end)

  it('all inline virtual text cells on a concealed character have the same mouse anchor', function()
    command('set mouse=a mousemoveevent')
    for _, text in ipairs({ 'III', 'I界I' }) do
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      conceal_line('aHIDDENb')
      api.nvim_buf_set_extmark(0, ns, 0, 1, {
        virt_text = { { text } },
        virt_text_pos = 'inline',
      })
      eq({ 'a' .. text .. 'b' }, screen_lines(1))
      for col = 1, fn.strdisplaywidth(text) do
        api.nvim_input_mouse('move', '', '', 0, 0, col)
        eq(2, fn.getmousepos().column)
      end
    end
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

    -- A concealed trailing TAB does not keep its raw final cell when gk chooses the row above.
    command('set tabstop=32')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(40), ('b'):rep(15) .. '\t' })
    api.nvim_buf_set_extmark(0, ns, 1, 15, { end_col = 16, conceal = '' })
    api.nvim_win_set_cursor(0, { 2, 15 })
    feed('$gk')
    eq({ 1, 39 }, api.nvim_win_get_cursor(0))
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
    screen0:expect([[
        ccccccccccccc^ccccc|
      {1:~                   }|*4
                          |
    ]])
    eq({ row = 1, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 21))

    command('set mouse=a')
    api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
    eq({ 1, 20 }, api.nvim_win_get_cursor(0))

    eq(20, col_after(35, 'g0')) -- leftcol itself
    eq(22, col_after(35, 'g^')) -- past the two leading spaces
    eq(30, col_after(35, 'gm')) -- leftcol + width/2
    eq(39, col_after(35, 'g$')) -- last visible raw column
  end)

  it("matches equivalent displayed text under 'rightleft'", function()
    command('set rightleft')
    conceal_line(sample)
    command('redraw!')
    local concealed = screen0:get_snapshot()

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. ('b'):rep(30) })
    command('redraw!')
    eq(concealed, screen0:get_snapshot())
  end)

  it('a line with nothing hidden keeps its virtual columns', function()
    -- A conceal-capable buffer must not change motions on an unconcealed line.
    command('set linebreak showbreak=>>')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'b 界 \t\t\t\tb a ', 'untouched', 'mark' })

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
    api.nvim_buf_set_extmark(0, ns, 2, 0, { end_col = 1, conceal = '' })
    eq(unconcealed, motions())
  end)

  it('raw virtual columns and ordinary motions ignore conceal-dependent wrap prefixes', function()
    for _, opts in ipairs({
      'showbreak=>>',
      'showbreak= breakindent breakindentopt=shift:2,min:0',
      'showbreak=>> nobreakindent linebreak',
    }) do
      command('set ' .. opts)
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      api.nvim_buf_set_lines(0, 0, -1, true, { sample, sample })
      local function positions()
        local result = {}
        for col = 1, #sample do
          result[#result + 1] = fn.virtcol({ 1, col }, true)
        end
        result[#result + 1] = col_after(24, 'j')
        result[#result + 1] = api.nvim_win_get_cursor(0)
        feed('k')
        result[#result + 1] = api.nvim_win_get_cursor(0)
        result[#result + 1] = col_after(0, '25|')
        result[#result + 1] = col_after(24, 'vj')
        feed('<Esc>')
        return result
      end
      local raw = positions()
      api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
      eq(raw, positions())
      api.nvim_win_set_cursor(0, { 1, 24 })
      eq(1, fn.winline())
      eq(19, fn.wincol())
      command('redraw!')
      eq({ 1, 19 }, { fn.winline(), fn.wincol() })
    end
  end)

  it('Visual blocks keep raw endpoints when wrap prefixes move', function()
    screen0:try_resize(20, 10)
    command('set showbreak=>>')
    api.nvim_buf_set_lines(0, 0, -1, true, { sample, sample })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    col_after(24, '<C-V>j')
    command('redraw!')
    local pos = fn.screenpos(0, 1, 25)
    eq({ 1, 19 }, { pos.row, pos.col })
    eq(false, fn.screenattr(pos.row, pos.col - 1) == fn.screenattr(pos.row, pos.col))
    eq(fn.screenattr(pos.row, pos.col - 1), fn.screenattr(pos.row, pos.col + 1))
    feed('y')
    eq('b\nb', fn.getreg('"'))
  end)

  it('dense conceal redraws across decoration-provider range boundaries', function()
    screen0:try_resize(120, 65)
    command('set linebreak')
    local last_row = exec_lua(function(nsid)
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { ('abcX '):rep(1600) })
      for i = 0, 1599 do
        vim.api.nvim_buf_set_extmark(0, nsid, 0, i * 5 + 3, {
          end_col = i * 5 + 4,
          conceal = '',
        })
      end
      _G.range_calls = 0
      _G.range_changed = false
      local extra_ns = vim.api.nvim_create_namespace('range_marks')
      vim.api.nvim_set_decoration_provider(nsid, {
        on_range = function(_, _, buf, _, col)
          _G.range_calls = _G.range_calls + 1
          if col > 0 and not _G.range_changed then
            _G.range_changed = true
            for _ = 1, 1000 do
              vim.api.nvim_buf_set_extmark(buf, extra_ns, 0, 0, {})
            end
          end
        end,
      })
      vim.cmd('redraw!')
      local cells = {}
      for col = 1, 120 do
        cells[col] = vim.fn.screenstring(54, col)
      end
      return table.concat(cells):gsub('%s+$', '')
    end, ns)
    eq(('abc '):rep(10):sub(1, -2), last_row)
    eq(true, exec_lua('return _G.range_changed'))
    local row = ('abc '):rep(30):sub(1, -2)
    for _ = 1, 3 do
      eq({ row, row }, screen_lines(2))
    end
    eq(54, api.nvim_win_text_height(0, {}).all)
    eq(true, exec_lua('return _G.range_calls > 3'))
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    eq(67, api.nvim_win_text_height(0, {}).all)
    eq({ ('abcX '):rep(24):sub(1, -2) }, screen_lines(1))
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
      if case.name == 'showbreak' then
        eq({ row = 2, col = 3, curscol = 3, endcol = 3 }, fn.screenpos(0, 1, 27))
        eq({ row = 3, col = 3, curscol = 3, endcol = 3 }, fn.screenpos(0, 1, 45))
      end
    end)
  end

  it("'linebreak' uses displayed width for exact-fit and overflow words", function()
    command('set linebreak')

    local function set_word(width)
      api.nvim_buf_set_lines(0, 0, -1, true, {
        ('a'):rep(5) .. 'HIDDEN' .. ('b'):rep(5) .. ' ' .. ('c'):rep(width),
      })
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      api.nvim_buf_set_extmark(0, ns, 0, 5, { end_col = 11, conceal = '' })
    end

    -- Nine c's exactly fill the displayed row.
    set_word(9)
    eq(1, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aaaaabbbbb ccccccccc|
      {1:~                   }|*4
                          |
    ]])
    feed('g$')
    eq({ 1, 25 }, api.nvim_win_get_cursor(0))

    -- Ten c's overflow by one cell, so the whole word moves to row 2.
    set_word(10)
    api.nvim_win_set_cursor(0, { 1, 0 })
    eq(2, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aaaaabbbbb          |
      cccccccccc          |
      {1:~                   }|*3
                          |
    ]])
    feed('gj')
    eq({ 1, 17 }, api.nvim_win_get_cursor(0))
    feed('g0')
    eq({ 1, 17 }, api.nvim_win_get_cursor(0))
    feed('g$')
    eq({ 1, 26 }, api.nvim_win_get_cursor(0))
  end)

  it("g$ stays on its own row when 'linebreak' pads the row with filler", function()
    -- The first two rows end in filler belonging to their last character.
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

    feed('g$')
    eq({ 1, 22 }, api.nvim_win_get_cursor(0))
    feed('gjg0g$')
    eq({ 1, 37 }, api.nvim_win_get_cursor(0))
    -- The short final row must still reach EOL.
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
    -- The tab spans both rows, but its cursor is drawn on the second row.
    command('set breakindent breakindentopt=min:0 tabstop=8')
    conceal_line(('a'):rep(6) .. 'HIDDEN' .. ('b'):rep(12) .. '\t' .. ('c'):rep(5))

    -- Row 1's last character is the b at buf 23, not the tab that starts on it.
    eq(23, col_after(0, 'g$'))
    eq(1, fn.screenpos(0, 1, fn.getcurpos()[3]).row)
  end)

  it("'linebreak' measures a concealed tab from the line start at every word break", function()
    -- The tab starts at raw vcol 5, even when lookahead resumes at a later word.
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

  it("'linebreak' measures a visible tab after conceal from the raw virtual column", function()
    command('set linebreak tabstop=8 breakat=\\ ')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaaa XX\t' .. ('b'):rep(14) })
    api.nvim_buf_set_extmark(0, ns, 0, 5, { end_col = 7, conceal = '' })

    -- The tab starts at raw vcol 7, so it occupies one cell. The displayed line is exactly 20
    -- cells and the following word stays on the first row.
    eq(1, api.nvim_win_text_height(0, {}).all)
    eq(1, fn.screenpos(0, 1, 22).row)
    screen0:expect([[
      ^aaaa  bbbbbbbbbbbbbb|
      {1:~                   }|*4
                          |
    ]])

    command('set vartabstop=4,8')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaaa XX\t' .. ('b'):rep(10) })
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_extmark(0, ns, 0, 5, { end_col = 7, conceal = '' })
    eq(1, api.nvim_win_text_height(0, {}).all)
    eq(1, fn.screenpos(0, 1, 18).row)

    command('set vartabstop=')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaaa a\tXyyyyyy\tbbbb' })
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_extmark(0, ns, 0, 7, { end_col = 8, conceal = '' })
    eq(1, api.nvim_win_text_height(0, {}).all)
    eq(1, fn.screenpos(0, 1, 19).row)
  end)

  it(
    "'linebreak' still treats a space as a break point when the concealed text right after it "
      .. "starts with a 'breakat' character",
    function()
      -- Concealed break characters must not absorb the preceding visible break.
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
      eq(fn.virtcol({ 1, '$' }) - 1, api.nvim_win_text_height(0, {}).end_vcol)
      feed('g$')
      eq({ 1, 22 }, api.nvim_win_get_cursor(0))
    end
  )

  it("'linebreak' does not treat a concealed break run as visible", function()
    command('set linebreak')
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(14) .. '**' .. ('b'):rep(6) })
    api.nvim_buf_set_extmark(0, ns, 0, 14, { end_col = 16, conceal = '' })

    local height = api.nvim_win_text_height(0, {})
    eq({ 1, fn.virtcol({ 1, '$' }) - 1 }, { height.all, height.end_vcol })
    screen0:expect([[
      ^aaaaaaaaaaaaaabbbbbb|
      {1:~                   }|*4
                          |
    ]])
  end)

  it("'linebreak' looks through hidden whitespace inside the following word", function()
    command('set linebreak')
    for _, hidden in ipairs({ 'HID HID', 'HID\tHID', 'HID  HID' }) do
      conceal_line('aaaaaa bb' .. hidden .. ('c'):rep(12), hidden)
      eq({ 'aaaaaa', 'bb' .. ('c'):rep(12) }, screen_lines(2))
      eq(2, api.nvim_win_text_height(0, {}).all)
      eq(7, col_after(0, 'gj'))
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
    end
    conceal_line('aa bb HID HID HID HID HID ' .. ('c'):rep(15) .. ' dd', 'HID HID HID HID HID ')
    eq({ 'aa bb', ('c'):rep(15) .. ' dd' }, screen_lines(2))
    eq(2, api.nvim_win_text_height(0, {}).all)
  end)

  it("'linebreak' classifies a visible conceal replacement instead of its source byte", function()
    screen0:try_resize(12, 6)
    command('set linebreak conceallevel=1')
    api.nvim_buf_set_lines(0, 0, -1, true, { '1234567890 éB' })
    api.nvim_buf_set_extmark(0, ns, 0, 11, { end_col = 13, conceal = '' })

    -- The default replacement is a space, so the displayed line is equivalent to
    -- "1234567890  B": the whole break run stays on row 1 and B starts row 2.
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 14))
    eq(13, col_after(0, 'gj'))

    screen0:try_resize(20, 6)
    for _, source in ipairs({ 'X', '界' }) do
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      api.nvim_buf_set_lines(0, 0, -1, true, { 'aa bb ' .. source .. ('c'):rep(15) })
      api.nvim_buf_set_extmark(0, ns, 0, 6, { end_col = 6 + #source, conceal = ' ' })
      eq({ 'aa bb', ('c'):rep(15) }, screen_lines(2))
      eq(2, api.nvim_win_text_height(0, {}).all)
    end

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaaaaa bbbbb bbbbbbbb' })
    api.nvim_buf_set_extmark(0, ns, 0, 12, { end_col = 13, conceal = 'X' })
    eq({ 'aaaaaa', 'bbbbbXbbbbbbbb' }, screen_lines(2))
  end)

  it("'linebreak' does not duplicate 'breakindent' after a concealed row boundary", function()
    command('set linebreak breakindent breakindentopt=shift:2,min:0 conceallevel=3')
    api.nvim_buf_set_lines(0, 0, -1, true, {
      ('a'):rep(15) .. ' `bbbb ' .. ('c'):rep(8) .. ' ' .. ('d'):rep(8) .. ' ' .. ('e'):rep(8),
    })
    api.nvim_buf_set_extmark(0, ns, 0, 16, { end_col = 17, conceal = '' })

    eq({ row = 3, col = 3, curscol = 3, endcol = 3 }, fn.screenpos(0, 1, 32))
    screen0:expect([[
      ^aaaaaaaaaaaaaaa     |
        bbbb cccccccc     |
        dddddddd eeeeeeee |
      {1:~                   }|*2
                          |
    ]])
  end)

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

  it('tab width uses raw vcol through conceal, including exact tabstop boundaries', function()
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

    -- At raw vcol 8 the tab expands to a full tabstop, not zero cells.
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    conceal_line(('a'):rep(5) .. 'XXX' .. '\t' .. ('b'):rep(30), 'XXX')
    api.nvim_win_set_cursor(0, { 1, 0 })
    eq(3, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aaaaa        bbbbbbb|
      bbbbbbbbbbbbbbbbbbbb|
      bbb                 |
      {1:~                   }|*2
                          |
    ]])
  end)

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

    -- Preserve gj's existing width2 offset under 'cpoptions'+=n.
    eq(26, col_after(0, 'gj'))
  end)

  it('reflow and motions account for inline virtual text width', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(5) })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    api.nvim_buf_set_extmark(0, ns, 0, 20, {
      virt_text = { { ('X'):rep(10), 'Comment' } },
      virt_text_pos = 'inline',
    })

    -- Inline text crosses the wrap boundary; the last 'b' is the only buffer text on row 2.
    eq(2, api.nvim_win_text_height(0, {}).all)

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

  it('motions account for conceal width changes that cancel out by end of line', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(40) })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 1, conceal = '界' })
    api.nvim_buf_set_extmark(0, ns, 0, 30, { end_col = 31, conceal = '' })

    -- The first replacement adds one displayed cell and the later conceal removes one, so the
    -- total width is unchanged. Between them, however, screen and virtual columns differ.
    eq(2, api.nvim_win_text_height(0, {}).all)
    eq({ 19, 19 }, { col_after(0, 'gj'), col_after(25, 'g0') })
  end)

  it(
    "reflow height counts inline virtual text anchored at a conceal region's start column, "
      .. "unaffected by 'linebreak'",
    function()
      -- Inline text remains visible when its anchor is concealed.
      api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(14) .. 'HIDDEN' .. ('b'):rep(4) })
      api.nvim_buf_set_extmark(0, ns, 0, 14, {
        virt_text = { { 'XXX', 'Comment' } },
        virt_text_pos = 'inline',
      })
      api.nvim_buf_set_extmark(0, ns, 0, 14, { end_col = 20, conceal = '' })

      eq(2, api.nvim_win_text_height(0, {}).all)
      screen0:expect([[
      ^aaaaaaaaaaaaaa{18:XXX}bbb|
      b                   |
      {1:~                   }|*3
                          |
    ]])

      -- gj from row 1 lands on the last 'b' (buf23), the only real buffer position on row 2.
      eq(23, col_after(0, 'gj'))

      -- g$ stops on row 1's last buffer character, after counting the inline text.
      eq(22, col_after(0, 'g$'))

      -- With no visible breaks, 'linebreak' must leave these motions unchanged.
      command('set linebreak')
      screen0:expect({ unchanged = true })

      eq(23, col_after(0, 'gj'))
      eq(22, col_after(0, 'g$'))
    end
  )

  it("'linebreak' counts inline virtual text width in its word-fit lookahead", function()
    -- Inline text participates in word-fit lookahead even without conceal.
    command('set linebreak')
    command('setlocal conceallevel=0')
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(12) .. ' bb' .. 'cc' })
    api.nvim_buf_set_extmark(0, ns, 0, 15, {
      virt_text = { { ('X'):rep(6), 'Comment' } },
      virt_text_pos = 'inline',
    })

    -- The decorated word needs ten cells; only seven remain on row 1.
    eq(2, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aaaaaaaaaaaa        |
      bb{18:XXXXXX}cc          |
      {1:~                   }|*3
                          |
    ]])

    feed('gj')
    eq({ 1, 13 }, api.nvim_win_get_cursor(0))

    -- The space before the pushed-down word remains on row 1.
    eq(12, col_after(0, 'g$'))

    -- The break character's inline width must not be reused when measuring conceal on the next
    -- character: the 15 displayed cells below fit exactly on one row.
    screen0:try_resize(15, 6)
    command('setlocal conceallevel=2')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaaaa Xbbbb' })
    api.nvim_buf_set_extmark(0, ns, 0, 5, {
      virt_text = { { 'VVVVV' } },
      virt_text_pos = 'inline',
    })
    api.nvim_buf_set_extmark(0, ns, 0, 6, { end_col = 7, conceal = '' })
    api.nvim_win_set_cursor(0, { 1, 0 })
    eq(1, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aaaaaVVVVV bbbb|
      {1:~              }|*4
                     |
    ]])
  end)

  it('eol virtual text does not affect reflow', function()
    conceal_line(('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(5))
    api.nvim_buf_set_extmark(0, ns, 0, 20, {
      virt_text = { { ('X'):rep(10), 'Comment' } },
      virt_text_pos = 'eol',
    })

    eq(1, api.nvim_win_text_height(0, {}).all)
  end)

  it('tracks only conceal decorations in marktree metadata', function()
    local other_ns = api.nvim_create_namespace('conceal_metadata')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'text' })
    api.nvim_buf_set_extmark(0, other_ns, 0, 0, { end_col = 1, hl_group = 'Comment' })
    eq(0, api.nvim__buf_stats(0).conceal_marks)

    local id = api.nvim_buf_set_extmark(0, other_ns, 0, 1, {
      end_col = 2,
      conceal = '界',
      virt_text = { { 'hint' } },
      virt_text_pos = 'inline',
    })
    eq(1, api.nvim__buf_stats(0).conceal_marks)
    eq(0, api.nvim__buf_stats(0).conceal_line_marks)

    api.nvim_buf_set_extmark(0, other_ns, 0, 1, {
      id = id,
      end_col = 2,
      hl_group = 'Comment',
    })
    eq(0, api.nvim__buf_stats(0).conceal_marks)

    api.nvim_buf_set_lines(0, 0, -1, true, { 'hidden', 'shown' })
    api.nvim_win_set_cursor(0, { 2, 0 })
    command('set conceallevel=3')
    api.nvim_buf_set_extmark(0, other_ns, 0, 0, {
      conceal_lines = '',
      virt_text = { { 'hint' } },
    })
    eq(1, api.nvim__buf_stats(0).conceal_marks)
    eq(1, api.nvim__buf_stats(0).conceal_line_marks)
    screen0:expect({ any = 'shown', none = 'hidden' })
    api.nvim_buf_clear_namespace(0, other_ns, 0, -1)
    eq(0, api.nvim__buf_stats(0).conceal_marks)
    eq(0, api.nvim__buf_stats(0).conceal_line_marks)

    api.nvim_buf_set_lines(0, 0, -1, true, { 'gone' })
    api.nvim_buf_set_extmark(0, other_ns, 0, 0, {
      end_col = 4,
      conceal = '',
      invalidate = true,
    })
    eq(1, api.nvim__buf_stats(0).conceal_marks)
    api.nvim_buf_set_text(0, 0, 0, 0, 4, {})
    eq(0, api.nvim__buf_stats(0).conceal_marks)
    command('undo')
    eq(1, api.nvim__buf_stats(0).conceal_marks)
  end)

  it('ephemeral (decoration-provider) conceal does not reflow', function()
    -- Ephemeral conceal exists only while drawing, so geometry cannot read it from the marktree.
    -- It keeps the historical boguscols behavior to keep drawing and geometry consistent.
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

  --- Fills the buffer with "count" lines that reflow at width 30: revealed is 34 cells (2 rows),
  --- concealed is 22 (1 row).
  local function reflowing_buf(ns, count, cchar)
    local lines = {}
    for i = 1, count do
      lines[i] = ('L%02d-AAA'):format(i) .. ('C'):rep(12) .. ('-t%02d-'):format(i) .. ('B'):rep(10)
    end
    api.nvim_buf_set_lines(0, 0, -1, true, lines)
    for i = 0, count - 1 do
      local c = lines[i + 1]:find('C')
      api.nvim_buf_set_extmark(0, ns, i, c - 1, { end_col = c - 1 + 12, conceal = cchar })
    end
  end

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
      reflowing_buf(ns, 20, case.cchar)

      -- Scroll into the middle, then walk the cursor down through several reflowing lines.
      api.nvim_win_set_cursor(0, { 8, 0 })
      feed('zzjjj')

      -- Cursor is on line 11 (revealed: 2 rows, C's visible); the other visible lines are concealed
      -- (1 row). Every line's geometry must be correct after the height-changing moves.
      screen:expect(case.expected)
    end)
  end

  -- 'concealcursor' reveals the whole Visual area, not just the cursor line, so every selected
  -- line's height must follow.
  it('reveals the whole Visual area when concealcursor lacks "v"', function()
    local screen = Screen.new(30, 8)
    local ns = api.nvim_create_namespace('conceal_wrap_visual')
    command('set wrap conceallevel=2 concealcursor=')
    reflowing_buf(ns, 6, '')

    feed('ggvG')
    screen:expect([[
      {17:L04-AAACCCCCCCCCCCC-t04-BBBBBB}|
      {17:BBBB}                          |
      {17:L05-AAACCCCCCCCCCCC-t05-BBBBBB}|
      {17:BBBB}                          |
      ^L06-AAACCCCCCCCCCCC-t06-BBBBBB|
      BBBB                          |
      {1:~                             }|
      {5:-- VISUAL --}                  |
    ]])

    feed('<Esc>')
    screen:expect([[
      L04-AAA-t04-BBBBBBBBBB        |
      L05-AAA-t05-BBBBBBBBBB        |
      ^L06-AAACCCCCCCCCCCC-t06-BBBBBB|
      BBBB                          |
      {1:~                             }|*3
                                    |
    ]])
  end)
end)

-- Conceal marks live in the shared buffer marktree, not per-window state; verify no
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

  it('switching windows updates which cursor line is revealed', function()
    local screen = Screen.new(42, 8)
    local ns = api.nvim_create_namespace('conceal_wrap_focus')
    command('set wrap conceallevel=3 concealcursor=')

    local lines = {}
    for i = 1, 6 do
      lines[i] = ('a'):rep(9) .. i .. 'HIDDEN' .. ('b'):rep(10)
    end
    api.nvim_buf_set_lines(0, 0, -1, true, lines)
    for i = 0, 5 do
      api.nvim_buf_set_extmark(0, ns, i, 10, { end_col = 16, conceal = '' })
    end

    command('vsplit')
    local left = api.nvim_get_current_win()
    api.nvim_win_set_cursor(left, { 1, 0 })
    command('wincmd l')
    local right = api.nvim_get_current_win()
    api.nvim_win_set_cursor(right, { 3, 0 })

    command('redraw')
    screen:expect([[
      aaaaaaaaa1bbbbbbbbbb │aaaaaaaaa1bbbbbbbbbb|
      aaaaaaaaa2bbbbbbbbbb │aaaaaaaaa2bbbbbbbbbb|
      aaaaaaaaa3bbbbbbbbbb │^aaaaaaaaa3HIDDENbbbb|
      aaaaaaaaa4bbbbbbbbbb │bbbbbb              |
      aaaaaaaaa5bbbbbbbbbb │aaaaaaaaa4bbbbbbbbbb|
      aaaaaaaaa6bbbbbbbbbb │aaaaaaaaa5bbbbbbbbbb|
      {2:[No Name] [+]         }{3:[No Name] [+]       }|
                                                |
    ]])
    api.nvim_set_current_win(left)
    screen:expect([[
      ^aaaaaaaaa1HIDDENbbbbb│aaaaaaaaa1bbbbbbbbbb|
      bbbbb                │aaaaaaaaa2bbbbbbbbbb|
      aaaaaaaaa2bbbbbbbbbb │aaaaaaaaa3bbbbbbbbbb|
      aaaaaaaaa3bbbbbbbbbb │aaaaaaaaa4bbbbbbbbbb|
      aaaaaaaaa4bbbbbbbbbb │aaaaaaaaa5bbbbbbbbbb|
      aaaaaaaaa5bbbbbbbbbb │aaaaaaaaa6bbbbbbbbbb|
      {3:[No Name] [+]         }{2:[No Name] [+]       }|
                                                |
    ]])
  end)
end)
