-- Tests for atom capture: the CmdAtom event, and dot-repeat of whole insert sessions.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local t_atom = require('test.functional.editor.atom_testutil')

local describe, it, before_each = t.describe, t.it, t.before_each
local retry = t.retry
local clear = n.clear
local command = n.command
local exec = n.exec
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
local pick = t_atom.pick

describe('dot-repeat', function()
  before_each(clear)

  it('replays insert-mode cursor-moves (the whole session)', function()
    fn.setline(1, { 'one', 'two' })
    feed('iab<Left>c<Esc>')
    eq({ 'acbone', 'two' }, get_lines())
    -- The ". register and undo still restart at the cursor-move, like Vim.
    eq('c', fn.getreg('.'))
    feed('u')
    eq({ 'abone', 'two' }, get_lines())
    feed('<C-r>')
    -- "." re-executes the whole session, cursor-move included.
    feed('j0.')
    eq({ 'acbone', 'acbtwo' }, get_lines())
    -- An absolute jump (<C-Home>) still restarts the capture: "." replays
    -- only the post-jump insert.
    feed('ggAxy<C-Home>z<Esc>')
    eq({ 'zacbonexy', 'acbtwo' }, get_lines())
    eq('z', fn.getreg('.'))
    feed('j0.')
    eq({ 'zacbonexy', 'zacbtwo' }, get_lines())
    -- Vim's repeat-only-the-tail behavior is a mapping away (documented in
    -- vim_diff.txt): i_CTRL-O re-entry restarts the capture.
    command('inoremap <Left> <C-o><Left>')
    feed('ggiab<Left>c<Esc>')
    eq({ 'acbzacbonexy', 'zacbtwo' }, get_lines())
    feed('j0.')
    eq({ 'acbzacbonexy', 'czacbtwo' }, get_lines())
  end)
end)

describe('CmdAtom', function()
  before_each(clear)

  it('a counted mapped motion carries its count in the atom', function()
    command('nnoremap j gj')
    fn.setline(1, { 'a1', 'b2', 'c3', 'd4', 'e5' })
    feed('gg')
    atoms_start()
    feed('3j')
    eq(4, fn.line('.'))
    local ev = atom_last()
    eq(
      { type = 'motion', lhs = 'j', keys = '3gj', count = 3 },
      pick(ev, 'type', 'lhs', 'keys', 'count')
    )
    -- The "," repeat recipe: replaying the KEYS verbatim repeats the count.
    feed('gg')
    n.exec_lua(([[vim.api.nvim_feedkeys(%q, 'nx', false)]]):format(ev.keys))
    eq(4, fn.line('.'))
    -- Multi-command mapping: the pre-typed count lands in the FIRST folded
    -- command; the folded atom itself has no single count.
    command('nnoremap <F6> xw')
    fn.setline(1, { 'abcdef ghi', 'jkl' })
    feed('gg0')
    feed('3<F6>')
    ev = atom_last()
    eq({ type = 'mapping' }, pick(ev, 'type', 'count'))
    eq({ keys = '3dl', count = 3 }, pick(ev.atoms[1], 'keys', 'count'))
  end)

  it('a Lua-callback mapping (the "]q" default) emits a mapping atom', function()
    -- Same shape as the "]q" default mapping: a Lua callback with no
    -- replayable keys. Still a user action: it publishes with an empty
    -- replay payload.
    n.exec_lua([[
      vim.keymap.set('n', ']q', function()
        vim.cmd({ cmd = 'cnext', count = vim.v.count1 })
      end, { desc = ':cnext' })
    ]])
    fn.setline(1, { 'aaa', 'bbb', 'ccc' })
    local bufnr = api.nvim_get_current_buf()
    fn.setqflist({ { bufnr = bufnr, lnum = 1 }, { bufnr = bufnr, lnum = 3 } })
    command('cfirst')
    atoms_start()
    feed(']q')
    eq(3, fn.line('.')) -- the mapping did run (:cnext)
    eq(
      { type = 'mapping', lhs = ']q', keys = '', changed = false },
      pick(atom_last(), 'type', 'lhs', 'keys', 'changed')
    )
    -- An empty-keys mapping that DOES edit still reports it: `changed` is
    -- the only informative payload of a Lua-callback edit.
    n.exec_lua([[
      vim.keymap.set('n', ',e', function()
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { 'NEW' })
      end)
    ]])
    feed(',e')
    eq({ keys = '', changed = true }, pick(atom_last(), 'keys', 'changed'))

    -- "<Cmd>" is opaque too, but unlike a Lua callback its command is text (like a ":" mapping).
    command('nnoremap ,c <Cmd>call setline(1, "N" . v:count)<CR>')
    feed('3,c')
    local cmdev = atom_last()
    eq({
      type = 'ex',
      lhs = ',c',
      keys = k('3<Cmd>call setline(1, "N" . v:count)<NL>'),
      text = 'call setline(1, "N" . v:count)',
      count = 3,
      changed = true,
    }, pick(cmdev, 'type', 'lhs', 'keys', 'text', 'count', 'changed'))
    -- Those keys replay: the count must survive, since "<Cmd>" reads v:count.
    eq('N3', fn.getline(1))
    fn.setline(1, 'reset')
    n.exec_lua(([[vim.api.nvim_feedkeys(%q, 'nx', false)]]):format(cmdev.keys))
    eq('N3', fn.getline(1))

    -- Opaque key that changes nothing is invisible: mid-selection it must not void the pending
    -- visual atom, which would void its per-cursor extents.
    command('vnoremap ,n <Cmd>call execute("")<CR>')
    fn.setline(1, { 'aaa bbb' })
    feed('gg0viw,nd')
    eq(' bbb', fn.getline(1))
    eq({ type = 'visual', keys = 'viwd' }, pick(atom_last(), 'type', 'keys'))
  end)

  it('motions, search, Ex emit without an edit', function()
    -- Emission is not tied to editing: every user action publishes, so
    -- plugins can observe all activity.
    fn.setline(1, { 'alpha beta', 'gamma delta' })
    feed('gg0')
    atoms_start()
    feed('w')
    feed('3l')
    feed('/gamma<CR>')
    feed(':nohlsearch<CR>')
    eq({
      { type = 'motion', keys = 'w' },
      { type = 'motion', keys = '3l' },
      { type = 'motion', keys = k('/gamma<NL>') },
      { type = 'ex', keys = k(':nohlsearch<NL>') },
    }, atoms_tail(4, 'type', 'keys'))
    -- ":" embeds its count as the range prefill, never as composed digits;
    -- the count field carries it.
    feed('gg')
    feed('2:<CR>')
    eq(2, fn.line('.'))
    eq(
      { type = 'ex', keys = k(':.,.+1<NL>'), count = 2, cmd = ':' },
      pick(atom_last(), 'type', 'keys', 'count', 'cmd')
    )
    eq({ 'alpha beta', 'gamma delta' }, get_lines()) -- nothing was edited
    -- Scrolls and mouse presses also emit (type "scroll"/"mouse"): emit-only,
    -- never cascaded.
    feed('<C-e>')
    feed('3<C-y>')
    api.nvim_input_mouse('wheel', 'up', '', 0, 0, 0)
    api.nvim_input_mouse('left', 'press', '', 0, 1, 2)
    eq({
      { type = 'scroll', keys = k('<C-E>'), cascade = false },
      { type = 'scroll', keys = k('3<C-Y>'), cascade = false },
      { type = 'scroll', keys = k('<ScrollWheelUp>'), cascade = false },
      { type = 'mouse', keys = k('<LeftMouse>'), cascade = false },
    }, atoms_tail(4, 'type', 'keys', 'cascade'))
    eq(2, fn.line('.')) -- the click moved the cursor
    -- <amatch>/match is the atom type, never path-expanded.
    n.exec_lua([[
      vim.api.nvim_create_autocmd('CmdAtom', {
        callback = function(ev)
          _G.last_match = ev.match
        end,
      })
    ]])
    feed('0w')
    n.poke_eventloop()
    eq('motion', n.exec_lua('return _G.last_match'))
  end)

  it('captures counts and payload chars', function()
    fn.setline(1, { 'abcd,ef' })
    feed('gg0')
    atoms_start()
    feed('yw')
    -- A yank emits but does not edit.
    eq({ operator = 'y', changed = false }, pick(atom_last(), 'operator', 'changed'))
    feed('3x')
    eq({ 'd,ef' }, get_lines())
    feed('vf,d')
    eq({ 'ef' }, get_lines())
    eq({ '3dl', 'vf,d' }, atoms_tail(2))
    eq(3, atoms()[#atoms() - 1].count)
    -- Structured decomposition: operator/motion/operand as fields, no byte-parsing.
    local op = atoms()[#atoms() - 1] -- "3dl"
    eq(
      { operator = 'd', cmd = 'l', changed = true },
      pick(op, 'operator', 'cmd', 'arg', 'motionforce', 'changed')
    )
    -- A visual atom carries the completing operator's fields, and decomposes
    -- into its commands ("v", "f," and the operator).
    local vis = atom_last() -- "vf,d"
    eq({ type = 'visual', operator = 'd' }, pick(vis, 'type', 'operator'))
    eq(
      {
        { keys = 'v', cmd = 'v', changed = false },
        { keys = 'f,', cmd = 'f', arg = ',', changed = false },
        { keys = 'd', changed = true }, -- the completing operator did the edit
      },
      vim.tbl_map(function(c)
        return pick(c, 'keys', 'cmd', 'arg', 'changed')
      end, vis.atoms)
    )
    eq('d', vis.atoms[3].operator)
    -- Operators with an interactively-typed search payload: the atom is the
    -- redobuff, which includes the payload.
    fn.setline(1, { 'aa END bb' })
    feed('gg0')
    feed('d/END<CR>')
    eq({ 'END bb' }, get_lines())
    eq({ k('d/END<NL>') }, atoms_tail(1))
    eq(
      { operator = 'd', cmd = '/', changed = true },
      pick(atom_last(), 'operator', 'cmd', 'changed')
    )
    -- An operand (mark or register name, target char) is its own field; the second char of a
    -- two-char command NAME ("gJ") composes into `cmd`.
    fn.setline(1, { 'one', 'two' })
    feed('gg0magJ')
    eq({ 'onetwo' }, get_lines()) -- "gJ": join without inserting a space
    eq({ cmd = 'm', arg = 'a' }, pick(atoms()[#atoms() - 1], 'cmd', 'arg'))
    eq({ cmd = 'gJ' }, pick(atom_last(), 'cmd', 'arg'))
    local nrec = #atoms()
    feed('qax') -- the recording register is an operand, not part of the name
    feed('q')
    eq({ cmd = 'q', arg = 'a' }, pick(atoms()[nrec + 1], 'cmd', 'arg'))
    -- Forced motion type ("dvj") is a field.
    fn.setline(1, { 'one', 'two' })
    feed('gg0dvj')
    eq(
      { operator = 'd', motionforce = 'v', cmd = 'j' },
      pick(atom_last(), 'operator', 'motionforce', 'cmd')
    )
  end)

  it('fires for user input, not programmatic sources', function()
    atoms_start()
    -- Drain deferred CmdAtom events, then return + clear the collected list.
    local function take()
      n.poke_eventloop()
      return n.exec_lua([[local a = _G.atoms; _G.atoms = {}; return a]])
    end
    -- Fresh buffer + cursor via the API (no keys, so no motion atoms).
    local function fresh()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'aaaaaaaa', 'bbbbbbbb' })
      api.nvim_win_set_cursor(0, { 1, 0 })
      take()
    end

    -- Typed input emits: real keys (nvim_input, via feed())...
    fresh()
    feed('x')
    eq(1, #take())
    -- ...and nvim_feedkeys() with the "t" (typed) flag.
    n.exec_lua([[vim.api.nvim_feedkeys('x', 't', false)]])
    eq(1, #take())

    -- A typed macro folds into exactly ONE atom, labeled "@q".
    fresh()
    feed('qqxq') -- recording is typed input
    take()
    feed('@q')
    local evs = take()
    eq(1, #evs)
    eq('@q', evs[1].lhs)
    -- Same for "Q" (replay the last recorded register).
    feed('Q')
    evs = take()
    eq(1, #evs)
    eq({ lhs = '@q', keys = 'dl' }, pick(evs[1], 'lhs', 'keys'))

    -- Programmatic / replayed input must NOT leak any atom.
    fresh()
    api.nvim_buf_set_lines(0, 0, 1, true, { 'ZZZZ' }) -- API buffer edit
    eq(0, #take())
    api.nvim_buf_set_text(0, 0, 0, 0, 1, { 'Q' })
    eq(0, #take())
    command('normal! x') -- :normal!
    eq(0, #take())
    command('normal x') -- :normal (with mappings)
    eq(0, #take())
    n.exec_lua([[vim.cmd('normal! x')]])
    eq(0, #take())
    n.exec_lua([[vim.api.nvim_feedkeys('x', '', false)]]) -- feedkeys without "t"
    eq(0, #take())
    command('normal! @q') -- macro played programmatically, not typed
    eq(0, #take())
    n.exec_lua([[vim.api.nvim_feedkeys('@q', '', false)]])
    eq(0, #take())
    command('normal! yy') -- prep-exempt operator (a yank builds no redo)
    eq(0, #take())
    n.exec_lua([[vim.api.nvim_feedkeys('viwd', '', false)]]) -- Visual sequence
    eq(0, #take())

    -- A timer/scheduled API edit must NOT leak.
    n.exec_lua([[
      _G.done = false
      vim.defer_fn(function()
        vim.api.nvim_buf_set_lines(0, 0, 1, true, { 'TTTT' })
        _G.done = true
      end, 5)
    ]])
    n.exec_lua('vim.wait(200, function() return _G.done end)')
    eq(0, #take())

    -- Sanity: typed input still emits after all the programmatic noise.
    fresh()
    feed('x')
    eq(1, #take())
  end)

  it('visual atom replay; fallback to equal-size if unreplayable', function()
    -- The core use-case for a plugin: observe CmdAtom, capture a Visual-mode
    -- operation's resolved `keys`, and replay them verbatim to re-execute it.
    fn.setline(1, { 'foo bar', 'longword bar' })
    feed('gg0')
    atoms_start()
    feed('viwd') -- select the inner word and delete it
    eq({ ' bar', 'longword bar' }, get_lines())
    local ev = atom_last()
    eq('visual', ev.type)

    -- Replay the captured keys at line 2. The keysequence RE-EXECUTES (not an equal-size reselect):
    -- "iw" selects THAT line's word (the longer one), so the delete adapts to the new context.
    feed('j0')
    n.exec_lua(([[vim.api.nvim_feedkeys(%q, 'nx', false)]]):format(ev.keys))
    eq({ ' bar', ' bar' }, get_lines())

    -- Builtin "." replays the same keysequence, not Vim's equal-size reselect.
    api.nvim_buf_set_lines(0, 0, -1, true, { 'foo bar', 'longword bar' })
    feed('gg0viwd')
    eq({ ' bar', 'longword bar' }, get_lines())
    feed('j0.')
    eq({ ' bar', ' bar' }, get_lines())

    -- A viewport scroll that drags the cursor along (edge/'scrolloff') grows
    -- the selection by a viewport-dependent amount: void, no atom.
    local lines = {}
    for i = 1, 30 do
      lines[i] = 'l' .. i
    end
    fn.setline(1, lines)
    feed('gg')
    local before = #atoms()
    feed('V<C-e>')
    n.poke_eventloop()
    eq(2, fn.line('.')) -- the scroll dragged the cursor: selection is lines 1-2
    feed('d')
    eq(before, #atoms()) -- not replayable: no atom published for the edit
    eq('l3', fn.getline(1)) -- the edit itself deleted both selected lines

    -- "." on the unreplayable operation falls back to an equal-size reselect
    -- ("1v" + operator): it deletes the same number of lines at the cursor.
    feed('.')
    eq('l5', fn.getline(1))

    -- A fed (":normal!") Visual-put preps the selection keysequence, like any fed visual
    -- operator (":normal! vjd"): "." re-executes "Vjp", not a bare "p".
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aa', 'bb', 'cc', 'dd', 'ee' })
    feed('ggyy')
    command('normal! Vjp')
    eq({ 'aa', 'cc', 'dd', 'ee' }, get_lines())
    feed('j.')
    eq({ 'aa', 'aa', 'bb', 'ee' }, get_lines())

    -- {Visual}r<C-V><CR> replaces with a literal <CR> (REPLACE_CR_NCHAR): inexpressible as
    -- spec chars, so the literal keys compose the redo tail, which "." replays.
    api.nvim_buf_set_lines(0, 0, -1, true, { 'abcd', 'efgh' })
    feed('gg0vlr<C-V><CR>')
    eq({ '\r\rcd', 'efgh' }, get_lines())
    feed('j0.')
    eq({ '\r\rcd', '\r\rgh' }, get_lines())

    -- <Cmd> ":norm" mapping that extends the selection: "." replays it. #41323
    command('xmap <M-m> <Cmd>normal! $<CR>')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaa', 'bbb' })
    feed('gg0v<M-m>d') -- "$" in Visual is one past EOL, so "d" swallows the newline (= plain v$d)
    eq({ 'bbb' }, get_lines())
    command('let v:errmsg = ""')
    feed('.')
    eq('', api.nvim_get_vvar('errmsg'))
    eq('n', fn.mode()) -- Not in Visual.
    eq({ '' }, get_lines())

    -- <Cmd> ":norm" captured as nested subatoms: the atom is "ved", not the <Cmd>.
    command('xmap <M-w> <Cmd>normal! e<CR>')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'one two three', 'four five six' })
    feed('gg0v<M-w>d')
    eq({ ' two three', 'four five six' }, get_lines())
    eq({ type = 'visual', keys = 'ved' }, pick(atom_last(), 'type', 'keys'))
    feed('j0.')
    eq({ ' two three', ' five six' }, get_lines())

    -- Buffer-editing <Cmd> is unreplayable (void), so "." fallsback to equal-size reselect.
    command('xmap <M-a> <Cmd>call append(1, "X")<CR>')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'ab', 'cd' })
    feed('gg0vl<M-a>d')
    eq({ '', 'X', 'cd' }, get_lines())
    feed('3gg0.')
    eq({ '', 'X', '' }, get_lines())

    -- A search-extended selection re-executes: the payload travels in the collected keys.
    api.nvim_buf_set_lines(0, 0, -1, true, { 'ab META x', 'cdef META y' })
    feed('gg0v/META<CR>d')
    eq({ 'ETA x', 'cdef META y' }, get_lines())
    eq({ type = 'visual', keys = k('v/META<NL>d') }, pick(atom_last(), 'type', 'keys'))
    feed('j0.')
    eq({ 'ETA x', 'ETA y' }, get_lines())
  end)

  it('a mapping can repeat the last visual atom', function()
    -- User-defined Visual dot-repeat: capture a visual atom's resolved
    -- `keys`, replay them verbatim from a mapping to RE-EXECUTE the
    -- operation (not an equal-size reselect like builtin |.|).
    n.exec_lua([[
      vim.api.nvim_create_autocmd('CmdAtom', {
        pattern = 'visual',
        callback = function(ev)
          _G.last_visual = ev.data.keys
        end,
      })
      vim.keymap.set('n', ',', function()
        -- Scheduled: runs after any pending CmdAtom event (fresh
        -- `last_visual`), and emits no CmdAtom itself. See |CmdAtom|.
        vim.schedule(function()
          if _G.last_visual then
            vim.api.nvim_feedkeys(_G.last_visual, 'n', false)
          end
        end)
      end)
    ]])
    --- Count of captured visual atoms.
    local function nvisual()
      local count = 0
      for _, a in ipairs(atoms()) do
        if a.type == 'visual' then
          count = count + 1
        end
      end
      return count
    end
    fn.setline(1, { 'foo bar', 'longword bar' })
    feed('gg0')
    atoms_start()
    feed('viwd')
    eq({ ' bar', 'longword bar' }, get_lines())
    eq('visual', atom_last().type)
    -- "iw" re-executes: it selects THAT line's (longer) word.
    feed('j0,')
    retry(nil, 1000, function()
      eq({ ' bar', ' bar' }, get_lines())
    end)
    -- The scheduled replay is programmatic input: it emits no visual atom itself.
    eq(1, nvisual())
    -- A Visual change (insert session): the atom embeds the selection, the
    -- operator, the inserted text, and <Esc>; the repeat re-executes it all.
    api.nvim_buf_set_lines(0, 0, -1, true, { 'foo bar', 'longword bar' })
    feed('gg0viwcX<Esc>')
    eq({ 'X bar', 'longword bar' }, get_lines())
    feed('j0,')
    retry(nil, 1000, function()
      eq({ 'X bar', 'X bar' }, get_lines())
    end)
    eq(2, nvisual())
  end)

  it('a mapping can restore equal-size visual dot-repeat', function()
    -- Keep in sync with the example in runtime/doc/repeat.txt.
    n.exec_lua([[
      local vop ---@type string?
      vim.api.nvim_create_autocmd('CmdAtom', {
        callback = function(ev)
          if ev.data.type == 'visual' then
            local children = ev.data.atoms
            vop = children and children[#children].keys or nil
          elseif ev.data.changed then
            vop = nil  -- the last change is no longer the Visual one
          end
        end,
      })
      vim.keymap.set('n', '.', function()
        vim.schedule(function()
          vim.api.nvim_feedkeys(vop and ('1v' .. vop) or '.', 'n', false)
        end)
      end)
    ]])
    fn.setline(1, { 'foo bar', 'longword bar' })
    feed('gg0viwd')
    eq({ ' bar', 'longword bar' }, get_lines())
    -- Equal-size repeat: a 3-char region at the cursor, NOT that line's word.
    feed('j0.')
    retry(nil, 1000, function()
      eq({ ' bar', 'gword bar' }, get_lines())
    end)
    -- A non-visual change falls back to the builtin |.|.
    feed('gg0x')
    eq({ 'bar', 'gword bar' }, get_lines())
    feed('j0.')
    retry(nil, 1000, function()
      eq({ 'bar', 'word bar' }, get_lines())
    end)
  end)

  it('one event per operation, for each kind of atom', function()
    n.clear({ args = { '--clean' }, args_rm = { '--cmd' } })
    --- Feeds `keys`, asserts exactly ONE new event, with the given keys.
    local function atom(keys, expected)
      local before = #atoms()
      feed(keys)
      local evs = atoms()
      eq({ before + 1, k(expected) }, { #evs, evs[#evs].keys })
    end
    local lines = {}
    for i = 1, 20 do
      lines[i] = 'alpha beta gamma delta epsilon zeta'
    end
    fn.setline(1, lines)
    feed('gg0')
    atoms_start()
    -- Operators: the atom is the redobuff (count/register included).
    -- "x" is normalized ("translated") to the elemental command "dl".
    atom('x', 'dl')
    atom('3x', '3dl')
    atom('dw', 'dw')
    atom('"z2dw', '"z2dw')
    atom('yy', 'yy')
    atom('p', 'p')
    atom('J', '2J')
    atom('3J', '3J')
    atom('r?', '1r?')
    atom('~', '~')
    atom('guiw', 'guiw')
    atom('gUiw', 'gUiw')
    atom('>>', '>>')
    atom('dfa', 'dfa')
    feed('ddk')
    atom('P', 'P')
    -- Insert sessions: one whole-session atom (entry + text + <Esc>).
    atom('iXY<Esc>', '1iXY<Esc>')
    atom('A!<Esc>', '1A!<Esc>')
    atom('oNEW<Esc>', '1oNEW<Esc>')
    atom('3iZ<Esc>', '3iZ<Esc>')
    atom('cwWORD<Esc>', 'cwWORD<Esc>')
    -- Visual: the full typed keysequence.
    atom('viwd', 'viwd')
    atom('Vd', 'Vd')
    atom('<C-v>jd', '<C-V>jd')
    -- Motions.
    atom('w', 'w')
    atom('3w', '3w')
    atom('fb', 'fb')
    atom('G', 'G')
    atom('$', '$')
    feed('gg0')
    atom(']]', ']]')
    -- Jumps: absolute/shared-state navigation, their own kind.
    atom('ma', 'ma')
    eq('command', atom_last().type) -- "m" sets state; it does not jump
    atom('`a', '`a')
    eq('jump', atom_last().type)
    atom('<C-o>', '<C-O>')
    eq('jump', atom_last().type)
    -- Non-redoable commands: still emitted, as type "command".
    atom('zz', 'zz')
    eq('command', atom_last().type)
    atom('u', 'u')
    atom('<C-r>', '<C-R>')
    -- "." emits its resolution (like "x" => "dl").
    feed('gg0')
    atom('x', 'dl')
    atom('.', 'dl')
    atom('3.', '3dl') -- "3.": the new count replaces the captured one
    -- Payload commands: the interactively-typed cmdline completes the
    -- keysequence (not a bare "/" or ":" prefix).
    atom('/beta<CR>', '/beta<NL>')
    eq({ type = 'motion', text = 'beta' }, pick(atom_last(), 'type', 'text'))
    atom('?alpha<CR>', '?alpha<NL>')
    atom('2/beta<CR>', '2/beta<NL>')
    -- Ex commands: their own atom kind, the cmdline is the "text" payload.
    atom(':set tw=42<CR>', ':set<Space>tw=42<NL>')
    eq({ type = 'ex', text = 'set tw=42' }, pick(atom_last(), 'type', 'text'))
    -- A nested cmdline opened by the command's own execution (":normal")
    -- does not hijack the payload.
    atom(':exe "normal! :echo 1\\r"<CR>', ':exe<Space>"normal!<Space>:echo<Space>1<Bslash>r"<NL>')
    -- A mapping is ALWAYS an atom, even when its commands capture no
    -- replayable keys ("]q" = :cnext): the event has empty keys.
    fn.setqflist({ { text = 'one' }, { text = 'two' } })
    feed(']q')
    eq(
      { type = 'mapping', lhs = ']q', keys = '' },
      pick(atom_last(), 'type', 'lhs', 'keys', 'pending')
    )
    -- A mapping that ends mid-operation says what it awaits.
    command('nnoremap ,D d')
    command('nnoremap ,V v')
    feed(',D')
    eq({ lhs = ',D', pending = 'operator' }, pick(atom_last(), 'lhs', 'pending'))
    atom('w', 'dw') -- the supplied motion completes the operation
    feed(',V')
    eq({ lhs = ',V', pending = 'visual' }, pick(atom_last(), 'lhs', 'pending'))
    feed('<Esc>')
    -- An ABORTED mapping emits nothing: an error discards its remaining
    -- keys, and the composite with them.
    command('nnoremap ,E :NoSuchCmd<CR>x')
    local count = #atoms()
    feed(',E') -- E492 mid-mapping: the trailing "x" never runs
    eq(count, #atoms())
    atom('x', 'dl') -- the next command is not folded into the dead composite
    eq(nil, atom_last().lhs) -- not from a mapping: omitted
    command('nmap ,A ,B')
    command('nmap ,B ,A')
    feed(',A') -- E223: recursive mapping
    atom('x', 'dl')
    eq(nil, atom_last().lhs) -- not from a mapping: omitted
    -- Macro playback ("@q") emits its commands' atoms (capture-on-replay);
    -- "@q" itself is a translation, never an atom.
    local total = #atoms()
    feed('qqxq')
    feed('@q')
    eq(total + 4, #atoms())
    eq({ 'qq', 'dl', 'q', 'dl' }, atoms_tail(4))
    -- The macro's atoms fold into one "@x"-labeled composite, like a mapping.
    eq('@q', atom_last().lhs)
    -- A typed scroll emits its own (emit-only) atom kind.
    feed('<C-d>')
    eq(total + 5, #atoms())
    eq({ type = 'scroll', keys = k('<C-D>') }, pick(atom_last(), 'type', 'keys'))
    -- An 'indentexpr' that runs ":normal" opens a nested command-frame mid-operator: "gq" still
    -- pushes its own atom, after the edit.
    exec([[
      func Indent()
        exe "normal! \<Ignore>"
        return 0
      endfunc
      setlocal indentexpr=Indent() textwidth=20
    ]])
    atom('Vgq', 'Vgq')
    eq(true, atom_last().changed)
  end)

  it('captures non-edit operators (zfap) and fold/view commands', function()
    fn.setline(1, { 'aa', 'aa', '' })
    feed('gg0')
    atoms_start()
    feed('zfap')
    eq({ 'zfap' }, atoms_tail(1))
    eq('operator', atom_last().type)
    eq(1, fn.foldclosed(1))
    feed('za')
    eq({ 'za' }, atoms_tail(1))
    -- Neither an operator nor a motion: its own kind.
    eq('command', atom_last().type)
    eq(-1, fn.foldclosed(1))
  end)

  it('a single-command mapping keeps its own type and structure', function()
    command('nnoremap ,d dw')
    fn.setline(1, { 'one two aa bb cc dd' })
    feed('gg0')
    atoms_start()
    feed(',d')
    eq({ 'two aa bb cc dd' }, get_lines())
    -- The event's structured fields mirror what is encoded in "keys"; a
    -- mapping labels its atom with the typed LHS (a single-command
    -- mapping: one event, keeping the command's own type and structure).
    local evs = atoms()
    eq(1, #evs)
    -- Inapplicable fields (count/reg/arg/motionforce/text/pending/atoms here) are omitted.
    eq({
      type = 'operator',
      keys = 'dw',
      operator = 'd',
      cmd = 'w',
      changed = true,
      cascade = true, -- the edit is cascadable
      lhs = ',d',
    }, evs[#evs])
    -- Count and register are captured; one event per occurrence.
    feed('"z2dw')
    feed('"z2dw')
    evs = atoms()
    eq({ keys = '"z2dw', count = 2, reg = 'z' }, pick(evs[#evs], 'keys', 'count', 'reg'))
    eq(evs[#evs - 1], evs[#evs])
  end)

  it('a mapping with edits and motions folds into one atom', function()
    -- Split the line at the cursor, ending at the EOL of the first half.
    command('nnoremap gj i<c-j><esc>k$')
    fn.setline(1, { 'aaa bbb' })
    feed('gg04l')
    atoms_start()
    feed('gj')
    eq({ 'aaa ', 'bbb' }, get_lines())
    -- The mapping IS the atom: its commands (the insert session, k, $)
    -- accumulate and fold into exactly ONE event, labeled with the typed
    -- LHS; the resolved keys remain the (replayable) payload. The
    -- mapping is never re-resolved.
    local evs = atoms()
    eq(1, #evs)
    eq(
      { type = 'mapping', lhs = 'gj', keys = k('1i<NL><Esc>k$'), changed = true },
      pick(evs[1], 'type', 'lhs', 'keys', 'changed')
    )
    -- The folded commands stay exposed, each with its own structure.
    eq(
      {
        { type = 'insert', keys = k('1i<NL><Esc>') },
        { type = 'motion', keys = 'k' },
        { type = 'motion', keys = '$' },
      },
      vim.tbl_map(function(c)
        return pick(c, 'type', 'keys')
      end, evs[1].atoms)
    )
    eq({ 'k', false }, { evs[1].atoms[2].cmd, evs[1].atoms[2].changed })
    -- A scroll inside a mapping is NOT a subatom: the composite's keys must
    -- stay replayable, so the scroll is elided.
    fn.setline(1, { 'l1', 'l2', 'l3', 'l4', 'l5', 'l6' })
    feed('3G')
    command('nnoremap gk <C-e>j$')
    feed('gk')
    eq(4, fn.line('.'))
    eq({ type = 'mapping', lhs = 'gk', keys = 'j$' }, pick(atom_last(), 'type', 'lhs', 'keys'))
    -- A recursive mapping (:nmap gJ gj) does not nest: the inner mapping's commands flatten
    -- into ONE composite labeled with the typed LHS, with the same resolved keys.
    command('nmap gJ gj')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaa bbb' })
    feed('gg04l')
    local before = #atoms()
    feed('gJ')
    eq({ 'aaa ', 'bbb' }, get_lines())
    evs = atoms()
    eq(before + 1, #evs)
    eq(
      { type = 'mapping', lhs = 'gJ', keys = k('1i<NL><Esc>k$') },
      pick(evs[#evs], 'type', 'lhs', 'keys')
    )
  end)

  it('an insert session atom captures its text', function()
    fn.setline(1, { 'aaa' })
    feed('gg0')
    atoms_start()
    -- No event for the bare "i" command, and none per keystroke: ONE
    -- whole-session event at <Esc>.
    feed('i')
    eq(0, #atoms())
    feed('X')
    eq(0, #atoms())
    feed('Y')
    eq(0, #atoms())
    feed('<Esc>')
    local evs = atoms()
    eq(1, #evs)
    -- `count` mirrors what the keys encode: insert keys always embed the count
    -- ("1i…"), so it is 1 even untyped. "dw" omits its count.
    eq(
      { type = 'insert', count = 1, text = 'XY', keys = k('1iXY<Esc>') },
      pick(evs[1], 'type', 'count', 'text', 'keys')
    )
    -- Counted insert: entry cmd + text + <Esc> keys, with count and the
    -- session's inserted text as fields.
    feed('3iZ<Esc>')
    eq({ type = 'insert', count = 3, text = 'Z' }, pick(atom_last(), 'type', 'count', 'text'))
  end)

  it("operatorfunc atom includes the getchar()'d payload", function()
    n.exec(t_atom.minisurround_vim)
    fn.setline(1, { 'alpha beta' })
    feed('gg0')
    atoms_start()
    feed('ysiw"')
    -- The atom is the redobuff plus the getchar()'d payload: a replayed
    -- opfunc reads the same wrap char.
    eq({ 'g@iw"' }, atoms_tail(1))
    eq({ '"alpha" beta' }, get_lines())
  end)

  it('a ":call" payload mapping publishes its resolved RHS', function()
    -- The atom published to CmdAtom carries the RESOLVED RHS (the ":call" line).
    n.exec(t_atom.delsurround_vim)
    fn.setline(1, { 'a (one)' })
    feed('gg0f(')
    atoms_start()
    feed('ds)') -- ")" is the getchar()'d payload
    eq({ 'a one' }, get_lines())
    local ev = atoms()[#atoms()]
    eq('ds', ev.lhs)
    t.matches(':call DelSurround%(%)', ev.keys)
  end)

  it('"," repeats the last motion atom', function()
    -- Keep in sync with the example in runtime/doc/repeat.txt.
    n.exec_lua([[
      local last ---@type string?
      vim.api.nvim_create_autocmd('CmdAtom', {
        pattern = 'motion',
        callback = function(ev)
          last = ev.data.keys
        end,
      })
      vim.keymap.set('n', ',', function()
        -- CmdAtom delivery is deferred: schedule the replay AFTER any pending
        -- event, so `last` is fresh even when "," immediately follows a
        -- motion. A scheduled replay is programmatic input: it emits no
        -- CmdAtom itself (no feedback loop).
        vim.schedule(function()
          if last then
            vim.api.nvim_feedkeys(last, 'n', false)  -- "n": already resolved
          end
        end)
      end)
    ]])
    local screen = Screen.new(30, 3)
    fn.setline(1, { 'aa bb cc dd ee' })
    feed('gg0')
    feed('2w') -- last motion: "2w" (count included)
    n.poke_eventloop() -- deliver the deferred CmdAtom before ","
    screen:expect([[
      aa bb ^cc dd ee                |
      {1:~                             }|
                                    |
    ]])
    feed(',') -- repeated: "2w" again
    screen:expect([[
      aa bb cc dd ^ee                |
      {1:~                             }|
                                    |
    ]])
    feed('0fb') -- last motion: "fb" (payload char included)
    n.poke_eventloop()
    screen:expect([[
      aa ^bb cc dd ee                |
      {1:~                             }|
                                    |
    ]])
    feed(',') -- repeated "fb": the second "b"
    screen:expect([[
      aa b^b cc dd ee                |
      {1:~                             }|
                                    |
    ]])
  end)

  it('activates a temporary mapping ("submode"), expired by the next unrelated atom', function()
    -- Keep in sync with the example in runtime/doc/repeat.txt.
    n.exec_lua([==[
      local active = false
      vim.api.nvim_create_autocmd('CmdAtom', {
        callback = function(ev)
          -- `cmd` is a key-notation name (unlike `keys`, which is raw bytes).
          local resize = ev.data.cmd == '<C-W>+' or ev.data.cmd == '<C-W>-'
          if resize then
            -- Activate. Use of "+"/"-" resolves to the same cmd => re-activates.
            vim.keymap.set('n', '+', '<C-w>+')
            vim.keymap.set('n', '-', '<C-w>-')
            active = true
          elseif active then
            vim.keymap.del('n', '+')
            vim.keymap.del('n', '-')
            active = false
          end
        end,
      })
      -- Also works if <c-w>+ was mapped to something else:
      vim.cmd[[nnoremap <leader>+ <c-w>+]]
    ]==])
    --- Waits for the deferred CmdAtom to (de)activate the temporary mappings.
    local function wait_active(active)
      eq(
        true,
        n.exec_lua(
          [[
            local active = ...
            return vim.wait(1000, function()
              return (vim.fn.maparg('+', 'n') ~= '') == active
            end)
          ]],
          active
        )
      )
    end
    fn.setline(1, { 'one', 'two' })
    command('split')
    local height = fn.winheight(0)
    feed('<C-w>+')
    wait_active(true) -- the deferred CmdAtom activated the mappings
    eq(height + 1, fn.winheight(0))
    feed('+') -- temporary mapping: resizes without the CTRL-W prefix
    n.poke_eventloop()
    eq(height + 2, fn.winheight(0))
    feed('-') -- its own use emits the same resolved keys: stays active
    n.poke_eventloop()
    eq(height + 1, fn.winheight(0))
    feed('j') -- any unrelated atom expires the mappings
    wait_active(false)
    feed('-') -- back to the builtin: a motion (up one line), not a resize
    n.poke_eventloop()
    eq(height + 1, fn.winheight(0))
    eq(1, fn.line('.'))
    -- A mapping whose atom RESOLVES to a resize also activates the submode.
    feed('\\+')
    n.poke_eventloop()
    eq(height + 2, fn.winheight(0))
    wait_active(true)
  end)
end)
