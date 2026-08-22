local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it = t.describe, t.it
local clear = n.clear
local eq = t.eq
local fn = n.fn
local command = n.command
local api = n.api
local mkdir = t.mkdir

describe("'autochdir'", function()
  it('given on the shell gets processed properly', function()
    local start_dir = vim.uv.cwd()
    local target_dir = t.paths.test_source_path .. '/test/functional/fixtures'

    -- By default 'autochdir' is off, thus getcwd() returns the initial directory.
    clear(target_dir .. '/tty-test.c')
    eq(start_dir, fn.getcwd())

    -- With 'autochdir' on, we should get the directory of tty-test.c.
    clear('--cmd', 'set autochdir', target_dir .. '/tty-test.c')
    eq(t.is_os('win') and target_dir:gsub('/', '\\') or target_dir, fn.getcwd())
  end)

  it('is not overwritten by getwinvar() call #17609', function()
    local curdir = t.fix_slashes(vim.uv.cwd())
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
    n.rmdir(dir_a)
    n.rmdir(dir_b)
  end)

  it('win_execute() keeps buffer names #41417', function()
    local root = vim.fs.normalize(t.tmpname(false))
    mkdir(root)
    mkdir(root .. '/a')
    mkdir(root .. '/b')
    clear()
    command('set shellslash')
    command('edit ' .. root .. '/a/file_a')
    command('vsplit ' .. root .. '/b/file_b')
    local win_b, buf_b = api.nvim_get_current_win(), api.nvim_get_current_buf()
    command('wincmd p')
    command('set autochdir')
    -- Sit in an ancestor of both files: 'autochdir' moves away from it during win_execute(), and
    -- both buffer names stay shortened, i.e. relative to the CWD.
    command('cd ' .. root)
    eq({ 'a/file_a', 'b/file_b' }, { fn.bufname('%'), fn.bufname(buf_b) })

    fn.win_execute(win_b, 'echo')

    eq({ 'a/file_a', 'b/file_b' }, { fn.bufname('%'), fn.bufname(buf_b) })
  end)
end)
