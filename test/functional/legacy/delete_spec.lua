local t = require('test.functional.testutil')(after_each)
local clear, source = t.clear, t.source
local eq, eval, command = t.eq, t.eval, t.command
local exc_exec = t.exc_exec

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
    if t.is_os('win') then
      command('silent !mklink /j Xlink Xdir1')
    else
      command('silent !ln -s Xdir1 Xlink')
    end
    eq(1, eval("isdirectory('Xdir1')"))
    eq(1, eval("isdirectory('Xlink')"))
    -- Delete the link, not the directory
    eq(0, eval("delete('Xlink')"))
    eq(-1, eval("delete('Xlink')"))
    eq(0, eval("delete('Xdir1', 'd')"))
  end)

  it('gives correct emsgs', function()
    eq('Vim(call):E474: Invalid argument', exc_exec("call delete('')"))
    eq('Vim(call):E15: Invalid expression: "0"', exc_exec("call delete('foo', 0)"))
  end)
end)
