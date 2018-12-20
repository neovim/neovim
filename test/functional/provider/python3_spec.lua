local helpers = require('test.functional.helpers')(after_each)
local eval, command, feed = helpers.eval, helpers.command, helpers.feed
local eq, clear, insert = helpers.eq, helpers.clear, helpers.insert
local expect, write_file = helpers.expect, helpers.write_file
local expect_err = helpers.expect_err
local feed_command = helpers.feed_command
local source = helpers.source
local missing_provider = helpers.missing_provider

do
  clear()
  if missing_provider('python3') then
    it(':python3 reports E319 if provider is missing', function()
      expect_err([[Vim%(python3%):E319: No "python3" provider found.*]],
                 command, 'python3 print("foo")')
    end)
    pending('Python 3 (or the pynvim module) is broken/missing', function() end)
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
  end)

  it('python3_execute', function()
    command('python3 vim.vars["set_by_python3"] = [100, 0]')
    eq({100, 0}, eval('g:set_by_python3'))
  end)

  it('does not truncate error message <1 MB', function()
    -- XXX: Python limits the error name to 200 chars, so this test is
    -- mostly bogus.
    local very_long_symbol = string.rep('a', 1200)
    feed_command(':silent! py3 print('..very_long_symbol..' b)')
    -- Truncated error message would not contain this (last) line.
    eq('SyntaxError: invalid syntax', eval('v:errmsg'))
  end)

  it('python3_execute with nested commands', function()
    command([[python3 vim.command('python3 vim.command("python3 vim.command(\'let set_by_nested_python3 = 555\')")')]])
    eq(555, eval('g:set_by_nested_python3'))
  end)

  it('python3_execute with range', function()
    insert([[
      line1
      line2
      line3
      line4]])
    feed('ggjvj:python3 vim.vars["range"] = vim.current.range[:]<CR>')
    eq({'line2', 'line3'}, eval('g:range'))
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

  it('py3eval', function()
    eq({1, 2, {['key'] = 'val'}}, eval([[py3eval('[1, 2, {"key": "val"}]')]]))
  end)

  it('RPC call to expand("<afile>") during BufDelete #5245 #5617', function()
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
    feed_command("bwipeout!")
    feed_command('help help')
    eq(2, eval('1+1'))  -- Still alive?
  end)
end)
