local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local neq = helpers.neq
local feed = helpers.feed
local clear = helpers.clear
local funcs = helpers.funcs
local meths = helpers.meths
local insert = helpers.insert
local expect = helpers.expect
local command = helpers.command
local exc_exec = helpers.exc_exec
local write_file = helpers.write_file
local curbufmeths = helpers.curbufmeths
local missing_provider = helpers.missing_provider
local matches = helpers.matches
local pcall_err = helpers.pcall_err

do
  clear()
  if missing_provider('python') then
    it(':python reports E319 if provider is missing', function()
      local expected = [[Vim%(py.*%):E319: No "python" provider found.*]]
      matches(expected, pcall_err(command, 'py print("foo")'))
      matches(expected, pcall_err(command, 'pyfile foo'))
    end)
    pending('Python 2 (or the pynvim module) is broken/missing', function() end)
    return
  end
end

before_each(function()
  clear()
  command('python import vim')
end)

describe('python feature test', function()
  it('works', function()
    eq(1, funcs.has('python'))
    eq(1, funcs.has('python_compiled'))
    eq(1, funcs.has('python_dynamic'))
    eq(0, funcs.has('python_dynamic_'))
    eq(0, funcs.has('python_'))
  end)
end)

describe(':python command', function()
  it('works with a line', function()
    command('python vim.vars["set_by_python"] = [100, 0]')
    eq({100, 0}, meths.get_var('set_by_python'))
  end)

  -- TODO(ZyX-I): works with << EOF
  -- TODO(ZyX-I): works with execute 'python' line1."\n".line2."\n"…

  it('supports nesting', function()
    command([[python vim.command('python vim.command("python vim.command(\'let set_by_nested_python = 555\')")')]])
    eq(555, meths.get_var('set_by_nested_python'))
  end)

  it('supports range', function()
    insert([[
      line1
      line2
      line3
      line4]])
    feed('ggjvj:python vim.vars["range"] = vim.current.range[:]<CR>')
    eq({'line2', 'line3'}, meths.get_var('range'))
  end)
end)

describe(':pyfile command', function()
  it('works', function()
    local fname = 'pyfile.py'
    write_file(fname, 'vim.command("let set_by_pyfile = 123")')
    command('pyfile pyfile.py')
    eq(123, meths.get_var('set_by_pyfile'))
    os.remove(fname)
  end)
end)

describe(':pydo command', function()
  it('works', function()
    -- :pydo 42 returns None for all lines,
    -- the buffer should not be changed
    command('normal :pydo 42')
    eq(false, curbufmeths.get_option('modified'))
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
end)

describe('pyeval()', function()
  it('works', function()
    eq({1, 2, {['key'] = 'val'}}, funcs.pyeval('[1, 2, {"key": "val"}]'))
  end)

  it('errors out when given non-string', function()
    eq('Vim(call):E474: Invalid argument', exc_exec('call pyeval(10)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call pyeval(v:_null_dict)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call pyeval(v:_null_list)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call pyeval(0.0)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call pyeval(function("tr"))'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call pyeval(v:true)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call pyeval(v:false)'))
    eq('Vim(call):E474: Invalid argument', exc_exec('call pyeval(v:null)'))
  end)

  it('accepts NULL string', function()
    neq(0, exc_exec('call pyeval($XXX_NONEXISTENT_VAR_XXX)'))
  end)
end)
