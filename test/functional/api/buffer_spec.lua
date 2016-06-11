-- Sanity checks for buffer_* API calls via msgpack-rpc
local helpers = require('test.functional.helpers')(after_each)
local clear, nvim, buffer = helpers.clear, helpers.nvim, helpers.buffer
local curbuf, curwin, eq = helpers.curbuf, helpers.curwin, helpers.eq
local curbufmeths, ok = helpers.curbufmeths, helpers.ok
local funcs = helpers.funcs

describe('buffer_* functions', function()
  before_each(clear)

  describe('line_count, insert and del_line', function()
    it('works', function()
      eq(1, curbuf('line_count'))
      curbuf('insert', -1, {'line'})
      eq(2, curbuf('line_count'))
      curbuf('insert', -1, {'line'})
      eq(3, curbuf('line_count'))
      curbuf('del_line', -1)
      eq(2, curbuf('line_count'))
      curbuf('del_line', -1)
      curbuf('del_line', -1)
      -- There's always at least one line
      eq(1, curbuf('line_count'))
    end)
  end)


  describe('{get,set,del}_line', function()
    it('works', function()
      eq('', curbuf('get_line', 0))
      curbuf('set_line', 0, 'line1')
      eq('line1', curbuf('get_line', 0))
      curbuf('set_line', 0, 'line2')
      eq('line2', curbuf('get_line', 0))
      curbuf('del_line', 0)
      eq('', curbuf('get_line', 0))
    end)

    it('get_line: out-of-bounds is an error', function()
      curbuf('set_line', 0, 'line1.a')
      eq(1, curbuf('line_count')) -- sanity
      eq(false, pcall(curbuf, 'get_line', 1))
      eq(false, pcall(curbuf, 'get_line', -2))
    end)

    it('set_line, del_line: out-of-bounds is an error', function()
      curbuf('set_line', 0, 'line1.a')
      eq(false, pcall(curbuf, 'set_line', 1, 'line1.b'))
      eq(false, pcall(curbuf, 'set_line', -2, 'line1.b'))
      eq(false, pcall(curbuf, 'del_line', 2))
      eq(false, pcall(curbuf, 'del_line', -3))
    end)

    it('can handle NULs', function()
      curbuf('set_line', 0, 'ab\0cd')
      eq('ab\0cd', curbuf('get_line', 0))
    end)
  end)


  describe('{get,set}_line_slice', function()
    it('get_line_slice: out-of-bounds returns empty array', function()
      curbuf('set_line_slice', 0, 0, true, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, curbuf('get_line_slice', 0, 2, true, true)) --sanity

      eq({}, curbuf('get_line_slice', 2, 3, false, true))
      eq({}, curbuf('get_line_slice', 3, 9, true, true))
      eq({}, curbuf('get_line_slice', 3, -1, true, true))
      eq({}, curbuf('get_line_slice', -3, -4, false, true))
      eq({}, curbuf('get_line_slice', -4, -5, true, true))
    end)

    it('set_line_slice: out-of-bounds extends past end', function()
      curbuf('set_line_slice', 0, 0, true, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, curbuf('get_line_slice', 0, 2, true, true)) --sanity

      eq({'c'}, curbuf('get_line_slice', -1, 4, true, true))
      eq({'a', 'b', 'c'}, curbuf('get_line_slice', 0, 5, true, true))
      curbuf('set_line_slice', 4, 5, true, true, {'d'})
      eq({'a', 'b', 'c', 'd'}, curbuf('get_line_slice', 0, 5, true, true))
      curbuf('set_line_slice', -4, -5, true, true, {'e'})
      eq({'e', 'a', 'b', 'c', 'd'}, curbuf('get_line_slice', 0, 5, true, true))
    end)

    it('works', function()
      eq({''}, curbuf('get_line_slice', 0, -1, true, true))
      -- Replace buffer
      curbuf('set_line_slice', 0, -1, true, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, curbuf('get_line_slice', 0, -1, true, true))
      eq({'b', 'c'}, curbuf('get_line_slice', 1, -1, true, true))
      eq({'b'}, curbuf('get_line_slice', 1, 2, true, false))
      eq({}, curbuf('get_line_slice', 1, 1, true, false))
      eq({'a', 'b'}, curbuf('get_line_slice', 0, -1, true, false))
      eq({'b'}, curbuf('get_line_slice', 1, -1, true, false))
      eq({'b', 'c'}, curbuf('get_line_slice', -2, -1, true, true))
      curbuf('set_line_slice', 1, 2, true, false, {'a', 'b', 'c'})
      eq({'a', 'a', 'b', 'c', 'c'}, curbuf('get_line_slice', 0, -1, true, true))
      curbuf('set_line_slice', -1, -1, true, true, {'a', 'b', 'c'})
      eq({'a', 'a', 'b', 'c', 'a', 'b', 'c'},
        curbuf('get_line_slice', 0, -1, true, true))
      curbuf('set_line_slice', 0, -3, true, false, {})
      eq({'a', 'b', 'c'}, curbuf('get_line_slice', 0, -1, true, true))
      curbuf('set_line_slice', 0, -1, true, true, {})
      eq({''}, curbuf('get_line_slice', 0, -1, true, true))
    end)
  end)

  describe('{get,set}_lines', function()
    local get_lines, set_lines = curbufmeths.get_lines, curbufmeths.set_lines
    local line_count = curbufmeths.line_count

    it('has correct line_count when inserting and deleting', function()
      eq(1, line_count())
      set_lines(-1, -1, true, {'line'})
      eq(2, line_count())
      set_lines(-1, -1, true, {'line'})
      eq(3, line_count())
      set_lines(-2, -1, true, {})
      eq(2, line_count())
      set_lines(-2, -1, true, {})
      set_lines(-2, -1, true, {})
      -- There's always at least one line
      eq(1, line_count())
    end)

    it('can get, set and delete a single line', function()
      eq({''}, get_lines(0, 1, true))
      set_lines(0, 1, true, {'line1'})
      eq({'line1'}, get_lines(0, 1, true))
      set_lines(0, 1, true, {'line2'})
      eq({'line2'}, get_lines(0, 1, true))
      set_lines(0, 1, true, {})
      eq({''}, get_lines(0, 1, true))
    end)

    it('can get a single line with strict indexing', function()
      set_lines(0, 1, true, {'line1.a'})
      eq(1, line_count()) -- sanity
      eq(false, pcall(get_lines, 1, 2, true))
      eq(false, pcall(get_lines, -3, -2, true))
    end)

    it('can get a single line with non-strict indexing', function()
      set_lines(0, 1, true, {'line1.a'})
      eq(1, line_count()) -- sanity
      eq({}, get_lines(1, 2, false))
      eq({}, get_lines(-3, -2, false))
    end)

    it('can set and delete a single line with strict indexing', function()
      set_lines(0, 1, true, {'line1.a'})
      eq(false, pcall(set_lines, 1, 2, true, {'line1.b'}))
      eq(false, pcall(set_lines, -3, -2, true, {'line1.c'}))
      eq({'line1.a'}, get_lines(0, -1, true))
      eq(false, pcall(set_lines, 1, 2, true, {}))
      eq(false, pcall(set_lines, -3, -2, true, {}))
      eq({'line1.a'}, get_lines(0, -1, true))
    end)

    it('can set and delete a single line with non-strict indexing', function()
      set_lines(0, 1, true, {'line1.a'})
      set_lines(1, 2, false, {'line1.b'})
      set_lines(-4, -3, false, {'line1.c'})
      eq({'line1.c', 'line1.a', 'line1.b'}, get_lines(0, -1, true))
      set_lines(3, 4, false, {})
      set_lines(-5, -4, false, {})
      eq({'line1.c', 'line1.a', 'line1.b'}, get_lines(0, -1, true))
    end)

    it('can handle NULs', function()
      set_lines(0, 1, true, {'ab\0cd'})
      eq({'ab\0cd'}, get_lines(0, -1, true))
    end)

    it('works with multiple lines', function()
      eq({''}, get_lines(0, -1, true))
      -- Replace buffer
      for _, mode in pairs({false, true}) do
        set_lines(0, -1, mode, {'a', 'b', 'c'})
        eq({'a', 'b', 'c'}, get_lines(0, -1, mode))
        eq({'b', 'c'}, get_lines(1, -1, mode))
        eq({'b'}, get_lines(1, 2, mode))
        eq({}, get_lines(1, 1, mode))
        eq({'a', 'b'}, get_lines(0, -2, mode))
        eq({'b'}, get_lines(1, -2, mode))
        eq({'b', 'c'}, get_lines(-3, -1, mode))
        set_lines(1, 2, mode, {'a', 'b', 'c'})
        eq({'a', 'a', 'b', 'c', 'c'}, get_lines(0, -1, mode))
        set_lines(-2, -1, mode, {'a', 'b', 'c'})
        eq({'a', 'a', 'b', 'c', 'a', 'b', 'c'},
          get_lines(0, -1, mode))
        set_lines(0, -4, mode, {})
        eq({'a', 'b', 'c'}, get_lines(0, -1, mode))
        set_lines(0, -1, mode, {})
        eq({''}, get_lines(0, -1, mode))
      end
    end)

    it('can get line ranges with non-strict indexing', function()
      set_lines(0, -1, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, get_lines(0, -1, true)) --sanity

      eq({}, get_lines(3, 4, false))
      eq({}, get_lines(3, 10, false))
      eq({}, get_lines(-5, -5, false))
      eq({}, get_lines(3, -1, false))
      eq({}, get_lines(-3, -4, false))
    end)

    it('can get line ranges with strict indexing', function()
      set_lines(0, -1, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, get_lines(0, -1, true)) --sanity

      eq(false, pcall(get_lines, 3, 4, true))
      eq(false, pcall(get_lines, 3, 10, true))
      eq(false, pcall(get_lines, -5, -5, true))
      -- empty or inverted ranges are not errors
      eq({}, get_lines(3, -1, true))
      eq({}, get_lines(-3, -4, true))
    end)

    it('set_line_slice: out-of-bounds can extend past end', function()
      set_lines(0, -1, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, get_lines(0, -1, true)) --sanity

      eq({'c'}, get_lines(-2, 5, false))
      eq({'a', 'b', 'c'}, get_lines(0, 6, false))
      eq(false, pcall(set_lines, 4, 6, true, {'d'}))
      set_lines(4, 6, false, {'d'})
      eq({'a', 'b', 'c', 'd'}, get_lines(0, -1, true))
      eq(false, pcall(set_lines, -6, -6, true, {'e'}))
      set_lines(-6, -6, false, {'e'})
      eq({'e', 'a', 'b', 'c', 'd'}, get_lines(0, -1, true))
    end)

  end)

  describe('{get,set,del}_var', function()
    it('works', function()
      curbuf('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, curbuf('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 'b:lua'))
      eq(1, funcs.exists('b:lua'))
      curbufmeths.del_var('lua')
      eq(0, funcs.exists('b:lua'))
    end)
  end)

  describe('{get,set}_option', function()
    it('works', function()
      eq(8, curbuf('get_option', 'shiftwidth'))
      curbuf('set_option', 'shiftwidth', 4)
      eq(4, curbuf('get_option', 'shiftwidth'))
      -- global-local option
      curbuf('set_option', 'define', 'test')
      eq('test', curbuf('get_option', 'define'))
      -- Doesn't change the global value
      eq([[^\s*#\s*define]], nvim('get_option', 'define'))
    end)
  end)

  describe('{get,set}_name', function()
    it('works', function()
      nvim('command', 'new')
      eq('', curbuf('get_name'))
      local new_name = nvim('eval', 'resolve(tempname())')
      curbuf('set_name', new_name)
      eq(new_name, curbuf('get_name'))
      nvim('command', 'w!')
      local f = io.open(new_name)
      ok(f ~= nil)
      f:close()
      os.remove(new_name)
    end)
  end)

  describe('is_valid', function()
    it('works', function()
      nvim('command', 'new')
      local b = nvim('get_current_buffer')
      ok(buffer('is_valid', b))
      nvim('command', 'bw!')
      ok(not buffer('is_valid', b))
    end)
  end)

  describe('get_mark', function()
    it('works', function()
      curbuf('insert', -1, {'a', 'bit of', 'text'})
      curwin('set_cursor', {3, 4})
      nvim('command', 'mark V')
      eq({3, 0}, curbuf('get_mark', 'V'))
    end)
  end)
end)
