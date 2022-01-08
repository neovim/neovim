local helpers = require('test.functional.helpers')(after_each)
local clear, eq, funcs, command = helpers.clear, helpers.eq, helpers.funcs, helpers.command

describe("'autochdir'", function()
  it('given on the shell using --cmd gets processed properly', function()
    local targetdir = 'test/functional/fixtures'

    -- By default 'autochdir' is off, thus getcwd() returns the repo root.
    clear(targetdir..'/tty-test.c')
    local rootdir = funcs.getcwd()
    local expected = rootdir .. '/' .. targetdir

    -- With 'autochdir' on, we should get the directory of tty-test.c.
    clear('--cmd', 'set autochdir', targetdir..'/tty-test.c')
    eq(helpers.iswin() and expected:gsub('/', '\\') or expected, funcs.getcwd())
  end)

  it('extracts CWD from term:// URI', function()
    clear()
    local targetdir = 'test/functional/fixtures'
    local rootdir = funcs.getcwd()
    local expected = rootdir .. '/' .. targetdir
    funcs.chdir(targetdir)
    command('terminal')
    funcs.chdir(rootdir)
    command('set autochdir')
    eq(helpers.iswin() and expected:gsub('/', '\\') or expected, funcs.getcwd())
  end)
end)
