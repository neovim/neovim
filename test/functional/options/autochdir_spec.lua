local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local getcwd = helpers.funcs.getcwd

if helpers.pending_win32(pending) then return end

describe("'autochdir'", function()
  it('given on the shell gets processed properly', function()
    local targetdir = 'test/functional/fixtures'

    -- By default 'autochdir' is off, thus getcwd() returns the repo root.
    clear(targetdir..'/tty-test.c')
    local rootdir = getcwd()

    -- With 'autochdir' on, we should get the directory of tty-test.c.
    clear('--cmd', 'set autochdir', targetdir..'/tty-test.c')
    eq(rootdir..'/'..targetdir, getcwd())
  end)
end)
