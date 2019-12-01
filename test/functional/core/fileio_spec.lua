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
local mkdir = helpers.mkdir
local sleep = helpers.sleep
local read_file = helpers.read_file
local trim = helpers.trim
local currentdir = helpers.funcs.getcwd
local iswin = helpers.iswin

describe('fileio', function()
  before_each(function()
  end)
  after_each(function()
    command(':qall!')
    os.remove('Xtest_startup_shada')
    os.remove('Xtest_startup_file1')
    os.remove('Xtest_startup_file1~')
    os.remove('Xtest_startup_file2')
    os.remove('Xtest_тест.md')
    rmdir('Xtest_startup_swapdir')
    rmdir('Xtest_backupdir')
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

  it('backup #9709', function()
    clear({ args={ '-i', 'Xtest_startup_shada',
                   '--cmd', 'set directory=Xtest_startup_swapdir' } })

    command('write Xtest_startup_file1')
    feed('ifoo<esc>')
    command('set backup')
    command('set backupcopy=yes')
    command('write')
    feed('Abar<esc>')
    command('write')

    local foobar_contents = trim(read_file('Xtest_startup_file1'))
    local bar_contents = trim(read_file('Xtest_startup_file1~'))

    eq('foobar', foobar_contents);
    eq('foo', bar_contents);
  end)

  it('backup with full path #11214', function()
    clear()
    mkdir('Xtest_backupdir')
    command('set backup')
    command('set backupdir=Xtest_backupdir//')
    command('write Xtest_startup_file1')
    feed('ifoo<esc>')
    command('write')
    feed('Abar<esc>')
    command('write')

    -- Backup filename = fullpath, separators replaced with "%".
    local backup_file_name = string.gsub(currentdir()..'/Xtest_startup_file1',
      iswin() and '[:/\\]' or '/', '%%') .. '~'
    local foo_contents = trim(read_file('Xtest_backupdir/'..backup_file_name))
    local foobar_contents = trim(read_file('Xtest_startup_file1'))

    eq('foobar', foobar_contents);
    eq('foo', foo_contents);
  end)

  it('readfile() on multibyte filename #10586', function()
    clear()
    local text = {
      'line1',
      '  ...line2...  ',
      '',
      'line3!',
      'тест yay тест.',
      '',
    }
    local fname = 'Xtest_тест.md'
    funcs.writefile(text, fname, 's')
    table.insert(text, '')
    eq(text, funcs.readfile(fname, 'b'))
  end)
end)

