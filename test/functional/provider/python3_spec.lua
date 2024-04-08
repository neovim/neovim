local t = require('test.functional.testutil')(after_each)
local assert_alive = t.assert_alive
local eval, command, feed = t.eval, t.command, t.feed
local eq, clear, insert = t.eq, t.clear, t.insert
local expect, write_file = t.expect, t.write_file
local feed_command = t.feed_command
local source = t.source
local missing_provider = t.missing_provider
local matches = t.matches
local pcall_err = t.pcall_err
local fn = t.fn
local dedent = t.dedent

do
  clear()
  local reason = missing_provider('python')
  if reason then
    it(':python3 reports E319 if provider is missing', function()
      local expected = [[Vim%(py3.*%):E319: No "python3" provider found.*]]
      matches(expected, pcall_err(command, 'py3 print("foo")'))
      matches(expected, pcall_err(command, 'py3file foo'))
    end)
    it('feature test when Python 3 provider is missing', function()
      eq(0, eval('has("python3")'))
      eq(0, eval('has("python3_compiled")'))
      eq(0, eval('has("python3_dynamic")'))
      eq(0, eval('has("pythonx")'))
    end)
    pending(
      string.format('Python 3 (or the pynvim module) is broken/missing (%s)', reason),
      function() end
    )
    return
  end
end

describe('python3 provider', function()
  before_each(function()
    clear()
    command('python3 import vim')
  end)

  it('feature test', function()
    eq(1, eval('has("python3")'))
    eq(1, eval('has("python3_compiled")'))
    eq(1, eval('has("python3_dynamic")'))
    eq(1, eval('has("pythonx")'))
    eq(0, eval('has("python3_dynamic_")'))
    eq(0, eval('has("python3_")'))
  end)

  it('python3_execute', function()
    command('python3 vim.vars["set_by_python3"] = [100, 0]')
    eq({ 100, 0 }, eval('g:set_by_python3'))
  end)

  it('does not truncate error message <1 MB', function()
    -- XXX: Python limits the error name to 200 chars, so this test is
    -- mostly bogus.
    local very_long_symbol = string.rep('a', 1200)
    feed_command(':silent! py3 print(' .. very_long_symbol .. ' b)')
    -- Error message will contain this (last) line.
    matches(
      string.format(
        dedent([[
      ^Error invoking 'python_execute' on channel 3 %%(python3%%-script%%-host%%):
        File "<string>", line 1
          print%%(%s b%%)
      %%C*
      SyntaxError: invalid syntax%%C*$]]),
        very_long_symbol
      ),
      eval('v:errmsg')
    )
  end)

  it('python3_execute with nested commands', function()
    command(
      [[python3 vim.command('python3 vim.command("python3 vim.command(\'let set_by_nested_python3 = 555\')")')]]
    )
    eq(555, eval('g:set_by_nested_python3'))
  end)

  it('python3_execute with range', function()
    insert([[
      line1
      line2
      line3
      line4]])
    feed('ggjvj:python3 vim.vars["range"] = vim.current.range[:]<CR>')
    eq({ 'line2', 'line3' }, eval('g:range'))
  end)

  it('py3file', function()
    local fname = 'py3file.py'
    write_file(fname, 'vim.command("let set_by_py3file = 123")')
    command('py3file py3file.py')
    eq(123, eval('g:set_by_py3file'))
    os.remove(fname)
  end)

  it('py3do', function()
    -- :pydo3 42 returns None for all lines,
    -- the buffer should not be changed
    command('normal :py3do 42')
    eq(0, eval('&mod'))
    -- insert some text
    insert('abc\ndef\nghi')
    expect([[
      abc
      def
      ghi]])
    -- go to top and select and replace the first two lines
    feed('ggvj:py3do return str(linenr)<CR>')
    expect([[
      1
      2
      ghi]])
  end)

  describe('py3eval()', function()
    it('works', function()
      eq({ 1, 2, { ['key'] = 'val' } }, fn.py3eval('[1, 2, {"key": "val"}]'))
    end)

    it('errors out when given non-string', function()
      eq('Vim:E474: Invalid argument', pcall_err(eval, 'py3eval(10)'))
      eq('Vim:E474: Invalid argument', pcall_err(eval, 'py3eval(v:_null_dict)'))
      eq('Vim:E474: Invalid argument', pcall_err(eval, 'py3eval(v:_null_list)'))
      eq('Vim:E474: Invalid argument', pcall_err(eval, 'py3eval(0.0)'))
      eq('Vim:E474: Invalid argument', pcall_err(eval, 'py3eval(function("tr"))'))
      eq('Vim:E474: Invalid argument', pcall_err(eval, 'py3eval(v:true)'))
      eq('Vim:E474: Invalid argument', pcall_err(eval, 'py3eval(v:false)'))
      eq('Vim:E474: Invalid argument', pcall_err(eval, 'py3eval(v:null)'))
    end)

    it('accepts NULL string', function()
      matches('.*SyntaxError.*', pcall_err(eval, 'py3eval($XXX_NONEXISTENT_VAR_XXX)'))
    end)
  end)

  it('pyxeval #10758', function()
    eq(3, eval([[&pyxversion]]))
    eq(3, eval([[pyxeval('sys.version_info[:3][0]')]]))
    eq(3, eval([[&pyxversion]]))
  end)

  it("setting 'pyxversion'", function()
    command 'set pyxversion=3' -- no error
    eq('Vim(set):E474: Invalid argument: pyxversion=2', pcall_err(command, 'set pyxversion=2'))
    command 'set pyxversion=0' -- allowed, but equivalent to pyxversion=3
    eq(3, eval '&pyxversion')
  end)

  it('RPC call to expand("<afile>") during BufDelete #5245 #5617', function()
    t.add_builddir_to_rtp()
    source([=[
      python3 << EOF
      import vim
      def foo():
        vim.eval('expand("<afile>:p")')
        vim.eval('bufnr(expand("<afile>:p"))')
      EOF
      autocmd BufDelete * python3 foo()
      autocmd BufUnload * python3 foo()]=])
    feed_command("exe 'split' tempname()")
    feed_command('bwipeout!')
    feed_command('help help')
    assert_alive()
  end)
end)

describe('python2 feature test', function()
  -- python2 is not supported, so correct behaviour is to return 0
  it('works', function()
    eq(0, fn.has('python2'))
    eq(0, fn.has('python'))
    eq(0, fn.has('python_compiled'))
    eq(0, fn.has('python_dynamic'))
    eq(0, fn.has('python_dynamic_'))
    eq(0, fn.has('python_'))
  end)
end)
