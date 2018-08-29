local helpers = require('test.functional.helpers')(after_each)
local clear, nvim, buffer = helpers.clear, helpers.nvim, helpers.buffer
local curbuf, curwin, eq = helpers.curbuf, helpers.curwin, helpers.eq
local curbufmeths, ok = helpers.curbufmeths, helpers.ok
local funcs = helpers.funcs
local request = helpers.request
local exc_exec = helpers.exc_exec
local feed_command = helpers.feed_command
local insert = helpers.insert
local NIL = helpers.NIL
local meth_pcall = helpers.meth_pcall
local command = helpers.command
local bufmeths = helpers.bufmeths

describe('api/buf', function()
  before_each(clear)

  -- access deprecated functions
  local function curbuf_depr(method, ...)
    return request('buffer_'..method, 0, ...)
  end


  describe('line_count, insert and del_line', function()
    it('works', function()
      eq(1, curbuf_depr('line_count'))
      curbuf_depr('insert', -1, {'line'})
      eq(2, curbuf_depr('line_count'))
      curbuf_depr('insert', -1, {'line'})
      eq(3, curbuf_depr('line_count'))
      curbuf_depr('del_line', -1)
      eq(2, curbuf_depr('line_count'))
      curbuf_depr('del_line', -1)
      curbuf_depr('del_line', -1)
      -- There's always at least one line
      eq(1, curbuf_depr('line_count'))
    end)

    it('line_count has defined behaviour for unloaded buffers', function()
      -- we'll need to know our bufnr for when it gets unloaded
      local bufnr = curbuf('get_number')
      -- replace the buffer contents with these three lines
      request('nvim_buf_set_lines', bufnr, 0, -1, 1, {"line1", "line2", "line3", "line4"})
      -- check the line count is correct
      eq(4, request('nvim_buf_line_count', bufnr))
      -- force unload the buffer (this will discard changes)
      command('new')
      command('bunload! '..bufnr)
      -- line count for an unloaded buffer should always be 0
      eq(0, request('nvim_buf_line_count', bufnr))
    end)

    it('get_lines has defined behaviour for unloaded buffers', function()
      -- we'll need to know our bufnr for when it gets unloaded
      local bufnr = curbuf('get_number')
      -- replace the buffer contents with these three lines
      buffer('set_lines', bufnr, 0, -1, 1, {"line1", "line2", "line3", "line4"})
      -- confirm that getting lines works
      eq({"line2", "line3"}, buffer('get_lines', bufnr, 1, 3, 1))
      -- force unload the buffer (this will discard changes)
      command('new')
      command('bunload! '..bufnr)
      -- attempting to get lines now always gives empty list
      eq({}, buffer('get_lines', bufnr, 1, 3, 1))
      -- it's impossible to get out-of-bounds errors for an unloaded buffer
      eq({}, buffer('get_lines', bufnr, 8888, 9999, 1))
    end)
  end)

  describe('{get,set,del}_line', function()
    it('works', function()
      eq('', curbuf_depr('get_line', 0))
      curbuf_depr('set_line', 0, 'line1')
      eq('line1', curbuf_depr('get_line', 0))
      curbuf_depr('set_line', 0, 'line2')
      eq('line2', curbuf_depr('get_line', 0))
      curbuf_depr('del_line', 0)
      eq('', curbuf_depr('get_line', 0))
    end)

    it('get_line: out-of-bounds is an error', function()
      curbuf_depr('set_line', 0, 'line1.a')
      eq(1, curbuf_depr('line_count')) -- sanity
      eq(false, pcall(curbuf_depr, 'get_line', 1))
      eq(false, pcall(curbuf_depr, 'get_line', -2))
    end)

    it('set_line, del_line: out-of-bounds is an error', function()
      curbuf_depr('set_line', 0, 'line1.a')
      eq(false, pcall(curbuf_depr, 'set_line', 1, 'line1.b'))
      eq(false, pcall(curbuf_depr, 'set_line', -2, 'line1.b'))
      eq(false, pcall(curbuf_depr, 'del_line', 2))
      eq(false, pcall(curbuf_depr, 'del_line', -3))
    end)

    it('can handle NULs', function()
      curbuf_depr('set_line', 0, 'ab\0cd')
      eq('ab\0cd', curbuf_depr('get_line', 0))
    end)
  end)

  describe('{get,set}_line_slice', function()
    it('get_line_slice: out-of-bounds returns empty array', function()
      curbuf_depr('set_line_slice', 0, 0, true, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, curbuf_depr('get_line_slice', 0, 2, true, true)) --sanity

      eq({}, curbuf_depr('get_line_slice', 2, 3, false, true))
      eq({}, curbuf_depr('get_line_slice', 3, 9, true, true))
      eq({}, curbuf_depr('get_line_slice', 3, -1, true, true))
      eq({}, curbuf_depr('get_line_slice', -3, -4, false, true))
      eq({}, curbuf_depr('get_line_slice', -4, -5, true, true))
    end)

    it('set_line_slice: out-of-bounds extends past end', function()
      curbuf_depr('set_line_slice', 0, 0, true, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, curbuf_depr('get_line_slice', 0, 2, true, true)) --sanity

      eq({'c'}, curbuf_depr('get_line_slice', -1, 4, true, true))
      eq({'a', 'b', 'c'}, curbuf_depr('get_line_slice', 0, 5, true, true))
      curbuf_depr('set_line_slice', 4, 5, true, true, {'d'})
      eq({'a', 'b', 'c', 'd'}, curbuf_depr('get_line_slice', 0, 5, true, true))
      curbuf_depr('set_line_slice', -4, -5, true, true, {'e'})
      eq({'e', 'a', 'b', 'c', 'd'}, curbuf_depr('get_line_slice', 0, 5, true, true))
    end)

    it('works', function()
      eq({''}, curbuf_depr('get_line_slice', 0, -1, true, true))
      -- Replace buffer
      curbuf_depr('set_line_slice', 0, -1, true, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, curbuf_depr('get_line_slice', 0, -1, true, true))
      eq({'b', 'c'}, curbuf_depr('get_line_slice', 1, -1, true, true))
      eq({'b'}, curbuf_depr('get_line_slice', 1, 2, true, false))
      eq({}, curbuf_depr('get_line_slice', 1, 1, true, false))
      eq({'a', 'b'}, curbuf_depr('get_line_slice', 0, -1, true, false))
      eq({'b'}, curbuf_depr('get_line_slice', 1, -1, true, false))
      eq({'b', 'c'}, curbuf_depr('get_line_slice', -2, -1, true, true))
      curbuf_depr('set_line_slice', 1, 2, true, false, {'a', 'b', 'c'})
      eq({'a', 'a', 'b', 'c', 'c'}, curbuf_depr('get_line_slice', 0, -1, true, true))
      curbuf_depr('set_line_slice', -1, -1, true, true, {'a', 'b', 'c'})
      eq({'a', 'a', 'b', 'c', 'a', 'b', 'c'},
        curbuf_depr('get_line_slice', 0, -1, true, true))
      curbuf_depr('set_line_slice', 0, -3, true, false, {})
      eq({'a', 'b', 'c'}, curbuf_depr('get_line_slice', 0, -1, true, true))
      curbuf_depr('set_line_slice', 0, -1, true, true, {})
      eq({''}, curbuf_depr('get_line_slice', 0, -1, true, true))
    end)
  end)

  describe('{get,set}_lines', function()
    local get_lines, set_lines = curbufmeths.get_lines, curbufmeths.set_lines
    local line_count = curbufmeths.line_count

    it('fails correctly when input is not valid', function()
      eq(1, curbufmeths.get_number())
      local err, emsg = pcall(bufmeths.set_lines, 1, 1, 2, false, {'b\na'})
      eq(false, err)
      local exp_emsg = 'String cannot contain newlines'
      -- Expected {filename}:{lnum}: {exp_emsg}
      eq(': ' .. exp_emsg, emsg:sub(-#exp_emsg - 2))
    end)

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

    it("set_line on alternate buffer does not access invalid line (E315)", function()
      feed_command('set hidden')
      insert('Initial file')
      command('enew')
      insert([[
      More
      Lines
      Than
      In
      The
      Other
      Buffer]])
      feed_command('$')
      local retval = exc_exec("call nvim_buf_set_lines(1, 0, 1, v:false, ['test'])")
      eq(0, retval)
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
      eq({false, 'Key not found: lua'}, meth_pcall(curbufmeths.del_var, 'lua'))
      curbufmeths.set_var('lua', 1)
      command('lockvar b:lua')
      eq({false, 'Key is locked: lua'}, meth_pcall(curbufmeths.del_var, 'lua'))
      eq({false, 'Key is locked: lua'}, meth_pcall(curbufmeths.set_var, 'lua', 1))
      eq({false, 'Key is read-only: changedtick'},
         meth_pcall(curbufmeths.del_var, 'changedtick'))
      eq({false, 'Key is read-only: changedtick'},
         meth_pcall(curbufmeths.set_var, 'changedtick', 1))
    end)
  end)

  describe('get_changedtick', function()
    it('works', function()
      eq(2, curbufmeths.get_changedtick())
      curbufmeths.set_lines(0, 1, false, {'abc\0', '\0def', 'ghi'})
      eq(3, curbufmeths.get_changedtick())
      eq(3, curbufmeths.get_var('changedtick'))
    end)

    it('buffer_set_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL, request('buffer_set_var', 0, 'lua', val1))
      eq(val1, request('buffer_set_var', 0, 'lua', val2))
    end)

    it('buffer_del_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL,  request('buffer_set_var', 0, 'lua', val1))
      eq(val1, request('buffer_set_var', 0, 'lua', val2))
      eq(val2, request('buffer_del_var', 0, 'lua'))
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

  describe('is_loaded', function()
    it('works', function()
      -- record our buffer number for when we unload it
      local bufnr = curbuf('get_number')
      -- api should report that the buffer is loaded
      ok(buffer('is_loaded', bufnr))
      -- hide the current buffer by switching to a new empty buffer
      -- Careful! we need to modify the buffer first or vim will just reuse it
      buffer('set_lines', bufnr, 0, -1, 1, {'line1'})
      command('hide enew')
      -- confirm the buffer is hidden, but still loaded
      local infolist = nvim('eval', 'getbufinfo('..bufnr..')')
      eq(1, #infolist)
      eq(1, infolist[1].hidden)
      eq(1, infolist[1].loaded)
      -- now force unload the buffer
      command('bunload! '..bufnr)
      -- confirm the buffer is unloaded
      infolist = nvim('eval', 'getbufinfo('..bufnr..')')
      eq(0, infolist[1].loaded)
      -- nvim_buf_is_loaded() should also report the buffer as unloaded
      eq(false, buffer('is_loaded', bufnr))
    end)
  end)

  describe('is_valid', function()
    it('works', function()
      nvim('command', 'new')
      local b = nvim('get_current_buf')
      ok(buffer('is_valid', b))
      nvim('command', 'bw!')
      ok(not buffer('is_valid', b))
    end)
  end)

  describe('get_mark', function()
    it('works', function()
      curbuf('set_lines', -1, -1, true, {'a', 'bit of', 'text'})
      curwin('set_cursor', {3, 4})
      nvim('command', 'mark V')
      eq({3, 0}, curbuf('get_mark', 'V'))
    end)
  end)
end)
