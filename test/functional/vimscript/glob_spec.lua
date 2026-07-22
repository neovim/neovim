local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, command, eval, eq = n.clear, n.command, n.eval, t.eq
local mkdir = t.mkdir
local fn = n.fn

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

describe('glob() with $ and ~ mixed with wildcards', function()
  before_each(function()
    clear()
    mkdir('test-wild')
    command('silent cd test-wild')
    -- Names containing literal '$' and '~'.
    command([[call writefile([], 'a$b.txt')]])
    command([[call writefile([], 'a$c.txt')]])
    mkdir('test-wild/d~e')
    command([[call writefile([], 'd~e/f.txt')]])
  end)

  after_each(function()
    n.rmdir('test-wild')
  end)

  it('$VAR is expanded before the trailing wildcard is globbed', function()
    command('let $WILDDIR = "d~e"')
    eq({ 'd~e/f.txt' }, eval([[glob('$WILDDIR/*', 0, 1)]]))
  end)

  it("wildcard descends through a component containing '~'", function()
    eq({ 'd~e/f.txt' }, eval([[glob('d~e/*', 0, 1)]]))
  end)

  it("'~' mid-component combined with a wildcard", function()
    eq({ 'd~e' }, eval([[glob('d~*', 0, 1)]]))
  end)
end)
