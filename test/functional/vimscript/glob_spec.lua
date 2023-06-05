local luv = require('luv')
local helpers = require('test.functional.helpers')(after_each)
local clear, command, eval, eq = helpers.clear, helpers.command, helpers.eval, helpers.eq
local mkdir = helpers.mkdir

before_each(function()
  clear()
  mkdir('test-glob')

  -- Long path might cause "Press ENTER" prompt; use :silent to avoid it.
  command('silent cd test-glob')
end)

after_each(function()
  luv.fs_rmdir('test-glob')
end)

describe('glob()', function()
  it("glob('.*') returns . and .. ", function()
    eq({'.', '..'}, eval("glob('.*', 0, 1)"))
    -- Do it again to verify scandir_next_with_dots() internal state.
    eq({'.', '..'}, eval("glob('.*', 0, 1)"))
  end)
  it("glob('*') returns an empty list ", function()
    eq({}, eval("glob('*', 0, 1)"))
    -- Do it again to verify scandir_next_with_dots() internal state.
    eq({}, eval("glob('*', 0, 1)"))
  end)
end)
