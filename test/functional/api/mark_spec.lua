local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, api, command = n.clear, n.api, n.command
local eq, matches, pcall_err = t.eq, t.matches, t.pcall_err
local fn, feed, poke_eventloop = n.fn, n.feed, n.poke_eventloop
local describe, before_each, it = t.describe, t.before_each, t.it

--- Buffer with "n" lines, not the current one.
local function scratch(nlines)
  local buf = api.nvim_create_buf(false, true)
  local lines = {} ---@type string[]
  for i = 1, nlines do
    lines[i] = 'other' .. i
  end
  api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  return buf
end

--- Mark position as a {row, col} tuple.
local function pos(name, opts)
  local mark = api.nvim_get_mark(name, opts or {})
  return { mark[1], mark[2] }
end

describe('api/mark', function()
  before_each(function()
    clear()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
  end)

  describe('nvim_set_mark', function()
    it('sets window-local marks', function()
      local win = api.nvim_get_current_win()
      api.nvim_set_mark("'", 2, 5, {})
      eq({ 2, 5 }, pos("'"))

      command('new')
      api.nvim_set_mark("'", 3, 1, { win = win })
      eq({ 3, 1 }, pos("'", { win = win }))
    end)

    it('sets global marks', function()
      api.nvim_set_mark('A', 3, 2, {})
      local mark = api.nvim_get_mark('A', {})
      eq({ 3, 2, api.nvim_get_current_buf() }, { mark[1], mark[2], mark[3] })

      api.nvim_set_mark('0', 2, 1, {})
      eq({ 2, 1 }, pos('0'))

      local buf = scratch(2)
      api.nvim_set_mark('B', 2, 0, { buf = buf })
      eq(buf, api.nvim_get_mark('B', {})[3])
      -- The mark lives elsewhere, so it does not resolve against this buffer.
      eq(0, api.nvim_get_mark('B', { buf = 0 })[1])
    end)

    it('sets buffer-local marks', function()
      api.nvim_set_mark('a', 2, 4, {})
      -- "buffer" and "buffername" are only filled in for global marks.
      local mark = api.nvim_get_mark('a', {})
      eq({ 2, 4, 0, '' }, { mark[1], mark[2], mark[3], mark[4] })
      eq({ 0, 2, 5, 0 }, fn.getpos("'a"))

      api.nvim_set_mark('"', 3, 0, {})
      api.nvim_set_mark('[', 1, 0, {})
      api.nvim_set_mark(']', 2, 0, {})
      eq({ 3, 1, 2 }, { pos('"')[1], pos('[')[1], pos(']')[1] })

      local buf = scratch(2)
      api.nvim_set_mark('z', 2, 1, { buf = buf })
      eq({ 2, 1 }, pos('z', { buf = buf }))
    end)

    it('sets the Visual marks and their mode', function()
      api.nvim_set_mark('<', 1, 2, {})
      api.nvim_set_mark('>', 3, 4, {})
      eq({ 1, 2 }, pos('<'))
      eq({ 3, 4 }, pos('>'))
      command('normal! gv')
      eq('v', fn.mode())
      feed('<Esc>')

      -- Without "mode" an existing selection keeps its type, so '> still
      -- reports v:maxcol while it is linewise.
      feed('ggVj<Esc>')
      api.nvim_set_mark('<', 1, 2, {})
      eq(n.eval('v:maxcol'), pos('>')[2])

      api.nvim_set_mark('>', 2, 3, { mode = '\22' })
      eq(3, pos('>')[2])
      command('normal! gv')
      eq('\22', fn.mode())
    end)

    it('changes the type of the previous Visual selection #23754', function()
      feed('ggVj<Esc>')
      api.nvim_set_mark('<', 1, 1, { mode = 'v' })
      api.nvim_set_mark('>', 1, 3, { mode = 'v' })
      feed('gvy')
      eq('ine', fn.getreg('"'))
    end)

    it('deletes a mark with line=0', function()
      command("mark '")
      command('2mark a')
      api.nvim_set_mark("'", 0, 0, {})
      api.nvim_set_mark('a', 0, 0, {})
      eq({ 0, 0 }, pos("'"))
      eq({ 0, 0 }, pos('a'))

      -- A global mark is cleared wherever it lives, so "buf" is ignored.
      api.nvim_set_mark('A', 2, 0, { buf = scratch(2) })
      api.nvim_set_mark('A', 0, 0, {})
      eq({ 0, 0, 0, '', 0 }, api.nvim_get_mark('A', {}))
    end)

    it('loads the buffer only when it is needed', function()
      local bufnr = fn.bufnr('set_mark', true)
      api.nvim_set_mark('A', 0, 0, { buf = bufnr })
      eq(false, api.nvim_buf_is_loaded(bufnr))
      api.nvim_set_mark('A', 1, 0, { buf = bufnr })
      eq(true, api.nvim_buf_is_loaded(bufnr))
    end)

    it('validation', function()
      matches('cannot be set manually', pcall_err(api.nvim_set_mark, '^', 1, 0, {}))
      matches('cannot be set manually', pcall_err(api.nvim_set_mark, '}', 1, 0, {}))
      matches(
        "mark ':' is only available in prompt buffers",
        pcall_err(api.nvim_set_mark, ':', 1, 0, {})
      )
      matches('Invalid mark name', pcall_err(api.nvim_set_mark, '!', 1, 0, {}))
      matches(
        'Invalid mark name %(must be a single char%)',
        pcall_err(api.nvim_set_mark, 'fail', 1, 0, {})
      )
      eq('Invalid buffer id: 999', pcall_err(api.nvim_set_mark, 'a', 1, 0, { buf = 999 }))
      eq('Invalid buffer id: 999', pcall_err(api.nvim_set_mark, 'A', 0, 0, { buf = 999 }))
      eq('Invalid window id: 999', pcall_err(api.nvim_set_mark, "'", 1, 0, { win = 999 }))
      eq(
        "cannot use 'buf' for window-local marks",
        pcall_err(api.nvim_set_mark, "'", 1, 0, { buf = 0 })
      )
      eq(
        "cannot use 'win' for non-window-local marks",
        pcall_err(api.nvim_set_mark, 'A', 1, 0, { win = 0 })
      )
      matches("Invalid 'line'", pcall_err(api.nvim_set_mark, 'a', 999, 0, {}))
      matches("Invalid 'line'", pcall_err(api.nvim_set_mark, "'", -1, 0, {}))
      matches("Invalid 'column'", pcall_err(api.nvim_set_mark, 'a', 1, -1, {}))
      matches('Invalid key', pcall_err(api.nvim_set_mark, 'a', 1, 0, { timestamp = true }))
      matches(
        "'mode' is only valid for the < and > marks",
        pcall_err(api.nvim_set_mark, 'a', 1, 0, { mode = 'v' })
      )
      matches(
        "'mode' cannot be used to delete a mark",
        pcall_err(api.nvim_set_mark, '<', 0, 0, { mode = 'v' })
      )
      matches('Invalid mode', pcall_err(api.nvim_set_mark, '<', 1, 0, { mode = 'x' }))
      matches('Invalid mode', pcall_err(api.nvim_set_mark, '<', 1, 0, { mode = 'vv' }))
    end)
  end)

  describe('nvim_get_mark', function()
    it('gets window-local marks', function()
      local win = api.nvim_get_current_win()
      api.nvim_set_mark("'", 2, 3, { win = win })
      command('new')
      eq({ 2, 3 }, pos("'", { win = win }))
    end)

    it('gets global marks', function()
      api.nvim_buf_set_name(0, 'mark_test')
      local buf = api.nvim_get_current_buf()
      command('2mark A')
      local mark = api.nvim_get_mark('A', {})
      eq({ 2, 0, buf }, { mark[1], mark[2], mark[3] })
      matches('mark_test$', mark[4])
    end)

    it('gets a global mark from a deleted buffer', function()
      local fname = t.tmpname()
      t.write_file(fname, 'a\nbit of\text')
      command('edit ' .. fname)
      local buf = api.nvim_get_current_buf()

      api.nvim_set_mark('F', 2, 2, {})
      command('new') -- Create new buf to avoid :bd failing
      command('bd! ' .. buf)
      os.remove(fname)

      local mark = api.nvim_get_mark('F', {})
      local tail_patt = [[[\/][^\/]*$]]
      eq(fname:match(tail_patt), mark[4]:match(tail_patt))
      eq({ 2, 2, buf }, { mark[1], mark[2], mark[3] })
    end)

    it('gets buffer-local, Visual and motion marks', function()
      command('3mark a')
      eq({ 3, 0 }, pos('a'))

      feed('ggVj<Esc>')
      eq({ 1, 2 }, { pos('<')[1], pos('>')[1] })

      api.nvim_win_set_cursor(0, { 1, 0 })
      eq(3, pos('}')[1])

      api.nvim_win_set_cursor(0, { 2, 3 })
      command('enew')
      command('bp')
      eq(2, pos('"')[1])
    end)

    it('reports an unset mark the same way with and without buf', function()
      api.nvim_set_mark('A', 2, 0, {})
      eq(true, api.nvim_del_mark('A', {}))
      eq({ 0, 0, 0, '', 0 }, api.nvim_get_mark('A', {}))
      eq({ 0, 0, 0, '', 0 }, api.nvim_get_mark('A', { buf = 0 }))
      eq({ 0, 0, 0, '', 0 }, api.nvim_get_mark('z', {}))
    end)

    it('keeps the column of a mark whose line was invalidated', function()
      api.nvim_set_mark('m', 2, 2, {})
      api.nvim_buf_set_lines(0, 1, 2, true, {})
      eq({ 0, 2 }, pos('m'))
    end)

    it('returns the timestamp', function()
      local before = os.time()
      api.nvim_set_mark('a', 2, 3, {})
      api.nvim_set_mark('A', 2, 3, {})
      eq(true, api.nvim_get_mark('a', {})[5] >= before)
      eq(true, api.nvim_get_mark('A', {})[5] >= before)

      -- Marks that carry no timestamp, and unset marks, report 0.
      api.nvim_set_mark("'", 2, 3, {})
      api.nvim_set_mark('[', 1, 0, {})
      eq(0, api.nvim_get_mark("'", {})[5])
      eq(0, api.nvim_get_mark('[', {})[5])
      eq(0, api.nvim_get_mark('y', {})[5])
      api.nvim_del_mark('a', {})
      api.nvim_del_mark('A', {})
      eq(0, api.nvim_get_mark('a', {})[5])
      eq(0, api.nvim_get_mark('A', {})[5])
    end)

    it('validation', function()
      matches(
        'motion marks are only available for the current buffer',
        pcall_err(api.nvim_get_mark, '}', { buf = scratch(2) })
      )
      matches('Invalid mark name', pcall_err(api.nvim_get_mark, '!', {}))
      matches(
        'Invalid mark name %(must be a single char%)',
        pcall_err(api.nvim_get_mark, 'fail', {})
      )
      matches('Invalid key', pcall_err(api.nvim_get_mark, '<', { mode = 'v' }))
      matches('Invalid key', pcall_err(api.nvim_get_mark, 'a', { timestamp = true }))
      eq("cannot use 'buf' for window-local marks", pcall_err(api.nvim_get_mark, "'", { buf = 0 }))
      eq(
        "cannot use 'win' for non-window-local marks",
        pcall_err(api.nvim_get_mark, 'a', { win = 0 })
      )
    end)
  end)

  describe('nvim_del_mark', function()
    it('deletes global marks', function()
      command('2mark A')
      eq(true, api.nvim_del_mark('A', {}))
      eq({ 0, 0, 0, '', 0 }, api.nvim_get_mark('A', {}))

      api.nvim_set_mark('0', 1, 1, {})
      eq(true, api.nvim_del_mark('0', {}))
      eq(0, pos('0')[1])
    end)

    it('deletes a global mark only when it lives in "buf"', function()
      local other = scratch(2)
      api.nvim_set_mark('A', 2, 0, { buf = other })
      eq(false, api.nvim_del_mark('A', { buf = 0 }))
      eq(2, pos('A')[1])
      eq(true, api.nvim_del_mark('A', { buf = other }))
      eq(0, pos('A')[1])
    end)

    it('deletes buffer-local marks', function()
      command('2mark a')
      eq(true, api.nvim_del_mark('a', {}))
      eq({ 0, 0 }, pos('a'))

      api.nvim_set_mark('"', 2, 0, {})
      command('2mark [')
      feed('ggVG<Esc>')
      eq(true, api.nvim_del_mark('"', {}))
      eq(true, api.nvim_del_mark('[', {}))
      eq(true, api.nvim_del_mark('<', {}))
      eq(true, api.nvim_del_mark('>', {}))

      local buf = scratch(2)
      api.nvim_set_mark('z', 2, 0, { buf = buf })
      eq(true, api.nvim_del_mark('z', { buf = buf }))
      eq(0, pos('z', { buf = buf })[1])
    end)

    it('returns false when nothing was deleted', function()
      eq(false, api.nvim_del_mark('Z', {}))
      eq(false, api.nvim_del_mark('b', {}))
      command('mark c')
      eq(true, api.nvim_del_mark('c', {}))
      eq(false, api.nvim_del_mark('c', {}))
    end)

    it('emits MarkSet only when a mark is deleted', function()
      api.nvim_set_mark('B', 2, 0, { buf = scratch(2) })
      command('2mark A')
      command('2mark b')
      command('let g:marks = ""')
      command([[autocmd MarkSet * let g:marks ..= expand('<amatch>')]])

      eq(false, api.nvim_del_mark('Z', {})) -- Not set.
      eq(false, api.nvim_del_mark('c', {})) -- Not set.
      eq(false, api.nvim_del_mark('B', { buf = 0 })) -- Lives in another buffer.
      poke_eventloop()
      eq('', api.nvim_get_var('marks'))

      eq(true, api.nvim_del_mark('A', {}))
      eq(true, api.nvim_del_mark('b', {}))
      poke_eventloop()
      eq('Ab', api.nvim_get_var('marks'))
    end)

    it('validation', function()
      local cannot = 'cannot be deleted'
      matches(cannot, pcall_err(api.nvim_del_mark, "'", {}))
      matches(cannot, pcall_err(api.nvim_del_mark, '`', {}))
      matches(cannot, pcall_err(api.nvim_del_mark, ':', {}))
      matches(cannot, pcall_err(api.nvim_del_mark, '^', {}))
      matches(cannot, pcall_err(api.nvim_del_mark, '}', {}))
      matches('Invalid mark name', pcall_err(api.nvim_del_mark, '!', {}))
      matches(
        'Invalid mark name %(must be a single char%)',
        pcall_err(api.nvim_del_mark, 'fail', {})
      )
      matches('Invalid key', pcall_err(api.nvim_del_mark, 'a', { win = 0 }))
      matches('Invalid key', pcall_err(api.nvim_del_mark, 'a', { timestamp = true }))
      eq('Invalid buffer id: 999', pcall_err(api.nvim_del_mark, 'a', { buf = 999 }))
    end)
  end)
end)
