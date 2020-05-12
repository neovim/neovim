local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local eq, eval, command = helpers.eq, helpers.eval, helpers.command

describe('Test for delete()', function()
  before_each(clear)
  after_each(function()
    os.remove('Xfile')
  end)

  it('file delete', function()
    command('split Xfile')
    command("call setline(1, ['a', 'b'])")
    command('wq')
    eq(eval("['a', 'b']"), eval("readfile('Xfile')"))
    eq(0, eval("delete('Xfile')"))
    eq(-1, eval("delete('Xfile')"))
  end)

  it('directory delete', function()
    command("call mkdir('Xdir1')")
    eq(1, eval("isdirectory('Xdir1')"))
    eq(0, eval("delete('Xdir1', 'd')"))
    eq(0, eval("isdirectory('Xdir1')"))
    eq(-1, eval("delete('Xdir1', 'd')"))
  end)
  it('recursive delete', function()
    command("call mkdir('Xdir1')")
    command("call mkdir('Xdir1/subdir')")
    command("call mkdir('Xdir1/empty')")
    command('split Xdir1/Xfile')
    command("call setline(1, ['a', 'b'])")
    command('w')
    command('w Xdir1/subdir/Xfile')
    command('close')

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
      if has('win32')
        silent !mklink Xlink Xfile
      else
        silent !ln -s Xfile Xlink
      endif
    ]])
    if eval('v:shell_error') ~= 0 then
      pending('Cannot create symlink')
    end
    -- Delete the link, not the file
    eq(0, eval("delete('Xlink')"))
    eq(-1, eval("delete('Xlink')"))
    eq(0, eval("delete('Xfile')"))
  end)

  it('symlink directory delete', function()
    command("call mkdir('Xdir1')")
    if helpers.iswin() then
      command("silent !mklink /j Xlink Xdir1")
    else
      command("silent !ln -s Xdir1 Xlink")
    end
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
      if has('win32')
        silent !mklink /j Xdir3\Xlink Xdir4
      else
        silent !ln -s ../Xdir4 Xdir3/Xlink
      endif
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
