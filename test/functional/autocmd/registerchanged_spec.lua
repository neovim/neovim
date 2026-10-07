local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, eq = n.clear, t.eq
local feed, command, eval, exec = n.feed, n.command, n.eval, n.exec
local api, fn = n.api, n.fn
local poke_eventloop = n.poke_eventloop

-- RegisterChanged is deferred: let the event loop run before reading events.
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

-- Drain pending events, then clear the list.
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

      reset()
      feed('gg"bdd')
      -- A linewise delete writes "b, then "1, and @" points at each in turn.
      eq({ 'b:delete', '":delete', '1:delete', '":delete' }, reasons())

      -- "2 now gets the previous "1; empty slots do not fire.
      reset()
      feed('dd')
      eq({ '2:shift', '1:delete', '":delete' }, reasons())
      eq('', events()[1].operator, 'shift does not license "operator"')
    end)

    it('change, Visual and Ex commands carry the operator', function()
      feed('ggcwX<Esc>')
      eq({ '-:delete', '":delete', '.:insert' }, reasons())
      eq('c', events()[1].operator)

      reset()
      feed('ggvd')
      eq({ '-:delete', '":delete' }, reasons())
      eq({ 'd', true }, { events()[1].operator, events()[1].visual })

      reset()
      command('2yank a')
      eq({ 'a:yank', '":yank' }, reasons())
      eq('y', events()[1].operator)
    end)

    it('record, setreg and redir', function()
      feed('qcjjq')
      eq({ 'c:record' }, reasons())

      reset()
      command([[call setreg('d', 'from-setreg')]])
      eq({ 'd:setreg' }, reasons())

      -- ":redir @e" clears the register, then appends each piece of output.
      reset()
      exec([[
        redir @e
        echo "redirected"
        redir END
      ]])
      eq({ 'e:redir', 'e:redir', 'e:redir' }, reasons())

      reset()
      exec([[
        redir @e
        let @f = 'not-redirected'
        redir END
      ]])
      eq({ 'e:redir', 'f:setreg' }, reasons())
    end)

    it('search covers both a search and an assignment to @/', function()
      feed('gg/beta<CR>')
      eq({ '/:search' }, reasons())

      -- "n" reuses the pattern, so the register does not change.
      reset()
      feed('n')
      eq({}, events())

      reset()
      command([[let @/ = 'gamma']])
      eq({ '/:search' }, reasons())

      reset()
      command('%s/alpha/ALPHA/e')
      eq({ '/:search' }, reasons())
      eq('alpha', fn.getreg('/'))
    end)

    it('expr', function()
      command([[let @= = '1+1']])
      eq({ '=:expr' }, reasons())
      eq('1+1', eval('getreg("=", 1)'))

      reset()
      feed('"=6*7<CR>p')
      eq({ '=:expr' }, reasons())
      eq('6*7', eval('getreg("=", 1)'))
    end)

    it('cmdline fires for typed commands only, after the command runs', function()
      feed(':let g:marker = 1<CR>')
      eq({ ':' }, names())
      eq('let g:marker = 1', fn.getreg(':'))

      reset()
      feed(':let g:marker = 1<CR>')
      eq({ ':' }, names())

      -- "@:" must not re-register itself.
      reset()
      feed('@:')
      eq({}, events())

      reset()
      command('let g:marker = 2')
      eq({}, events())
    end)

    it('insert', function()
      feed('ggihello<Esc>')
      eq({ '.:insert' }, reasons())

      reset()
      feed('ggihello<Esc>')
      eq({ '.:insert' }, reasons(), 'inserting the same text again is still a write')

      reset()
      feed('ggrZ')
      eq({ '.:insert' }, reasons())
      eq('Z', fn.getreg('.'))
    end)

    it('shada fires on :rshada but not during startup', function()
      local shada = t.tmpname()
      command([[call setreg('a', 'from-shada')]])
      command([[let @/ = 'from-shada']])
      command('wshada! ' .. shada)

      clear({
        args = {
          '-i',
          shada,
          '--cmd',
          'let g:events = []',
          '--cmd',
          'autocmd RegisterChanged * call add(g:events, deepcopy(v:event))',
        },
      })
      eq({}, events())
      eq('from-shada', fn.getreg('a'))

      command([[call setreg('a', 'changed-locally')]])
      command([[let @/ = 'changed-locally']])
      reset()
      command('rshada! ' .. shada)
      eq({ 'a:shada', '/:shada' }, reasons())
      eq('from-shada', fn.getreg('/'))
      eq('from-shada', fn.getreg('a'))
      os.remove(shada)
    end)
  end)

  describe('fires once per write', function()
    it('even when the value is unchanged', function()
      command([[call setreg('a', 'same')]])
      reset()
      command([[call setreg('a', 'same')]])
      eq({ 'a' }, names())
    end)

    it('for each half of a save-and-restore round trip', function()
      command([[call setreg('a', 'original')]])
      reset()
      command([[let g:save = @a | let @a = 'temporary' | let @a = g:save]])
      eq({ 'a', 'a' }, names())
      eq('original', fn.getreg('a'))
    end)

    it('for every write of a burst, which vim.schedule() can batch', function()
      -- The example in |RegisterChanged|.
      n.exec_lua(function()
        _G.updates = 0
        local pending = false
        vim.api.nvim_create_autocmd('RegisterChanged', {
          callback = function()
            if pending then
              return
            end
            pending = true
            vim.schedule(function()
              pending = false
              _G.updates = _G.updates + 1
            end)
          end,
        })
      end)
      local lines = {}
      for i = 1, 200 do
        lines[i] = 'foo ' .. i
      end
      api.nvim_buf_set_lines(0, 0, -1, true, lines)
      reset()
      command('%normal! "Ayy')
      -- 200 appends to "a, each reported under "a and "".
      eq(400, #events())
      eq(1, n.exec_lua('return _G.updates'))
    end)

    it('for a recording that captured nothing', function()
      feed('qaq')
      eq({ 'a:record' }, reasons())
    end)

    it('for register writes made from a handler, at the next tick', function()
      command([[autocmd RegisterChanged g call setreg('h', 'from-handler')]])
      reset()
      command([[call setreg('g', 'trigger')]])
      eq({ 'g', 'h' }, names())
    end)
  end)

  describe('does not fire', function()
    it('for the black hole register', function()
      feed('gg"_dd')
      eq({}, events())
    end)

    it('for searchcount(), which changes @/ only transiently', function()
      command([[let @/ = 'sentinel']])
      reset()
      pcall(fn.searchcount, { pattern = 'alpha', maxcount = 10 })
      eq({}, events())
      eq('sentinel', fn.getreg('/'))
    end)

    it('for nvim_load_context(), which restores state rather than writing it', function()
      command([[let @a = 'hello' | let @z = 'wiped']])
      local ctx = api.nvim_get_context({ types = { 'regs' } })
      reset()
      api.nvim_load_context(ctx)
      eq({}, events())

      command([[let @z = 'gone']])
      reset()
      api.nvim_load_context(ctx)
      eq({}, events())
      eq('wiped', fn.getreg('z'))
    end)
  end)

  describe('multicursor', function()
    local function clear_cursors()
      n.exec_lua(function()
        local ns = vim.api.nvim_create_namespace('nvim.multicursor')
        vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
      end)
    end

    it('fires for the primary cursor, then for the joined result, never for others', function()
      command([[let @a = 'untouched' | let @z = 'untouched']])
      api.nvim_buf_set_lines(0, 0, -1, true, { 'one two', 'three four' })
      feed('gg0Qj')
      reset()

      feed('dW')
      eq({ '-:delete', '":delete' }, reasons())

      reset()
      clear_cursors()
      eq({ '0:setreg', '":setreg', '-:setreg' }, reasons())
      eq({ 'one ', 'three ' }, fn.getreg('0', 1, 1))
    end)

    it('does not fire for a motion or for registers swapped per cursor', function()
      command([[let @a = 'untouched']])
      api.nvim_buf_set_lines(0, 0, -1, true, { 'one two', 'three four' })
      feed('gg0Qj')
      reset()

      feed('w')
      eq({}, events())
      feed('x')
      eq({ '-:delete', '":delete' }, reasons())
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
  end)

  it('reports a lowercase name for an uppercase append', function()
    feed('gg"ayy')
    reset()
    feed('gg"Ayy')
    eq({ 'a', '"' }, names())
    eq({ 'alpha', 'alpha' }, fn.getreg('a', 1, 1))
  end)

  describe('the unnamed register', function()
    it('fires under every name that resolves to the slot just written', function()
      command([[call setreg('b', 'bbb')]])
      command([[call setreg('"', {'points_to': 'b'})]])
      reset()
      feed('gg"ayy')
      eq({ 'a', '"' }, names())
      eq('a', events()[2].points_to)
    end)

    it('fires when setreg() repoints it with "isunnamed" or the "u" option', function()
      command([[call setreg('a', 'aaa', 'u')]])
      eq({ 'a', '"' }, names())
      eq('a', events()[2].points_to)

      reset()
      command([[call setreg('b', {'regcontents': 'bbb', 'isunnamed': v:true})]])
      eq({ 'b', '"' }, names())
      eq('b', events()[2].points_to)
    end)

    it('stays on the appended register after a linewise "Add', function()
      feed('gg"ayy')
      reset()
      feed('gg"Add')
      eq({ 'a:delete', '":delete', '1:delete' }, reasons())
      eq('a', events()[2].points_to)
    end)

    it('fires when the pointer moves between two equal values', function()
      command([[call setreg('a', 'dup')]])
      command([[call setreg('b', 'dup')]])
      command([[call setreg('"', {'points_to': 'a'})]])
      reset()
      command([[call setreg('"', {'points_to': 'b'})]])
      eq({ '"' }, names())
      eq('b', events()[1].points_to)
    end)
  end)

  describe('names that are not slots', function()
    it('report the register actually written', function()
      -- @" writes "0.
      command([[call setreg('0', 'zero')]])
      reset()
      command([[let @" = 'via-quote']])
      eq({ '0', '"' }, names())
      eq('via-quote', fn.getreg('0'))
      eq('0', events()[2].points_to)

      reset()
      feed('q"jjq')
      eq({ '0', '"' }, names())
      eq('jj', fn.getreg('0'))
    end)
  end)

  describe('the window-state registers', function()
    it('never fire, because they are projections rather than content', function()
      command('edit Xregisterchanged_one')
      command('edit Xregisterchanged_two')
      reset()

      command('edit Xregisterchanged_one')
      eq({}, events())
      eq('Xregisterchanged_one', fn.getreg('%'))

      reset()
      command([[let @# = 'Xregisterchanged_two']])
      eq({}, events())
      eq('Xregisterchanged_two', fn.getreg('#'))
    end)
  end)

  describe('payload', function()
    it('is ev.data in a Lua callback, and the same as v:event', function()
      n.exec_lua(function()
        _G.data = {}
        vim.api.nvim_create_autocmd('RegisterChanged', {
          callback = function(ev)
            table.insert(_G.data, ev.data)
          end,
        })
      end)
      command([[call setreg('a', 'text')]])
      local from_vim = events()
      eq(from_vim, n.exec_lua('return _G.data'))
      eq('a', from_vim[1].regname)
    end)

    it('carries the same four keys for every register, and no value', function()
      local function keys(e)
        local k = vim.tbl_keys(e)
        table.sort(k)
        return k
      end
      local expected = { 'operator', 'reason', 'regname', 'visual' }

      command([[call setreg('a', 'text')]])
      eq(expected, keys(events()[1]))

      reset()
      command([[let @/ = 'pattern']])
      local e = events()[1]
      eq(expected, keys(e))
      eq('', e.operator)
      eq(false, e.visual)
    end)

    it('reports visual for a Visual-mode yank', function()
      feed('ggVy')
      eq(true, events()[1].visual)
    end)
  end)

  describe('emission order', function()
    it('follows the writes, with the unnamed register after the slot it points at', function()
      -- Nine distinct deletes so every numbered register holds something.
      for i = 1, 9 do
        api.nvim_buf_set_lines(0, 0, -1, true, { 'line' .. i, 'rest' })
        feed('ggdd')
      end
      api.nvim_buf_set_lines(0, 0, -1, true, { 'final', 'rest' })
      reset()
      feed('gg"add')
      eq({ 'a', '"', '2', '3', '4', '5', '6', '7', '8', '9', '1', '"' }, names())
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

    it('fire for what Nvim writes, not for a read', function()
      feed('gg"+yy')
      eq({ '+', '"' }, names())

      -- Reading a clipboard change made by another application.
      reset()
      command("let g:test_clip['+'] = [['from-another-app'], 'v']")
      eq('from-another-app', fn.getreg('+'))
      eq({}, events())

      reset()
      feed('j"+yy')
      eq({ '+', '"' }, names())
      eq('beta\n', fn.getreg('+'))
    end)

    it('are not written by a plain yank under clipboard=unnamedplus', function()
      command('set clipboard=unnamedplus')
      reset()
      feed('ggyy')
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
    it('lets a handler change the buffer, because it runs at a safe state', function()
      command(
        'autocmd RegisterChanged z call nvim_buf_set_lines(0, 0, -1, v:true, ["set-by-handler"])'
      )
      command([[call setreg('z', 'trigger')]])
      poke_eventloop()
      eq({ 'set-by-handler' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)
end)
