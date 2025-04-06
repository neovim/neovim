local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, command, eval, eq = n.clear, n.command, n.eval, t.eq
local mkdir = t.mkdir

before_each(function()
  clear()
  mkdir('test-glob')

  -- Long path might cause "Press ENTER" prompt; use :silent to avoid it.
  command('silent cd test-glob')
end)

after_each(function()
  vim.uv.fs_rmdir('test-glob')
end)

describe('glob()', function()
  it("glob('.*') returns . and .. ", function()
    eq({ '.', '..' }, eval("glob('.*', 0, 1)"))
    -- Do it again to verify scandir_next_with_dots() internal state.
    eq({ '.', '..' }, eval("glob('.*', 0, 1)"))
  end)
  it("glob('*') returns an empty list ", function()
    eq({}, eval("glob('*', 0, 1)"))
    -- Do it again to verify scandir_next_with_dots() internal state.
    eq({}, eval("glob('*', 0, 1)"))
  end)
end)
