-- biscide's runtime (runtime/lua/biscide): the program read as a graph, the
-- lanes, the card cursor, the history, each card a window on the real file
-- kept to its part, the keys, the pickers and the tree.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local eq = t.eq
local ok = t.ok
local clear = n.clear
local exec_lua = n.exec_lua

describe('biscide', function()
  local dir

  before_each(function()
    clear()
    dir = exec_lua(function()
      local d = vim.fn.tempname()
      vim.fn.mkdir(d .. '/pkg', 'p')
      local function write(rel, text)
        local f = assert(io.open(d .. '/' .. rel, 'w'))
        f:write(text)
        f:close()
      end
      write('go.mod', 'module example.com/m\n')
      write(
        'main.go',
        table.concat({
          'package main',
          '',
          'import "example.com/m/pkg"',
          '',
          'func main() {',
          '\ts := pkg.New()',
          '\trun(s)',
          '}',
          '',
          'func run(s *pkg.Store) {',
          '\ts.Load()',
          '}',
          '',
        }, '\n')
      )
      write(
        'pkg/store.go',
        table.concat({
          'package pkg',
          '',
          'type Store struct{ n int }',
          '',
          'func New() *Store { return &Store{} }',
          '',
          'func (s *Store) Load() int { return s.n }',
          '',
        }, '\n')
      )
      return d
    end)
    exec_lua(function(d)
      _G.active = nil
      vim.api.nvim_create_autocmd('User', {
        pattern = 'BiscideActive',
        callback = function(a)
          _G.active = a.data
        end,
      })
      require('biscide').start({ root = d, max_rows = 30 })
    end, dir)
  end)

  after_each(function()
    exec_lua(function(d)
      vim.fn.delete(d, 'rf')
    end, dir)
  end)

  local function node(name)
    return exec_lua(function(nm)
      for _, x in ipairs(require('biscide').state.graph.nodes) do
        if x.name == nm then
          return { id = x.id, rel = x.rel, srow = x.srow }
        end
      end
    end, name)
  end

  it('reads the program as a graph of declarations', function()
    local kinds = exec_lua(function()
      local S = require('biscide').state
      local by = {}
      for _, x in ipairs(S.graph.nodes) do
        by[x.name] = x
      end
      local function uses(a, b)
        for _, e in ipairs(by[a].out) do
          if S.graph.nodes[e.to].name == b then
            return vim.tbl_keys(e.kinds)
          end
        end
      end
      return {
        main_new = uses('main', 'New'),
        run_store = uses('run', 'Store'),
        load_store = uses('Store.Load', 'Store'),
      }
    end)
    eq({ 'call' }, kinds.main_new)
    eq({ 'parameter' }, kinds.run_store)
    eq({ 'receiver' }, kinds.load_store)
  end)

  it('lays out the lanes, moves the card cursor, keeps a history', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      local S = g.state
      g.go(id)
      local out = {
        active = _G.active and _G.active.name,
        uses = #S.lanes.uses,
        used_by = #S.lanes.used_by,
      }
      g.lane('right')
      out.cursor = S.cursor and S.cursor.lane
      g.go_cursor()
      out.after = S.active().rel
      out.prev = S.lanes.prev == id
      g.history(-1)
      out.back = S.active().name
      return out
    end, run.id)
    eq('run', r.active)
    ok(r.uses >= 1)
    eq(1, r.used_by)
    eq('uses', r.cursor)
    eq('pkg/store.go', r.after)
    eq(true, r.prev)
    eq('run', r.back)
  end)

  it('puts every line of a file in exactly one card', function()
    local r = exec_lua(function(d)
      local S = require('biscide').state
      local f = io.open(d .. '/main.go')
      local lines = vim.split(f:read('*a'), '\n', { plain = true })
      f:close()
      local owner, kinds = {}, {}
      for _, n in ipairs(S.graph.nodes) do
        if n.rel == 'main.go' then
          kinds[#kinds + 1] = n.kind .. ' ' .. n.name
          for row = n.srow, n.erow do
            owner[row] = (owner[row] or 0) + 1
          end
        end
      end
      local missing, twice = {}, {}
      for row = 0, #lines - 1 do
        if lines[row + 1]:match('%S') and not owner[row] then
          missing[#missing + 1] = row + 1
        end
        if (owner[row] or 0) > 1 then
          twice[#twice + 1] = row + 1
        end
      end
      table.sort(kinds)
      return { missing = missing, twice = twice, kinds = kinds }
    end, dir)
    eq({}, r.missing)
    eq({}, r.twice)
    eq({ 'func main', 'func run', 'imports imports', 'package package main' }, r.kinds)
  end)

  it('edits the real file in its card, written in place', function()
    local run = node('run')
    local r = exec_lua(function(id, d)
      local g = require('biscide')
      g.go(id)
      local card = g.card(id, 'file')
      local out = { real = vim.api.nvim_buf_get_name(card.buf) == d .. '/main.go' }
      local ino = vim.uv.fs_stat(d .. '/main.go').ino
      -- A line added in the part, at its end.
      local s, e = require('biscide.narrow').rows(card.win)
      vim.api.nvim_buf_set_lines(card.buf, e + 1, e + 1, false, { '// after run' })
      vim.api.nvim_buf_set_lines(card.buf, e, e, false, { '\t_ = 1' })
      vim.api.nvim_buf_call(card.buf, function()
        vim.cmd('silent write')
      end)
      vim.wait(300)
      local f = io.open(d .. '/main.go')
      local text = f:read('*a')
      f:close()
      out.written = text:find('\ts.Load()\n\t_ = 1\n}', 1, true) ~= nil
      out.same_inode = vim.uv.fs_stat(d .. '/main.go').ino == ino
      out.grew = select(2, require('biscide.narrow').rows(g.card(g.state.lanes.active, 'file').win)) - e
      return out
    end, run.id, dir)
    eq(true, r.real)
    eq(true, r.written)
    eq(true, r.same_inode)
    eq(1, r.grew)
  end)

  it('keeps a card to its part: the cursor does not leave it', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      g.go(id)
      local card = g.card(id, 'file')
      local s, e = require('biscide.narrow').rows(card.win)
      local rows = {}
      for _, keys in ipairs({ 'G', 'gg', '20j', '20k' }) do
        vim.api.nvim_feedkeys(keys, 'x', false)
        rows[#rows + 1] = vim.api.nvim_win_get_cursor(card.win)[1] - 1
      end
      -- An operator works only in the part: `ggdd` deletes its first line.
      local first = vim.api.nvim_buf_get_lines(card.buf, s, s + 1, false)[1]
      vim.api.nvim_feedkeys('ggdd', 'x', false)
      local package = vim.api.nvim_buf_get_lines(card.buf, 0, 1, false)[1]
      return { s = s, e = e, rows = rows, handle = type(card.handle), first = first, package = package,
        now = vim.api.nvim_buf_get_lines(card.buf, s, s + 1, false)[1] }
    end, run.id)
    eq({ r.e, r.s, r.e, r.s }, r.rows)
    eq('number', r.handle)
    eq('package main', r.package)
    t.neq(r.first, r.now)
  end)

  it('has its keys as GUI keymaps: first, in any buffer', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      -- A configuration's own global map of the same keys.
      vim.keymap.set('n', '<C-l>', '<C-w>l')
      require('biscide.keymaps').setup()
      g.go(id)
      -- In a buffer that is no card's, with its own map of the keys.
      vim.cmd('new')
      vim.keymap.set('n', '<C-l>', function()
        _G.own = true
      end, { buf = 0 })
      vim.api.nvim_feedkeys(vim.keycode('<C-l>'), 'x', false)
      local cursor = g.state.cursor and g.state.cursor.lane
      local gui = vim.tbl_map(function(m)
        return m.lhs
      end, vim.api.nvim_gui_get_keymap('n'))
      return { cursor = cursor, own = _G.own, has = vim.tbl_contains(gui, '<C-L>') }
    end, run.id)
    eq('uses', r.cursor)
    eq(nil, r.own)
    eq(true, r.has)
  end)

  it('makes a card the active one with <CR>, else hands <CR> on', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      local State = g.state
      require('biscide.keymaps').setup()
      g.go(id)
      local out = {}
      -- In a card of the uses lane: <CR> makes it the active one.
      local used = State.lanes.uses[1]
      local card = g.card(used, 'uses')
      vim.api.nvim_set_current_win(card.win)
      vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'x', false)
      out.active = State.lanes.active == used
      -- The card cursor on a card: <CR> goes there.
      g.lane('used_by')
      local marked = State.cursor and State.cursor.node
      vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'x', false)
      out.went = marked ~= nil and State.lanes.active == marked
      -- In a buffer that is no card's: its own <CR>.
      vim.cmd('new')
      vim.keymap.set('n', '<CR>', function()
        _G.own = true
      end, { buf = 0 })
      vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'x', false)
      out.own = _G.own
      return out
    end, run.id)
    eq(true, r.active)
    eq(true, r.went)
    eq(true, r.own)
  end)

  it('finds with a picker: fuzzy, the matches lit, picked', function()
    local r = exec_lua(function()
      local g = require('biscide')
      local picker = require('biscide.picker')
      local sent = {}
      vim._gui_send = function(kind, payload)
        sent[kind] = payload
      end
      require('biscide.pickers').open('declarations')
      -- The query typed.
      vim.api.nvim_buf_set_lines(picker.state.prompt.buf, 0, -1, false, { 'Lod' })
      vim.api.nvim_exec_autocmds('TextChangedI', { buffer = picker.state.prompt.buf })
      local p = sent.picker
      local out = {
        open = p.open,
        first = p.items[1] and p.items[1].text,
        pos = p.items[1] and p.items[1].pos,
        count = p.count,
        total = p.total,
        preview = p.preview_win ~= vim.NIL,
      }
      picker.confirm()
      vim.wait(100, function()
        return g.state.active() and g.state.active().short == 'Load'
      end)
      out.active = g.state.active() and g.state.active().name
      out.closed = sent.picker.open == false
      return out
    end)
    eq(true, r.open)
    eq('Store.Load', r.first)
    eq({ 6, 7, 9 }, r.pos)
    eq(1, r.count)
    eq(true, r.preview)
    eq('Store.Load', r.active)
    eq(true, r.closed)
  end)

  it('shows vim.ui.select as a picker', function()
    local r = exec_lua(function()
      local picker = require('biscide.picker')
      require('biscide.ui').setup()
      local got = {}
      vim.ui.select({ 'alpha', 'beta', 'gamma' }, { prompt = 'Pick one:' }, function(item, idx)
        got = { item = item, idx = idx }
      end)
      local title = picker.state.spec.title
      picker.move(2)
      picker.confirm()
      vim.wait(100, function()
        return got.item ~= nil
      end)
      -- Closed without a choice: nil.
      local none = 'unset'
      vim.ui.select({ 'x' }, {}, function(item)
        none = item
      end)
      picker.close()
      return { title = title, item = got.item, idx = got.idx, none = none }
    end)
    eq({ title = 'Pick one', item = 'gamma', idx = 3, none = nil }, r)
  end)

  it('keeps the tree as rows the GUI draws: opened, clicked, revealed', function()
    local r = exec_lua(function()
      local tree = require('biscide.tree')
      local sent
      vim._gui_send = function(kind, payload)
        if kind == 'tree' then
          sent = payload
        end
      end
      tree.open(true)
      local names = function()
        return vim.tbl_map(function(row)
          return row.name .. (row.dir and '/' or '')
        end, sent.rows)
      end
      local out = { first = names(), focused = sent.focused }
      -- pkg/ clicked: opened.
      for k, row in ipairs(sent.rows) do
        if row.name == 'pkg' then
          tree.click(k)
        end
      end
      out.opened = names()
      tree.reveal('main.go')
      out.selected = sent.rows[sent.selected].name
      out.kind = sent.rows[sent.selected].kind
      return out
    end)
    eq(true, r.focused)
    eq({ vim.fs.basename(dir) .. '/', 'pkg/', 'go.mod', 'main.go' }, r.first)
    eq({ vim.fs.basename(dir) .. '/', 'pkg/', 'store.go', 'go.mod', 'main.go' }, r.opened)
    eq('main.go', r.selected)
    eq('go', r.kind)
  end)

  it('keeps a card as tall as its part: a sign does not wrap it shorter', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      g.go(id)
      local card = g.card(id, 'file')
      local win = card.win
      local function height()
        local s, e = unpack(vim.api.nvim_win_get_range(win))
        return vim.api.nvim_win_text_height(win, { start_row = s, end_row = e }).all
      end
      local textoff = vim.fn.getwininfo(win)[1].textoff
      -- A diagnostic's sign appears on the part.
      local ns = vim.api.nvim_create_namespace('test_sign')
      vim.api.nvim_buf_set_extmark(card.buf, ns, card.srow, 0, { sign_text = 'E' })
      g.render()
      -- The cursor to its last line: no scrolling part way into a line.
      local s, e = unpack(vim.api.nvim_win_get_range(win))
      vim.api.nvim_win_set_cursor(win, { e + 1, 0 })
      local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
      return {
        same_gutter = vim.fn.getwininfo(win)[1].textoff == textoff,
        fits = vim.api.nvim_win_get_height(win) >= height(),
        top = view.topline == s + 1,
        skipcol = view.skipcol,
        smoothscroll = vim.wo[win].smoothscroll,
      }
    end, run.id)
    eq({ same_gutter = true, fits = true, top = true, skipcol = 0, smoothscroll = false }, r)
  end)

  it('shows a new declaration being written in its card only, not as a part too', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      local State = g.state
      g.go(id)
      g.new({ 'func df' }, { 1, 7 })
      vim.cmd.stopinsert()
      local w = State.new_at
      -- The program read again as it is typed (the typing paused).
      require('biscide.program').refresh('main.go', vim.fn.bufnr(w.path))
      local sent
      vim._gui_send = function(kind, payload)
        if kind == 'state' then
          sent = payload
        end
      end
      g.render()
      local covering = 0
      for _, c in ipairs(sent.cards) do
        local n = State.graph.nodes[c.node]
        if n and n.path == w.path and n.erow >= w.srow then
          covering = covering + 1
        end
      end
      return { new_card = sent.new_card ~= vim.NIL, covering = covering }
    end, run.id)
    eq({ new_card = true, covering = 0 }, r)
  end)

  it('gives a name that is nowhere a card, resolved by creating it', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      local State = g.state
      g.go(id)
      local n = State.active()
      local buf = vim.fn.bufnr(n.path)
      -- The language server says `helper` is undefined, where it is called.
      vim.api.nvim_buf_set_lines(buf, n.srow + 1, n.srow + 2, false, { '\thelper(s)' })
      local ns = vim.api.nvim_create_namespace('test_lsp')
      vim.diagnostic.set(ns, buf, {
        { lnum = n.srow + 1, col = 1, message = 'undefined: helper', severity = vim.diagnostic.severity.ERROR },
      })
      local sent
      vim._gui_send = function(kind, payload)
        if kind == 'state' or kind == 'picker' then
          sent = sent or {}
          sent[kind] = payload
        end
      end
      g.render()
      local st = sent.state
      local missing = st.lanes.uses[#st.lanes.uses]
      local info = st.nodes[tostring(missing)]
      local link
      for _, l in ipairs(st.links) do
        if l.node == missing then
          link = l
        end
      end
      -- Its card clicked: what can be done.
      g.mark(missing, 'uses')
      -- Its options come as they are found.
      vim.wait(200, function()
        return #sent.picker.items > 0
      end)
      local picker = require('biscide.picker')
      local first = sent.picker.items[1].text
      picker.confirm(1)
      vim.wait(200, function()
        return State.new_at ~= nil
      end)
      vim.cmd.stopinsert()
      local w = State.new_at
      local text = w and vim.api.nvim_buf_get_lines(buf, w.srow, w.erow + 1, false)
      picker.close()
      return {
        kind = info and info.kind,
        violation = link and link.violation,
        row = link and link.row == n.srow + 1,
        first = first,
        text = text,
      }
    end, run.id)
    eq('missing', r.kind)
    eq(true, r.violation)
    eq(true, r.row)
    eq('Create func helper', r.first)
    eq({ 'func helper(s *pkg.Store) {', '\t', '}' }, r.text)
  end)

  it('fills a template: its names, where the cursor goes', function()
    local r = exec_lua(function()
      local t = require('biscide.templates')
      local lines, at = t.expand({ title = 'm', text = 'func (r *${recv}) ${name}() {\n\t${cursor}\n}' }, { name = 'Get', recv = 'Store' })
      return { lines = lines, at = at, lang = t.lang('a/b.rs') }
    end)
    eq({ lines = { 'func (r *Store) Get() {', '\t', '}' }, at = { 2, 1 }, lang = 'rust' }, r)
  end)

  it('finds names that are nowhere itself, and what they are from their use', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      g.go(id)
      local n = g.state.active()
      local buf = vim.fn.bufnr(n.path)
      -- No language server: written, they are found anyway.
      vim.api.nvim_buf_set_lines(buf, n.srow + 1, n.srow + 2, false, {
        '\tx, err := fetch(s, "k"); helper(); _ = Thing{Size: 3}; _ = x; _ = err; s.Load()',
      })
      local out = {}
      for _, m in ipairs(require('biscide.missing').of(n)) do
        out[m.name] = { hint = m.hint, vars = m.vars }
      end
      return out
    end, run.id)
    eq({
      fetch = { hint = 'func', vars = { params = 's *pkg.Store, arg2 string', results = ' (any, error)', fields = '' } },
      helper = { hint = 'func', vars = { params = '', results = '', fields = '' } },
      Thing = { hint = 'struct', vars = { params = '', results = '', fields = 'Size int\n\t' } },
    }, r)
  end)

  it("keeps the file's end in its last card, and a card the blank lines typed in it", function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      local State = g.state
      g.go(id)
      local n = State.active()
      local buf = vim.fn.bufnr(n.path)
      local count = vim.api.nvim_buf_line_count(buf)
      local out = {}
      -- The last card: a line opened under it, read again while still blank.
      local card = g.card(id, 'file')
      vim.api.nvim_set_current_win(card.win)
      vim.api.nvim_win_set_cursor(card.win, { n.erow + 1, 0 })
      vim.api.nvim_buf_set_lines(buf, n.erow + 1, n.erow + 1, false, { '' })
      vim.api.nvim_win_set_cursor(card.win, { n.erow + 2, 0 })
      require('biscide.program').refresh('main.go', buf)
      card = g.card(State.lanes.active, 'file')
      out.cursor_kept = vim.api.nvim_win_get_cursor(card.win)[1] == n.erow + 2
      out.range_has_it = vim.api.nvim_win_get_range(card.win)[2] >= n.erow + 1
      -- Blank lines at the file's end: the last part's.
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { '', '' })
      require('biscide.program').refresh('main.go', buf)
      local last = 0
      for _, p in ipairs(State.graph.nodes) do
        if p.path == n.path then
          last = math.max(last, p.erow)
        end
      end
      out.end_owned = last == vim.api.nvim_buf_line_count(buf) - 1
      -- A new declaration left empty: the file as it was.
      local before = vim.api.nvim_buf_line_count(buf)
      g.new()
      vim.cmd.stopinsert()
      require('biscide.navigate').leave_new()
      out.new_gone = vim.api.nvim_buf_line_count(buf) == before
      out.count = count
      return out
    end, run.id)
    eq(true, r.cursor_kept)
    eq(true, r.range_has_it)
    eq(true, r.end_owned)
    eq(true, r.new_gone)
  end)

  it('keeps the card typed in, and the cursor in it, as its code is rewritten', function()
    local run = node('run')
    local r = exec_lua(function(id)
      local g = require('biscide')
      local State = g.state
      g.go(id)
      local n = State.active()
      local buf = vim.fn.bufnr(n.path)
      local card = g.card(id, 'file')
      local win = card.win
      vim.api.nvim_set_current_win(win)
      local out = {}
      -- Renamed as it is typed in: the same card, the same window.
      vim.api.nvim_buf_set_lines(buf, n.srow, n.srow + 1, false, { 'func runner(s *pkg.Store) {' })
      vim.api.nvim_win_set_cursor(win, { n.srow + 1, 8 })
      require('biscide.program').refresh('main.go', buf)
      out.renamed = State.active().name
      out.same_window = vim.api.nvim_get_current_win() == win and g.card(State.lanes.active, 'file').win == win
      -- Half typed (a block left open): the cursor stays where it is typed.
      vim.api.nvim_buf_set_lines(buf, n.srow + 2, n.srow + 2, false, { '\tif s != nil {', '\t\ts.Load(' })
      vim.api.nvim_win_set_cursor(win, { n.srow + 4, 9 })
      require('biscide.program').refresh('main.go', buf)
      out.still_here = vim.api.nvim_get_current_win() == win
        and vim.api.nvim_win_get_cursor(win)[1] == n.srow + 4
      return out
    end, run.id)
    eq('runner', r.renamed)
    eq(true, r.same_window)
    eq(true, r.still_here)
  end)

  it('grows the card typed in as its text grows, before it is read again', function()
    local run = node('run')
    local before = exec_lua(function(id)
      local g = require('biscide')
      g.go(id)
      local card = g.card(id, 'file')
      vim.api.nvim_set_current_win(card.win)
      local n = g.state.active()
      vim.api.nvim_win_set_cursor(card.win, { n.srow + 2, 0 })
      return card.rows
    end, run.id)
    -- Typed, still in Insert mode: three lines more.
    n.feed('o_ = 1<CR>_ = 2<CR>_ = 3')
    n.poke_eventloop()
    local r = exec_lua(function(id)
      local g = require('biscide')
      vim.wait(50)
      local card = g.state.cards:of_win(vim.api.nvim_get_current_win())
      return {
        mode = vim.api.nvim_get_mode().mode,
        rows = card and card.rows,
        range = vim.api.nvim_win_get_range(card.win),
      }
    end, run.id)
    eq('i', r.mode)
    eq(before + 3, r.rows)
    n.feed('<Esc>')
  end)
end)
