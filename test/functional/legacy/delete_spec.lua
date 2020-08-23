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
end)
