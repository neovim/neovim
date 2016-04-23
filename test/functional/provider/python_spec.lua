local helpers = require('test.functional.helpers')
local eval, command, feed = helpers.eval, helpers.command, helpers.feed
local eq, clear, insert = helpers.eq, helpers.clear, helpers.insert
local expect, write_file = helpers.expect, helpers.write_file

do
  clear()
  command('let [g:interp, g:errors] = provider#pythonx#Detect(2)')
  local errors = eval('g:errors')
  if errors ~= '' then
    pending(
      'Python 2 (or the Python 2 neovim module) is broken or missing:\n' .. errors,
      function() end)
    return
  end
end

describe('python commands and functions', function()
  before_each(function()
    clear()
    command('python import vim')
  end)

  it('feature test', function()
    eq(1, eval('has("python")'))
  end)

  it('python_execute', function()
    command('python vim.vars["set_by_python"] = [100, 0]')
    eq({100, 0}, eval('g:set_by_python'))
  end)

  it('python_execute with nested commands', function()
    command([[python vim.command('python vim.command("python vim.command(\'let set_by_nested_python = 555\')")')]])
    eq(555, eval('g:set_by_nested_python'))
  end)

  it('python_execute with range', function()
    insert([[
      line1
      line2
      line3
      line4]])
    feed('ggjvj:python vim.vars["range"] = vim.current.range[:]<CR>')
    eq({'line2', 'line3'}, eval('g:range'))
  end)

  it('pyfile', function()
    local fname = 'pyfile.py'
    write_file(fname, 'vim.command("let set_by_pyfile = 123")')
    command('pyfile pyfile.py')
    eq(123, eval('g:set_by_pyfile'))
    os.remove(fname)
  end)

  it('pydo', function()
    -- :pydo 42 returns None for all lines,
    -- the buffer should not be changed
    command('normal :pydo 42')
    eq(0, eval('&mod'))
    -- insert some text
    insert('abc\ndef\nghi')
    expect([[
      abc
      def
      ghi]])
    -- go to top and select and replace the first two lines
    feed('ggvj:pydo return str(linenr)<CR>')
    expect([[
      1
      2
      ghi]])
  end)

  it('pyeval', function()
    eq({1, 2, {['key'] = 'val'}}, eval([[pyeval('[1, 2, {"key": "val"}]')]]))
  end)
end)
