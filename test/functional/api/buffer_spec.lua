local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, nvim, buffer = helpers.clear, helpers.nvim, helpers.buffer
local curbuf, curwin, eq = helpers.curbuf, helpers.curwin, helpers.eq
local curbufmeths, ok = helpers.curbufmeths, helpers.ok
local meths = helpers.meths
local funcs = helpers.funcs
local request = helpers.request
local exc_exec = helpers.exc_exec
local feed_command = helpers.feed_command
local insert = helpers.insert
local NIL = helpers.NIL
local command = helpers.command
local bufmeths = helpers.bufmeths
local feed = helpers.feed
local pcall_err = helpers.pcall_err

describe('api/buf', function()
  before_each(clear)

  -- access deprecated functions
  local function curbuf_depr(method, ...)
    return request('buffer_'..method, 0, ...)
  end


  describe('nvim_buf_set_lines, nvim_buf_line_count', function()
    it('deprecated forms', function()
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

    it('cursor position is maintained after lines are inserted #9961', function()
      -- replace the buffer contents with these three lines.
      request('nvim_buf_set_lines', 0, 0, -1, 1, {"line1", "line2", "line3", "line4"})
      -- Set the current cursor to {3, 2}.
      curwin('set_cursor', {3, 2})

      -- add 2 lines and delete 1 line above the current cursor position.
      request('nvim_buf_set_lines', 0, 1, 2, 1, {"line5", "line6"})
      -- check the current set of lines in the buffer.
      eq({"line1", "line5", "line6", "line3", "line4"}, buffer('get_lines', 0, 0, -1, 1))
      -- cursor should be moved below by 1 line.
      eq({4, 2}, curwin('get_cursor'))

      -- add a line after the current cursor position.
      request('nvim_buf_set_lines', 0, 5, 5, 1, {"line7"})
      -- check the current set of lines in the buffer.
      eq({"line1", "line5", "line6", "line3", "line4", "line7"}, buffer('get_lines', 0, 0, -1, 1))
      -- cursor position is unchanged.
      eq({4, 2}, curwin('get_cursor'))

      -- overwrite current cursor line.
      request('nvim_buf_set_lines', 0, 3, 5, 1, {"line8", "line9"})
      -- check the current set of lines in the buffer.
      eq({"line1", "line5", "line6", "line8",  "line9", "line7"}, buffer('get_lines', 0, 0, -1, 1))
      -- cursor position is unchanged.
      eq({4, 2}, curwin('get_cursor'))

      -- delete current cursor line.
      request('nvim_buf_set_lines', 0, 3, 5, 1, {})
      -- check the current set of lines in the buffer.
      eq({"line1", "line5", "line6", "line7"}, buffer('get_lines', 0, 0, -1, 1))
      -- cursor position is unchanged.
      eq({4, 2}, curwin('get_cursor'))
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

  describe('deprecated: {get,set,del}_line', function()
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

  describe('deprecated: {get,set}_line_slice', function()
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

  describe('nvim_buf_get_lines, nvim_buf_set_lines', function()
    local get_lines, set_lines = curbufmeths.get_lines, curbufmeths.set_lines
    local line_count = curbufmeths.line_count

    it('fails correctly when input is not valid', function()
      eq(1, curbufmeths.get_number())
      eq([[String cannot contain newlines]],
        pcall_err(bufmeths.set_lines, 1, 1, 2, false, {'b\na'}))
    end)

    it("fails if 'nomodifiable'", function()
      command('set nomodifiable')
      eq([[Buffer is not 'modifiable']],
        pcall_err(bufmeths.set_lines, 1, 1, 2, false, {'a','b'}))
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

    it('set_lines: out-of-bounds can extend past end', function()
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

    it("set_lines on alternate buffer does not access invalid line (E315)", function()
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

    it("set_lines of invisible buffer doesn't move cursor in current window", function()
      local screen = Screen.new(20, 5)
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue1},
        [2] = {bold = true},
      })
      screen:attach()

      insert([[
        Who would win?
        A real window
        with proper text]])
      local buf = meths.create_buf(false,true)
      screen:expect([[
        Who would win?      |
        A real window       |
        with proper tex^t    |
        {1:~                   }|
                            |
      ]])

      meths.buf_set_lines(buf, 0, -1, true, {'or some', 'scratchy text'})
      feed('i') -- provoke redraw
      screen:expect([[
        Who would win?      |
        A real window       |
        with proper tex^t    |
        {1:~                   }|
        {2:-- INSERT --}        |
      ]])
    end)

    it('set_lines on hidden buffer preserves "previous window" #9741', function()
      insert([[
        visible buffer line 1
        line 2
      ]])
      local hiddenbuf = meths.create_buf(false,true)
      command('vsplit')
      command('vsplit')
      feed('<c-w>l<c-w>l<c-w>l')
      eq(3, funcs.winnr())
      feed('<c-w>h')
      eq(2, funcs.winnr())
      meths.buf_set_lines(hiddenbuf, 0, -1, true,
                          {'hidden buffer line 1', 'line 2'})
      feed('<c-w>p')
      eq(3, funcs.winnr())
    end)
  end)

  describe('nvim_buf_get_lines, nvim_buf_set_text', function()
    local get_lines, set_text = curbufmeths.get_lines, curbufmeths.set_text

    it('works', function()
      insert([[
      hello foo!
      text
      ]])

      eq({'hello foo!'}, get_lines(0, 1, true))


      -- can replace a single word
      set_text(0, 6, 0, 9, {'world'})
      eq({'hello world!', 'text'}, get_lines(0, 2, true))

      -- can insert text
      set_text(0, 0, 0, 0, {'well '})
      eq({'well hello world!', 'text'}, get_lines(0, 2, true))

      -- can delete text
      set_text(0, 0, 0, 5, {''})
      eq({'hello world!', 'text'}, get_lines(0, 2, true))

      -- can replace with multiple lines
      set_text(0, 6, 0, 11, {'foo', 'wo', 'more'})
      eq({'hello foo', 'wo', 'more!', 'text'}, get_lines(0,  4, true))

      -- will join multiple lines if needed
      set_text(0, 6, 3, 4, {'bar'})
      eq({'hello bar'}, get_lines(0,  1, true))
    end)

    it('works with undo', function()
        insert([[
        hello world!
        foo bar
        ]])

        -- setting text
        set_text(0, 0, 0, 0, {'well '})
        feed('u')
        eq({'hello world!'}, get_lines(0, 1, true))

        -- deleting text
        set_text(0, 0, 0, 6, {''})
        feed('u')
        eq({'hello world!'}, get_lines(0, 1, true))

        -- inserting newlines
        set_text(0, 0, 0, 0, {'hello', 'mr '})
        feed('u')
        eq({'hello world!'}, get_lines(0, 1, true))

        -- deleting newlines
        set_text(0, 0, 1, 4, {'hello'})
        feed('u')
        eq({'hello world!'}, get_lines(0, 1, true))
    end)

    it('updates the cursor position', function()
      insert([[
      hello world!
      ]])

      -- position the cursor on `!`
      curwin('set_cursor', {1, 11})
      -- replace 'world' with 'foo'
      set_text(0, 6, 0, 11, {'foo'})
      eq('hello foo!', curbuf_depr('get_line', 0))
      -- cursor should be moved left by two columns (replacement is shorter by 2 chars)
      eq({1, 9}, curwin('get_cursor'))
    end)

    it('can handle NULs', function()
      set_text(0, 0, 0, 0, {'ab\0cd'})
      eq('ab\0cd', curbuf_depr('get_line', 0))
    end)

    it('adjusts extmarks', function()
      local ns = request('nvim_create_namespace', "my-fancy-plugin")
      insert([[
      foo bar
      baz
      ]])
      local id1 = curbufmeths.set_extmark(ns, 0, 1, {})
      local id2 = curbufmeths.set_extmark(ns, 0, 7, {})
      local id3 = curbufmeths.set_extmark(ns, 1, 1, {})
      set_text(0, 4, 0, 7, {"q"})

      eq({'foo q', 'baz'}, get_lines(0, 2, true))
      -- mark before replacement point is unaffected
      eq({0, 1}, curbufmeths.get_extmark_by_id(ns, id1, {}))
      -- mark gets shifted back because the replacement was shorter
      eq({0, 5}, curbufmeths.get_extmark_by_id(ns, id2, {}))
      -- mark on the next line is unaffected
      eq({1, 1}, curbufmeths.get_extmark_by_id(ns, id3, {}))

      -- replacing the text spanning two lines will adjust the mark on the next line
      set_text(0, 3, 1, 3, {"qux"})
      eq({'fooqux', ''}, get_lines(0, 2, true))
      eq({0, 6}, curbufmeths.get_extmark_by_id(ns, id3, {}))
      -- but mark before replacement point is still unaffected
      eq({0, 1}, curbufmeths.get_extmark_by_id(ns, id1, {}))
      -- and the mark in the middle was shifted to the end of the insertion
      eq({0, 6}, curbufmeths.get_extmark_by_id(ns, id2, {}))

      -- marks should be put back into the same place after undoing
      set_text(0, 0, 0, 2, {''})
      feed('u')
      eq({0, 1}, curbufmeths.get_extmark_by_id(ns, id1, {}))
      eq({0, 6}, curbufmeths.get_extmark_by_id(ns, id2, {}))
      eq({0, 6}, curbufmeths.get_extmark_by_id(ns, id3, {}))

	  -- marks should be shifted over by the correct number of bytes for multibyte
	  -- chars
	  set_text(0, 0, 0, 0, {'Ø'})
	  eq({0, 3}, curbufmeths.get_extmark_by_id(ns, id1, {}))
	  eq({0, 8}, curbufmeths.get_extmark_by_id(ns, id2, {}))
	  eq({0, 8}, curbufmeths.get_extmark_by_id(ns, id3, {}))
    end)
  end)

  describe('nvim_buf_get_offset', function()
    local get_offset = curbufmeths.get_offset
    it('works', function()
      curbufmeths.set_lines(0,-1,true,{'Some\r','exa\000mple', '', 'buf\rfer', 'text'})
      eq(5, curbufmeths.line_count())
      eq(0, get_offset(0))
      eq(6, get_offset(1))
      eq(15, get_offset(2))
      eq(16, get_offset(3))
      eq(24, get_offset(4))
      eq(29, get_offset(5))
      eq('Index out of bounds', pcall_err(get_offset, 6))
      eq('Index out of bounds', pcall_err(get_offset, -1))

      curbufmeths.set_option('eol', false)
      curbufmeths.set_option('fixeol', false)
      eq(28, get_offset(5))

      -- fileformat is ignored
      curbufmeths.set_option('fileformat', 'dos')
      eq(0, get_offset(0))
      eq(6, get_offset(1))
      eq(15, get_offset(2))
      eq(16, get_offset(3))
      eq(24, get_offset(4))
      eq(28, get_offset(5))
      curbufmeths.set_option('eol', true)
      eq(29, get_offset(5))

      command("set hidden")
      command("enew")
      eq(6, bufmeths.get_offset(1,1))
      command("bunload! 1")
      eq(-1, bufmeths.get_offset(1,1))
    end)
  end)

  describe('nvim_buf_get_var, nvim_buf_set_var, nvim_buf_del_var', function()
    it('works', function()
      curbuf('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, curbuf('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 'b:lua'))
      eq(1, funcs.exists('b:lua'))
      curbufmeths.del_var('lua')
      eq(0, funcs.exists('b:lua'))
      eq( 'Key not found: lua', pcall_err(curbufmeths.del_var, 'lua'))
      curbufmeths.set_var('lua', 1)
      command('lockvar b:lua')
      eq('Key is locked: lua', pcall_err(curbufmeths.del_var, 'lua'))
      eq('Key is locked: lua', pcall_err(curbufmeths.set_var, 'lua', 1))
      eq('Key is read-only: changedtick',
         pcall_err(curbufmeths.del_var, 'changedtick'))
      eq('Key is read-only: changedtick',
         pcall_err(curbufmeths.set_var, 'changedtick', 1))
    end)
  end)

  describe('nvim_buf_get_changedtick', function()
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

  describe('nvim_buf_get_option, nvim_buf_set_option', function()
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

  describe('nvim_buf_get_name, nvim_buf_set_name', function()
    it('works', function()
      nvim('command', 'new')
      eq('', curbuf('get_name'))
      local new_name = nvim('eval', 'resolve(tempname())')
      curbuf('set_name', new_name)
      eq(new_name, curbuf('get_name'))
      nvim('command', 'w!')
      eq(1, funcs.filereadable(new_name))
      os.remove(new_name)
    end)
  end)

  describe('nvim_buf_is_loaded', function()
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

  describe('nvim_buf_is_valid', function()
    it('works', function()
      nvim('command', 'new')
      local b = nvim('get_current_buf')
      ok(buffer('is_valid', b))
      nvim('command', 'bw!')
      ok(not buffer('is_valid', b))
    end)
  end)

  describe('nvim_buf_delete', function()
    it('allows for just deleting', function()
      nvim('command', 'new')
      local b = nvim('get_current_buf')
      ok(buffer('is_valid', b))
      nvim('buf_delete', b, {})
      ok(not buffer('is_loaded', b))
      ok(not buffer('is_valid', b))
    end)

    it('allows for just unloading', function()
      nvim('command', 'new')
      local b = nvim('get_current_buf')
      ok(buffer('is_valid', b))
      nvim('buf_delete', b, { unload = true })
      ok(not buffer('is_loaded', b))
      ok(buffer('is_valid', b))
    end)
  end)

  describe('nvim_buf_get_mark', function()
    it('works', function()
      curbuf('set_lines', -1, -1, true, {'a', 'bit of', 'text'})
      curwin('set_cursor', {3, 4})
      nvim('command', 'mark v')
      eq({3, 0}, curbuf('get_mark', 'v'))
    end)
  end)
end)
