local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, eq = n.clear, t.eq
local feed, command, eval = n.feed, n.command, n.eval
local api, fn = n.api, n.fn
local poke_eventloop = n.poke_eventloop

-- RegisterChanged is deferred: it is queued during the write and fired at the
-- next event-loop tick. Every assertion therefore has to let the loop run first,
-- which is what events() does.

local function events()
  poke_eventloop()
  return eval('g:events')
end

--- @return string[] the register names reported, in emission order
local function names()
  local out = {}
  for _, e in ipairs(events()) do
    out[#out + 1] = e.regname
  end
  return out
end

--- @return string[] "name:reason" for each event, in emission order
local function reasons()
  local out = {}
  for _, e in ipairs(events()) do
    out[#out + 1] = e.regname .. ':' .. e.reason
  end
  return out
end

-- Drain first: events queued by the previous step would otherwise land in the
-- list we are about to treat as empty.
local function reset()
  poke_eventloop()
  command('let g:events = []')
end

describe('RegisterChanged', function()
  before_each(function()
    clear()
    command('let g:events = []')
    command('autocmd RegisterChanged * call add(g:events, deepcopy(v:event))')
    api.nvim_buf_set_lines(0, 0, -1, true, { 'alpha', 'beta', 'gamma' })
    reset()
  end)

  describe('reason', function()
    it('yank and delete carry the operator, and a delete shifts the numbered registers', function()
      feed('gg"ayy')
      eq({ 'a:yank', '":yank' }, reasons())
      eq('y', events()[1].operator)

      -- @" is silent here: it followed the rotation onto "1, which now holds the
      -- same text "a already did. A pointer move between equal values is not a
      -- change.
      reset()
      feed('gg"bdd')
      eq({ '1:delete', 'b:delete' }, reasons())

      -- The rotation is silent until there are distinct values to demote: "1 was
      -- empty before the first delete, so nothing moved.
      reset()
      feed('dd')
      eq({ '1:delete', '2:shift', '":delete' }, reasons())
      eq('', events()[2].operator, 'shift does not license "operator"')
    end)

    it('record, setreg and redir', function()
      feed('qcjjq')
      eq({ 'c:record' }, reasons())

      reset()
      command([[call setreg('d', 'from-setreg')]])
      eq({ 'd:setreg' }, reasons())

      reset()
      command('redir @e')
      command('echo "redirected"')
      command('redir END')
      -- One event for the whole redirection, not one per chunk.
      eq({ 'e:redir' }, reasons())

      -- ":redir @e" clears the register as it starts, which is itself a change
      -- and carries the redir reason. A ":let @f =" in flight is still a plain
      -- setreg: the reason names the mechanism writing that register, not the
      -- redirection that happens to be open.
      reset()
      command('redir @e')
      command([[let @f = 'not-redirected']])
      command('redir END')
      eq({ 'e:redir', 'f:setreg' }, reasons())
    end)

    it('search covers both a search and an assignment to @/', function()
      feed('gg/beta<CR>')
      eq({ '/:search' }, reasons())
      eq({ 'beta' }, events()[1].regcontents)

      -- "n" reuses the pattern, so the register does not change.
      reset()
      feed('n')
      eq({}, events())

      -- ":let @/ =" reaches set_last_search_pat(), the same funnel a search uses,
      -- so it shares the reason. A handler cannot tell the two apart.
      reset()
      command([[let @/ = 'gamma']])
      eq({ '/:search' }, reasons())

      -- ":s" moves last_idx to the substitute slot, and the event reports what
      -- @/ now reads rather than the search slot.
      reset()
      command('%s/alpha/ALPHA/e')
      eq({ '/:search' }, reasons())
      eq({ 'alpha' }, events()[1].regcontents)
    end)

    it('expr reports the expression source, never its value', function()
      command([[let @= = '1+1']])
      eq({ '=:expr' }, reasons())
      eq({ '1+1' }, events()[1].regcontents)
      eq('2', eval('getreg("=")'))
    end)

    it('cmdline fires for typed commands only, after the command runs', function()
      feed(':let g:marker = 1<CR>')
      eq({ ':' }, names())
      eq({ 'let g:marker = 1' }, events()[1].regcontents)

      -- The same command again is not a change.
      reset()
      feed(':let g:marker = 1<CR>')
      eq({}, events())

      -- "@:" must not re-register itself.
      reset()
      feed('@:')
      eq({}, events())

      -- A command that was not typed never reaches the register.
      reset()
      command('let g:marker = 2')
      eq({}, events())
    end)

    it('insert reports the visible text, without the trailing ESC', function()
      feed('ggihello<Esc>')
      eq({ '.:insert' }, reasons())
      eq({ 'hello' }, events()[1].regcontents)

      reset()
      feed('ggihello<Esc>')
      eq({}, events(), 'inserting the same text again is not a change')

      -- "r{char}" writes the register through a different site.
      reset()
      feed('ggrZ')
      eq({ '.:insert' }, reasons())
      eq({ 'Z' }, events()[1].regcontents)
    end)

    it('shada fires on :rshada but not during startup', function()
      local shada = t.tmpname()
      command([[call setreg('a', 'from-shada')]])
      command('wshada! ' .. shada)

      -- A fresh session loads that register at startup with a handler live, and
      -- must stay silent: the replacement contract is getreg() at VimEnter.
      clear({ args = { '-i', shada } })
      command('let g:events = []')
      command('autocmd RegisterChanged * call add(g:events, deepcopy(v:event))')
      command('autocmd VimEnter * let g:at_vimenter = getreg("a")')
      eq({}, events())

      -- Mid-session it is audible.
      command([[call setreg('a', 'changed-locally')]])
      reset()
      command('rshada! ' .. shada)
      eq({ 'a:shada' }, reasons())
      eq('from-shada', fn.getreg('a'))
      os.remove(shada)
    end)
  end)

  describe('does not fire', function()
    it('for the black hole register', function()
      feed('gg"_dd')
      eq({}, events())
    end)

    it('when a write puts back the value that was already there', function()
      command([[call setreg('a', 'same')]])
      reset()
      command([[call setreg('a', 'same')]])
      eq({}, events())
    end)

    it('for a save-and-restore round trip', function()
      command([[call setreg('a', 'original')]])
      reset()
      command([[let g:save = @a | let @a = 'temporary' | let @a = g:save]])
      eq({}, events())
      eq('original', fn.getreg('a'))
    end)

    it('when @/ is changed and reverted inside a function', function()
      command([[let @/ = 'sentinel']])
      reset()
      command([[
        function! F()
          silent! s/nope/z/e
        endfunction
      ]])
      command('call F()')
      eq({}, events())
      eq('sentinel', fn.getreg('/'))
    end)

    it('for searchcount(), which changes @/ only transiently', function()
      command([[let @/ = 'sentinel']])
      reset()
      pcall(fn.searchcount, { pattern = 'alpha', maxcount = 10 })
      eq({}, events())
      eq('sentinel', fn.getreg('/'))
    end)

    it('for register writes made from a handler', function()
      command([[autocmd RegisterChanged g call setreg('h', 'from-handler')]])
      reset()
      command([[call setreg('g', 'trigger')]])
      eq({ 'g' }, names(), 'the handler write is invisible to the event')
      eq('from-handler', fn.getreg('h'), 'but the write itself still happens')
    end)
  end)

  describe('pattern', function()
    before_each(function()
      command('autocmd! RegisterChanged')
      command('autocmd RegisterChanged a call add(g:events, {"seen": expand("<amatch>")})')
      reset()
    end)

    it('matches the register name and nothing else', function()
      command([[call setreg('a', 'x')]])
      eq({ { seen = 'a' } }, events())

      reset()
      command([[call setreg('b', 'x')]])
      eq({}, events())
    end)

    it('is matched case-insensitively only where the platform says so', function()
      -- "A is register "a plus an append flag, so the event always reports "a".
      command([[call setreg('a', 'x')]])
      reset()
      feed('gg"Ayy')
      eq({ { seen = 'a' } }, events())
    end)
  end)

  it('reports a lowercase name for an uppercase append', function()
    feed('gg"ayy')
    reset()
    feed('gg"Ayy')
    eq({ 'a', '"' }, names())
    eq({ 'alpha', 'alpha' }, events()[1].regcontents)
  end)

  describe('the unnamed register', function()
    it('fires under every name that resolves to the slot just written', function()
      command([[call setreg('b', 'bbb')]])
      command([[call setreg('"', {'points_to': 'b'})]])
      reset()
      feed('gg"ayy')
      -- "a changed, and @" now reads it instead of "b, so both fire - "" last.
      eq({ 'a', '"' }, names())
      eq('a', events()[2].points_to)
      eq({ 'alpha' }, events()[2].regcontents)
    end)

    it('is silent when the pointer moves between two equal values', function()
      command([[call setreg('a', 'dup')]])
      command([[call setreg('b', 'dup')]])
      command([[call setreg('"', {'points_to': 'a'})]])
      reset()
      command([[call setreg('"', {'points_to': 'b'})]])
      eq({}, events(), 'points_to is reported but is not part of the compared value')
    end)

    it('fires alone when only the pointer moves', function()
      command([[call setreg('a', 'aaa')]])
      command([[call setreg('b', 'bbb')]])
      command([[call setreg('"', {'points_to': 'a'})]])
      reset()
      command([[call setreg('"', {'points_to': 'b'})]])
      eq({ '"' }, names())
      eq('b', events()[1].points_to)
      eq({ 'bbb' }, events()[1].regcontents)
    end)
  end)

  describe('names that are not slots', function()
    it('report the register actually written', function()
      -- "" is not a slot of its own: both "q\"" and ":let @\" =" write "0, and
      -- the event says "0 with the alias beside it.
      command([[call setreg('0', 'zero')]])
      reset()
      command([[let @" = 'via-quote']])
      eq({ '0', '"' }, names())
      eq('via-quote', fn.getreg('0'))
      eq('0', events()[2].points_to)

      reset()
      feed('q"jjq')
      eq({ '0', '"' }, names())
      eq({ 'jj' }, events()[1].regcontents)
    end)
  end)

  describe('the window-state registers', function()
    it('never fire, because they are projections rather than content', function()
      command('edit Xregisterchanged_one')
      command('edit Xregisterchanged_two')
      reset()

      -- "% changes with the buffer and is read-only.
      command('edit Xregisterchanged_one')
      eq({}, events())
      eq('Xregisterchanged_one', fn.getreg('%'))

      -- "# is writable, and writing it is a register write with no event.
      reset()
      command([[let @# = 'Xregisterchanged_two']])
      eq({}, events())
      eq('Xregisterchanged_two', fn.getreg('#'))
    end)
  end)

  describe('payload', function()
    it('carries the same six keys for every register', function()
      local expected = { 'operator', 'reason', 'regcontents', 'regname', 'regtype', 'visual' }

      command([[call setreg('a', 'text')]])
      eq(expected, vim.tbl_keys(events()[1]) and (function()
        local k = vim.tbl_keys(events()[1])
        table.sort(k)
        return k
      end)())

      -- The specials carry exactly the same set, with degenerate operator/visual.
      reset()
      command([[let @/ = 'pattern']])
      local e = events()[1]
      local k = vim.tbl_keys(e)
      table.sort(k)
      eq(expected, k)
      eq('', e.operator)
      eq(false, e.visual)
      eq('v', e.regtype)
    end)

    it('adds points_to on the unnamed register only', function()
      feed('gg"ayy')
      local seen = {}
      for _, e in ipairs(events()) do
        seen[e.regname] = e.points_to ~= nil
      end
      eq(true, seen['"'])
      eq(false, seen['a'])
    end)

    it('never carries inclusive, which TextYankPost has', function()
      feed('gg"ayy')
      eq(nil, events()[1].inclusive)
    end)

    it('renders a cleared register as an empty list', function()
      command([[call setreg('a', 'text')]])
      reset()
      command([[call setreg('a', [])]])
      eq({}, events()[1].regcontents)
    end)

    it('reports the formatted regtype, including the blockwise width', function()
      feed('gg<C-v>jl"fy')
      eq('\0222', events()[1].regtype)
    end)

    it('reports visual for a Visual-mode yank', function()
      feed('ggVy')
      eq(true, events()[1].visual)
    end)
  end)

  describe('emission order', function()
    it('is :registers order with the unnamed register last', function()
      -- Nine distinct deletes so every numbered register holds something.
      for i = 1, 9 do
        api.nvim_buf_set_lines(0, 0, -1, true, { 'line' .. i, 'rest' })
        feed('ggdd')
      end
      api.nvim_buf_set_lines(0, 0, -1, true, { 'final', 'rest' })
      reset()
      feed('gg"add')
      eq({ '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', '"' }, names())
    end)
  end)

  describe('the clipboard registers', function()
    before_each(function()
      clear({ args = { '--cmd', 'set rtp^=test/functional/fixtures' } })
      command('call getreg("*")') -- force the provider to load
      command('let g:events = []')
      command('autocmd RegisterChanged * call add(g:events, deepcopy(v:event))')
      api.nvim_buf_set_lines(0, 0, -1, true, { 'alpha', 'beta' })
      reset()
    end)

    it('report what Nvim wrote, not what a read left in the slot', function()
      feed('gg"+yy')
      eq({ '+', '"' }, names())

      -- Another application copies something, and Nvim reads it. The y_regs slot
      -- for "+ is provider scratch, so the read overwrites it - but a read is not
      -- a change and must not fire.
      reset()
      command("let g:test_clip['+'] = [['from-another-app'], 'v']")
      eq('from-another-app', fn.getreg('+'))
      eq({}, events())

      -- Writing the same text Nvim last put there is still not a change: the
      -- comparison basis is the shadow, not the read-clobbered slot. Without it
      -- this emits a second event carrying "alpha".
      reset()
      feed('gg"+yy')
      eq({}, events())

      reset()
      feed('j"+yy')
      eq({ '+', '"' }, names())
      eq({ 'beta' }, events()[1].regcontents)
    end)

    it('are not written by a plain yank under clipboard=unnamedplus', function()
      command('set clipboard=unnamedplus')
      reset()
      feed('ggyy')
      -- The outbound path resolves a target and discards it, so the "+ slot is
      -- never written and the event has nothing to report for it.
      eq({ '0', '"' }, names())
    end)

    it('are subscribable individually, with the glob escaped', function()
      command('autocmd! RegisterChanged')
      command([[autocmd RegisterChanged \* call add(g:events, {'seen': expand('<amatch>')})]])
      reset()
      command([[call setreg('*', 'star')]])
      eq({ { seen = '*' } }, events())

      reset()
      command([[call setreg('a', 'not-star')]])
      eq({}, events(), [[\* is the selection register alone, not every register]])
    end)
  end)

  describe('deferral', function()
    it('coalesces a burst into one event per register', function()
      local lines = {}
      for i = 1, 200 do
        lines[i] = 'foo ' .. i
      end
      api.nvim_buf_set_lines(0, 0, -1, true, lines)
      reset()
      command('%normal! "Ayy')
      -- 200 appends to "a, one event for "a and one for "".
      eq({ 'a', '"' }, names())
      eq(200, #fn.getreg('a', 1, 1))
    end)

    it('lets a handler change the buffer, because it runs at a safe state', function()
      -- The event is deferred, so there is no textlock to violate.
      command(
        'autocmd RegisterChanged z call nvim_buf_set_lines(0, 0, -1, v:true, ["set-by-handler"])'
      )
      command([[call setreg('z', 'trigger')]])
      poke_eventloop()
      eq({ 'set-by-handler' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)
end)
