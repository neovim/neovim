local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local funcs = helpers.funcs
local nvim_prog = helpers.nvim_prog
local rmdir = helpers.rmdir
local sleep = helpers.sleep

describe('fileio', function()
  before_each(function()
  end)
  after_each(function()
    command(':qall!')
    os.remove('Xtest_startup_shada')
    os.remove('Xtest_startup_file1')
    os.remove('Xtest_startup_file2')
    rmdir('Xtest_startup_swapdir')
  end)

  it('fsync() codepaths #8304', function()
    -- This is an "acceptance test" or "smoke test".

    clear({ args={ '-i', 'Xtest_startup_shada',
                   '--cmd', 'set directory=Xtest_startup_swapdir' } })

    -- These cases ALWAYS force fsync (regardless of 'fsync' option):

    -- 1. Idle (CursorHold) with modified buffers (+ 'swapfile').
    command('set swapfile')
    command('set updatetime=1')
    command('write Xtest_startup_file1')
    feed('ifoo<esc>h')
    sleep(2)
    eq(1, eval('&modified'))

    -- 2. Exit caused by deadly signal (+ 'swapfile').
    local j = funcs.jobstart({ nvim_prog, '-u', 'NONE', '-i',
                               'Xtest_startup_shada', '--headless',
                               '-c', 'set swapfile',
                               '-c', 'write Xtest_startup_file2',
                               '-c', 'put =localtime()', })
    sleep(10)         -- Let Nvim start.
    funcs.jobstop(j)  -- Send deadly signal.

    -- 3. SIGPWR signal.
    -- ??

    -- 4. Explicit :preserve command.
    command('preserve')

    -- 5. Enable 'fsync' option, write file.
    command('set fsync')
    feed('ibaz<esc>h')
    command('write')
  end)
end)

