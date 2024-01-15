local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local fn = helpers.fn
local command = helpers.command
local mkdir = helpers.mkdir

describe("'autochdir'", function()
  it('given on the shell gets processed properly', function()
    local targetdir = 'test/functional/fixtures'

    -- By default 'autochdir' is off, thus getcwd() returns the repo root.
    clear(targetdir .. '/tty-test.c')
    local rootdir = fn.getcwd()
    local expected = rootdir .. '/' .. targetdir

    -- With 'autochdir' on, we should get the directory of tty-test.c.
    clear('--cmd', 'set autochdir', targetdir .. '/tty-test.c')
    eq(helpers.is_os('win') and expected:gsub('/', '\\') or expected, fn.getcwd())
  end)

  it('is not overwritten by getwinvar() call #17609', function()
    local curdir = vim.uv.cwd():gsub('\\', '/')
    local dir_a = curdir .. '/Xtest-functional-options-autochdir.dir_a'
    local dir_b = curdir .. '/Xtest-functional-options-autochdir.dir_b'
    mkdir(dir_a)
    mkdir(dir_b)
    clear()
    command('set shellslash')
    command('set autochdir')
    command('edit ' .. dir_a .. '/file1')
    eq(dir_a, fn.getcwd())
    command('lcd ' .. dir_b)
    eq(dir_b, fn.getcwd())
    command('botright vnew ../file2')
    eq(curdir, fn.getcwd())
    command('wincmd w')
    eq(dir_a, fn.getcwd())
    fn.getwinvar(2, 'foo')
    eq(dir_a, fn.getcwd())
    helpers.rmdir(dir_a)
    helpers.rmdir(dir_b)
  end)
end)
