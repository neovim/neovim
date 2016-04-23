local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local eq, eval, execute = helpers.eq, helpers.eval, helpers.execute

describe('Test for delete()', function()
  before_each(clear)

  it('file delete', function()
    execute('split Xfile')
    execute("call setline(1, ['a', 'b'])")
    execute('wq')
    eq(eval("['a', 'b']"), eval("readfile('Xfile')"))
    eq(0, eval("delete('Xfile')"))
    eq(-1, eval("delete('Xfile')"))
  end)

  it('directory delete', function()
    execute("call mkdir('Xdir1')")
    eq(1, eval("isdirectory('Xdir1')"))
    eq(0, eval("delete('Xdir1', 'd')"))
    eq(0, eval("isdirectory('Xdir1')"))
    eq(-1, eval("delete('Xdir1', 'd')"))
  end)
  it('recursive delete', function()
    execute("call mkdir('Xdir1')")
    execute("call mkdir('Xdir1/subdir')")
    execute("call mkdir('Xdir1/empty')")
    execute('split Xdir1/Xfile')
    execute("call setline(1, ['a', 'b'])")
    execute('w')
    execute('w Xdir1/subdir/Xfile')
    execute('close')

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
    source([[
      split Xfile
      call setline(1, ['a', 'b'])
      wq
      silent !ln -s Xfile Xlink
    ]])
    -- Delete the link, not the file
    eq(0, eval("delete('Xlink')"))
    eq(-1, eval("delete('Xlink')"))
    eq(0, eval("delete('Xfile')"))
  end)

  it('symlink directory delete', function()
    execute("call mkdir('Xdir1')")
    execute("silent !ln -s Xdir1 Xlink")
    eq(1, eval("isdirectory('Xdir1')"))
    eq(1, eval("isdirectory('Xlink')"))
    -- Delete the link, not the directory
    eq(0, eval("delete('Xlink')"))
    eq(-1, eval("delete('Xlink')"))
    eq(0, eval("delete('Xdir1', 'd')"))
  end)

  it('symlink recursive delete', function()
    source([[
      call mkdir('Xdir3')
      call mkdir('Xdir3/subdir')
      call mkdir('Xdir4')
      split Xdir3/Xfile
      call setline(1, ['a', 'b'])
      w
      w Xdir3/subdir/Xfile
      w Xdir4/Xfile
      close
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
end)
