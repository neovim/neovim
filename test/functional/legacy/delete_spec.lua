local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local eq, eval = helpers.eq, helpers.eval

describe('Test for delete()', function()
  before_each(function()
    clear()
    helpers.rmdir('Xcomplicated')
  end)
  after_each(function()
    helpers.rmdir('Xcomplicated')
  end)

  it('file delete', function()
    source([[
      call writefile(['a', 'b'], 'Xfile')
    ]])

    eq(eval("['a', 'b']"), eval("readfile('Xfile')"))
    eq(0, eval("delete('Xfile')"))
    eq(-1, eval("delete('Xfile')"))
  end)

  it('directory delete', function()
    source([[
      call mkdir('Xdir1')
    ]])

    eq(1, eval("isdirectory('Xdir1')"))
    eq(0, eval("delete('Xdir1', 'd')"))
    eq(0, eval("isdirectory('Xdir1')"))
    eq(-1, eval("delete('Xdir1', 'd')"))
  end)
  it('recursive delete', function()
    source([[
      call mkdir('Xdir1/subdir', 'p')
      call mkdir('Xdir1/empty')
      call writefile(['a', 'b'], 'Xdir1/Xfile')
      call writefile(['a', 'b'], 'Xdir1/subdir/Xfile')
    ]])

    eq(1, eval("isdirectory('Xdir1')"))
    eq(eval("['a', 'b']"), eval("readfile('Xdir1/Xfile')"))
    eq(1, eval("isdirectory('Xdir1/subdir')"))
    eq(eval("['a', 'b']"), eval("readfile('Xdir1/subdir/Xfile')"))
    eq(1, eval("isdirectory('Xdir1/empty')"))
    eq(0, eval("delete('Xdir1', 'rf')"))
    eq(0, eval("isdirectory('Xdir1')"))
    eq(-1, eval("delete('Xdir1', 'd')"))
  end)

  it('symlink delete', function()
    if helpers.pending_win32(pending) then return end

    source([[
      call writefile(['a', 'b'], 'Xfile')
      silent !ln -s Xfile Xlink
    ]])

    -- Delete the link, not the file
    eq(0, eval("delete('Xlink')"))
    eq(-1, eval("delete('Xlink')"))
    eq(0, eval("delete('Xfile')"))
  end)

  it('symlink directory delete', function()
    if helpers.pending_win32(pending) then return end

    source([[
      call mkdir('Xdir1')
      silent !ln -s Xdir1 Xlink
    ]])

    eq(1, eval("isdirectory('Xdir1')"))
    eq(1, eval("isdirectory('Xlink')"))
    -- Delete the link, not the directory
    eq(0, eval("delete('Xlink')"))
    eq(-1, eval("delete('Xlink')"))
    eq(0, eval("delete('Xdir1', 'd')"))
  end)

  it('symlink recursive delete', function()
    if helpers.pending_win32(pending) then return end

    source([[
      call mkdir('Xdir3/subdir', 'p')
      call mkdir('Xdir4')
      call writefile(['a', 'b'], 'Xdir3/Xfile')
      call writefile(['a', 'b'], 'Xdir3/subdir/Xfile')
      call writefile(['a', 'b'], 'Xdir4/Xfile')
      silent !ln -s ../Xdir4 Xdir3/Xlink
    ]])

    eq(1, eval("isdirectory('Xdir3')"))
    eq(eval("['a', 'b']"), eval("readfile('Xdir3/Xfile')"))
    eq(1, eval("isdirectory('Xdir3/subdir')"))
    eq(eval("['a', 'b']"), eval("readfile('Xdir3/subdir/Xfile')"))
    eq(1, eval("isdirectory('Xdir4')"))
    eq(1, eval("isdirectory('Xdir3/Xlink')"))
    eq(eval("['a', 'b']"), eval("readfile('Xdir4/Xfile')"))

    eq(0, eval("delete('Xdir3', 'rf')"))
    eq(0, eval("isdirectory('Xdir3')"))
    eq(-1, eval("delete('Xdir3', 'd')"))
    -- symlink is deleted, not the directory it points to
    eq(1, eval("isdirectory('Xdir4')"))
    eq(eval("['a', 'b']"), eval("readfile('Xdir4/Xfile')"))
    eq(0, eval("delete('Xdir4/Xfile')"))
    eq(0, eval("delete('Xdir4', 'd')"))
  end)

  it('complicated name delete', function()
    source([[
      call mkdir('Xcomplicated/[complicated-1 ]', 'p')
      call mkdir('Xcomplicated/{complicated,2 }', 'p')
      call writefile(['a', 'b'], 'Xcomplicated/Xfile')
      call writefile(['a', 'b'], 'Xcomplicated/[complicated-1 ]/Xfile')
      call writefile(['a', 'b'], 'Xcomplicated/{complicated,2 }/Xfile')
    ]])

    eq(1, eval("isdirectory('Xcomplicated')"))
    eq(eval("['a', 'b']"), eval("readfile('Xcomplicated/Xfile')"))
    eq(1, eval("isdirectory('Xcomplicated/[complicated-1 ]')"))
    eq(eval("['a', 'b']"), eval("readfile('Xcomplicated/[complicated-1 ]/Xfile')"))
    eq(1, eval("isdirectory('Xcomplicated/{complicated,2 }')"))
    eq(eval("['a', 'b']"), eval("readfile('Xcomplicated/{complicated,2 }/Xfile')"))

    eq(0, eval("delete('Xcomplicated', 'rf')"))
    eq(0, eval("isdirectory('Xcomplicated')"))
    eq(-1, eval("delete('Xcomplicated', 'd')"))
  end)

  it('complicated name delete in unix', function()
    source([[
      call mkdir('Xcomplicated/[complicated-1 ?', 'p')
      call writefile(['a', 'b'], 'Xcomplicated/Xfile')
      call writefile(['a', 'b'], 'Xcomplicated/[complicated-1 ?/Xfile')
    ]])

    eq(1, eval("isdirectory('Xcomplicated')"))
    eq(eval("['a', 'b']"), eval("readfile('Xcomplicated/Xfile')"))
    eq(1, eval("isdirectory('Xcomplicated/[complicated-1 ?')"))
    eq(eval("['a', 'b']"), eval("readfile('Xcomplicated/[complicated-1 ?/Xfile')"))

    eq(0, eval("delete('Xcomplicated', 'rf')"))
    eq(0, eval("isdirectory('Xcomplicated')"))
    eq(-1, eval("delete('Xcomplicated', 'd')"))
  end)
end)
