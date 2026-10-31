-- Conceal-aware line wrapping (#14409): a line with extmark-conceal wraps at its concealed width.
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
    command('set wrap conceallevel=2 concealcursor=nvic mousetime=0')
  end)

  -- Most tests use this line: 10 a (buf 0-9) + HIDDEN (buf 10-15, concealed) + 30 b (buf 16-45).
  -- Reflowed at width 20 that is row 1 = a*10 + b*10 (buf 16-25), row 2 = b*20 (buf 26-45).
  local sample = ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(30)

  --- Sets the buffer to `text` and conceals only the first occurrence of `hidden` in it.
  local function conceal_line(text, hidden)
    hidden = hidden or 'HIDDEN'
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { text })
    local col = assert(text:find(hidden, 1, true)) - 1
    api.nvim_buf_set_extmark(0, ns, 0, col, { end_col = col + #hidden, conceal = '' })
  end

  --- Feeds `keys` with the cursor at buffer column `col`.
  --- @return integer Column after the motion.
  local function col_after(col, keys)
    api.nvim_win_set_cursor(0, { 1, col })
    feed(keys)
    return api.nvim_win_get_cursor(0)[2]
  end

  --- Waits until the top rows of the screen show `rows`, ignoring highlights and the cursor.
  local function expect_rows(rows)
    screen0:expect({
      condition = function()
        local lines = screen0:render(false, {})
        local actual = {}
        for i = 1, #rows do
          actual[i] = lines[i]:gsub('%^', ''):sub(1, -2):gsub('%s+$', '')
        end
        eq(rows, actual)
      end,
    })
  end

  it('extmark conceal owns wrapped layout over other conceal sources', function()
    local prefix = ('a'):rep(19)
    for _, source in ipairs({ 'syntax', 'match', 'ephemeral', 'ephemeral false' }) do
      local id = exec_lua(function(kind, marks, text)
        local a = vim.api
        vim.cmd('set wrap')
        vim.cmd('syntax clear')
        vim.fn.clearmatches()
        local provider = a.nvim_create_namespace('mixed-conceal')
        a.nvim_set_decoration_provider(provider, {})
        a.nvim_buf_clear_namespace(0, marks, 0, -1)
        a.nvim_buf_set_lines(0, 0, -1, false, { ('%sXZ'):format(text), '!' })
        a.nvim_win_set_cursor(0, { 1, 0 })
        if kind == 'syntax' then
          vim.cmd('syntax match MixedConceal /X/ conceal cchar=Q')
        elseif kind == 'match' then
          vim.fn.matchadd('Conceal', 'X', 10, -1, { conceal = 'Q' })
        else
          a.nvim_set_decoration_provider(provider, {
            on_line = function(_, _, buf, row)
              if row == 0 then
                a.nvim_buf_set_extmark(buf, provider, 0, 19, {
                  end_col = 20,
                  conceal = kind == 'ephemeral' and 'Q',
                  priority = 200,
                  ephemeral = true,
                })
              end
            end,
          })
        end
        return a.nvim_buf_set_extmark(0, marks, 0, 19, {
          end_col = 20,
          conceal = '',
          priority = 100,
        })
      end, source, ns, prefix)
      eq(1, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
      expect_rows({ ('%sZ'):format(prefix), '!', '~' })

      command('set nowrap')
      local unowned = source == 'ephemeral false' and 'X' or 'Q'
      expect_rows({ ('%s%s'):format(prefix, unowned), '!', '~' })
      command('set wrap')
      local mark = { id = id, end_col = 20, priority = 100, conceal = false }
      api.nvim_buf_set_extmark(0, ns, 0, 19, mark)
      eq(2, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
      expect_rows({ ('%s%s'):format(prefix, unowned), 'Z', '!' })

      mark.conceal = '界'
      api.nvim_buf_set_extmark(0, ns, 0, 19, mark)
      eq(2, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
      expect_rows({ ('%s>'):format(prefix), '界Z', '!' })
    end

    -- A line without decorations does not reuse the conceal of the last drawn character.
    exec_lua(function()
      vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace('mixed-conceal'), {})
      vim.cmd('syntax clear | syntax match Hide /bar/ conceal')
    end)
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'foo bar baz', ('a'):rep(40) .. 'Zb' })
    api.nvim_buf_set_extmark(0, ns, 1, 40, { end_col = 41, conceal = 'X' })
    api.nvim_win_set_cursor(0, { 1, 0 })
    screen0:try_resize(20, 4)
    -- The draw ends on the extmark conceal at buf 40, then line 1 alone is redrawn.
    command('redraw!')
    command('call setline(1, getline(1))')
    screen0:expect([[
      ^foo  baz            |
      aaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaaaaaaaaa{1:@@@}|
                          |
    ]])
  end)

  it('fully hidden extmark conceal reflows height and screen positions', function()
    -- 25 raw cells: without conceal this wraps to two screen rows at width 20.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9) })
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- Hide "HIDDEN" (cols 10..16, no replacement char): 19 displayed cells -> one row.
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    eq(1, api.nvim_win_text_height(0, {}).all)
    screen0:try_resize(14, 6)
    screen0:expect([[
      ^aaaaaaaaaabbbb|
      bbbbb         |
      {1:~             }|*3
                    |
    ]])
    screen0:try_resize(20, 6)
    -- Eol virtual text does not count: it would need a second row.
    api.nvim_buf_set_extmark(0, ns, 0, 25, {
      virt_text = { { ('X'):rep(10), 'Comment' } },
      virt_text_pos = 'eol',
    })
    eq(1, api.nvim_win_text_height(0, {}).all)

    -- A mark from an earlier row hides the rows it spans.
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaaa' .. ('X'):rep(30), ('Y'):rep(30), 'ZZb' })
    api.nvim_buf_set_extmark(0, ns, 0, 4, { end_row = 2, end_col = 2, conceal = '' })
    eq(3, api.nvim_win_text_height(0, {}).all)

    conceal_line(sample)
    eq({ row = 2, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 27))
    eq({ row = 1, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 1))
    eq({ row = 1, col = 15, curscol = 15, endcol = 15 }, fn.screenpos(0, 1, 21))
    api.nvim_win_set_cursor(0, { 1, 26 })
    eq({ 2, 1 }, { fn.winline(), fn.wincol() })
    api.nvim_win_set_cursor(0, { 1, 20 })
    eq({ 1, 15 }, { fn.winline(), fn.wincol() })

    -- So do clicks, getmousepos() and getchar(), also right after the hidden text.
    api.nvim_input_mouse('left', 'press', '', 0, 0, 14)
    eq({ { 1, 20 }, 21 }, { api.nvim_win_get_cursor(0), fn.getmousepos().column })
    feed(':call getchar()<CR>')
    api.nvim_input_mouse('left', 'press', '', 0, 0, 10)
    n.poke_eventloop()
    eq({ 1, 17 }, { api.nvim_get_vvar('mouse_lnum'), api.nvim_get_vvar('mouse_col') })
  end)

  it("column highlights, 'cursorline' and 'list' TABs use displayed columns", function()
    command('set colorcolumn=8,25,30 cursorcolumn')
    conceal_line(sample)
    api.nvim_buf_set_lines(0, 1, -1, true, { ('c'):rep(30) })
    api.nvim_win_set_cursor(0, { 2, 21 })
    screen0:add_extra_attr_ids({ [100] = { background = Screen.colors.LightRed } })
    screen0:expect([[
      aaaaaaa{100:a}aabbbbbbbbbb|
      b{21:b}bb{100:b}bbbb{100:b}bbbbbbbbbb|
      ccccccc{100:c}cccccccccccc|
      c^ccc{100:c}cccc{100:c}          |
      {1:~                   }|
                          |
    ]])

    -- A TAB absorbs the hidden cells, so later columns line up with the next line.
    command('set colorcolumn=12 nocursorcolumn')
    conceal_line(('a'):rep(5) .. 'HIDDEN' .. '\t' .. ('b'):rep(30))
    api.nvim_buf_set_lines(0, 1, -1, true, { ('c'):rep(30) })
    screen0:expect([[
      aaaaa      {100: }    bbbb|
      bbbbb^bbbbbbbbbbbbbbb|
      bbbbbb              |
      ccccccccccc{100:c}cccccccc|
      cccccccccc          |
                          |
    ]])

    -- 'list' with 'linebreak' highlights only the TAB.
    command('set colorcolumn= list listchars=tab:>- linebreak')
    conceal_line('abXYZ\t cdefgh', 'XYZ')
    screen0:expect([[
      ab{1:>-----} cdefg^h     |
      {1:~                   }|*4
                          |
    ]])

    -- 'cursorlineopt=screenline' highlights the cursor's displayed row.
    command('set nolist nolinebreak cursorline cursorlineopt=screenline')
    conceal_line(sample)
    api.nvim_win_set_cursor(0, { 1, 20 })
    screen0:expect([[
      {21:aaaaaaaaaabbbb^bbbbbb}|
      bbbbbbbbbbbbbbbbbbbb|
      {1:~                   }|*3
                          |
    ]])
    api.nvim_win_set_cursor(0, { 1, 40 })
    screen0:expect([[
      aaaaaaaaaabbbbbbbbbb|
      {21:bbbbbbbbbbbbbb^bbbbbb}|
      {1:~                   }|*3
                          |
    ]])
  end)

  it('does not add a wrapped row for a hidden tail', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(20) .. ('X'):rep(140), 'END' })
    api.nvim_buf_set_extmark(0, ns, 0, 20, { end_col = 160, conceal = '' })
    api.nvim_win_set_cursor(0, { 1, 100 })
    screen0:expect([[
      aaaaaaaaaaaaaaaaaaa^a|
      END                 |
      {1:~                   }|*3
                          |
    ]])
    eq(1, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
    feed('A')
    eq(1, fn.winline())
    expect_rows({ ('a'):rep(20), 'END' })
    feed('<Esc>')

    local inline = api.nvim_buf_set_extmark(0, ns, 0, 160, {
      virt_text = { { 'II' } },
      virt_text_pos = 'inline',
    })
    expect_rows({ ('a'):rep(20), 'II', 'END' })
    eq(2, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
    api.nvim_buf_set_extmark(0, ns, 0, 20, {
      id = inline,
      virt_text = { { 'II' } },
      virt_text_pos = 'inline',
    })
    expect_rows({ ('a'):rep(20), 'II', 'END' })
    command('set list listchars=eol:$')
    expect_rows({ ('a'):rep(20), 'II$', 'END$' })
    api.nvim_buf_set_extmark(0, ns, 0, 0, {
      virt_lines = { { { ('v'):rep(20) } } },
      virt_lines_above = true,
    })
    fn.winrestview({ lnum = 1, col = 0, topline = 1, topfill = 1 })
    expect_rows({ ('v'):rep(20), ('a'):rep(20), 'II$', 'END$' })

    -- Hidden text at a row end, then a visible row: the row end does not draw ahead.
    command('set nolist | syntax match Special /b\\+/')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    local a20 = ('a'):rep(20)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('%sHIDDENbbbb'):format(a20), ('%sbbbb'):format(a20) })
    api.nvim_buf_set_extmark(0, ns, 0, 20, { end_col = 26, conceal = '' })
    for _, vt in ipairs({ { 'XY', 'overlay' }, { 'R', 'right_align' } }) do
      api.nvim_buf_set_extmark(0, ns, 1, 20, { virt_text = { { vt[1] } }, virt_text_pos = vt[2] })
    end
    api.nvim_win_set_cursor(0, { 1, 22 })
    screen0:expect([[
      aaaaaaaaaaaaaaaaaaaa|
      {16:^bbbb}                |
      aaaaaaaaaaaaaaaaaaaa|
      XY{16:bb}               R|
      {1:~                   }|
                          |
    ]])
    eq({ 2, 1 }, { fn.winline(), fn.wincol() })

    -- 'showbreak' cells fill the row before the hidden tail.
    command('set showbreak=>>')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('%sHIDDEN'):format(('a'):rep(38)), 'END' })
    api.nvim_buf_set_extmark(0, ns, 0, 38, { end_col = 44, conceal = '' })
    api.nvim_win_set_cursor(0, { 1, 0 })
    screen0:expect([[
      ^aaaaaaaaaaaaaaaaaaaa|
      {1:>>}aaaaaaaaaaaaaaaaaa|
      END                 |
      {1:~                   }|*2
                          |
    ]])
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

    -- Undo restores an invalidated mark.
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '', invalidate = true })
    api.nvim_buf_set_text(0, 0, 10, 0, 16, {})
    command('silent undo')
    eq(1, api.nvim_win_text_height(0, {}).all)

    -- Redraws with 'nowrap' too.
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(40) .. 'tail', 'END' })
    api.nvim_win_set_cursor(0, { 2, 0 })
    local concealed = [[
      tail                |
      ^END                 |
      {1:~                   }|*3
                          |
    ]]
    local wrapped = [[
      aaaaaaaaaaaaaaaaaaaa|*2
      tail                |
      ^END                 |
      {1:~                   }|
                          |
    ]]
    local unwrapped = [[
      aaaaaaaaaaaaaaaaaaaa|
      ^END                 |
      {1:~                   }|*3
                          |
    ]]
    for _, case in ipairs({ { true, wrapped }, { false, unwrapped } }) do
      api.nvim_set_option_value('wrap', case[1], { win = 0 })
      local id = api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 40, conceal = '' })
      screen0:expect(concealed)
      api.nvim_buf_del_extmark(0, ns, id)
      screen0:expect(case[2])
    end
  end)

  it('replacement characters do not retain the source tab or wide character width', function()
    command('set vartabstop=32')
    for _, case in ipairs({
      { '\tX', 0, 1, 'X', 'XX' },
      { ('a'):rep(18) .. '界Z', 18, 21, 'X', ('a'):rep(18) .. 'XZ' },
      { '界Z', 0, 3, '界', '界Z' },
      { 'XZ', 0, 1, '界', '界Z' },
      { '\tZ', 0, 1, '界', '界Z' },
      { '\tX', 0, 1, '', ' X', level = 1 },
      { '\tX', 0, 1, '', 'X', level = 3 },
      { '界\tZ', 0, 3, '界', '界', (' '):rep(12) .. 'Z' },
      { ('a'):rep(19) .. 'XZ', 19, 20, '界', ('a'):rep(19) .. '>', '界Z' },
      { ('a'):rep(19) .. '\tZ', 19, 20, '界', ('a'):rep(19) .. '>', '界Z' },
      { ('a'):rep(19) .. '界Z', 19, 22, 'X', ('a'):rep(19) .. 'X', 'Z' },
    }) do
      command(('set conceallevel=%d'):format(case.level or 2))
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      api.nvim_buf_set_lines(0, 0, -1, true, { case[1], 'NEXT' })
      api.nvim_buf_set_extmark(0, ns, 0, case[2], { end_col = case[3], conceal = case[4] })
      api.nvim_win_set_cursor(0, { 2, 0 })
      local height = case[6] and 2 or 1
      eq(height, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
      expect_rows(case[6] and { case[5], case[6], 'NEXT' } or { case[5], 'NEXT' })
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
      -- A click on the replacement lands on its source; with level 3 on the next character.
      api.nvim_input_mouse('left', 'press', '', 0, pos[1] - 1, pos[2] - 1)
      eq({ 1, case.level == 3 and case[3] or case[2] }, api.nvim_win_get_cursor(0))
      api.nvim_input_mouse('left', 'press', '', 0, height, 0)
      eq({ 2, 2 }, { fn.line('.'), fn.getmousepos().line })
    end

    -- A TAB narrower than its replacement draws the cursor on the replacement.
    command('set vartabstop= tabstop=8 conceallevel=2')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'abcdefg\tXYZ' })
    api.nvim_buf_set_extmark(0, ns, 0, 7, { end_col = 8, conceal = '界' })
    api.nvim_win_set_cursor(0, { 1, 7 })
    eq({ 8, 8 }, { fn.wincol(), fn.screenpos(0, 1, 8).curscol })

    -- A replacement wider than its source: both cells click onto it, and a TAB absorbs the extra.
    command('set virtualedit=all')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { '- **Alpha**', 'AX\tB' })
    api.nvim_buf_set_extmark(0, ns, 0, 2, { end_col = 4, conceal = '界' })
    api.nvim_buf_set_extmark(0, ns, 1, 1, { end_col = 2, conceal = '界' })
    eq({ row = 1, col = 3, curscol = 3, endcol = 4 }, fn.screenpos(0, 1, 3))
    eq(9, fn.screenpos(0, 2, 4).col)
    for col = 2, 3 do
      api.nvim_input_mouse('left', 'press', '', 0, 0, col)
      eq({ 1, 2, 0 }, { fn.line('.'), fn.col('.') - 1, fn.getcurpos()[4] })
    end
  end)

  it('all inline virtual text cells on a concealed character have the same mouse anchor', function()
    command('set mouse=a mousemoveevent')
    for _, text in ipairs({ 'III', 'I界I' }) do
      conceal_line('aHIDDENb')
      api.nvim_buf_set_extmark(0, ns, 0, 1, {
        virt_text = { { text } },
        virt_text_pos = 'inline',
      })
      expect_rows({ ('a%sb'):format(text) })
      for col = 1, fn.strdisplaywidth(text) do
        api.nvim_input_mouse('move', '', '', 0, 0, col)
        eq(2, fn.getmousepos().column)
      end
    end
  end)

  it("g0/gm/g$ with 'virtualedit' coladd act like an unconcealed line", function()
    command('set virtualedit=all')
    --- Cursor 5 cells past the last character, then each motion.
    --- @return table<string, integer[]> cursor column from the line end, and coladd
    local function motions(text, hidden)
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      if hidden then
        conceal_line(text, hidden)
      else
        api.nvim_buf_set_lines(0, 0, -1, true, { text })
      end
      local result = {}
      for _, keys in ipairs({ 'g0', 'gm', 'g$' }) do
        fn.setpos('.', { 0, 1, #text, 5 })
        feed(keys)
        result[keys] = { api.nvim_win_get_cursor(0)[2] - #text, fn.getcurpos()[4] }
      end
      return result
    end
    eq(motions(('a'):rep(10) .. ('b'):rep(30)), motions(sample, 'HIDDEN'))
  end)

  it('gj/gk move by the reflowed screen line', function()
    conceal_line(sample)

    -- From row 1 col 0, gj lands straight below on row 2 col 0 = buffer col 26.
    eq(26, col_after(0, 'gj'))
    -- Back up, gk returns to the same visible column on row 1.
    feed('gk')
    eq({ 1, 0 }, api.nvim_win_get_cursor(0))

    -- The screen column is kept: from a 'b' at screen col 15 (buf 20) to row 2 col 15 (buf 40).
    eq(40, col_after(20, 'gj'))
    -- From the last reflowed row, gj enters a closed fold as one line.
    api.nvim_buf_set_lines(0, 1, -1, true, { 'fold2', 'fold3', 'last' })
    command('2,3fold')
    feed('gj')
    eq(2, api.nvim_win_get_cursor(0)[1])

    -- A concealed trailing TAB does not keep its raw final cell when gk chooses the row above.
    command('set tabstop=32')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(40), ('b'):rep(15) .. '\t' })
    api.nvim_buf_set_extmark(0, ns, 1, 15, { end_col = 16, conceal = '' })
    api.nvim_win_set_cursor(0, { 2, 15 })
    feed('$gk')
    eq({ 1, 39 }, api.nvim_win_get_cursor(0))

    -- A desired column near MAXCOL does not overflow on a line widened by wide replacements.
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'x', ('a'):rep(15), ('b'):rep(40) })
    for col = 0, 14 do
      api.nvim_buf_set_extmark(0, ns, 1, col, { end_col = col + 1, conceal = '界' })
    end
    api.nvim_win_set_cursor(0, { 2, 0 })
    feed('$')
    command("call setpos('.', getcurpos())")
    eq(2147483646, fn.winsaveview().curswant)
    feed('gj')
    eq({ 3, 19 }, api.nvim_win_get_cursor(0))
    feed('gk')
    eq({ 2, 14 }, api.nvim_win_get_cursor(0))
  end)

  it('reflowed rows: height, screenpos() and g-motions', function()
    -- After the options, text and height: { start col, keys, expected col } on line 1. `pos` maps a
    -- column to its screenpos() { row, col, endcol }. `inline` is { col, text } of inline virt_text.
    for _, case in ipairs({
      {
        '',
        ('a'):rep(20) .. ' HIDDEN ' .. ('c'):rep(18),
        2,
        { 35, 'g0', 20 },
        { 35, 'g^', 28 },
        { 35, 'gm', 36 },
        { 35, 'g$', 45 },
      },
      -- A row's first character sits past the wrap prefix.
      {
        'showbreak=>>',
        sample,
        3,
        { 0, 'gj', 26 },
        { 0, 'gjgj', 44 },
        { 30, 'g0', 26 },
        { 30, 'g$', 43 },
        { 30, 'g$g$', 43 },
        { 0, '<LeftMouse><2,1>', 26 },
        pos = { [27] = { 2, 3, 3 }, [45] = { 3, 3, 3 } },
      },
      {
        'breakindent breakindentopt=min:0',
        '    ' .. ('a'):rep(6) .. 'HIDDEN' .. ('b'):rep(30),
        3,
        { 0, 'gj', 26 },
        { 0, 'gjgj', 42 },
        { 30, 'g0', 26 },
        { 30, 'g$', 41 },
        { 30, 'g$g$', 41 },
      },
      -- Display cells, not bytes.
      {
        '',
        ('a'):rep(10) .. 'HIDDEN' .. ('古'):rep(15),
        2,
        { 0, 'gj', 31 },
        { 0, '<LeftMouse><1,1>', 31 },
        { 40, 'g0', 31 },
        { 40, 'g$', 58 },
        pos = { [32] = { 2, 1, 2 } },
      },
      {
        '',
        ('a'):rep(10) .. 'HIDDEN' .. ('é'):rep(30),
        2,
        { 0, 'gj', 36 },
        { 45, 'g0', 36 },
        { 45, 'g$', 74 },
        pos = { [37] = { 2, 1, 1 } },
      },
      -- A TAB absorbs the hidden cells before it, and is 2 cells without "tab:" in 'listchars'.
      {
        '',
        ('a'):rep(5) .. 'HIDDEN\t' .. ('b'):rep(30),
        3,
        { 0, 'gj', 16 },
        { 30, 'g0', 16 },
        { 30, 'g$', 35 },
        pos = { [17] = { 2, 1, 1 } },
      },
      {
        'list listchars=eol:$',
        ('a'):rep(5) .. 'HIDDEN\t' .. ('b'):rep(30),
        2,
        { 0, 'gj', 25 },
        { 20, 'g0', 0 },
        { 20, 'g$', 24 },
        { 0, '<LeftMouse><6,0>', 11 },
        pos = { [26] = { 2, 1, 1 } },
      },
      -- Rows after the first are wider (16, then 20).
      {
        'number numberwidth=4 cpoptions+=n',
        sample,
        3,
        { 30, 'g0', 22 },
        { 30, 'g$', 41 },
        { 0, 'gj', 26 },
        { 0, '<LeftMouse><0,1>', 22 },
      },
      -- A TAB across the row boundary is drawn on the next row.
      {
        'breakindent breakindentopt=min:0',
        ('a'):rep(6) .. 'HIDDEN' .. ('b'):rep(12) .. '\tccccc',
        2,
        { 0, 'g$', 23 },
      },
      -- Inline virt_text, also where the conceal starts, takes cells but no column.
      {
        '',
        ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(5),
        2,
        { 0, 'gj', 20 },
        { 0, 'g$', 19 },
        { 0, '<LeftMouse><4,1>', 20 },
        inline = { 20, ('X'):rep(10) },
      },
      {
        '',
        ('a'):rep(14) .. 'HIDDEN' .. ('b'):rep(4),
        2,
        { 0, 'gj', 23 },
        { 0, 'g$', 22 },
        { 0, '<LeftMouse><0,1>', 23 },
        inline = { 14, 'XXX' },
      },
      -- Skipping white space and hidden text, up to the end of a row of only those.
      { '', '  HIDDEN  A', 1, { 0, 'g^', 10 } },
      { '', '  HIDDEN  ', 1, { 0, 'g^', 9 } },
      { 'virtualedit=all', '  HIDDEN  ', 1, { 0, 'g^', 10 } },
    }) do
      command(
        ('set showbreak= nobreakindent nolist nonumber cpoptions& virtualedit= %s'):format(case[1])
      )
      conceal_line(case[2])
      if case.inline then
        local vt = { virt_text = { { case.inline[2] } }, virt_text_pos = 'inline' }
        api.nvim_buf_set_extmark(0, ns, 0, case.inline[1], vt)
      end
      eq(case[3], api.nvim_win_text_height(0, {}).all)
      for col, expected in pairs(case.pos or {}) do
        local pos = fn.screenpos(0, 1, col)
        eq(expected, { pos.row, pos.col, pos.endcol })
      end
      for i = 4, #case do
        eq(case[i][3], col_after(case[i][1], case[i][2]))
      end
    end
  end)

  it("g0/g^/gm/g$ use the raw leftcol under 'nowrap'", function()
    command('set nowrap')
    -- 20 a (buf 0..19, concealed) + 2 spaces (buf 20..21) + 30 c (buf 22..51).
    conceal_line(('a'):rep(20) .. '  ' .. ('c'):rep(30), ('a'):rep(20))
    -- Scroll past the concealed run, with the cursor in view so leftcol stays.
    fn.winrestview({ lnum = 1, col = 35, leftcol = 20 })
    eq({ row = 1, col = 1, curscol = 1, endcol = 1 }, fn.screenpos(0, 1, 21))
    api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
    eq({ 1, 20 }, api.nvim_win_get_cursor(0))

    eq(20, col_after(35, 'g0')) -- The leftcol itself.
    eq(22, col_after(35, 'g^')) -- Past the two leading spaces.
    eq(30, col_after(35, 'gm')) -- The leftcol + width/2.
    eq(39, col_after(35, 'g$')) -- The last visible raw column.
  end)

  it("matches equivalent displayed text under 'rightleft'", function()
    command('set rightleft')
    conceal_line(sample)
    api.nvim_buf_set_lines(0, 1, -1, true, { ('a'):rep(10) .. ('b'):rep(30) })
    screen0:expect([[
      bbbbbbbbbbaaaaaaaaa^a|
      bbbbbbbbbbbbbbbbbbbb|
      bbbbbbbbbbaaaaaaaaaa|
      bbbbbbbbbbbbbbbbbbbb|
      {1:                   ~}|
                          |
    ]])
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
      -- The cursor drawn on a TAB.
      api.nvim_win_set_cursor(0, { 1, 7 })
      cols[#cols + 1] = { fn.winline(), fn.wincol() }
      -- 'virtualedit' coladd inside each TAB, and getmousepos() over 'showbreak' and filler cells.
      command('set virtualedit=all')
      for _, motion in ipairs({ 'g0', 'g^', 'gm', 'g$' }) do
        for col = 7, 10 do
          fn.setpos('.', { 0, 1, col, 3 })
          feed(motion)
          cols[#cols + 1] = fn.getcurpos()
        end
      end
      for row = 0, 2 do
        for col = 0, 19 do
          api.nvim_input_mouse('move', '', '', 0, row, col)
          local pos = fn.getmousepos()
          cols[#cols + 1] = { pos.line, pos.column, pos.coladd }
        end
      end
      command('set virtualedit=')
      return cols
    end

    command('setlocal conceallevel=0')
    local unconcealed = motions()
    command('setlocal conceallevel=2')
    api.nvim_buf_set_extmark(0, ns, 2, 0, { end_col = 1, conceal = '' })
    eq(unconcealed, motions())
  end)

  it('raw virtual columns and ordinary motions ignore conceal-dependent wrap prefixes', function()
    for _, opts in ipairs({
      'showbreak=>>',
      'showbreak= breakindent breakindentopt=shift:2,min:0',
      'showbreak=>> nobreakindent linebreak',
    }) do
      command(('set %s'):format(opts))
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
      -- A click sets a raw curswant too.
      api.nvim_win_set_cursor(0, { 1, 0 })
      api.nvim_input_mouse('left', 'press', '', 0, 0, 18)
      eq({ 24, raw[25][1] }, { api.nvim_win_get_cursor(0)[2], fn.getcurpos()[5] })
      eq({ 1, 19 }, { fn.winline(), fn.wincol() })
    end
  end)

  it('Visual blocks keep raw endpoints when wrap prefixes move', function()
    screen0:try_resize(20, 10)
    command('set showbreak=>>')
    api.nvim_buf_set_lines(0, 0, -1, true, { sample, sample })
    api.nvim_buf_set_extmark(0, ns, 0, 10, { end_col = 16, conceal = '' })
    col_after(24, '<C-V>j')
    screen0:expect([[
      aaaaaaaaaabbbbbbbb{17:b}b|
      {1:>>}bbbbbbbbbbbbbbbbbb|
      {1:>>}bb                |
      aaaaaaaaaaHIDDENbbbb|
      {1:>>}bbbb{17:^b}bbbbbbbbbbbbb|
      {1:>>}bbbbbbbb          |
      {1:~                   }|*3
      {5:-- VISUAL BLOCK --}  |
    ]])
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
    expect_rows({ row, row })
    eq(54, api.nvim_win_text_height(0, {}).all)
    eq(true, exec_lua('return _G.range_calls > 3'))
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    eq(67, api.nvim_win_text_height(0, {}).all)
    expect_rows({ ('abcX '):rep(24):sub(1, -2) })
  end)

  it("'linebreak' breaks at displayed word boundaries", function()
    screen0:try_resize(20, 30)
    command('set linebreak')
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'aaaaaHIDDENbbbbb ccccccccc', -- Exact fit.
      'aaaaaHIDDENbbbbb cccccccccc', -- Overflow by one cell.
      'aaaHIDDENaaa bbbb cccc dddd eeee ffff gggggggg', -- Rows end in filler.
      'aa bb\tcc dddddddddddddd', -- The concealed TAB is measured from the line start.
      'aaaaaaaaaaaaaa **bbbbbb', -- A space before concealed 'breakat' characters still breaks.
      'A **Supercalifragilistic** word',
      'aaaaaaaaaaaaaa**bbbbbb', -- A concealed break run is not visible.
      'aaaaaa bbHID HIDcccccccccccc', -- Hidden whitespace inside the next word.
      'aaaaaa bbHID\tHIDcccccccccccc',
      'aaaaaa bbHID  HIDcccccccccccc',
      'aa bb HID HID HID HID HID ccccccccccccccc dd',
      'aa bb Xccccccccccccccc', -- A visible replacement breaks, not its source.
      'aa bb 界ccccccccccccccc',
      'aaaaaa bbbbb bbbbbbbb',
    })
    for _, mark in ipairs({
      { 0, 5, 11 },
      { 1, 5, 11 },
      { 2, 3, 9 },
      { 3, 5, 6 },
      { 4, 15, 17 },
      { 5, 2, 4 },
      { 5, 24, 26 },
      { 6, 14, 16 },
      { 7, 9, 16 },
      { 8, 9, 16 },
      { 9, 9, 17 },
      { 10, 6, 26 },
      { 11, 6, 7, ' ' },
      { 12, 6, 9, ' ' },
      { 13, 12, 13, 'X' },
    }) do
      local row, col, end_col, conceal = unpack(mark)
      api.nvim_buf_set_extmark(0, ns, row, col, { end_col = end_col, conceal = conceal or '' })
    end
    screen0:expect([[
      ^aaaaabbbbb ccccccccc|
      aaaaabbbbb          |
      cccccccccc          |
      aaaaaa bbbb cccc    |
      dddd eeee ffff      |
      gggggggg            |
      aa bbcc             |
      dddddddddddddd      |
      aaaaaaaaaaaaaa      |
      bbbbbb              |
      A                   |
      Supercalifragilistic|
       word               |
      aaaaaaaaaaaaaabbbbbb|
      aaaaaa              |
      bbcccccccccccc      |
      aaaaaa              |
      bbcccccccccccc      |
      aaaaaa              |
      bbcccccccccccc      |
      aa bb               |
      ccccccccccccccc dd  |
      aa bb {14: }             |
      ccccccccccccccc     |
      aa bb {14: }             |
      ccccccccccccccc     |
      aaaaaa              |
      bbbbb{14:X}bbbbbbbb      |
      {1:~                   }|
                          |
    ]])
    local heights = {}
    for row = 0, 13 do
      heights[#heights + 1] = api.nvim_win_text_height(0, { start_row = row, end_row = row }).all
    end
    eq({ 1, 2, 3, 2, 2, 3, 1, 2, 2, 2, 2, 2, 2, 2 }, heights)
    for _, row in ipairs({ 4, 6 }) do
      local height = api.nvim_win_text_height(0, { start_row = row, end_row = row })
      eq(fn.virtcol({ row + 1, '$' }) - 1, height.end_vcol)
    end

    -- { line, keys from its start, expected col }
    for _, motion in ipairs({
      { 1, 'g$', 25 },
      { 2, 'gj', 17 },
      { 2, 'gjg0', 17 },
      { 2, 'gjg$', 26 },
      { 3, 'g$', 22 },
      { 3, 'g$gjg0g$', 37 },
      { 3, 'g$gjg0g$gjg0g$', 45 },
      { 5, 'gj', 17 },
      { 5, 'gjg0', 17 },
      { 5, 'gjg$', 22 },
      { 8, 'gj', 7 },
      { 9, 'gj', 7 },
      { 10, 'gj', 7 },
    }) do
      api.nvim_win_set_cursor(0, { motion[1], 0 })
      feed(motion[2])
      eq({ motion[1], motion[3] }, api.nvim_win_get_cursor(0))
    end

    -- The filler exists only in the concealed layout, so 'virtualedit' stops on its character.
    command('set virtualedit=all')
    api.nvim_win_set_cursor(0, { 3, 0 })
    feed('g$')
    eq({ 22, 0 }, { api.nvim_win_get_cursor(0)[2], fn.getcurpos()[4] })
  end)

  it('smoothscroll skips only the displayed part of a tab after conceal', function()
    api.nvim_open_win(0, true, {
      relative = 'editor',
      row = 0,
      col = 0,
      width = 8,
      height = 3,
      style = 'minimal',
    })
    command('set smoothscroll showbreak=> tabstop=64 virtualedit=all')
    conceal_line(('X'):rep(20) .. '\tabcdefghijk', ('X'):rep(20))
    fn.winrestview({ lnum = 1, col = 20, coladd = 25, topline = 1, skipcol = 24 })
    screen0:expect([[
      {11:>}{4:  ^     }            |
      {11:>}{4:       }            |*2
      {1:>}      abcdefghijk  |
      {1:~                   }|
                          |
    ]])
    -- The TAB absorbs the 20 hidden cells: 64 cells, ending with row 9.
    fn.winrestview({ lnum = 1, col = 21, topline = 1, skipcol = 56 })
    screen0:expect([[
      {11:>}{4:       }            |*2
      {11:>}{4:abcdef^g}            |
      {1:>}      abcdefghijk  |
      {1:~                   }|
                          |
    ]])
  end)

  it("'linebreak' measures a visible tab after conceal as absorbing the hidden cells", function()
    command('set linebreak tabstop=8 breakat=\\ ')
    conceal_line('aaaa XX\t' .. ('b'):rep(14), 'XX')

    -- The TAB spans 3 cells (1 + the 2 hidden), so the word no longer fits on the first row. On the
    -- second row it starts at vcol 22 and spans 4 cells (2 + the 2 hidden).
    eq(2, api.nvim_win_text_height(0, {}).all)
    eq({ row = 2, col = 18, curscol = 18, endcol = 18 }, fn.screenpos(0, 1, 22))
    screen0:expect([[
      ^aaaa                |
          bbbbbbbbbbbbbb  |
      {1:~                   }|*3
                          |
    ]])

    command('set vartabstop=4,8')
    conceal_line('aaaa XX\t' .. ('b'):rep(10), 'XX')
    eq(2, api.nvim_win_text_height(0, {}).all)
    eq({ row = 2, col = 18, curscol = 18, endcol = 18 }, fn.screenpos(0, 1, 18))

    command('set vartabstop=')
    conceal_line('aaaa a\tXyyyyyy\tbbbb', 'X')
    -- Same as 'conceallevel=0'.
    eq(2, api.nvim_win_text_height(0, {}).all)
    eq(2, fn.screenpos(0, 1, 19).row)
    command('set conceallevel=0')
    eq(2, api.nvim_win_text_height(0, {}).all)

    -- A concealed TAB with a replacement keeps the cells hidden before it for the next TAB.
    command('set conceallevel=1')
    conceal_line('aXXXb\tc\tdd', 'XXX')
    api.nvim_buf_set_extmark(0, ns, 0, 5, { end_col = 6, conceal = '' })
    eq(17, fn.screenpos(0, 1, 9).col)
    screen0:expect([[
      ^a{14: }b{14: }c           dd  |
      {1:~                   }|*4
                          |
    ]])
    command('set list listchars=tab:>-')
    screen0:expect([[
      ^a{14: }b{14: }c{1:>----------}dd  |
      {1:~                   }|*4
                          |
    ]])

    -- A TAB in 'breakat' that a word follows absorbs the hidden cells too.
    command('set nolist breakat& conceallevel=2')
    conceal_line('aXXXb\tc', 'XXX')
    eq(9, fn.screenpos(0, 1, 7).col)
    screen0:expect([[
      ^ab      c           |
      {1:~                   }|*4
                          |
    ]])
    command('set list')
    screen0:expect([[
      ^ab{1:>-----}c           |
      {1:~                   }|*4
                          |
    ]])

    -- A concealed TAB's 'linebreak' filler is drawn, not hidden.
    command('set nolist conceallevel=1')
    conceal_line(('aaaaaa\t%s\t c'):format(('b'):rep(17)), '\t')
    local pos = fn.screenpos(0, 1, 27)
    eq({ 3, 2 }, { pos.row, pos.col })
    screen0:expect([[
      ^aaaaaa{14: }             |
      bbbbbbbbbbbbbbbbb   |
       c                  |
      {1:~                   }|*2
                          |
    ]])
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

  it('tab alignment ignores conceal', function()
    -- Like :syntax conceal and 'nowrap': a TAB absorbs the cells hidden since the previous TAB.
    conceal_line('abcdefghij\tc', 'abcdefghij')
    screen0:expect([[
      ^                c   |
      {1:~                   }|*4
                          |
    ]])
    eq({ row = 1, col = 17, curscol = 17, endcol = 17 }, fn.screenpos(0, 1, 12))
    -- The cursor is at the end of the TAB.
    api.nvim_buf_set_lines(0, 1, -1, true, { ('x'):rep(20) })
    api.nvim_win_set_cursor(0, { 1, 10 })
    feed('gj')
    eq({ 2, 15 }, api.nvim_win_get_cursor(0))

    -- A TAB keeps one cell after a wider replacement, so the next TAB absorbs the extra cell.
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'abcdefg\tX', 'abcdefg\t1234567\tY' })
    for row = 0, 1 do
      api.nvim_buf_set_extmark(0, ns, row, 6, { end_col = 7, conceal = '界' })
    end
    screen0:expect([[
      abcdef{14:界} X          |
      abcdef{14:界} 1234567^ Y  |
      {1:~                   }|*3
                          |
    ]])
    eq({ 10, 9, 18 }, {
      fn.screenpos(0, 1, 9).col,
      fn.screenpos(0, 2, 8).col,
      fn.screenpos(0, 2, 17).col,
    })

    -- Across a wrap prefix: same rows as 'conceallevel=0', the second TAB absorbs the 3 cells
    -- hidden from the first.
    screen0:try_resize(13, 6)
    command('set showbreak=> breakindent breakindentopt=shift:1,min:0')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aabc\t\t\t abc', 'END' })
    api.nvim_buf_set_extmark(0, ns, 0, 4, { end_col = 5, conceal = ' ' })
    expect_rows({ 'aabc', ' >          a', ' >bc', 'END' })
    eq(3, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
    local pos = fn.screenpos(0, 1, 9)
    eq({ 2, 13 }, { pos.row, pos.col })

    -- A TAB at the start of a 'breakindent' row is sized before the indent, also without conceal.
    screen0:try_resize(40, 4)
    command('set showbreak= breakindentopt=')
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { ('    %s\ty'):format(('x'):rep(36)) })
    api.nvim_win_set_cursor(0, { 1, 41 })
    eq(13, fn.screenpos(0, 1, 42).col)
    screen0:expect([[
          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
                  ^y                           |
      {1:~                                       }|
                                              |
    ]])
  end)

  it('motions account for conceal width changes that cancel out by end of line', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(40) })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 1, conceal = '界' })
    api.nvim_buf_set_extmark(0, ns, 0, 30, { end_col = 31, conceal = '' })

    -- The first replacement adds one displayed cell and the later conceal removes one, so the
    -- total width is unchanged. Between them, however, screen and virtual columns differ.
    eq(2, api.nvim_win_text_height(0, {}).all)
    eq({ 19, 19 }, { col_after(0, 'gj'), col_after(25, 'g0') })

    api.nvim_open_win(0, true, {
      relative = 'editor',
      row = 0,
      col = 0,
      width = 4,
      height = 4,
      style = 'minimal',
    })
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aXb界Zcd', 'END' })
    api.nvim_buf_set_extmark(0, ns, 0, 1, { end_col = 2, conceal = '' })
    api.nvim_buf_set_extmark(0, ns, 0, 6, { end_col = 7, conceal = '界' })
    command('set concealcursor=')
    api.nvim_win_set_cursor(0, { 2, 0 })
    screen0:expect([[
      {4:ab界}{14:界}cd            |
      {14:界}{4:cd}                |
      {4:^END }{1:                }|
      {4:    }{1:                }|
      {1:~                   }|
                          |
    ]])
    eq(2, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
    -- Net hidden width is zero, but revealing the line adds a wide-character edge filler.
    feed('k')
    screen0:expect([[
      {4:^aXb}{11:>}{14:界}cd            |
      {4:界Zc}                |
      {4:d   }{1:                }|
      {4:END }{1:                }|
      {1:~                   }|
                          |
    ]])
    eq(3, api.nvim_win_text_height(0, { start_row = 0, end_row = 0 }).all)
  end)

  it("'linebreak' counts inline virtual text before a concealed character once", function()
    -- Exactly one row: 'aaaaa', the inline 'VVVVV', the break character and 'bbbb'.
    screen0:try_resize(15, 6)
    command('set linebreak')
    conceal_line('aaaaa Xbbbb', 'X')
    api.nvim_buf_set_extmark(0, ns, 0, 5, { virt_text = { { 'VVVVV' } }, virt_text_pos = 'inline' })
    eq(1, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aaaaaVVVVV bbbb|
      {1:~              }|*4
                     |
    ]])
  end)

  it('ephemeral (decoration-provider) conceal does not reflow', function()
    -- Ephemeral conceal exists only while drawing, so geometry cannot read it from the marktree.
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(10) .. 'HIDDEN' .. ('b'):rep(9) })
    exec_lua(function(nsid)
      vim.api.nvim_set_decoration_provider(nsid, {
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

    -- The line keeps its two raw rows.
    eq(2, api.nvim_win_text_height(0, {}).all)
    screen0:expect([[
      ^aaaaaaaaaabbbb      |
      bbbbb               |
      {1:~                   }|*3
                          |
    ]])
  end)
end)

-- Moving the cursor or the Visual area reveals or conceals wrapped lines, changing their height.
describe('conceal-aware wrapping redraw (#14409)', function()
  before_each(clear)

  --- Fills the buffer with `count` lines that reflow at width 30: revealed is 34 cells (2 rows),
  --- concealed is 22 (1 row).
  local function reflowing_buf(ns, count)
    local lines = {}
    for i = 1, count do
      lines[i] = ('L%02d-AAA'):format(i) .. ('C'):rep(12) .. ('-t%02d-'):format(i) .. ('B'):rep(10)
    end
    api.nvim_buf_set_lines(0, 0, -1, true, lines)
    for i = 0, count - 1 do
      local c = lines[i + 1]:find('C')
      api.nvim_buf_set_extmark(0, ns, i, c - 1, { end_col = c - 1 + 12, conceal = '' })
    end
  end

  it('keeps geometry correct while moving the cursor reveals lines and scrolls', function()
    local screen = Screen.new(30, 8)
    local ns = api.nvim_create_namespace('conceal_wrap_redraw')
    -- An empty 'concealcursor' reveals the cursor line, so moving the cursor changes its height.
    command('set wrap conceallevel=2 concealcursor= scrolloff=1')
    reflowing_buf(ns, 20)

    -- Scroll into the middle, then walk the cursor down through several reflowing lines.
    api.nvim_win_set_cursor(0, { 8, 0 })
    feed('zzjjj')
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
  end)

  -- 'concealcursor' reveals the whole Visual area, not just the cursor line, so every selected
  -- line's height must follow.
  it('reveals the whole Visual area when concealcursor lacks "v"', function()
    local screen = Screen.new(30, 8)
    local ns = api.nvim_create_namespace('conceal_wrap_visual')
    command('set wrap conceallevel=2 concealcursor=')
    reflowing_buf(ns, 6)

    feed('ggvG')
    screen:expect([[
      {17:L04-AAACCCCCCCCCCCC-t04-BBBBBB}|
      {17:BBBB}                          |
      {17:L05-AAACCCCCCCCCCCC-t05-BBBBBB}|
      {17:BBBB}                          |
      {17:^L}06-AAACCCCCCCCCCCC-t06-BBBBBB|
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

    -- Lines between the old and new cursor line enter the Visual area too.
    reflowing_buf(ns, 3)
    api.nvim_buf_set_lines(0, 0, 0, true, { 'top' })
    api.nvim_buf_set_lines(0, 4, 4, true, { '', 'end' })
    screen:try_resize(30, 10)
    feed('ggV}')
    screen:expect([[
      {17:top}                           |
      {17:L01-AAACCCCCCCCCCCC-t01-BBBBBB}|
      {17:BBBB}                          |
      {17:L02-AAACCCCCCCCCCCC-t02-BBBBBB}|
      {17:BBBB}                          |
      {17:L03-AAACCCCCCCCCCCC-t03-BBBBBB}|
      {17:BBBB}                          |
      {17:^ }                             |
      end                           |
      {5:-- VISUAL LINE --}             |
    ]])
    eq(8, fn.winline())
    -- A click maps the revealed layout on screen, before ending Visual conceals it again.
    api.nvim_input_mouse('left', 'press', '', 0, 3, 8)
    eq({ 3, 8 }, api.nvim_win_get_cursor(0))

    -- Moving only the start reveals the lines it passes.
    feed('4GV')
    screen:expect([[
      top                           |
      L01-AAA-t01-BBBBBBBBBB        |
      L02-AAA-t02-BBBBBBBBBB        |
      {17:^L03-AAACCCCCCCCCCCC-t03-BBBBBB}|
      {17:BBBB}                          |
                                    |
      end                           |
      {1:~                             }|*2
      {5:-- VISUAL LINE --}             |
    ]])
    feed('ip')
    screen:expect([[
      {17:top}                           |
      {17:L01-AAACCCCCCCCCCCC-t01-BBBBBB}|
      {17:BBBB}                          |
      {17:L02-AAACCCCCCCCCCCC-t02-BBBBBB}|
      {17:BBBB}                          |
      {17:^L03-AAACCCCCCCCCCCC-t03-BBBBBB}|
      {17:BBBB}                          |
                                    |
      end                           |
      {5:-- VISUAL LINE --}             |
    ]])
  end)

  it('clamps the skipcol of a topline that is concealed again', function()
    local screen = Screen.new(30, 5)
    local ns = api.nvim_create_namespace('conceal_wrap_skipcol')
    command('set wrap conceallevel=2 concealcursor=')
    local text = 'Intro [first link](https://example.com/'
      .. ('a'):rep(40)
      .. ') and [second](https://example.com/'
      .. ('b'):rep(45)
      .. ') end.'
    api.nvim_buf_set_lines(0, 0, -1, true, { text, 'line two', 'line three', 'line four' })
    -- Hide the link syntax: "[", and "](" through ")".
    for _, range in ipairs({ { 6, 7 }, { 17, 80 }, { 85, 86 }, { 92, 160 } }) do
      api.nvim_buf_set_extmark(0, ns, 0, range[1], { end_col = range[2], conceal = '' })
    end
    for _, sms in ipairs({ false, true }) do
      command(sms and 'set smoothscroll' or 'set nosmoothscroll')
      feed('gg$')
      screen:expect([[
        {1:<<<}aaaaaaaaaaaaaaaa) and [seco|
        nd](https://example.com/bbbbbb|
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
        bbbbbbbbb) end^.               |
                                      |
      ]])
      feed('j')
      eq(0, fn.winsaveview().skipcol)
      screen:expect([[
        Intro first link and second en|
        d.                            |
        line tw^o                      |
        line three                    |
                                      |
      ]])
    end

    -- Marks changed above the topline keep its skipcol.
    api.nvim_buf_set_lines(0, 1, 2, true, { text })
    feed('2Gzt<C-E>')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { 'X' } }, virt_text_pos = 'inline' })
    screen:expect([[
      {1:<<<}e.com/aaaaaaaaaaaaaaaaaaaaa|
      ^aaaaaaaaaaaaaaaaaaa) and [seco|
      nd](https://example.com/bbbbbb|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
                                    |
    ]])

    -- Conceal that shortens the topline below its skipcol resets it, with the cursor elsewhere: a
    -- new mark, or 'conceallevel' enabling an existing one.
    command('set smoothscroll concealcursor=n')
    api.nvim_buf_set_lines(0, 0, -1, true, { ('x'):rep(100), 'a', 'b', 'c' })
    for _, by_option in ipairs({ false, true }) do
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      command(('set conceallevel=%d'):format(by_option and 0 or 2))
      feed('gg3G')
      screen:expect([[
        {1:<<<}xxxxxxxxxxxxxxxxxxxxxxxxxxx|
        xxxxxxxxxx                    |
        a                             |
        ^b                             |
                                      |
      ]])
      api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 95, conceal = '' })
      if by_option then
        command('set conceallevel=2')
      end
      screen:expect([[
        xxxxx                         |
        a                             |
        ^b                             |
        c                             |
                                      |
      ]])
    end

    -- So does an edit that shortens the topline's displayed size below its skipcol, though its raw
    -- size still reaches past it.
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    local long = ('a%s%s'):format(('H'):rep(30), ('b'):rep(60))
    api.nvim_buf_set_lines(0, 0, -1, true, { long, 'a', 'b' })
    api.nvim_buf_set_extmark(0, ns, 0, 1, { end_col = 31, conceal = '' })
    feed('gg3G')
    eq(30, fn.winsaveview().skipcol)
    eq(
      0,
      exec_lua(function()
        vim.api.nvim_buf_set_text(0, 0, 31, 0, 70, {})
        return vim.fn.winsaveview().skipcol
      end)
    )

    -- On the cursor line it stays, also past the end: Insert after a full line in a 1-row window.
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    command('set nosmoothscroll conceallevel=0')
    api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(30), 'next' })
    command('1split')
    feed('ggA')
    screen:expect([[
      ^                              |
      {3:[No Name] [+]                 }|
      next                          |
      {2:[No Name] [+]                 }|
      {5:-- INSERT --}                  |
    ]])
  end)
end)

-- Conceal marks belong to the buffer; each window conceals by its own options and cursor.
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

    local right_current = [[
      aaaaaaaaa1bbbbbbbbbb │aaaaaaaaa1bbbbbbbbbb|
      aaaaaaaaa2bbbbbbbbbb │aaaaaaaaa2bbbbbbbbbb|
      aaaaaaaaa3bbbbbbbbbb │^aaaaaaaaa3HIDDENbbbb|
      aaaaaaaaa4bbbbbbbbbb │bbbbbb              |
      aaaaaaaaa5bbbbbbbbbb │aaaaaaaaa4bbbbbbbbbb|
      aaaaaaaaa6bbbbbbbbbb │aaaaaaaaa5bbbbbbbbbb|
      {2:[No Name] [+]         }{3:[No Name] [+]       }|
                                                |
    ]]
    screen:expect(right_current)
    -- A click maps the layout on screen, before entering the window reveals its cursor line.
    api.nvim_input_mouse('left', 'press', '', 0, 0, 10)
    eq({ left, { 1, 16 } }, { api.nvim_get_current_win(), api.nvim_win_get_cursor(0) })
    api.nvim_win_set_cursor(0, { 1, 0 })
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
    -- Also while messages are scrolled.
    feed(':echo "1\\n2" | wincmd l<CR><CR>')
    screen:expect(right_current)

    -- Moving the cursor redraws no line of the other window, which reveals none.
    exec_lua(function()
      _G.drawn = {}
      vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace('conceal_wrap_drawn'), {
        on_line = function(_, win)
          _G.drawn[win] = true
        end,
      })
      vim.cmd('redraw!')
      _G.drawn = {}
    end)
    feed('j')
    screen:expect([[
      aaaaaaaaa1bbbbbbbbbb │aaaaaaaaa1bbbbbbbbbb|
      aaaaaaaaa2bbbbbbbbbb │aaaaaaaaa2bbbbbbbbbb|
      aaaaaaaaa3bbbbbbbbbb │aaaaaaaaa3bbbbbbbbbb|
      aaaaaaaaa4bbbbbbbbbb │^aaaaaaaaa4HIDDENbbbb|
      aaaaaaaaa5bbbbbbbbbb │bbbbbb              |
      aaaaaaaaa6bbbbbbbbbb │aaaaaaaaa5bbbbbbbbbb|
      {2:[No Name] [+]         }{3:[No Name] [+]       }|
                                                |
    ]])
    eq({ right }, exec_lua('return vim.tbl_keys(_G.drawn)'))
    -- The Visual area is revealed in both.
    feed('V')
    screen:expect([[
      aaaaaaaaa1bbbbbbbbbb │aaaaaaaaa1bbbbbbbbbb|
      aaaaaaaaa2bbbbbbbbbb │aaaaaaaaa2bbbbbbbbbb|
      aaaaaaaaa3bbbbbbbbbb │aaaaaaaaa3bbbbbbbbbb|
      {17:aaaaaaaaa4HIDDENbbbbb}│{17:^aaaaaaaaa4HIDDENbbbb}|
      {17:bbbbb}                │{17:bbbbbb}              |
      aaaaaaaaa5bbbbbbbbbb │aaaaaaaaa5bbbbbbbbbb|
      {2:[No Name] [+]         }{3:[No Name] [+]       }|
      {5:-- VISUAL LINE --}                         |
    ]])

    -- When 'concealcursor' conceals the cursor lines, switching windows redraws no line of the
    -- previous window.
    feed('<Esc>')
    command('windo set concealcursor=n | redraw')
    exec_lua('_G.drawn = {}')
    command('wincmd h | redraw')
    eq({ left }, exec_lua('return vim.tbl_keys(_G.drawn)'))

    -- A click into a window whose WinEnter deletes the clicked line.
    command('autocmd WinEnter * ++once silent 3,$delete')
    api.nvim_input_mouse('left', 'press', '', 0, 4, 22)
    eq({ 2, 0 }, api.nvim_win_get_cursor(0))
    eq('', api.nvim_get_vvar('errmsg'))
  end)
end)
