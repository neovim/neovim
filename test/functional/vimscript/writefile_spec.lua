local helpers = require('test.functional.helpers')(after_each)
local luv = require('luv')

local mkdir = helpers.mkdir
local clear = helpers.clear
local eq = helpers.eq
local funcs = helpers.funcs
local meths = helpers.meths
local exc_exec = helpers.exc_exec
local read_file = helpers.read_file
local write_file = helpers.write_file
local pcall_err = helpers.pcall_err
local command = helpers.command

local fname = 'Xtest-functional-eval-writefile'
local dname = fname .. '.d'
local dfname_tail = '1'
local dfname = dname .. '/' .. dfname_tail
local ddname_tail = '2'
local ddname = dname .. '/' .. ddname_tail

before_each(function()
  mkdir(dname)
  mkdir(ddname)
  clear()
end)

after_each(function()
  os.remove(fname)
  os.remove(dfname)
  luv.fs_rmdir(ddname)
  luv.fs_rmdir(dname)
end)

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

  it('writes list with a null string to a file', function()
    eq(0, exc_exec(
       ('call writefile([v:_null_string], "%s", "b")'):format(
          fname)))
    eq('', read_file(fname))
    eq(0, exc_exec(('call writefile([v:_null_string], "%s")'):format(
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

  it('writes with s and S', function()
    eq(0, funcs.writefile({'\na\nb\n'}, fname, 'bs'))
    eq('\0a\0b\0', read_file(fname))
    eq(0, funcs.writefile({'a\n\n\nb'}, fname, 'bS'))
    eq('a\0\0\0b', read_file(fname))
  end)

  it('correctly overwrites file', function()
    eq(0, funcs.writefile({'\na\nb\n'}, fname, 'b'))
    eq('\0a\0b\0', read_file(fname))
    eq(0, funcs.writefile({'a\n'}, fname, 'b'))
    eq('a\0', read_file(fname))
  end)

  it('shows correct file name when supplied numbers', function()
    meths.set_current_dir(dname)
    eq('Vim(call):E482: Can\'t open file 2 for writing: illegal operation on a directory',
       pcall_err(command, ('call writefile([42], %s)'):format(ddname_tail)))
  end)

  it('writefile(..., "p") creates missing parent directories', function()
    os.remove(dname)
    eq(nil, read_file(dfname))
    eq(0, funcs.writefile({'abc', 'def', 'ghi'}, dfname, 'p'))
    eq('abc\ndef\nghi\n', read_file(dfname))
    os.remove(dfname)
    os.remove(dname)
    eq(nil, read_file(dfname))
    eq(0, funcs.writefile({'\na\nb\n'}, dfname, 'pb'))
    eq('\0a\0b\0', read_file(dfname))
    os.remove(dfname)
    os.remove(dname)
    eq('Vim(call):E32: No file name',
      pcall_err(command, ('call writefile([], "%s", "p")'):format(dfname .. '.d/')))
    eq(('Vim(call):E482: Can\'t open file ./ for writing: illegal operation on a directory'),
    pcall_err(command, 'call writefile([], "./", "p")'))
    eq(('Vim(call):E482: Can\'t open file . for writing: illegal operation on a directory'),
      pcall_err(command, 'call writefile([], ".", "p")'))
  end)

  it('errors out with invalid arguments', function()
    write_file(fname, 'TEST')
    eq('Vim(call):E119: Not enough arguments for function: writefile',
       pcall_err(command, 'call writefile()'))
    eq('Vim(call):E119: Not enough arguments for function: writefile',
       pcall_err(command, 'call writefile([])'))
    eq('Vim(call):E118: Too many arguments for function: writefile',
       pcall_err(command, ('call writefile([], "%s", "b", 1)'):format(fname)))
    for _, arg in ipairs({'0', '0.0', 'function("tr")', '{}', '"test"'}) do
      eq('Vim(call):E475: Invalid argument: writefile() first argument must be a List or a Blob',
         pcall_err(command, ('call writefile(%s, "%s", "b")'):format(arg, fname)))
    end
    for _, args in ipairs({'[], %s, "b"', '[], "' .. fname .. '", %s'}) do
      eq('Vim(call):E730: Using a List as a String',
         pcall_err(command, ('call writefile(%s)'):format(args:format('[]'))))
      eq('Vim(call):E731: Using a Dictionary as a String',
         pcall_err(command, ('call writefile(%s)'):format(args:format('{}'))))
      eq('Vim(call):E729: Using a Funcref as a String',
         pcall_err(command, ('call writefile(%s)'):format(args:format('function("tr")'))))
    end
    eq('Vim(call):E5060: Unknown flag: «»',
       pcall_err(command, ('call writefile([], "%s", "bs«»")'):format(fname)))
    eq('TEST', read_file(fname))
  end)

  it('does not write to file if error in list', function()
    local args = '["tset"] + repeat([%s], 3), "' .. fname .. '"'
    eq('Vim(call):E805: Expected a Number or a String, Float found',
        pcall_err(command, ('call writefile(%s)'):format(args:format('0.0'))))
    eq(nil, read_file(fname))
    write_file(fname, 'TEST')
    eq('Vim(call):E745: Expected a Number or a String, List found',
        pcall_err(command, ('call writefile(%s)'):format(args:format('[]'))))
    eq('TEST', read_file(fname))
    eq('Vim(call):E728: Expected a Number or a String, Dictionary found',
        pcall_err(command, ('call writefile(%s)'):format(args:format('{}'))))
    eq('TEST', read_file(fname))
    eq('Vim(call):E703: Expected a Number or a String, Funcref found',
        pcall_err(command, ('call writefile(%s)'):format(args:format('function("tr")'))))
    eq('TEST', read_file(fname))
  end)
end)
