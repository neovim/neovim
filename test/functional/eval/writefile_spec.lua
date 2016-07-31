local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local funcs = helpers.funcs
local exc_exec = helpers.exc_exec
local read_file = helpers.read_file

local fname = 'Xtest-functional-eval-writefile'

before_each(clear)
after_each(function() os.remove(fname) end)

describe('writefile()', function()
  it('writes empty list to a file', function()
    eq(nil, read_file(fname))
    eq(0, funcs.writefile({}, fname))
    eq('', read_file(fname))
    os.remove(fname)
    eq(nil, read_file(fname))
    eq(0, funcs.writefile({}, fname, 'b'))
    eq('', read_file(fname))
    os.remove(fname)
    eq(nil, read_file(fname))
    eq(0, funcs.writefile({}, fname, 'ab'))
    eq('', read_file(fname))
    os.remove(fname)
    eq(nil, read_file(fname))
    eq(0, funcs.writefile({}, fname, 'a'))
    eq('', read_file(fname))
  end)

  it('writes list with an empty string to a file', function()
    eq(0, exc_exec(
       ('call writefile([$XXX_NONEXISTENT_VAR_XXX], "%s", "b")'):format(
          fname)))
    eq('', read_file(fname))
    eq(0, exc_exec(('call writefile([$XXX_NONEXISTENT_VAR_XXX], "%s")'):format(
        fname)))
    eq('\n', read_file(fname))
  end)

  it('appends to a file', function()
    eq(nil, read_file(fname))
    eq(0, funcs.writefile({'abc', 'def', 'ghi'}, fname))
    eq('abc\ndef\nghi\n', read_file(fname))
    eq(0, funcs.writefile({'jkl'}, fname, 'a'))
    eq('abc\ndef\nghi\njkl\n', read_file(fname))
    os.remove(fname)
    eq(nil, read_file(fname))
    eq(0, funcs.writefile({'abc', 'def', 'ghi'}, fname, 'b'))
    eq('abc\ndef\nghi', read_file(fname))
    eq(0, funcs.writefile({'jkl'}, fname, 'ab'))
    eq('abc\ndef\nghijkl', read_file(fname))
  end)

  it('correctly treats NLs', function()
    eq(0, funcs.writefile({'\na\nb\n'}, fname, 'b'))
    eq('\0a\0b\0', read_file(fname))
    eq(0, funcs.writefile({'a\n\n\nb'}, fname, 'b'))
    eq('a\0\0\0b', read_file(fname))
  end)

  it('correctly overwrites file', function()
    eq(0, funcs.writefile({'\na\nb\n'}, fname, 'b'))
    eq('\0a\0b\0', read_file(fname))
    eq(0, funcs.writefile({'a\n'}, fname, 'b'))
    eq('a\0', read_file(fname))
  end)

  it('errors out with invalid arguments', function()
    eq('Vim(call):E119: Not enough arguments for function: writefile',
       exc_exec('call writefile()'))
    eq('Vim(call):E119: Not enough arguments for function: writefile',
       exc_exec('call writefile([])'))
    eq('Vim(call):E118: Too many arguments for function: writefile',
       exc_exec(('call writefile([], "%s", "b", 1)'):format(fname)))
    for _, arg in ipairs({'0', '0.0', 'function("tr")', '{}', '"test"'}) do
      eq('Vim(call):E686: Argument of writefile() must be a List',
         exc_exec(('call writefile(%s, "%s", "b")'):format(arg, fname)))
    end
    for _, args in ipairs({'%s, "b"', '"' .. fname .. '", %s'}) do
      eq('Vim(call):E806: using Float as a String',
         exc_exec(('call writefile([], %s)'):format(args:format('0.0'))))
      eq('Vim(call):E730: using List as a String',
         exc_exec(('call writefile([], %s)'):format(args:format('[]'))))
      eq('Vim(call):E731: using Dictionary as a String',
         exc_exec(('call writefile([], %s)'):format(args:format('{}'))))
      eq('Vim(call):E729: using Funcref as a String',
         exc_exec(('call writefile([], %s)'):format(args:format('function("tr")'))))
    end
  end)
end)
