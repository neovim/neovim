local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local feed = helpers.feed
local funcs = helpers.funcs
local nvim_prog = helpers.nvim_prog
local request = helpers.request
local retry = helpers.retry
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
    clear({ args={ '-i', 'Xtest_startup_shada',
                   '--cmd', 'set directory=Xtest_startup_swapdir' } })

    -- These cases ALWAYS force fsync (regardless of 'fsync' option):

    -- 1. Idle (CursorHold) with modified buffers (+ 'swapfile').
    command('write Xtest_startup_file1')
    feed('ifoo<esc>h')
    command('write')
    eq(0, request('nvim__stats').fsync)   -- 'nofsync' is the default.
    command('set swapfile')
    command('set updatetime=1')
    feed('izub<esc>h')                    -- File is 'modified'.
    sleep(3)                              -- Allow 'updatetime' to expire.
    retry(3, nil, function()
      eq(1, request('nvim__stats').fsync)
    end)
    command('set updatetime=9999')

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
    eq(2, request('nvim__stats').fsync)

    -- 5. Enable 'fsync' option, write file.
    command('set fsync')
    feed('ibaz<esc>h')
    command('write')
    eq(4, request('nvim__stats').fsync)
  end)
end)

