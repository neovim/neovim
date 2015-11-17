local lfs = require('lfs')
local helpers = require('test.functional.helpers')
local clear, execute, eval, eq = helpers.clear, helpers.execute, helpers.eval, helpers.eq

before_each(function()
  clear()
  lfs.mkdir('test-glob')

  -- Long path might cause "Press ENTER" prompt; use :silent to avoid it.
  execute('silent cd test-glob')
end)

after_each(function()
  lfs.rmdir('test-glob')
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
