-- Multicursor tests.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local t_atom = require('test.functional.editor.atom_testutil')

local describe, it, before_each = t.describe, t.it, t.before_each
local pending = t.pending
local clear = n.clear
local command = n.command
local feed = n.feed
local fn = n.fn
local eq = t.eq
local api = n.api
local get_lines = t_atom.get_lines
local k = t_atom.k
local atoms_start = t_atom.atoms_start
local atoms = t_atom.atoms
local atoms_tail = t_atom.atoms_tail
local atom_last = t_atom.atom_last

--- Clears the buffer mcursors like the default CTRL-L mapping (test-harness "mapclear" removed it).
local function clear_cursors()
  n.exec_lua(
    [[vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace('nvim.multicursor'), 0, -1)]]
  )
end

--- Number of multicursors.
local function ncursors()
  local ns = api.nvim_create_namespace('nvim.multicursor')
  return #api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
end

--- Positions ({row, col}, 0-based, in position order) of the mcursors.
local function anchors()
  local ns = api.nvim_create_namespace('nvim.multicursor')
  local positions = {}
  for _, m in ipairs(api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
    positions[#positions + 1] = { m[2], m[3] }
  end
  return positions
end

--- Sets the buffer lines, then places cursors by "Q".
local function cursors(lines, place)
  api.nvim_buf_set_lines(0, 0, -1, true, lines)
  feed('gg0')
  feed(place or 'QjQj')
end

--- Asserts table-driven cascade rows.
--- - `row.place` (default: "gg0") places the primary.
--- - `row.keys` input (the "Q" placements and the operation), then compare the whole buffer.
--- - `row.after` optionally feeds a key after the operation.
--- - `row.pre` runs a :command first (such rows go last: the option persists).
local function assert_rows(rows)
  for _, row in ipairs(rows) do
    clear_cursors()
    if row.pre then
      command(row.pre)
    end
    api.nvim_buf_set_lines(0, 0, -1, true, row.lines)
    feed(row.place or 'gg0')
    feed(row.keys)
    eq(row.expect, get_lines(), row.keys)
    if row.after then
      feed(row.after)
      eq(row.after_expect, get_lines(), ('%s ; %s'):format(row.keys, row.after))
    end
  end
end

describe('multicursor', function()
  before_each(function()
    clear()
    command('hi MCursor guifg=Black guibg=LightGrey')
  end)

  describe('Q (add cursor)', function()
    it('does not modify buffer', function()
      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjQ')
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
    end)

    it('creates a cursor again after clearing all', function()
      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjQ')
      clear_cursors()
      clear_cursors() -- Repeated clear (nothing to remove) is a no-op.
      eq(0, ncursors())
      eq(false, n.exec_lua("return require('vim._core.mcursor').active()"))
      feed('Q')
      eq(1, ncursors())
      eq(true, n.exec_lua("return require('vim._core.mcursor').active()"))
      feed('gg0x')
      eq({ 'aa', 'bb', 'ccc' }, get_lines())
    end)

    it('clearing mcursors also disables q= follow-mode', function()
      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjQ')
      feed('q=')
      clear_cursors()
      feed('Q')
      eq(1, ncursors())
      feed('l')
      eq(1, ncursors())
      -- Partial-range clear does not end the mc-session; the remaining cursors keep "q=".
      clear_cursors()
      cursors({ 'aaa', 'bbb', 'ccc' }) -- cursors on lines 1-2, primary on line 3
      feed('q=')
      n.exec_lua(
        [[vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace('nvim.multicursor'), 0, 1)]]
      )
      eq(1, ncursors()) -- cursor 1 is gone, cursor 2 still exists.
      feed('l')
      eq({ { 1, 1 } }, anchors()) -- Still in follow-mode.
    end)

    it('nvim_mcursor() at an existing cursor is a no-op (no double-apply)', function()
      fn.setline(1, { 'abcdef', 'ghijkl' })
      feed('gg0')
      api.nvim_mcursor(0, { 1, 0 })
      api.nvim_mcursor(0, { 1, 0 }) -- The duplicate is ignored ("Q" toggles instead)...
      eq(1, ncursors())
      feed('j0x') -- ...so the edit applies once at the line-1 cursor.
      eq({ 'bcdef', 'hijkl' }, get_lines())
      eq(1, ncursors())
    end)

    it('adds a cursor in the current buffer while mcursors exist in another', function()
      cursors({ 'aaa', 'bbb' }, 'Q')
      eq(1, ncursors())
      command('set hidden')
      feed(':enew<CR>') -- Typed, so the buffer switch goes through atom capture.
      cursors({ 'xxx', 'yyy' }, 'Q')
      eq(1, ncursors()) -- One cursor in this buffer (other buf keeps its own).
      feed('jx') -- Only the current buffer's cursors cascade.
      eq({ 'xx', 'yy' }, get_lines())
      command('buffer #')
      eq(1, ncursors())
      eq({ 'aaa', 'bbb' }, get_lines()) -- The other buffer was not touched.
    end)

    it('entering a buffer with mcursors via a nav mapping keeps them', function()
      -- A navigation mapping ("nnoremap <C-l> <C-w>l") ending in another buffer must not count as
      -- "the mapping edited the buffer".
      command('nnoremap <F5> <C-w>p')
      fn.setline(1, { 'aaa', 'bbb' })
      feed('gg0Q') -- Cursor in buf1, at the primary position.
      eq(1, ncursors())
      command('set hidden')
      command('vsplit | enew')
      fn.setline(1, { 'xxx', 'yyy' })
      feed('gg0Q') -- Cursor in buf2.
      eq(1, ncursors())
      feed('<F5>') -- Mapped switch to win1/buf1.
      eq(1, ncursors()) -- buf1 cursor still exists
      feed('<F5>') -- and back
      eq(1, ncursors()) -- buf2 cursor also
    end)

    it('"qQ" is recording (register Q), not a cursor', function()
      -- "q" is the recording command; a stray "q" before "Q" starts recording
      -- into register Q (uppercase: append) instead of adding a cursor.
      feed('qQ')
      eq('Q', fn.reg_recording())
      eq(0, ncursors())
      feed('q') -- stop recording: "Q" creates cursors again
      eq('', fn.reg_recording())
      feed('Q')
      eq(1, ncursors())
    end)

    it('gQ restores the cleared cursors (like gv)', function()
      cursors({ 'aaa', 'bbb', 'ccc', 'ddd' }, 'QjQ')
      clear_cursors()
      eq(0, ncursors())
      feed('gQ')
      eq(2, ncursors())
      feed('Gx') -- the restored cursors cascade
      eq({ 'aa', 'bb', 'ccc', 'dd' }, get_lines())
      -- The snapshot is extmark-tracked: edits in between shift it.
      clear_cursors()
      feed('ggO<Esc>') -- new line on top shifts the snapshot down
      feed('gQ')
      eq({ { 1, 0 }, { 2, 0 } }, anchors())
    end)

    it(':edit! clears the gQ snapshot', function()
      local fname = t.tmpname()
      fn.writefile({ 'aaa', 'bbb' }, fname)
      command('edit ' .. fname)
      feed('gg0QjQ')
      clear_cursors()
      command('edit!')
      feed('gQ')
      eq(0, ncursors()) -- nothing to restore: the snapshot died with the text
    end)

    it(':g//normal! Q places a cursor at each match', function()
      fn.setline(1, { 'foo a', 'bar b', 'foo c', 'baz d', 'foo e' })
      command('g/foo/normal! Q')
      eq(3, ncursors())
      feed('A!<Esc>') -- edit applies once per line (primary ends on the last match)
      eq({ 'foo a!', 'bar b', 'foo c!', 'baz d', 'foo e!' }, get_lines())
    end)

    it('Q in operator-pending mode aborts the operator', function()
      -- nv_Q: checkclearop() clears the pending operator, no cursor.
      fn.setline(1, { 'one two' })
      feed('gg0')
      feed('dQ')
      eq({ 'one two' }, get_lines())
      eq(0, ncursors())
      feed('wx') -- "w" moves (the "d" is gone), then x deletes one char
      eq({ 'one wo' }, get_lines())
    end)

    it('Q in Visual mode adds a cursor on each selected line', function()
      fn.setline(1, { 'aaa', 'bbb', 'ccc' })
      feed('ggvjQ') -- selection spans lines 1-2
      eq('n', fn.mode()) -- Visual mode ended
      eq({ 1, 0 }, api.nvim_win_get_cursor(0)) -- primary: first selected line
      eq(2, ncursors()) -- one per selected line, including under the primary
      feed('x') -- edits both lines
      eq({ 'aa', 'bb', 'ccc' }, get_lines())
      -- Cursors align by screen column, not byte column: a multibyte char before the cursor
      -- on one line must not shift the cursors on the other lines.
      clear_cursors()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'é123', 'abcdef' })
      feed('gg0llvjQ') -- Visual from "2" (line 1) down; cursor ends on "c" (screen column 3)
      eq({ 1, 3 }, api.nvim_win_get_cursor(0)) -- primary: on "2", not mid-"é"
      feed('x')
      eq({ 'é13', 'abdef' }, get_lines())
    end)

    it('Q then non-moving edit applies once (cursor merges into primary)', function()
      fn.setline(1, { 'ab' })
      feed('Q')
      eq(1, ncursors())
      feed('x')
      eq({ 'b' }, get_lines())
      eq(0, ncursors()) -- merged at the cascade; multicursor mode ended
    end)

    it('Q on an existing cursor removes it (toggle)', function()
      fn.setline(1, { 'aaa', 'bbb' })
      feed('Q')
      eq(1, ncursors())
      feed('Q') -- toggle off: multicursor mode ends
      eq(0, ncursors())
      feed('QjQk')
      eq(2, ncursors())
      feed('Q') -- removes only the cursor under the primary
      eq(1, ncursors())
      feed('x') -- the remaining cursor still cascades
      eq({ 'aa', 'bb' }, get_lines())
    end)

    it('Q not allowed in a macro (recording or executing)', function()
      -- |mcursor-limitations|: Q beeps (no cursor) while recording or executing a macro.
      fn.setline(1, { 'aaa', 'bbb', 'ccc' })
      feed('gg0')
      feed('qq')
      feed('Q') -- recording: not allowed (but still recorded)
      feed('q')
      eq(0, ncursors())
      feed('@q') -- executing the recorded "Q": not allowed either
      eq(0, ncursors())
      feed('Q') -- outside a macro: works
      eq(1, ncursors())
    end)

    it('1Q then Q mixes both cursor sets', function()
      fn.setline(1, { 'foo bar foo' })
      feed('gg0*') -- sets the last search pattern; the cursor lands on the second "foo"
      feed('1Q')
      eq(2, ncursors()) -- both "foo"s, including under the primary
      feed('0fb')
      feed('Q')
      eq(3, ncursors())
      feed('$') -- the primary edits a fourth position
      feed('x')
      eq({ 'oo ar o' }, get_lines())
    end)
  end)

  describe('mouse', function()
    it('<C-LeftMouse> toggles a cursor at the click, without moving the primary', function()
      command('set mousetime=0') -- repeated clicks must not count as double-clicks
      fn.setline(1, { 'aaa', 'bbb', 'ccc' })
      feed('gg0')
      api.nvim_input_mouse('left', 'press', 'C', 0, 2, 0) -- ctrl-click on line 3
      api.nvim_input_mouse('left', 'release', 'C', 0, 2, 0)
      -- The primary did not move; a cursor was added at left-click.
      eq(1, fn.line('.'))
      eq({ { 2, 0 } }, anchors())
      feed('x') -- cascades to the clicked position
      eq({ 'aa', 'bbb', 'cc' }, get_lines())
      -- CTRL-click on the existing cursor removes it (toggle).
      api.nvim_input_mouse('left', 'press', 'C', 0, 2, 0)
      api.nvim_input_mouse('left', 'release', 'C', 0, 2, 0)
      eq(0, ncursors())
      -- CTRL-click keeps "q=" follow-mode (unlike Q).
      feed('ggQj')
      feed('q=')
      api.nvim_input_mouse('left', 'press', 'C', 0, 2, 0)
      api.nvim_input_mouse('left', 'release', 'C', 0, 2, 0)
      feed('l')
      eq({ { 0, 1 }, { 2, 1 } }, anchors()) -- Still following: the motion cascaded.
      feed('q=') -- Off.
      -- No-op in Insert mode.
      feed('i')
      api.nvim_input_mouse('left', 'press', 'C', 0, 0, 1)
      api.nvim_input_mouse('left', 'release', 'C', 0, 0, 1)
      eq(2, ncursors())
      eq(2, fn.line('.'))
      eq('i', fn.mode())
      feed('<Esc>')
    end)

    it('middle-click paste applies once', function()
      -- Fake clipboard provider: "*" must not touch the real system clipboard.
      clear('--cmd', 'set rtp^=test/functional/fixtures')
      fn.setline(1, { 'abc', 'def', 'ghi' })
      fn.setreg('*', 'NEW') -- middle-click pastes the * register
      feed('gg0')
      api.nvim_input_mouse('middle', 'press', '', 0, 2, 0)
      api.nvim_input_mouse('middle', 'release', '', 0, 2, 0)
      feed('<Ignore>')
      -- Sanity: middle-click pastes (no cursors yet).
      local _, pasted = table.concat(get_lines(), '\n'):gsub('NEW', '')
      eq(1, pasted)
      feed('ggQjQ2j') -- cursors on lines 1-2, primary below
      api.nvim_input_mouse('middle', 'press', '', 0, 0, 0)
      api.nvim_input_mouse('middle', 'release', '', 0, 0, 0)
      feed('<Ignore>')
      -- One more paste at the click position; no paste at the other cursors.
      _, pasted = table.concat(get_lines(), '\n'):gsub('NEW', '')
      eq(2, pasted)
    end)
  end)

  describe('normal-mode cascade', function()
    it('CTRL-C interrupts the cascade; one "u" undoes the partial edit', function()
      local nlines = 5000
      local lines = {} ---@type string[]
      for i = 1, nlines do
        lines[i] = 'aaa'
      end
      api.nvim_buf_set_lines(0, 0, -1, true, lines)
      api.nvim_win_set_cursor(0, { 1, 0 })
      for i = 2, nlines do
        api.nvim_mcursor(0, { i, 0 })
      end
      eq(nlines - 1, ncursors())

      -- Interrupt from in-process on_key handler. The cascade runs too fast for test-runner CTRL-C.
      n.exec_lua(function()
        _G.keys_seen, _G.cascading_seen = 0, false
        vim.on_key(function()
          _G.keys_seen = _G.keys_seen + 1
          _G.cascading_seen = _G.cascading_seen or vim.api.nvim__mcursor_cascading()
          if _G.keys_seen == 1000 then
            vim.fn.interrupt()
          end
        end)
      end)

      feed('x') -- Primary edit + cascade over ~5000 cursors...
      n.poke_eventloop()
      eq(true, n.exec_lua('return _G.cascading_seen'))
      local edited, unedited = 0, 0
      for _, l in ipairs(get_lines()) do
        if l == 'aa' then
          edited = edited + 1
        elseif l == 'aaa' then
          unedited = unedited + 1
        end
      end
      eq(nlines, edited + unedited) -- no line was half-edited
      eq(true, edited >= 1) -- the primary's own edit happened
      eq(true, unedited >= 1) -- >=1 cursor did NOT cascade
      -- The partial cascade is still one undo block.
      feed('u')
      eq(lines, get_lines())
    end)

    it('successive operations update cursor positions', function()
      cursors({ 'AAAA', 'BBBB', 'CCCC' }, 'QjQ')
      feed('jx')
      eq({ 'AAA', 'BBB', 'CCC' }, get_lines())
      feed('x')
      eq({ 'AA', 'BB', 'CC' }, get_lines())
    end)

    it('cursor positions follow line insertions/deletions', function()
      -- "o" inserts a line at each cursor; cursors below must shift.
      cursors({ 'aaa', 'bbb', 'ccc' })
      feed('oX<Esc>')
      eq({ 'aaa', 'X', 'bbb', 'X', 'ccc', 'X' }, get_lines())
      -- The primary cursor also shifted (2 lines were inserted above it).
      eq(6, fn.line('.'))
    end)

    it('CTRL-D scrolling does not affect the other cursors', function()
      local screen = Screen.new(30, 10)
      local l = {}
      for i = 1, 50 do
        l[#l + 1] = ('line%d'):format(i)
      end
      cursors(l)
      -- Scrolling is viewport-dependent, not repeatable. Other cursors do not move, even in
      -- follow-mode.
      feed('<C-d>')
      eq({ { 0, 0 }, { 1, 0 } }, anchors())
      feed('q=')
      feed('<C-d>')
      feed('q=')
      eq({ { 0, 0 }, { 1, 0 } }, anchors())
      feed('<C-u>')
      -- An edit still cascades to the off-screen cursors, and the viewport stays anchored
      -- (replays scroll the window; the cascade restores it).
      feed('x')
      eq({ 'ine1', 'ine2' }, { get_lines()[1], get_lines()[2] })
      screen:expect([[
        line5                         |
        line6                         |
        ^ine7                          |
        line8                         |
        line9                         |
        line10                        |
        line11                        |
        line12                        |
        line13                        |
        multicursor: ...ow motion off |
      ]])
    end)
  end)

  describe('. (dot-repeat)', function()
    it('repeats operators, pre-cursor edits, inserts and changes at all cursors', function()
      -- Operator.
      cursors({ 'aaa', 'bbb', 'ccc' })
      feed('x')
      eq({ 'aa', 'bb', 'cc' }, get_lines())
      feed('.')
      eq({ 'a', 'b', 'c' }, get_lines())
      -- An edit made before placing cursors repeats at all of them.
      clear_cursors()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'aaa', 'bbb', 'ccc' })
      feed('gg0')
      feed('x')
      eq({ 'aa', 'bbb', 'ccc' }, get_lines())
      feed('QjQj')
      feed('.')
      eq({ 'a', 'bb', 'cc' }, get_lines())
      -- Insert.
      clear_cursors()
      cursors({ 'aaa', 'bbb' }, 'Qj')
      feed('iZ<Esc>')
      eq({ 'Zaaa', 'Zbbb' }, get_lines())
      feed('.')
      eq({ 'ZZaaa', 'ZZbbb' }, get_lines())
      -- Change, with a q= move between the change and the repeat.
      clear_cursors()
      cursors({ 'one two', 'one two' }, 'Qj')
      feed('cwX<Esc>')
      eq({ 'X two', 'X two' }, get_lines())
      feed('q=')
      feed('w')
      feed('q=')
      feed('.')
      eq({ 'X X', 'X X' }, get_lines())
    end)
  end)

  describe('per-cursor registers', function()
    it('yy/p roundtrips each cursor through its own register', function()
      cursors({ 'aaa', 'bbb' }, 'Qj')
      feed('yy')
      feed('p')
      eq({ 'aaa', 'aaa', 'bbb', 'bbb' }, get_lines())
    end)

    it('empty at cursor init restores as empty', function()
      fn.setline(1, { 'one two', 'three four' })
      feed('gg0')
      feed('Q') -- this cursor's snapshot: @a is EMPTY
      feed('j0')
      command([[let @a = 'LEAK']]) -- primary-only write (synthetic: no cascade)
      feed('"ap')
      -- The replay loads the other cursor's register snapshot, where @a was empty: nothing
      -- pastes there (empty registers are omitted; the primary's @a must not leak through).
      eq({ 'one two', 'tLEAKhree four' }, get_lines())
    end)

    it('dW + p swaps words using each cursor register', function()
      cursors({ 'one two', 'three four' }, 'Qj')
      feed('q=')
      feed('dW')
      eq({ 'two', 'four' }, get_lines())
      feed('E')
      feed('p')
      feed('q=')
      eq({ 'twoone ', 'fourthree ' }, get_lines())
    end)

    it('clearing joins/gathers the per-cursor registers (DWIM)', function()
      cursors({ 'one two', 'three four' }, 'Qj')
      feed('dW')
      eq({ 'two', 'four' }, get_lines())
      clear_cursors()
      -- On exit, each cursor's delete is joined (document order) into '"'.
      eq('one \nthree \n', fn.getreg('"'))
      feed('Go<Esc>p')
      eq({ 'two', 'four', '', 'one ', 'three ' }, get_lines())

      -- A cursor whose replays never wrote a register contributes nothing: it has no snapshot,
      -- so the pre-session '"' cannot be joined in as if it were that cursor's delete.
      fn.setreg('"', 'STALE')
      cursors({ '', 'abc' }, 'Qj')
      feed('x') -- writes a register at the primary only: "x" on the cursor's empty line is a no-op
      clear_cursors()
      eq('a', fn.getreg('"')) -- No contributions to join; primary's register is untouched.
      eq('v', fn.getregtype('"'))

      -- Partial-range clear deletes cursors without ending the session; no join/gather (yet).
      cursors({ 'one two', 'three four', 'five six' })
      feed('dW')
      eq({ 'two', 'four', 'six' }, get_lines())
      n.exec_lua(
        [[vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace('nvim.multicursor'), 0, 1)]]
      )
      eq('five ', fn.getreg('"')) -- Primary's own delete, unjoined.
      clear_cursors()
      eq('three \nfive \n', fn.getreg('"')) -- All cursors cleared => yanks joined.
    end)

    it('visual p pastes each cursor register over the selection', function()
      cursors({ 'aaa X', 'bbb Y' }, 'Qj')
      feed('yiw')
      feed('q=')
      feed('w')
      feed('q=')
      feed('viwp')
      eq({ 'aaa aaa', 'bbb bbb' }, get_lines())
    end)
  end)

  describe('operator matrix', function()
    it('operators cascade at each cursor', function()
      assert_rows({
        -- x deletes a char at each cursor.
        { lines = { 'aaa', 'bbb', 'ccc' }, keys = 'QjQjx', expect = { 'aa', 'bb', 'cc' } },
        -- dw deletes a word at each cursor.
        {
          lines = { 'hello world', 'foo bar', 'one two' },
          keys = 'QjQjdw',
          expect = { 'world', 'bar', 'two' },
        },
        -- 2x deletes 2 chars at each cursor.
        { lines = { 'aaaa', 'bbbb', 'cccc' }, keys = 'QjQj2x', expect = { 'aa', 'bb', 'cc' } },
        -- dd deletes a line at each cursor.
        {
          lines = { 'a1', 'a2', 'b1', 'b2', 'c1', 'c2' },
          keys = 'Q2jQ2jdd',
          expect = { 'a2', 'b2', 'c2' },
        },
        -- D deletes to EOL, C changes to EOL.
        {
          lines = { 'one two', 'three four' },
          place = 'gg0ll',
          keys = 'QjD',
          expect = { 'on', 'th' },
        },
        {
          lines = { 'one two', 'three four' },
          place = 'gg0ll',
          keys = 'QjCX<Esc>',
          expect = { 'onX', 'thX' },
        },
        -- 2cl changes 2 chars.
        { lines = { 'abcd', 'efgh' }, keys = 'Qj2clXY<Esc>', expect = { 'XYcd', 'XYgh' } },
        -- ~ toggles case and advances.
        { lines = { 'abc', 'def' }, keys = 'Qj~~', expect = { 'ABc', 'DEf' } },
        -- cT{char} changes backwards.
        {
          lines = { 'x_abcY', 'w_defgZ' },
          place = 'gg$',
          keys = 'Qj$cT_M<Esc>',
          expect = { 'x_MY', 'w_MZ' },
        },
        -- d4h deletes backwards.
        { lines = { 'abcdef', 'ghijkl' }, place = 'gg$', keys = 'Qj$d4h', expect = { 'af', 'gl' } },
        -- c2aw changes counted text objects.
        {
          lines = { 'one two three', 'foo bar baz' },
          keys = 'Qjc2awX<Esc>',
          expect = { 'Xthree', 'Xbaz' },
        },
        -- ci( on empty parens inserts inside.
        {
          lines = { 'a()b', 'c()d' },
          place = 'gg0l',
          keys = 'Qjci(X<Esc>',
          expect = { 'a(X)b', 'c(X)d' },
        },
        -- ci" seeks forward to the quotes.
        {
          lines = { 'x "aa" y', 'z "bbb" w' },
          keys = 'Qjci"NEW<Esc>',
          expect = { 'x "NEW" y', 'z "NEW" w' },
        },
        -- df{char} cascades with its payload char.
        { lines = { 'ab,cd', 'wxy,z' }, keys = 'Qjdf,', expect = { 'cd', 'z' } },
        -- [count]r{char} replaces.
        { lines = { 'abc', 'def' }, keys = 'Qj2rZ', expect = { 'ZZc', 'ZZf' } },
        -- r<CR> and gr{char}: self-terminating replace sessions (no trailing <Esc>) cascade.
        {
          lines = { 'abcd', 'efgh' },
          place = 'gg0l',
          keys = 'Qjr<CR>',
          expect = { 'a', 'cd', 'e', 'gh' },
        },
        { lines = { 'abc', 'def' }, keys = 'QjgrZ', expect = { 'Zbc', 'Zef' } },
        -- x deletes one multibyte char at each cursor.
        { lines = { 'éàü', '日本語' }, keys = 'Qjx', expect = { 'àü', '本語' } },
        -- diw leaves the cursor at the deleted region (the "x" probes every cursor).
        {
          lines = { 'foo bar', 'baz qux', 'aaa bbb' },
          place = 'gg0l',
          keys = 'QjQjdiw',
          expect = { ' bar', ' qux', ' bbb' },
          after = 'x',
          after_expect = { 'bar', 'qux', 'bbb' },
        },
        -- guiW lowercases and leaves the cursor at the region start.
        {
          lines = { 'FOO BAR', 'BAZ QUX' },
          place = 'gg0l',
          keys = 'QjguiW',
          expect = { 'foo BAR', 'baz QUX' },
          after = 'x',
          after_expect = { 'oo BAR', 'az QUX' },
        },
        -- An operator with a search-motion payload cascades whole (the atom IS the redobuff);
        -- each cursor finds its own match.
        {
          lines = { 'aaa find end', 'bbb find end' },
          keys = 'Qjd/find<CR>',
          expect = { 'find end', 'find end' },
        },
        -- cc preserves per-line indent with 'autoindent'.
        {
          lines = { '  aaa', '      bbb' },
          pre = 'set autoindent',
          keys = 'QjccX<Esc>',
          expect = { '  X', '      X' },
        },
        -- >> indents the line at each cursor.
        {
          lines = { 'foo', 'bar' },
          pre = 'set shiftwidth=2',
          keys = 'Qj>>',
          expect = { '  foo', '  bar' },
        },
      })
    end)
  end)

  describe('[count]Q (search matches)', function()
    it('places a cursor at each match of the last search pattern', function()
      fn.setline(1, { 'foo bar foo', 'baz foo qux', 'foobar foo' })
      feed('gg0') -- on the first "foo"
      feed('*') -- whole-word pattern; the cursor moves to the next match
      feed('1Q')
      -- 4 whole-word "foo" matches ("foobar" excluded), including under the primary.
      eq(4, ncursors())
      -- The primary cursor does not move ("*" left it on the second match).
      eq({ 1, 8 }, api.nvim_win_get_cursor(0))
      feed('cwXXX<Esc>')
      eq({ 'XXX bar XXX', 'baz XXX qux', 'foobar XXX' }, get_lines())
      -- The cursor under the primary merged at the cascade (no double-apply).
      eq(3, ncursors())
      -- A "/" search likewise, also with several matches per line.
      clear_cursors()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'ab ab ab', 'xx ab' })
      feed('gg0/ab<CR>') -- the cursor lands on the second "ab"
      feed('1Q')
      eq(4, ncursors())
      feed('x')
      eq({ 'b b b', 'xx b' }, get_lines())
      -- Placement uses the real search engine, so it matches what "n" finds under the current
      -- case options. 'ignorecase': "/foo" matches all three cases.
      clear_cursors()
      command('set ignorecase')
      api.nvim_buf_set_lines(0, 0, -1, true, { 'Foo foo FOO' })
      feed('gg0/foo<CR>')
      feed('1Q')
      eq(3, ncursors())
      feed('gUiw')
      eq({ 'FOO FOO FOO' }, get_lines())
      -- 'smartcase': an uppercase letter in the pattern forces case-sensitivity, so only the
      -- exact-case match is a cursor (matchbufline would have matched all three).
      clear_cursors()
      command('set smartcase')
      api.nvim_buf_set_lines(0, 0, -1, true, { 'Foo foo Foo' })
      feed('gg0/Foo<CR>') -- only the two "Foo"s, not "foo"
      feed('1Q')
      eq(2, ncursors())
      feed('x')
      eq({ 'oo foo oo' }, get_lines())
    end)

    it('does nothing without a previous search (E35)', function()
      fn.setline(1, { 'foo foo' })
      feed('1Q')
      eq(0, ncursors())
    end)
  end)

  describe('g CTRL-A (counter)', function()
    it('inserts an ascending number at each cursor', function()
      cursors({ 'a', 'b', 'c' }, 'Qj0Qj0')
      feed('g<C-A>')
      eq({ '1a', '2b', '3c' }, get_lines())
      -- A count sets the starting number.
      clear_cursors()
      cursors({ 'a', 'b' }, 'Qj0')
      feed('5g<C-A>')
      eq({ '5a', '6b' }, get_lines())
      -- The primary sitting ON a cursor (no cascade ran in between, so mc_dedupe did not):
      -- the coincident pair shares one number slot, and the cursor survives.
      clear_cursors()
      cursors({ 'x', 'y', 'z' }, 'QjQj')
      feed('gg0g<C-A>')
      eq({ '1x', '2y', 'z' }, get_lines())
      eq(2, ncursors())
    end)

    it('via a mapping applies ONCE (cursor-global: no avalanche)', function()
      cursors({ 'a', 'b', 'c' })
      command('nnoremap ,n g<C-A>')
      feed(',n')
      eq({ '1a', '2b', '3c' }, get_lines())
    end)

    it('without cursors, g CTRL-A is not a command', function()
      fn.setline(1, { 'x 5' })
      feed('gg0g<C-A>')
      eq({ 'x 5' }, get_lines()) -- beeps, no counter and no increment
      feed('<C-A>') -- plain CTRL-A increments as usual
      eq({ 'x 6' }, get_lines())
    end)

    it('number() takes start/step/format', function()
      cursors({ 'x', 'x', 'x' }, 'Qj0Qj0')
      n.exec_lua([[require('vim._core.mcursor').number(10, 2, '%d) ')]])
      eq({ '10) x', '12) x', '14) x' }, get_lines())
    end)
  end)

  describe('nvim_mcursor()', function()
    it('adds a cursor at (row, col), which cascades', function()
      fn.setline(1, { 'aaa', 'bbb', 'ccc' })
      eq(1, api.nvim_mcursor(0, { 1, 0 }))
      eq(2, api.nvim_mcursor(0, { 2, 0 }))
      feed('Gx')
      eq({ 'aa', 'bb', 'cc' }, get_lines())

      -- Can add mcursor to a hidden buffer.
      command('set hidden')
      local other = api.nvim_create_buf(true, false)
      api.nvim_buf_set_lines(other, 0, -1, true, { 'xxx', 'yyy' })
      eq(3, api.nvim_mcursor(other, { 1, 0 }))
      api.nvim_set_current_buf(other)
      feed('Gx')
      eq({ 'xx', 'yy' }, get_lines())
    end)

    it('rejects invalid positions', function()
      fn.setline(1, { 'aaa' })
      t.matches('Invalid cursor line: out of range', t.pcall_err(api.nvim_mcursor, 0, { 99, 0 }))
      t.matches(
        "Invalid 'pos': expected %[row, col%] array",
        t.pcall_err(api.nvim_mcursor, 0, { 1 })
      )
      t.matches('Invalid buffer', t.pcall_err(api.nvim_mcursor, 9999, { 1, 0 }))
    end)

    it('deleting a cursor extmark deletes the cursor', function()
      cursors({ 'aaa', 'bbb', 'ccc' })
      local ns = api.nvim_create_namespace('nvim.multicursor')
      local marks = api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
      eq(2, #marks)
      api.nvim_buf_del_extmark(0, ns, marks[1][1])
      feed('x') -- the cursor without a mark is swept; the other cascades
      eq({ 'aaa', 'bb', 'cc' }, get_lines())
      eq(1, ncursors())
    end)

    it('exit with cursors active in multiple buffers', function()
      cursors({ 'aaa', 'bbb' }, 'Qj')
      feed('yy') -- Session-written register, exit path reaches mc_reg_gather.
      command('new')
      fn.setline(1, { 'ccc' })
      api.nvim_mcursor(0, { 1, 0 })
      n.expect_exit(command, 'qall!')
    end)

    it('cursors are freed with their buffer', function()
      fn.setline(1, { 'aaa', 'bbb' })
      local buf = api.nvim_get_current_buf()
      eq(1, api.nvim_mcursor(0, { 1, 0 }))
      eq(2, api.nvim_mcursor(0, { 2, 0 }))
      command('new')
      fn.setreg('"', 'KEEP')
      command('bwipeout! ' .. buf)
      -- Registers NOT gathered/joined, the cleared cursors are not in curbuf.
      eq('KEEP', fn.getreg('"'))
      eq('v', fn.getregtype('"'))
      fn.setline(1, { 'xxx', 'yyy' })
      -- The wiped buffer's cursors are gone: only the new one counts.
      eq(1, api.nvim_mcursor(0, { 1, 0 }))
      feed('Gx')
      eq({ 'xx', 'yy' }, get_lines())
    end)
  end)

  describe('buffers and windows', function()
    it('cascade is per-buffer: pauses in another buffer, resumes on return', function()
      -- Cursors cascade only if their buffer is the current buffer.
      command('set hidden')
      cursors({ 'aaa', 'bbb' }, 'Qj')
      command('enew')
      fn.setline(1, { 'xxx' })
      feed('gg0x') -- no cascade into the other buffer
      eq({ 'xx' }, get_lines())
      eq(0, ncursors())
      command('buffer #')
      eq({ 'aaa', 'bbb' }, get_lines())
      eq(1, ncursors()) -- the extmark-tracked cursor survived the round-trip
      feed('2G0x')
      eq({ 'aa', 'bb' }, get_lines())
    end)

    it('each buffer has its own cursor set', function()
      command('set hidden')
      fn.setline(1, { 'aaa', 'bbb' })
      local buf_a = api.nvim_get_current_buf()
      feed('gg0Q')
      feed('j')
      command('new')
      local buf_b = api.nvim_get_current_buf()
      cursors({ 'xxx', 'yyy' }, 'Qj')
      eq(1, ncursors())
      feed('x') -- cascades only in the current buffer
      eq({ 'xx', 'yy' }, get_lines())
      eq({ 'aaa', 'bbb' }, api.nvim_buf_get_lines(buf_a, 0, -1, true))
      command('wincmd p')
      feed('2G0x')
      eq({ 'aa', 'bb' }, get_lines())
      eq({ 'xx', 'yy' }, api.nvim_buf_get_lines(buf_b, 0, -1, true))
    end)

    it('edits cascade from any window showing the buffer (:split)', function()
      -- Cascade is conditional on the buffer, not the window.
      cursors({ 'aaa', 'bbb' }, 'Q')
      command('split')
      feed('jx') -- edit from the new window
      eq({ 'aa', 'bb' }, get_lines())
    end)

    it('clearing is per-buffer', function()
      command('set hidden')
      cursors({ 'aaa', 'bbb' }, 'Qj')
      command('enew')
      clear_cursors()
      command('buffer #')
      eq(1, ncursors())
      clear_cursors()
      eq(0, ncursors())
      feed('gg0x') -- only the primary edits
      eq({ 'aa', 'bbb' }, get_lines())
    end)

    it('nvim_buf_clear_namespace("nvim.multicursor") deletes the cursors', function()
      cursors({ 'aaa', 'bbb' }, 'Qj')
      eq(1, ncursors())
      n.exec_lua([[
        vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace('nvim.multicursor'), 0, -1)
      ]])
      eq(0, ncursors())
      feed('gQ') -- the deletion snapshotted the cursors: restorable
      eq(1, ncursors())
      feed('x') -- both cursors edit again (primary still on line 2)
      eq({ 'aa', 'bb' }, get_lines())
    end)

    it(':edit! reload clears the cursors', function()
      local fname = t.tmpname()
      fn.writefile({ 'aaa', 'bbb' }, fname)
      command('edit ' .. fname)
      feed('gg0Q')
      feed('j')
      eq(1, ncursors())
      command('edit!')
      eq(0, ncursors())
      feed('Q') -- A new session starts cleanly.
      eq(1, ncursors())
    end)
  end)

  describe('insert-mode cascade', function()
    it('CTRL-U cascades before <Esc> (deletion crossing the session anchor)', function()
      -- Deleting typed text cascades live (the region shrinks). But CTRL-U here eats the "o"
      -- autoindent, which precedes the tracked region, invisible to the preview diff.
      -- Non-literal keys flush instead: the pending keys replay as a span immediately.
      command('set autoindent')
      cursors({ '    indented aa', '    indented cc' }, 'Q')
      feed('2gg0')
      feed('o')
      feed('<C-u>')
      -- Mid-session (no <Esc> yet): the cursor's line must match the
      -- primary's (indent eaten at both).
      eq({ '    indented aa', '', '    indented cc', '' }, get_lines())
    end)

    it('o + CTRL-U does not join lines at less-indented cursors', function()
      -- 'autoindent': "o" opens an indented line at the indented cursors, an empty line at the flat
      -- cursor. The replayed CTRL-U there has nothing to delete; it must not backspace through the
      -- line boundary ('backspace' includes "eol") and join lines.
      command('set autoindent')
      cursors({ '    indented aa', 'flat bb', '    indented cc' })
      feed('o<C-u><Tab>yay<Esc>')
      eq({
        '    indented aa',
        '\tyay',
        'flat bb',
        '\tyay',
        '    indented cc',
        '\tyay',
      }, get_lines())
    end)

    it('cursor-moves cascade live at each cursor', function()
      cursors({ 'alpha one', 'beta two', 'gamma three' })
      -- A cursor-move key is a cmd, not text: it flushes pending keys as a span (like CTRL-U).
      feed('Aab<Left><Left>X')
      -- Mid-session (no <Esc> yet): the cursor-move already applied everywhere.
      eq({ 'alpha oneXab', 'beta twoXab', 'gamma threeXab' }, get_lines())
      feed('<Esc>')
      feed('AZ<Home>Y<Esc>')
      eq({ 'Yalpha oneXabZ', 'Ybeta twoXabZ', 'Ygamma threeXabZ' }, get_lines())
      -- Word-wise cursor-move: per-cursor word boundaries, not a copied column offset.
      feed('A<S-Left>W<Esc>')
      eq({ 'Yalpha WoneXabZ', 'Ybeta WtwoXabZ', 'Ygamma WthreeXabZ' }, get_lines())
    end)

    it('CTRL-G U cursor-move cascades live; one undo block', function()
      cursors({ 'aa', 'bb' }, 'Qj')
      feed('i12<C-g>U<Left>3')
      -- Mid-session: the CTRL-G U move flushed and cascaded.
      eq({ '132aa', '132bb' }, get_lines())
      feed('<Esc>')
      -- CTRL-G U does not split undo (unlike plain <Left>).
      feed('u')
      eq({ 'aa', 'bb' }, get_lines())
    end)

    it('absolute jump (<C-Home>) splits: previews stay, the live cascade re-anchors', function()
      fn.setline(1, { 'alpha', 'beta', 'gamma' })
      feed('j0Q')
      feed('j0Q')
      feed('gg$')
      feed('ix<C-Home>y')
      -- Mid-session: "x" stays as text; "y" (after jump) continues at the re-anchored positions.
      eq({ 'yalphxa', 'xybeta', 'xygamma' }, get_lines())
      feed('<Esc>')
      eq({ 'yalphxa', 'xybeta', 'xygamma' }, get_lines())
    end)

    it('CTRL-C ends the session like <Esc>: text and cursors survive', function()
      command('set autoindent')
      cursors({ '    indented aa', 'flat bb', '    indented cc' })
      feed('o<C-u><Tab>yay')
      -- Drain first: a CTRL-C pending in typeahead cancels the queued keys before they execute
      -- (unrelated to multicursor).
      n.poke_eventloop()
      feed('<C-c>')
      -- CTRL-C ended the insert session; it must not also abort the commit replay (the primary
      -- keeps its text on CTRL-C, so the cursors do too).
      eq({
        '    indented aa',
        '\tyay',
        'flat bb',
        '\tyay',
        '    indented cc',
        '\tyay',
      }, get_lines())
      -- The cursors survive: a subsequent edit still cascades to all three.
      feed('x')
      eq({
        '    indented aa',
        '\tya',
        'flat bb',
        '\tya',
        '    indented cc',
        '\tya',
      }, get_lines())
    end)

    it('EOL insertion points display as virtual cells', function()
      local screen = Screen.new(40, 5)
      command('hi MCursor guifg=NONE guibg=Red')
      cursors({ 'aa', 'bbbb', 'cc' })
      -- "A": each insertion point is past EOL (no char cell), a virtual cell overlays it. #41576
      feed('A')
      screen:add_extra_attr_ids({
        [100] = { background = Screen.colors.Red },
      })
      screen:expect([[
        aa{100: }                                     |
        bbbb{100: }                                   |
        cc^                                      |
        {1:~                                       }|
        {5:-- INSERT --}                            |
      ]])
      -- Ending the session moves cursors onto last char (real text); the virtual cell disappears.
      feed('!<Esc>')
      screen:expect([[
        aa{100:!}                                     |
        bbbb{100:!}                                   |
        cc^!                                     |
        {1:~                                       }|
                                                |
      ]])
    end)

    it('typed text appears at cursors before leaving insert-mode', function()
      local screen = Screen.new(30, 6)
      cursors({ 'aaa', 'bbb', 'ccc' })
      -- Still in insert mode (no <Esc> yet): the text already cascaded; each cursor displays
      -- at its insertion point, like the primary.
      feed('iXY')
      screen:expect([[
        XY{17:a}aa                         |
        XY{17:b}bb                         |
        XY^ccc                         |
        {1:~                             }|*2
        {5:-- INSERT --}                  |
      ]])
      feed('<Esc>')
      eq({ 'XYaaa', 'XYbbb', 'XYccc' }, get_lines())
      -- The session end shifts every cursor onto the last inserted char.
      screen:expect([[
        X{17:Y}aaa                         |
        X{17:Y}bbb                         |
        X^Yccc                         |
        {1:~                             }|*2
                                      |
      ]])
      -- Entering insert mode displays each cursor at its insertion point
      -- right away, BEFORE any text is typed ("a": one char to the right).
      feed('a')
      screen:expect([[
        XY{17:a}aa                         |
        XY{17:b}bb                         |
        XY^ccc                         |
        {1:~                             }|*2
        {5:-- INSERT --}                  |
      ]])
      feed('<Esc>')
      -- An operator entry ("ciw") live-mirrors the same way: the entry
      -- replay changes each cursor's OWN word, still in insert mode.
      feed('0ciwZ')
      screen:expect([[
        Z{17: }                            |
        Z{17: }                            |
        Z^                             |
        {1:~                             }|*2
        {5:-- INSERT --}                  |
      ]])
      feed('<Esc>')
      -- A Visual-entered change ("viwc") live-mirrors too: the entry replay
      -- re-executes the selection at each cursor.
      feed('viwcW')
      screen:expect([[
        W{17: }                            |
        W{17: }                            |
        W^                             |
        {1:~                             }|*2
        {5:-- INSERT --}                  |
      ]])
      feed('<Esc>')
    end)
  end)

  describe('insert-mode depth', function()
    it('session survives all cursors deduping away mid-session', function()
      -- A cursor at the primary's position: the "A" entry replay lands it on the primary and
      -- dedupe removes it mid-session; the <Esc> commit must not cascade into the empty set.
      fn.setline(1, { 'x' })
      feed('Q')
      feed('Ahi<Esc>')
      n.assert_alive()
      eq({ 'xhi' }, get_lines())
    end)

    it('insert sessions cascade at each cursor', function()
      assert_rows({
        -- iZ: after <Esc> the cursors sit ON the last inserted char (like the primary cursor).
        {
          lines = { 'aaa', 'bbb', 'ccc' },
          keys = 'QjQjiZ<Esc>',
          expect = { 'Zaaa', 'Zbbb', 'Zccc' },
          after = 'x',
          after_expect = { 'aaa', 'bbb', 'ccc' },
        },
        -- A: distinct chars and line lengths, so an off-by-one anchor (e.g. a past-EOL anchor
        -- clamped by a replay in MODE_NORMAL) inserts before the last char, which identical
        -- chars ("!!") would mask.
        {
          lines = { 'a', 'bb bb', 'c cc' },
          keys = 'QjQjA!?<Esc>',
          expect = { 'a!?', 'bb bb!?', 'c cc!?' },
          after = 'x',
          after_expect = { 'a!', 'bb bb!', 'c cc!' },
        },
        -- cw changes a word at each cursor.
        {
          lines = { 'aaa one', 'bbb two', 'ccc three' },
          keys = 'QjQjcwFOO<Esc>',
          expect = { 'FOO one', 'FOO two', 'FOO three' },
        },
        -- <BS> cascades deletion.
        { lines = { 'aaa', 'bbb' }, keys = 'QjiXY<BS>Z<Esc>', expect = { 'XZaaa', 'XZbbb' } },
        -- <BS> deletes before the insert start.
        {
          lines = { 'abc', 'def' },
          place = 'gg0l',
          keys = 'Qji<BS>Z<Esc>',
          expect = { 'Zbc', 'Zef' },
        },
        -- <BS> at col 0 joins with the line above.
        {
          lines = { 'aa', 'bb', 'cc', 'dd' },
          place = 'ggj0',
          keys = 'Q2ji<BS><Esc>',
          expect = { 'aabb', 'ccdd' },
        },
        -- <CR> mid-insert splits the line.
        {
          lines = { 'aaXbb', 'ccXdd' },
          place = 'gg02l',
          keys = 'QjiAB<CR>CD<Esc>',
          expect = { 'aaAB', 'CDXbb', 'ccAB', 'CDXdd' },
        },
        -- O opens a line above.
        {
          lines = { 'aaa', 'bbb', 'ccc' },
          keys = 'Q2jOX<Esc>',
          expect = { 'X', 'aaa', 'bbb', 'X', 'ccc' },
        },
        -- a appends after the cursor char.
        { lines = { 'abc', 'def' }, keys = 'QjaZ<Esc>', expect = { 'aZbc', 'dZef' } },
        -- I inserts at the first non-blank.
        {
          lines = { '  aa', '    bb' },
          place = 'gg$',
          keys = 'Qj$IX<Esc>',
          expect = { '  Xaa', '    Xbb' },
        },
        -- i_CTRL-W deletes a word.
        {
          lines = { 'zz', 'yy' },
          keys = 'Qjifoo bar<C-w>X<Esc>',
          expect = { 'foo Xzz', 'foo Xyy' },
        },
        -- i_CTRL-V inserts a unicode char; after <Esc> the cursors sit ON it.
        {
          lines = { 'aaa', 'bbb' },
          keys = 'Qji<C-v>u00e9<Esc>',
          expect = { 'éaaa', 'ébbb' },
          after = 'x',
          after_expect = { 'aaa', 'bbb' },
        },
        -- i<Esc> at col 0 keeps the cursor at col 0.
        {
          lines = { 'abc', 'def' },
          keys = 'Qji<Esc>',
          expect = { 'abc', 'def' },
          after = 'x',
          after_expect = { 'bc', 'ef' },
        },
        -- 3iZ (counted insert) cascades the whole session.
        { lines = { 'aaa', 'bbb' }, keys = 'Qj3iZ<Esc>', expect = { 'ZZZaaa', 'ZZZbbb' } },
        -- R replaces; R + <BS> restores the replaced chars.
        { lines = { 'abcdef', 'ghijkl' }, keys = 'QjRXY<Esc>', expect = { 'XYcdef', 'XYijkl' } },
        {
          lines = { 'abcdef', 'ghijkl' },
          keys = 'QjRXY<BS><BS><Esc>',
          expect = { 'abcdef', 'ghijkl' },
        },
        -- Abbreviations expand identically at each cursor.
        {
          lines = { 'aaa', 'bbb' },
          pre = 'iabbrev teh the',
          keys = 'Qjiteh <Esc>',
          expect = { 'the aaa', 'the bbb' },
        },
        -- 'autoindent' applies per cursor with o.
        {
          lines = { '  aa', '      bb' },
          pre = 'set autoindent',
          keys = 'QjoX<Esc>',
          expect = { '  aa', '  X', '      bb', '      X' },
        },
      })
    end)

    it('ea appends at word end at each cursor (with q=)', function()
      cursors({ 'one two', 'three four' }, 'Qj')
      feed('q=')
      feed('ea!<Esc>')
      feed('q=')
      eq({ 'one! two', 'three! four' }, get_lines())
    end)

    it('i_CTRL-N completion result appears at each cursor', function()
      fn.setline(1, { 'wombat', 'wo', 'wo' })
      feed('2gg')
      feed('Q')
      feed('j')
      feed('A<C-n><Esc>')
      eq({ 'wombat', 'wombat', 'wombat' }, get_lines())
    end)
  end)

  describe('navigation state (primary-only)', function()
    it('jumplist, changelist and marks follow only the primary', function()
      local l = {}
      for i = 1, 30 do
        l[#l + 1] = ('word%d line'):format(i)
      end
      cursors(l)
      -- Change marks and changelist: one edit at 3 cursors records the primary's position only.
      local nchanges = #fn.getchangelist()[1]
      feed('x')
      eq({ 3, 0 }, api.nvim_buf_get_mark(0, '['))
      eq({ 3, 0 }, api.nvim_buf_get_mark(0, ']'))
      eq({ 3, 0 }, api.nvim_buf_get_mark(0, '.'))
      eq(nchanges + 1, #fn.getchangelist()[1])
      -- Visual marks: the primary's selection.
      feed('viwy')
      eq({ 3, 0 }, api.nvim_buf_get_mark(0, '<'))
      eq({ 3, 3 }, api.nvim_buf_get_mark(0, '>'))
      -- Jumplist: a followed jump records one entry (the primary's).
      -- (Last: all cursors land on line 30 and merge.)
      command('clearjumps')
      feed('q=')
      feed('G')
      feed('q=')
      eq(1, #fn.getjumplist()[1])
    end)
  end)

  describe('completion', function()
    -- While a completion is active, the cascade pauses: redobuff is frozen, and spans cannot replay
    -- into a busy completion (edit() refuses recursive insert). The other cursors catch up when the
    -- completion ends.

    --- Three empty lines under "foo*" completion candidates; cursors on lines 4-5, primary on 6.
    local function ac_setup()
      command('setlocal autocomplete')
      cursors({ 'foo', 'foobar', 'foobarbaz', '', '', '' }, '3jQjQj')
    end

    it("'autocomplete' popup: cursors catch up when the completion ends", function()
      local screen = Screen.new(40, 12)
      ac_setup()
      feed('if')
      feed('o')
      screen:expect({ any = 'INSERT' })
      -- The preview updates live (even during completion); cursors intact.
      eq(2, ncursors())
      feed('<Esc>')
      eq({ 'foo', 'foobar', 'foobarbaz', 'fo', 'fo', 'fo' }, get_lines())
      eq(2, ncursors())
    end)

    it("'autocomplete': accepting a completion applies at all cursors", function()
      ac_setup()
      feed('if')
      feed('<C-n>') -- select the first popup entry
      feed('<C-y>') -- accept
      feed(' tail<Esc>') -- and keep typing
      local l = get_lines()
      eq({ l[4], l[4] }, { l[5], l[6] })
    end)

    it("'autocomplete': <BS> and <C-e> cancel propagate", function()
      ac_setup()
      feed('ifoo<BS>x<Esc>')
      eq({ 'fox', 'fox', 'fox' }, { get_lines()[4], get_lines()[5], get_lines()[6] })
      feed('cc')
      feed('f<C-n><C-n><C-e><Esc>') -- cycle, then cancel back to the leader
      eq({ 'f', 'f', 'f' }, { get_lines()[4], get_lines()[5], get_lines()[6] })
    end)

    it('InsertCharPre-driven complete() plugin (cmp-style)', function()
      local screen = Screen.new(40, 12)
      -- Typical third-party completion plugin: an InsertCharPre handler
      -- that schedules complete() (textlock forbids calling it directly).
      n.exec_lua([[
        vim.api.nvim_create_autocmd('InsertCharPre', {
          callback = function()
            vim.schedule(function()
              if vim.fn.mode():find('i') and vim.fn.pumvisible() == 0 then
                vim.fn.complete(1, { 'foobar', 'foolish' })
              end
            end)
          end,
        })
      ]])
      cursors({ '', '', '' })
      feed('if')
      screen:expect({ any = 'foolish' }) -- wait for the popup
      feed('<C-y>') -- accept the (pre-inserted) first candidate
      feed('<Esc>')
      eq({ 'foobar', 'foobar', 'foobar' }, get_lines())
      screen:expect({ none = 'foolish' }) -- popup closed
      -- <Esc> with the popup still visible keeps all cursors equal too.
      feed('cc')
      feed('x')
      screen:expect({ any = 'foolish' }) -- wait for the new popup
      feed('<Esc>')
      local l = get_lines()
      eq({ l[3], l[3] }, { l[1], l[2] })
    end)
  end)

  describe('visual-mode cascade', function()
    it('failed command mid-replay does not leak Visual mode into the next replay', function()
      fn.setline(1, { 'alpha bravo', 'golf hotel', 'mike november' })
      feed('ggVjjQ') -- cursor on each line; enables "q=" follow-motion
      feed('gg0')
      -- The abandoned selection replays "vlo h <Esc>" at each cursor ("q=" follow). The "h" fails
      -- (col 0 after "o" swapped to the selection start), which flushes the rest of the replay,
      -- eating the terminating <Esc>. Visual mode must not leak into the next cursor's replay.
      feed('vloh<Esc>')
      eq({ 'alpha bravo', 'golf hotel', 'mike november' }, get_lines())
      eq('n', api.nvim_get_mode().mode)
    end)

    it('shows per-cursor visual selection', function()
      local screen = Screen.new(30, 6)
      cursors({ 'longword x', 'ab y', 'medium z' })
      -- Each cursor shows its own selection ("iw" = that cursor's word), previewed live.
      feed('viw')
      screen:expect([[
        {17:longword} x                    |
        {17:ab} y                          |
        {17:mediu}^m z                      |
        {1:~                             }|*2
        {5:-- VISUAL --}                  |
      ]])
      feed('e')
      screen:expect([[
        {17:longword x}                    |
        {17:ab y}                          |
        {17:medium }^z                      |
        {1:~                             }|*2
        {5:-- VISUAL --}                  |
      ]])
      feed('<Esc>')
      screen:expect([[
        {17:l}ongword x                    |
        {17:a}b y                          |
        medium ^z                      |
        {1:~                             }|*2
                                      |
      ]])
    end)

    it('shows linewise/blockwise selections', function()
      local screen = Screen.new(30, 6)
      cursors({ 'aaaa', 'bbbb', 'cccc', 'dddd' }, 'Q2j')
      feed('Vj') -- linewise: primary lines 3-4, fake lines 1-2
      screen:expect([[
        {17:aaaa}                          |
        {17:bbbb}                          |
        {17:cccc}                          |
        ^d{17:ddd}                          |
        {1:~                             }|
        {5:-- VISUAL LINE --}             |
      ]])
      feed('<Esc>')
      feed('3G0l')
      feed('<C-v>jl') -- blockwise: primary (3,1)-(4,2), fake (1,0)-(2,1)
      screen:expect([[
        {17:aa}aa                          |
        {17:bb}bb                          |
        c{17:cc}c                          |
        d{17:d}^dd                          |
        {1:~                             }|
        {5:-- VISUAL BLOCK --}            |
      ]])
    end)

    it('replays the full visual keysequence', function()
      cursors({ 'one two three x', 'aa bb cc d' }, 'Qj')
      -- Select word, extend twice, delete: selection re-executes at each cursor, so the extents are
      -- per-cursor (not a fixed-size reselect).
      atoms_start()
      feed('viweex')
      eq({ ' x', ' d' }, get_lines())
      -- The operator is normalized ("translated"): visual "x" == "d".
      eq({ 'viweed' }, atoms_tail(1))
    end)

    it('operators cascade at each cursor', function()
      assert_rows({
        -- Vjd deletes two lines.
        { lines = { 'a', 'b', 'c', 'd', 'e', 'f' }, keys = 'Q4jVjd', expect = { 'c', 'd' } },
        -- r replaces the selection.
        { lines = { 'one two', 'ab cd' }, keys = 'QjviwrX', expect = { 'XXX two', 'XX cd' } },
        -- Blockwise c changes the block, I inserts before it, A appends after it.
        {
          lines = { 'ab', 'cd', 'ef', 'gh' },
          keys = 'Q2j<C-v>jcX<Esc>',
          expect = { 'Xb', 'Xd', 'Xf', 'Xh' },
        },
        {
          lines = { 'ab', 'cd', 'ef', 'gh' },
          keys = 'Q2j<C-v>jIX<Esc>',
          expect = { 'Xab', 'Xcd', 'Xef', 'Xgh' },
        },
        {
          lines = { 'ab', 'cd', 'ef', 'gh' },
          keys = 'Q2j<C-v>jA!<Esc>',
          expect = { 'a!b', 'c!d', 'e!f', 'g!h' },
        },
      })
    end)

    it('<Esc> discards the pending visual atom', function()
      cursors({ 'abc', 'def' }, 'Qj')
      feed('viw<Esc>')
      feed('x') -- cascades normally; no stray visual replay
      eq({ 'bc', 'de' }, get_lines())
    end)

    it('cursor displays at each selection end; o swaps it', function()
      local screen = Screen.new(40, 6)
      command('hi MCursor guifg=NONE guibg=Red')
      command('hi MCursorVisual guibg=Blue')
      cursors({ 'aaa bbb ccc', 'ddd eee fff', 'ggg hhh iii' }, '4lQjQj')
      feed('vl')
      screen:add_extra_attr_ids({
        [100] = { background = Screen.colors.Blue1 },
      })
      -- The (red) display cursor sits at each selection end; the (blue)
      -- anchor cell shows only the selection.
      screen:expect([[
        aaa {100:b}{30:b}b ccc                             |
        ddd {100:e}{30:e}e fff                             |
        ggg {17:h}^hh iii                             |
        {1:~                                       }|*2
        {5:-- VISUAL --}                            |
      ]])
      feed('o')
      screen:expect([[
        aaa {30:b}{100:b}b ccc                             |
        ddd {30:e}{100:e}e fff                             |
        ggg ^h{17:h}h iii                             |
        {1:~                                       }|*2
        {5:-- VISUAL --}                            |
      ]])
      feed('<Esc>')
      -- Back to normal mode: the cursor highlight returns to the anchors.
      screen:expect([[
        aaa {30:b}bb ccc                             |
        ddd {30:e}ee fff                             |
        ggg ^hhh iii                             |
        {1:~                                       }|*2
                                                |
      ]])
    end)

    it('payload motions: f{char} and search', function()
      cursors({ 'abcd,ef', 'wxyz,gh' }, 'Qj')
      feed('vf,d') -- f-operand: replayable, cascades.
      eq({ 'ef', 'gh' }, get_lines())
      clear_cursors()
      cursors({ 'one two', 'one two' }, 'Qj')
      feed('v/two<CR>d') -- Search payload travels in the collected keys, cascades.
      eq({ 'wo', 'wo' }, get_lines())
      clear_cursors()
      -- Viewport scroll (C-E) that drags the cursor (viewport edge, 'scrolloff') changes the
      -- selection by a viewport-dependent amount: not replayable, edits primary only.
      local lines = {}
      for i = 1, 30 do
        lines[i] = 'x' .. i
      end
      fn.setline(1, lines)
      feed('10ggQgg')
      feed('V<C-e>') -- Drags the primary onto line 2: selection is lines 1-2.
      feed('d')
      eq(28, fn.line('$')) -- Primary deleted 2 lines; no cascade.
      eq({ 'x3', 'x4' }, { fn.getline(1), fn.getline(2) })
    end)
  end)

  describe('q= (follow motion)', function()
    it('cursors follow primary-cursor motions', function()
      cursors({ 'abcd', 'efgh' }, 'Q')
      feed('j') -- No cascade/follow.
      feed('q=')
      feed('ll') -- Cascade, both cursors move 2 chars rightwards.
      feed('x')
      eq({ 'abd', 'efh' }, get_lines())
      -- Toggle off: "h" moves only primary, the other cursor still deletes at its unmoved position.
      feed('q=')
      feed('h')
      feed('x')
      eq({ 'ab', 'eh' }, get_lines())
      -- [count]q= forces the mode instead of toggling.
      feed('1q=') -- Force "on".
      feed('1q=')
      feed('h')
      feed('x')
      eq({ 'b', 'h' }, get_lines())
      feed('2q=') -- Force "off".
      feed('2q=')
      feed('A!<Esc>')
      feed('h')
      feed('x')
      eq({ 'b', '!' }, get_lines())
    end)

    it('implicit exit (cursors deduped) resets follow-motion', function()
      cursors({ 'aaa', 'bbb', 'ccc' })
      eq(2, ncursors())
      feed('q=')
      feed('gg') -- Absolute motion: every cursor lands on the primary, all deduped.
      eq(0, ncursors())
      -- Exited implicitly: "q=" resets, else the next "Q" would dedupe on "j".
      feed('Q')
      feed('j')
      eq(1, ncursors())
    end)

    it('Q (placing a cursor) ends follow-mode', function()
      cursors({ 'aaa', 'bbb', 'ccc' }, 'Qj')
      feed('q=')
      feed('l') -- Sanity: cascades.
      eq({ { 0, 1 } }, anchors())
      feed('Q') -- Adds a cursor at the primary, and exits follow-mode.
      eq(2, ncursors())
      feed('j') -- No follow: nothing converges or dedupes.
      eq(2, ncursors())
      eq({ { 0, 1 }, { 1, 1 } }, anchors())
    end)

    it('jumps are not followed (CTRL-O, backtick)', function()
      cursors({ 'abcd', 'efgh', 'ijkl' }, 'Q')
      feed('3G') -- Jumps fill the jumplist; no cascade.
      feed('2G')
      feed('q=') -- Follow-mode.
      feed('l') -- Sanity: motions cascade.
      eq({ { 0, 1 } }, anchors())
      feed('<C-o>') -- Jump.
      feed('``') -- Jump.
      eq({ { 0, 1 } }, anchors())
    end)

    it('cursors follow j/k, gj/gk, arrow keys, and $', function()
      cursors({ 'a1', 'a2', 'a3', 'b1', 'b2', 'b3' }, 'Q')
      feed('3j') -- Cursors at "a1" and "b1".
      feed('q=')
      feed('j') -- Both cursors move down.
      feed('x')
      eq({ 'a1', '2', 'a3', 'b1', '2', 'b3' }, get_lines())
      feed('k') -- Both cursors move back up.
      feed('x')
      eq({ '1', '2', 'a3', '1', '2', 'b3' }, get_lines())
      feed('gj') -- Display-line motions follow too.
      feed('x')
      eq({ '1', '', 'a3', '1', '', 'b3' }, get_lines())
      feed('gk')
      feed('x')
      eq({ '', '', 'a3', '', '', 'b3' }, get_lines())
      -- Arrow keys follow.
      clear_cursors()
      cursors({ 'abcd', 'efgh', 'ijkl', 'mnop' }, 'Q2j') -- Cursors at "abcd" and "ijkl".
      feed('q=')
      feed('<Down>')
      feed('<Right>')
      feed('x')
      eq({ 'abcd', 'egh', 'ijkl', 'mop' }, get_lines())
      feed('<Up>')
      feed('<Left>')
      feed('x')
      eq({ 'bcd', 'egh', 'jkl', 'mop' }, get_lines())
      feed('q=')
      -- $ moves each cursor to its own EOL.
      clear_cursors()
      cursors({ 'abc', 'defgh' }, 'Qj')
      feed('q=')
      feed('$')
      feed('x')
      eq({ 'ab', 'defg' }, get_lines())
    end)

    it('cursors follow mapped motions (nnoremap j gj)', function()
      command('nnoremap j gj')
      cursors({ 'a1', 'a2', 'b1', 'b2' }, 'Q2j')
      feed('q=')
      feed('j')
      feed('x')
      eq({ 'a1', '2', 'b1', '2' }, get_lines())
      -- Expr-mapping results follow the same way.
      command([[nnoremap <expr> j v:count == 0 ? 'gk' : 'k']])
      feed('j')
      feed('x')
      eq({ '1', '2', '1', '2' }, get_lines())
      -- No follow: a motion mapping does not cascade; the "x" does.
      feed('q=')
      feed('j') -- gk: moves only the primary.
      feed('x')
      eq({ '', '', '1', '2' }, get_lines())
    end)

    it('q= while macro-recording does not toggle', function()
      fn.setline(1, { 'a1', 'a2', 'b1', 'b2' })
      feed('gg0')
      feed('Q') -- Cursor placed before recording starts.
      feed('qa') -- Start recording.
      feed('2j')
      feed('q=') -- q stops recording; = is a pending operator...
      feed('<Esc>')
      feed('j')
      feed('x')
      -- Follow did not toggle.
      eq({ '1', 'a2', 'b1', '2' }, get_lines())
    end)

    it('abandoned visual selection moves cursors to their selection ends', function()
      cursors({ 'aaa bbb ccc', 'ddd eee fff', 'ggg hhh iii' }, '4lQjQj')
      feed('q=')
      feed('viw<Esc>') -- Selection end: the last char of each cursor's word.
      feed('x')
      eq({ 'aaa bb ccc', 'ddd ee fff', 'ggg hh iii' }, get_lines())
      -- No follow: <Esc> discards, other cursors stay; "x" cascades.
      feed('q=')
      feed('0viw<Esc>')
      feed('x')
      eq({ 'aaa bbccc', 'ddd eefff', 'gg hh iii' }, get_lines())
    end)

    it('per-cursor curswant is kept over short lines', function()
      fn.setline(1, { 'ABCDEF', 'xy', 'GHIJKL', 'MNOPQR', 'zw', 'STUVWX' })
      feed('gg04l') -- Cursor at (1,4).
      feed('Q')
      feed('3jhh') -- Primary at (4,2), a different column.
      feed('q=')
      feed('jj') -- Over the short lines: each cursor keeps its column.
      feed('q=')
      feed('x')
      eq({ 'ABCDEF', 'xy', 'GHIJL', 'MNOPQR', 'zw', 'STVWX' }, get_lines())
    end)
  end)

  describe('parity', function()
    it('mapped command cascades its resolved atom', function()
      command('nnoremap ,d dw')
      cursors({ 'one two aa bb', 'three four cc dd' }, 'Qj')
      atoms_start()
      feed(',d')
      eq({ 'two aa bb', 'four cc dd' }, get_lines())
      -- With mcursors: still exactly one CmdAtom event; cascade replays do not emit CmdAtoms.
      eq(1, #atoms())
    end)

    it('mapping with edits and motions cascades as one unit', function()
      -- Split the line at the cursor, ending at the EOL of the first half.
      command('nnoremap gj i<c-j><esc>k$')
      cursors({ 'aaa bbb', 'ccc ddd', 'eee fff' }, '4lQjQj')
      atoms_start()
      feed('gj')
      eq({ 'aaa ', 'bbb', 'ccc ', 'ddd', 'eee ', 'fff' }, get_lines())
      -- The mapping is the atom: exactly one CmdAtom event. Never re-resolved.
      local evs = atoms()
      eq(1, #evs)
      eq({ type = 'mapping', lhs = 'gj', keys = k('1i<Esc>i<NL><Esc>k$'), changed = true }, {
        type = evs[1].type,
        lhs = evs[1].lhs,
        keys = evs[1].keys,
        changed = evs[1].changed,
      })
      -- `atoms` is non-empty iff the atom is a composite of more than one command;
      local children = {}
      for _, c in ipairs(evs[1].atoms) do
        table.insert(children, { c.type, c.keys })
      end
      eq({
        { 'insert', k('1i<Esc>') }, -- spans display as "insert" (cascade-internal type)
        { 'insert', k('i<NL><Esc>') },
        { 'motion', 'k' },
        { 'motion', '$' },
      }, children)
      eq({ 'k', false }, { evs[1].atoms[3].cmd, evs[1].atoms[3].changed })
      -- The mapping's motions (k$) cascade too, even without "q=", because the mapping edits.
      feed('x')
      eq({ 'aaa', 'bbb', 'ccc', 'ddd', 'eee', 'fff' }, get_lines())
    end)

    it('operator + insert mapping cascades as one unit', function()
      command('nnoremap ,x dwiFOO <esc>')
      cursors({ 'one two', 'three four' }, 'Qj')
      feed(',x')
      eq({ 'FOO two', 'FOO four' }, get_lines())
    end)

    it('live insert cascade emits one whole-session atom', function()
      cursors({ 'aaa', 'bbb' }, 'Qj')
      atoms_start()
      -- Typed key-by-key (event-loop pulses between keys): cascades span-by-span, yet emits one
      -- insert-session atom. Spans are cascade-internal, never CmdAtom events.
      feed('i')
      n.poke_eventloop()
      feed('X')
      n.poke_eventloop()
      feed('Y')
      n.poke_eventloop()
      feed('<Esc>')
      local evs = atoms()
      eq(1, #evs)
      eq({ type = 'insert', text = 'XY', keys = k('1iXY<Esc>') }, {
        type = evs[#evs].type,
        text = evs[#evs].text,
        keys = evs[#evs].keys,
      })
      -- No session marks outlive the session (mc_ins_commit() drops them, cascaded or not).
      eq(
        0,
        n.exec_lua([[
          local ns = vim.api.nvim_get_namespaces()['nvim.multicursor._session']
          return ns and #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) or 0
        ]])
      )
      -- A Visual-entered session keeps its "visual" type: each nested span-replay bracket owns
      -- its own InsSession, so it cannot clobber the primary session's `vis`.
      clear_cursors()
      cursors({ 'alpha one', 'beta two' }, 'Qj')
      feed('viwcX<Esc>')
      eq({ 'X one', 'X two' }, get_lines())
      eq('visual', atom_last().type)
    end)

    it('InsertEnter/InsertLeave/TextChanged(I) fire once per action', function()
      command('let [g:ie, g:il, g:tci, g:tc] = [0, 0, 0, 0]')
      command('autocmd InsertEnter * let g:ie += 1')
      command('autocmd InsertLeave * let g:il += 1')
      command('autocmd TextChangedI * let g:tci += 1')
      command('autocmd TextChanged * let g:tc += 1')
      cursors({ 'aaa', 'bbb' }, 'Qj')
      -- Drain input between keys: TextChanged(I) fires only at idle.
      -- The expected counts below are exactly what this sequence produces WITHOUT multicursors.
      feed('i')
      n.poke_eventloop()
      feed('X')
      n.poke_eventloop()
      feed('Y')
      n.poke_eventloop()
      feed('<Esc>')
      n.poke_eventloop()
      eq({ 'XYaaa', 'XYbbb' }, get_lines())
      eq(1, api.nvim_get_var('ie'))
      eq(1, api.nvim_get_var('il'))
      eq(2, api.nvim_get_var('tci')) -- Once per typed char, not per cursor.
      eq(1, api.nvim_get_var('tc')) -- Once for the whole session.
    end)

    it('InsertCharPre fires once per typed char, result applies everywhere', function()
      command('let g:icp = 0')
      command('autocmd InsertCharPre * let g:icp += 1 | let v:char = toupper(v:char)')
      cursors({ 'aaa', 'bbb' }, 'Qj')
      feed('ixy<Esc>')
      eq({ 'XYaaa', 'XYbbb' }, get_lines())
      eq(2, api.nvim_get_var('icp'))
    end)

    it('TextYankPost fires per cursor with per-cursor contents', function()
      command('let g:yanks = []')
      command(
        'autocmd TextYankPost * let g:yanks += [[v:event.regcontents, luaeval("vim.api.nvim__mcursor_cascading()")]]'
      )
      cursors({ 'aaa', 'bbb' }, 'Qj')
      feed('yy')
      -- The primary's own yank fires first and is not a replay.
      eq({ { { 'bbb' }, false }, { { 'aaa' }, true } }, api.nvim_get_var('yanks'))
      -- The primary's registers win, it is the effective yank.
      eq('bbb\n', fn.getreg('"'))
    end)
  end)

  describe('yank DWIM (concat on exit)', function()
    it('joins per-cursor yanks (document order) into the register on exit', function()
      cursors({ 'foo x', 'bar y', 'baz z' }, 'Qj0Q')
      feed('j0') -- Cursors on lines 1,2; primary on line 3 (yanked first).
      feed('yiw')
      -- During multicursor, the register is the primary's own yank.
      eq('baz', fn.getreg('"'))
      clear_cursors() -- Exit: concat, in document-order (not yank-order).
      eq('foo\nbar\nbaz\n', fn.getreg('"'))
      eq('V', fn.getregtype('"')) -- Linewise.
    end)

    it('regular yank (no multicursor)', function()
      fn.setline(1, { 'hello' })
      feed('gg0yiw')
      eq('hello', fn.getreg('"'))
    end)

    it('a named register concatenates, an untouched one is preserved', function()
      fn.setreg('z', 'PRESET') -- 'z' is untouched during multicursor.
      cursors({ 'foo', 'bar' }, 'Qj0')
      feed('"ayiw')
      clear_cursors()
      eq('foo\nbar\n', fn.getreg('a')) -- The used register is joined.
      eq('PRESET', fn.getreg('z')) -- An untouched register is not tripled.
    end)

    it('last-write-wins: delete after yank yields the deletes', function()
      cursors({ 'aa', 'bb' }, 'Qj0')
      feed('yl') -- Yank a char into '"'.
      feed('x') -- Delete a char into '"' (overwrites, per register semantics).
      clear_cursors()
      eq('a\nb\n', fn.getreg('"')) -- The deletes, not the yanks.
    end)
  end)

  describe('options', function()
    it("'textwidth' auto-wrap applies at each cursor", function()
      api.nvim_set_option_value('textwidth', 10, {})
      cursors({ 'aaa', 'bbb' }, 'Qj')
      feed('Awww xxx yyy zzz<Esc>')
      local lines = get_lines()
      -- The text of both cursors wrapped the same way (same number of lines each).
      eq(0, #lines % 2)
      local half = #lines / 2
      for i = 1, half do
        local a = lines[i]:gsub('^aaa', '')
        local b = lines[half + i]:gsub('^bbb', '')
        eq(a, b)
      end
      -- The primary's line actually wrapped.
      eq(true, #lines > 2)
    end)
  end)

  describe('undo', function()
    it('redo (CTRL-R) restores the cursors to their post-edit positions', function()
      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjQj$')
      feed('IX <Esc>')
      eq({ 'X aaa', 'X bbb', 'X ccc' }, get_lines())
      eq({ { 0, 1 }, { 1, 1 } }, anchors())
      feed('u')
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
      eq({ { 0, 0 }, { 1, 0 } }, anchors())
      feed('<C-r>')
      eq({ 'X aaa', 'X bbb', 'X ccc' }, get_lines())
      -- Splice adjustment alone would drift the marks to col 2: the
      -- explicit post-session positions must be restored.
      eq({ { 0, 1 }, { 1, 1 } }, anchors())
      -- The primary restores to its recorded post-edit position too (the undo header's cursor is
      -- the PRE-change position, it serves undo), in sync with the mcursors.
      eq({ 3, 1 }, api.nvim_win_get_cursor(0))
      feed('x')
      eq({ 'Xaaa', 'Xbbb', 'Xccc' }, get_lines())
    end)

    it('uu undoes two cascaded edits step by step', function()
      cursors({ 'abc', 'def' }, 'Q')
      feed('jx')
      eq({ 'bc', 'ef' }, get_lines())
      feed('x')
      eq({ 'c', 'f' }, get_lines())
      feed('u')
      eq({ 'bc', 'ef' }, get_lines())
      feed('u')
      eq({ 'abc', 'def' }, get_lines())
      feed('<C-r><C-r>')
      eq({ 'c', 'f' }, get_lines())
      -- Counted undo (2u) likewise treats each cascade as one change.
      feed('2u')
      eq({ 'abc', 'def' }, get_lines())
    end)

    it('bulk undo across a live insert then a cascaded delete (one step each)', function()
      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjQj0')
      feed('IX<Esc>') -- live insert at all cursors
      eq({ 'Xaaa', 'Xbbb', 'Xccc' }, get_lines())
      feed('x') -- cascaded delete at all cursors
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
      feed('u') -- revert the delete everywhere
      eq({ 'Xaaa', 'Xbbb', 'Xccc' }, get_lines())
      feed('u') -- revert the insert everywhere
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
      eq(3, fn.line('.')) -- primary placement after undoing a live insert
    end)

    it('a mapped undo/redo (vim-repeat "nmap u") does not cascade', function()
      -- vim-repeat maps u/U/<C-R> to undo/redo wrappers. Such a mapping changes the buffer, but an
      -- undo/redo is buffer-global, not a per-cursor edit: it must NOT cascade, or every cursor
      -- would undo again, over-undoing the whole session (the reported bug).
      fn.setline(1, { 'aaa', 'bbb', 'ccc' })
      feed('gg0Qj0Qj0') -- 3 cursors
      feed('x') -- one cascade: aa,bb,cc
      eq({ 'aa', 'bb', 'cc' }, get_lines())
      command('nnoremap <silent> u :<C-U>undo<CR>')
      command('nnoremap <silent> <C-R> :<C-U>redo<CR>')
      feed('u') -- ONE undo of the cascade, not one-per-cursor (would reach the empty buffer)
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
      feed('<C-R>') -- redo mapping likewise does not cascade
      eq({ 'aa', 'bb', 'cc' }, get_lines())
      -- The guard survives a nested normal_execute() after the undo, in the same mapped command.
      command('nnoremap <silent> u :<C-U>undo <Bar> normal! l<CR>')
      feed('u')
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
    end)

    it('u/CTRL-R ping-pong toggles without drift', function()
      -- Repeated undo/redo of one cascade must stabilize (no extmark drift).
      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjQ')
      feed('jx')
      eq({ 'aa', 'bb', 'cc' }, get_lines())
      feed('u')
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
      feed('<C-r>')
      eq({ 'aa', 'bb', 'cc' }, get_lines())
      feed('u')
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
      feed('<C-r>')
      eq({ 'aa', 'bb', 'cc' }, get_lines())
    end)

    it('undo steps across the mc-enter boundary', function()
      -- Q is placement, not an edit: the undo tree spans pre-mc and in-mc
      -- edits with no extra step in between.
      fn.setline(1, { 'xxx', 'yyy' })
      feed('gg0x')
      eq({ 'xx', 'yyy' }, get_lines())
      feed('Q')
      feed('jx')
      eq({ 'x', 'yy' }, get_lines())
      feed('u')
      eq({ 'xx', 'yyy' }, get_lines())
      feed('u')
      eq({ 'xxx', 'yyy' }, get_lines())
    end)

    it('u after a line-inserting cascade restores every cursor position', function()
      -- "o" shifts the other cursors' lines; undo must move them all back
      -- (cursor extmarks restore on undo).
      cursors({ 'aaa', 'bbb', 'ccc' })
      feed('oX<Esc>')
      eq({ 'aaa', 'X', 'bbb', 'X', 'ccc', 'X' }, get_lines())
      feed('u')
      eq({ 'aaa', 'bbb', 'ccc' }, get_lines())
      feed('x')
      eq({ 'aa', 'bb', 'cc' }, get_lines())
    end)

    it('one u/CTRL-R reverts a whole macro (@q) cascade', function()
      -- "@x" cascades as ONE unit, so it is one undo block.
      fn.setreg('q', 'iX\027')
      cursors({ 'aaa', 'bbb' }, 'Qj')
      feed('@q')
      eq({ 'Xaaa', 'Xbbb' }, get_lines())
      feed('u')
      eq({ 'aaa', 'bbb' }, get_lines())
      feed('<C-r>')
      eq({ 'Xaaa', 'Xbbb' }, get_lines())
    end)

    it('u undoes a visual-mode cascade at all cursors', function()
      cursors({ 'abc def', 'ghi jkl' }, 'Qj')
      feed('viwd')
      eq({ ' def', ' jkl' }, get_lines())
      feed('u')
      eq({ 'abc def', 'ghi jkl' }, get_lines())
      -- The cursors are back at their pre-edit positions.
      feed('x')
      eq({ 'bc def', 'hi jkl' }, get_lines())
    end)

    it('g-/g+ (time-travel) exits multicursor mode', function()
      -- Out of scope forever (mcursor.md): time-travel jumps across cascade
      -- boundaries, where per-cursor state is meaningless: all cursors are
      -- removed instead.
      cursors({ 'aaa', 'bbb' }, 'Q')
      feed('jx')
      eq({ 'aa', 'bb' }, get_lines())
      eq(1, ncursors())
      feed('g-')
      eq(0, ncursors())
      eq({ 'aaa', 'bbb' }, get_lines()) -- one step back: the whole cascade
      feed('g+')
      eq(0, ncursors()) -- still out of multicursor mode
      eq({ 'aa', 'bb' }, get_lines())
      feed('Q') -- a new session starts cleanly
      eq(1, ncursors())
    end)

    it('u restores the buffer but NOT the registers (Vim parity)', function()
      -- Undo never restores registers.
      cursors({ 'foo x', 'bar y' }, 'Qj0')
      feed('diw') -- each cursor deletes its word into its own register
      eq({ ' x', ' y' }, get_lines())
      feed('u')
      eq({ 'foo x', 'bar y' }, get_lines())
      -- The primary's register still holds its deletion...
      eq('bar', fn.getreg('"'))
      -- ...and the per-cursor values persist too: exiting concatenates them
      -- (yank DWIM) as if the undo never happened.
      clear_cursors()
      eq('foo\nbar\n', fn.getreg('"'))
    end)
  end)

  describe('same-line cursors', function()
    it('two cursors on one line edit at their own columns', function()
      cursors({ 'abcdef' }, 'Q4l')
      feed('x')
      eq({ 'bcdf' }, get_lines())
      feed('x')
      eq({ 'cd' }, get_lines())
    end)

    it('linewise op with two cursors on one line applies once', function()
      pending('policy: dedup linewise ops for same-line cursors (mcursor.md)')
    end)

    it('coincident cursors merge', function()
      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjQ')
      feed('q=')
      feed('G') -- all cursors land on the last line
      feed('q=')
      feed('x') -- one deletion, not three
      eq({ 'aaa', 'bbb', 'cc' }, get_lines())
    end)
  end)

  describe('multibyte', function()
    it('cursor highlight covers a double-width char', function()
      local screen = Screen.new(20, 4)
      cursors({ '日本語', '中文字' }, 'Qj')
      screen:expect([[
        {17:日}本語              |
        ^中文字              |
        {1:~                   }|
                            |
      ]])
    end)
  end)

  describe('terminal multiple-cursors protocol', function()
    local exec_lua = n.exec_lua

    before_each(function()
      -- Stub the UI channel: record emitted sequences instead of sending.
      exec_lua([[
        _G.sent = {}
        vim.api.nvim_ui_send = function(s)
          table.insert(_G.sent, s)
        end
      ]])
    end)

    --- Runs detect() and replies to its support query with the given TermResponse `sequence`.
    local function detect(sequence)
      exec_lua(([[
        require('vim._core.mcursor').detect({ chan = 1 })
        vim.api.nvim_exec_autocmds('TermResponse', {
          data = { sequence = %q, chan = 1 },
        })
      ]]):format(sequence))
    end

    it('enabled only if the terminal reply lists shape 29', function()
      detect('\027[>1;2;3 q') -- no shape 29
      -- The support query was sent, but no cursor updates follow.
      eq({ '\027[> q' }, exec_lua('return _G.sent'))
      feed('Q')
      exec_lua('vim.wait(10)')
      eq({ '\027[> q' }, exec_lua('return _G.sent'))
    end)

    it('displays multicursors as terminal cursors', function()
      local screen = Screen.new(30, 6)
      detect('\027[>1;2;3;29;30;40;100;101 q')

      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjQ')
      exec_lua('vim.wait(10)') -- drain the scheduled refresh
      -- Clear-all, then shape 29 ("follow main cursor") at each position.
      local sent = exec_lua('return _G.sent')
      eq('\027[>0;4 q\027[>29;2:1:1;2:2:1 q', sent[#sent])

      -- The cell-highlight fallback is suppressed (no {17:} on line 1).
      screen:expect([[
        aaa                           |
        ^bbb                           |
        ccc                           |
        {1:~                             }|*2
                                      |
      ]])

      -- Removing all cursors clears the terminal cursors.
      clear_cursors()
      exec_lua('vim.wait(10)')
      sent = exec_lua('return _G.sent')
      eq('\027[>0;4 q', sent[#sent])

      -- tty_cursors(false) restores the cell-highlight fallback.
      feed('Q')
      exec_lua("require('vim._core.mcursor').tty_cursors(false)")
      screen:expect([[
        aaa                           |
        {17:^b}bb                           |
        ccc                           |
        {1:~                             }|*2
                                      |
      ]])
    end)

    it('displays the cursors of every visible window (splits)', function()
      local _ = Screen.new(30, 9)
      detect('\027[>1;2;3;29;30;40;100;101 q')
      fn.setline(1, { 'aaa', 'bbb' })
      feed('gg0Q') -- cursor in buffer 1
      command('split | enew') -- top window: a second buffer
      fn.setline(1, { 'xxx', 'yyy' })
      feed('gg0Q') -- cursor in buffer 2
      exec_lua('vim.wait(10)')
      -- The last sequence draws BOTH cursors: buffer 2's in the focused top
      -- window, and buffer 1's in the (unfocused) bottom window.
      local sent = exec_lua('return _G.sent') ---@type string[]
      local seq = sent[#sent]
      local win1 = fn.win_getid(fn.winnr('j'))
      local pos1 = fn.screenpos(win1, 1, 1)
      t.ok(
        seq:find(('2:%d:%d'):format(pos1.row, pos1.col), 1, true) ~= nil,
        'buf1 cursor drawn',
        seq
      )
      local pos2 = fn.screenpos(0, 1, 1)
      t.ok(
        seq:find(('2:%d:%d'):format(pos2.row, pos2.col), 1, true) ~= nil,
        'buf2 cursor drawn',
        seq
      )
    end)
  end)

  describe('operatorfunc (g@)', function()
    it('VISUAL-mode surround ("S") cascades', function()
      pending('visual ":" LHS-replay: the visual selection differs per cursor; TODO')
      -- Minimal vim-surround "S": VSurround is an Ex command plus a getchar()
      -- payload: `:<C-U>call <SID>opfunc(visualmode(),...)<CR>` + the wrap char.
      n.exec([=[
        function! VisualSurround() abort
          let c = nr2char(getchar())
          let [l1, c1] = getpos("'<")[1:2]
          let [l2, c2] = getpos("'>")[1:2]
          call setpos('.', [0, l2, c2, 0])
          exe "normal! a" . c
          call setpos('.', [0, l1, c1, 0])
          exe "normal! i" . c
        endfunction
        xnoremap <silent> S :<C-U>call VisualSurround()<CR>
      ]=])
      cursors({ 'foo one', 'bar two' }, 'Qj0')
      feed('viwS"')
      -- Each cursor's own word is wrapped (per-cursor extents, like "viwd").
      eq({ '"foo" one', '"bar" two' }, get_lines())
    end)

    it(
      'surround-style plugin cascades, getchar() payload included; one u/CTRL-R reverts',
      function()
        -- The op edits each cursor's region through :normal + register juggling (a full
        -- exec_normal() per cursor).
        n.exec(t_atom.minisurround_vim)
        cursors({ 'alpha beta', 'gamma delta', 'epsilon zeta' }, 'Qj0Qj0')
        atoms_start()
        feed('ysiw"')
        -- The atom is the redobuff plus the getchar()'d payload: the replayed
        -- opfunc reads the same wrap char.
        eq({ 'g@iw"' }, atoms_tail(1))
        eq({ '"alpha" beta', '"gamma" delta', '"epsilon" zeta' }, get_lines())
        -- The whole cascade (primary + replays) is ONE undo step: a single
        -- u/CTRL-R reverts or reapplies it at every cursor.
        feed('u')
        eq({ 'alpha beta', 'gamma delta', 'epsilon zeta' }, get_lines())
        feed('<C-r>')
        eq({ '"alpha" beta', '"gamma" delta', '"epsilon" zeta' }, get_lines())
      end
    )

    it('a no-effect operator (aborted "ysa[") does not cascade; cursors survive', function()
      -- vim-surround "ysa[" whose surround char is <Esc>/CTRL-C: a redoable g@ whose opfunc does
      -- nothing. Its "a[" textobject jumps EVERY cursor to the same "[", so a cascade would
      -- collapse them (dedupe). No edit and no register write = no per-cursor effect: must not
      -- cascade.
      n.exec([[
        function! Noop(type) abort
          call getchar()
        endfunction
        function! NoopSetup() abort
          set operatorfunc=Noop
          return 'g@'
        endfunction
        nnoremap <expr> ,s NoopSetup()
      ]])
      fn.setline(1, { 'aaa', 'bbb', 'ccc', 'x [y] z' }) -- only line 4 has brackets
      feed('gg0Qj0') -- cursor on line 1, primary on line 2 (neither has brackets)
      feed(',sa[z') -- g@ + a[ jumps primary to line 4's "["; opfunc getchar()'s "z", does nothing
      eq(1, ncursors()) -- the cursor survives
    end)

    it('cursors placed inside the opfunc are live for the next typed cascade', function()
      -- Occurrence-operator pattern (vim-mode-plus "co{motion}", issue #21334): the
      -- 'operatorfunc' places a cursor at each occurrence of the word within the motion, then
      -- a following typed edit cascades to all of them. Pins that nvim_mcursor() called from
      -- WITHIN an opfunc yields cursors the next command cascades to (the g@ itself has no
      -- effect, so it does not cascade and the placed cursors survive, like |v_Q| placement).
      n.exec_lua([==[
        _G.occur_opfunc = function()
          local ms = vim.fn.matchbufline('%', _G.occur_pat, vim.fn.line("'["), vim.fn.line("']"))
          vim.api.nvim_win_set_cursor(0, { ms[1].lnum, ms[1].byteidx })
          for i = 2, #ms do
            vim.api.nvim_mcursor(0, { ms[i].lnum, ms[i].byteidx })
          end
        end
        vim.keymap.set('n', 'co', function()
          _G.occur_pat = ([[\<%s\>]]):format(vim.fn.expand('<cword>')) -- before g@ moves the cursor
          vim.o.operatorfunc = 'v:lua.occur_opfunc'
          return 'g@'
        end, { expr = true })
      ]==])
      fn.setline(1, { 'text a text', 'b text c' })
      api.nvim_win_set_cursor(0, { 1, 0 }) -- on the first "text"
      feed('coip') -- place a cursor at every "text" in the paragraph
      eq(2, ncursors()) -- 3 matches: primary + 2 multicursors
      feed('ciwWORD<Esc>') -- a typed edit cascades to the opfunc-placed cursors
      eq({ 'WORD a WORD', 'b WORD c' }, get_lines())
    end)

    it(
      'payload mapping (":call" + getchar, like vim-surround "ds") cascades via LHS-replay',
      function()
        -- A mapping whose edit is done through :normal is invisible to atom
        -- capture (decide-once sees nothing). It cascades by re-running the
        -- mapping (LHS + the getchar()'d target) at each cursor: LHS-replay.
        n.exec(t_atom.delsurround_vim)
        fn.setline(1, { 'a (one)', 'b (two)', 'c (three)' })
        feed('gg0f(Qj0f(Qj0f(')
        atoms_start()
        feed('ds)') -- ")" is the getchar()'d payload
        eq({ 'a one', 'b two', 'c three' }, get_lines())
        -- The emitted atom carries the resolution plus the getchar()'d payload; the cascade
        -- itself re-runs `lhs` (the edit is invisible, so nothing was queued for it).
        local ev = atoms()[#atoms()]
        eq({ lhs = 'ds)', keys = ':call DelSurround()\n)' }, { lhs = ev.lhs, keys = ev.keys })

        -- Same for a mapping that produces NO capturable keys at all (kKeyOpaque):
        -- "<Cmd>" (K_COMMAND) and a Lua callback (K_LUA). Both are real user
        -- keystrokes, so their edit is a mapping edit and cascades by LHS-replay.
        command('nnoremap <F3> <Cmd>normal! x<CR>')
        n.exec_lua([[vim.keymap.set('n', '<F4>', function() vim.cmd('normal! x') end)]])
        for _, lhs in ipairs({ '<F3>', '<F4>' }) do
          clear_cursors()
          fn.setline(1, { 'aaa', 'bbb', 'ccc' })
          feed('gg0QjQj')
          feed(lhs)
          eq({ 'aa', 'bb', 'cc' }, get_lines())
        end

        -- Op-pending payload mapping (vim-sneak :omap) cascades by `keys`.
        n.exec(t_atom.minisneak_vim)
        clear_cursors()
        fn.setline(1, { 'aa (x) here', 'bb (y) here', 'cc (z) here' })
        feed('gg0QjQj')
        feed('dzhe')
        eq({ 'here', 'here', 'here' }, get_lines())

        -- Lua :omap textobject (starts Visual mode, |omap-info|) cascades by `keys` too. #41482
        n.exec_lua([[
          vim.keymap.set('o', 'gt', function()
            vim.cmd('normal! viw')
          end)
        ]])
        clear_cursors()
        fn.setline(1, { 'aaa xxx', 'bbb yyy', 'ccc zzz' })
        feed('gg0wQj0wQj0w')
        feed('dgt')
        eq({ 'aaa ', 'bbb ', 'ccc ' }, get_lines())
      end
    )
  end)

  describe(']C and [C', function()
    local function cur()
      return { fn.line('.'), fn.col('.') - 1 }
    end

    -- The default mappings require the standard startup.
    before_each(function()
      n.clear({ args_rm = { '--cmd' } })
    end)

    it(']C scrolls the viewport to an off-screen cursor', function()
      local screen = Screen.new(30, 6)
      local lines = {} ---@type string[]
      for i = 1, 40 do
        lines[i] = ('line %d'):format(i)
      end
      fn.setline(1, lines)
      feed('gg0Q')
      api.nvim_mcursor(0, { 30, 0 })
      feed(']C') -- jump to line 30: the viewport must follow
      eq(30, fn.line('.'))
      screen:expect({ any = 'ine 30' }) -- ("l" is under the painted cursor cell)
    end)

    it('cycle through the cursors, wrapping', function()
      cursors({ 'aaa', 'bbb', 'ccc', 'ddd' }, 'Q2jllQ')
      feed('gg0j')
      feed(']C')
      eq({ 3, 2 }, cur())
      feed(']C') -- wraps
      eq({ 1, 0 }, cur())
      feed('2]C') -- count
      eq({ 1, 0 }, cur())
      feed('[C')
      eq({ 3, 2 }, cur())
      feed('[C')
      eq({ 1, 0 }, cur())
    end)

    it('does not move the other cursors in q= mode', function()
      cursors({ 'aaa', 'bbb', 'ccc' }, 'Qj')
      feed('q=')
      feed(']C')
      eq({ 1, 0 }, cur())
      eq({ { 0, 0 } }, anchors())
      feed('q=')
    end)

    it('beeps and does not move without cursors', function()
      fn.setline(1, { 'aaa' })
      feed('gg0')
      eq(0, fn.assert_beeps('normal! ]C'))
      eq({ 1, 0 }, cur())
    end)
  end)

  describe('treesitter interaction', function()
    it('markdown highlighting survives a live insert', function()
      n.exec_lua([[
        -- Large, injection-heavy buffer: multi-slice ASYNC parses (the
        -- crash lived in a resumed parse's external scanner).
        local lines = {}
        for i = 1, 800 do
          vim.list_extend(lines, {
            ('# Section %d'):format(i),
            '',
            '- item with `code` and *emphasis*',
            '  - nested [link](http://x)',
            '',
            '```lua',
            'local x = ' .. i,
            '```',
            '',
          })
        end
        vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
        vim.treesitter.start(0, 'markdown')
      ]])
      feed('gg0Q2jQ2jQ4j')
      feed('A')
      for c in ('hello world'):gmatch('.') do
        feed(c)
        n.poke_eventloop()
      end
      feed('<Esc>')
      feed('u')
      feed('<C-r>')
      n.assert_alive()
    end)
  end)

  describe('clipboard', function()
    it("perf: provider syncs once per cascade with 'clipboard'", function()
      n.exec_lua([[
        _G.copies = 0
        _G.content = {}
        vim.g.clipboard = {
          name = 'test',
          copy = {
            ['+'] = function(lines)
              _G.copies = _G.copies + 1
              _G.content = lines
            end,
          },
          paste = {
            ['+'] = function()
              return _G.content
            end,
          },
        }
        vim.o.clipboard = 'unnamedplus'
      ]])
      cursors({ 'aa bb', 'cc dd', 'ee ff' })
      local base = n.exec_lua('return _G.copies')
      feed('dw')
      eq({ 'bb', 'dd', 'ff' }, get_lines())
      -- One provider sync for the primary's own delete, ONE for the whole
      -- cascade (not one per cursor), and the primary's registers win.
      eq(base + 2, n.exec_lua('return _G.copies'))
      eq({ 'ee ' }, n.exec_lua('return _G.content'))
    end)
  end)

  describe('UI integration', function()
    it('cursor positions are pushed to UIs (win_extmark)', function()
      local screen = Screen.new(30, 5)
      cursors({ 'aaa', 'bbb', 'ccc' }, 'QjlQj')
      local ns = api.nvim_create_namespace('nvim.multicursor')
      local marks = api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
      eq(2, #marks)
      screen:expect({
        grid = [[
        {17:a}aa                           |
        b{17:b}b                           |
        c^cc                           |
        {1:~                             }|
                                      |
      ]],
        extmarks = {
          [2] = {
            { 1000, ns, marks[1][1], 0, 0 },
            { 1000, ns, marks[2][1], 1, 1 },
          },
        },
      })
    end)

    it('showcmd area shows the cursor count ("N×")', function()
      local screen = Screen.new(30, 5)
      command('set showcmd') -- the test env defaults to 'noshowcmd'
      cursors({ 'aaa', 'bbb', 'ccc' }, 'Q')
      screen:expect({ any = '1×' })
      feed('jQ')
      screen:expect({ any = '2×' })
      command('silent normal! 1q=') -- Follow mode: "=" prefix (silent to avoid the q= message).
      feed('l') --  Tickle showcmd redraw.
      screen:expect({ any = '=2×' })
      command('silent normal! 2q=')
      feed('h') --  Tickle showcmd redraw.
      clear_cursors() -- cleared with the cursors
      feed('<Esc>') -- the indicator refreshes on the next command
      screen:expect([[
        aaa                           |
        ^bbb                           |
        ccc                           |
        {1:~                             }|
                                      |
      ]])
    end)

    it('showcmd area shows the cursor count ("N×") with ui2', function()
      local screen = Screen.new(30, 5)
      command('set showcmd')
      n.exec_lua([[require('vim._core.ui2').enable({})]])
      cursors({ 'aaa', 'bbb', 'ccc' }, 'Q')
      screen:expect({ any = '1×' })
      feed('jQ')
      screen:expect({ any = '2×' })
      command('silent normal! 1q=') -- Follow mode: "=" prefix (silent to avoid the q= message).
      feed('l') -- Tickle showcmd redraw.
      screen:expect({ any = '=2×' })
    end)
  end)

  describe('workflows', function()
    it('split visual selection into line cursors', function()
      -- {Visual}Q
      fn.setline(1, { 'aaaa', 'bbbb', 'cc', 'dddd' })
      feed('gg0ll')
      feed('V2j')
      feed('Q')
      -- Primary cursor is the top of the range.
      eq({ 1, 2 }, api.nvim_win_get_cursor(0))
      -- One cursor per selected line, at primary cursor's column (on the short line: past EOL).
      feed('iX<Esc>')
      eq({ 'aaXaa', 'bbXbb', 'ccX', 'dddd' }, get_lines())
      -- The mapping enabled follow-motion (q=).
      feed('jx')
      eq({ 'aaXaa', 'bbbb', 'cc', 'ddd' }, get_lines())
    end)

    it('place a cursor at a range of quickfix items: :cdo normal! Q', function()
      fn.setline(1, { 'aaa', 'bbb', 'ccc', 'ddd' })
      fn.setqflist({
        { bufnr = fn.bufnr(''), lnum = 1, col = 1 },
        { bufnr = fn.bufnr(''), lnum = 2, col = 1 },
        { bufnr = fn.bufnr(''), lnum = 4, col = 1 },
      })
      command('cdo normal! Q')
      eq(3, ncursors())
      feed('3G0') -- Move the primary off the last item's cursor (it would double-apply).
      feed('x')
      eq({ 'aa', 'bb', 'cc', 'dd' }, get_lines())
      -- A range addresses quickfix items: cursors on items 2-3 only.
      clear_cursors()
      command('2,3cdo normal! Q')
      eq(2, ncursors())
    end)

    it('CTRL-X/CTRL-A apply at each cursor; g CTRL-A is the counter', function()
      cursors({ 'x = 5', 'y = 5' }, 'Qj')
      feed('<C-x>')
      eq({ 'x = 4', 'y = 4' }, get_lines())
      feed('<C-a>')
      eq({ 'x = 5', 'y = 5' }, get_lines())
      -- g_CTRL-A inserts counter at the cursor positions.
      feed('g<C-a>')
      eq({ 'x = 15', 'y = 25' }, get_lines())
    end)

    it('o with primary cursor BETWEEN the other cursors', function()
      -- The primary's own line-insert shifts the other cursors' extmarks BEFORE the replays.
      fn.setline(1, { 'aaa', 'bbb', 'ccc' })
      api.nvim_mcursor(0, { 1, 0 })
      api.nvim_mcursor(0, { 3, 0 })
      api.nvim_win_set_cursor(0, { 2, 0 })
      feed('oX<Esc>')
      eq({ 'aaa', 'X', 'bbb', 'X', 'ccc', 'X' }, get_lines())
    end)

    it('typeahead behind the cascade-triggering key is not consumed by replays', function()
      -- Batch input: "x" cascades; queued "yy" must survive the replays (save_current_state), then
      -- cascade (per-cursor registers prove the yank ran at both cursors).
      cursors({ 'abc', 'def' }, 'Qj')
      feed('xyy')
      eq({ 'bc', 'ef' }, get_lines())
      feed('p')
      eq({ 'bc', 'bc', 'ef', 'ef' }, get_lines())
    end)

    it('x then p at EOL on lines of different lengths', function()
      -- Jagged EOL: each cursor deletes last char into its own register, then pastes at its own
      -- (shorter) EOL.
      fn.setline(1, { 'abc', 'de' })
      feed('gg$Q')
      feed('j$')
      feed('x')
      eq({ 'ab', 'd' }, get_lines())
      feed('p')
      eq({ 'abc', 'de' }, get_lines())
    end)

    it('fold parity: cascade at a cursor inside a closed fold', function()
      -- Operator on a closed fold applies to the whole fold (|fold-behavior|), so the replayed "x"
      -- deletes the fold's lines.
      fn.setline(1, { 'aaa', 'bbb', 'ccc', 'ddd' })
      feed('3G0Q')
      command('2,4fold')
      eq(2, fn.foldclosed(3))
      feed('gg0')
      feed('x')
      eq({ 'aa' }, get_lines())
    end)

    it('type=excmd CmdAtoms are emit-only, ":s" does not cascade', function()
      -- cmdline payloads are captured but never cascaded: only the primary's ":s" runs.
      cursors({ 'foo', 'foo' }, 'Qj')
      atoms_start()
      feed(':s/o/O/<CR>')
      eq({ 'foo', 'fOo' }, get_lines())
      local ev = atoms()[#atoms()]
      eq('excmd', ev.type)
      eq('s/o/O/', ev.text)
    end)
  end)

  describe('@ (macro replay)', function()
    it('cascades at each cursor', function()
      fn.setline(1, { 'aaa', 'bbb', 'ccc' })
      feed('gg0qqxq') -- record "x"; line 1 becomes "aa"
      feed('jQ')
      feed('j0')
      feed('@q')
      eq({ 'aa', 'bb', 'cc' }, get_lines())
      -- "@@" repeats, still cascading.
      feed('@@')
      eq({ 'aa', 'b', 'c' }, get_lines())
      -- A macro with an insert session cascades too.
      clear_cursors()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'aaa', 'bbb', 'ccc' })
      feed('gg0qwA!<Esc>q') -- record "A!<Esc>"; line 1 becomes "aaa!"
      feed('jQ')
      feed('j0')
      feed('@w')
      eq({ 'aaa!', 'bbb!', 'ccc!' }, get_lines())
      -- A count applies at each cursor.
      clear_cursors()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'aaaa', 'bbbb', 'cccc' })
      feed('gg0')
      feed('jQ')
      feed('j0')
      feed('2@q') -- the "x" macro, twice per cursor
      eq({ 'aaaa', 'bb', 'cc' }, get_lines())
    end)

    it('from a cursorless buffer, cascades in the buffer it enters', function()
      -- Capture starts before the macro runs (buffer unknown). A macro typed where there are no
      -- cursors, cascades in the buffer it navigates into, like a mapping.
      command('set hidden')
      cursors({ 'aaa', 'bbb' }, 'jQk') -- buf1: primary on line 1, cursor on line 2.
      command('vsplit | enew') -- buf2: no cursors.
      fn.setreg('q', k('<C-w>px'))
      feed('@q')
      eq({ 'aa', 'bb' }, get_lines())
    end)
  end)

  describe('CmdAtom', function()
    it('fires for a cascaded operation', function()
      cursors({ 'aaa', 'bbb' }, 'Q')
      atoms_start()
      feed('jx')
      -- Atom shape: see cmdatom_spec. With cursors: no extra atoms from the cascade replays.
      eq({ 'j', 'dl' }, atoms_tail(2))
      -- A yank cascades (per-cursor registers) but does not edit.
      feed('yy')
      eq(false, atoms()[#atoms()].changed)
    end)

    it('non-edit operator (zfap) cascades; fold toggles (za) do not', function()
      fn.setline(1, { 'aa', 'aa', '', 'bb', 'bb', '' })
      feed('4G0Q')
      feed('gg0')
      atoms_start()
      feed('zfap')
      -- With cursors: the cascade adds no atoms. (Atom shape is covered in cmdatom_spec.)
      eq({ 'zfap' }, atoms_tail(1))
      -- The fold operator cascades: each cursor folds its own paragraph.
      eq({ { 1, 3 }, { 4, 6 } }, {
        { fn.foldclosed(1), fn.foldclosedend(1) },
        { fn.foldclosed(4), fn.foldclosedend(4) },
      })
      feed('za')
      eq({ 'za' }, atoms_tail(1))
      -- Fold toggles are view state: emitted, not cascaded.
      eq({ -1, 4 }, { fn.foldclosed(1), fn.foldclosed(4) })
    end)

    it('records q= motions', function()
      cursors({ 'abcd', 'efgh' }, 'Qj')
      atoms_start()
      feed('q=')
      feed('l')
      feed('l')
      feed('q=')
      eq({ 'q=', 'l', 'l', 'q=' }, atoms_tail(4))
      eq('motion', atoms()[#atoms() - 1].type)
    end)
  end)

  describe('programmatic edits', function()
    it('API edits do not cascade; they shift the cursors, which then track', function()
      -- Extmarks are authoritative: the cascade re-queries positions, so an interleaved API edit
      -- just shifts where the replays land.
      cursors({ 'aaa', 'bbb', 'ccc' })
      n.exec_lua("vim.api.nvim_buf_set_lines(0, 0, 0, true, { 'zzz' })")
      eq({ 'zzz', 'aaa', 'bbb', 'ccc' }, get_lines())
      feed('x')
      eq({ 'zzz', 'aa', 'bb', 'cc' }, get_lines())
    end)

    it('TextChanged autocmd editing the buffer does not re-cascade', function()
      fn.setline(1, { 'top', 'aaa', 'bbb' })
      feed('2G0Q')
      feed('j')
      n.exec_lua([[
        _G.fired = 0
        vim.api.nvim_create_autocmd('TextChanged', {
          callback = function()
            _G.fired = _G.fired + 1
            if _G.fired == 1 then
              vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'X' })
            end
          end,
        })
      ]])
      feed('x')
      n.poke_eventloop()
      eq({ 'Xtop', 'aa', 'bb' }, get_lines())
      -- Once for the whole cascade + once for the autocmd's own API edit.
      -- Not once per cursor, and the autocmd edit did not cascade.
      eq(2, n.exec_lua('return _G.fired'))
    end)

    it('replacing the whole buffer via API does not crash the cascade', function()
      cursors({ 'aaa', 'bbb', 'ccc' })
      n.exec_lua("vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'fresh', 'stuff' })")
      -- The cursor lines are gone: both marks collapse to the edit boundary (past the last line),
      -- where they merge/dedupe into one cursor; its replay clamps onto the last line.
      feed('x')
      eq({ 'fresh', 'uff' }, get_lines())
      eq(0, ncursors())
    end)

    it(':normal! never cascades (programmatic input)', function()
      cursors({ 'aaa', 'bbb' }, 'Qj')
      command('normal! x') -- Programmatic, no cascade (primary only).
      eq({ 'aaa', 'bb' }, get_lines())
      feed('x') -- User input, cascades.
      eq({ 'aa', 'b' }, get_lines())
    end)
  end)
end)
