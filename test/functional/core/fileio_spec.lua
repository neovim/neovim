local uv = vim.uv
local t = require('test.functional.testutil')()

local assert_log = t.assert_log
local assert_nolog = t.assert_nolog
local clear = t.clear
local command = t.command
local eq = t.eq
local neq = t.neq
local ok = t.ok
local feed = t.feed
local fn = t.fn
local nvim_prog = t.nvim_prog
local request = t.request
local retry = t.retry
local rmdir = t.rmdir
local matches = t.matches
local api = t.api
local mkdir = t.mkdir
local sleep = vim.uv.sleep
local read_file = t.read_file
local trim = vim.trim
local currentdir = t.fn.getcwd
local assert_alive = t.assert_alive
local check_close = t.check_close
local expect_exit = t.expect_exit
local write_file = t.write_file
local Screen = require('test.functional.ui.screen')
local feed_command = t.feed_command
local skip = t.skip
local is_os = t.is_os
local is_ci = t.is_ci
local spawn = t.spawn
local set_session = t.set_session

describe('fileio', function()
  before_each(function() end)
  after_each(function()
    check_close()
    os.remove('Xtest_startup_shada')
    os.remove('Xtest_startup_file1')
    os.remove('Xtest_startup_file1~')
    os.remove('Xtest_startup_file2')
    os.remove('Xtest_startup_file2~')
    os.remove('Xtest_тест.md')
    os.remove('Xtest-u8-int-max')
    os.remove('Xtest-overwrite-forced')
    rmdir('Xtest_startup_swapdir')
    rmdir('Xtest_backupdir')
    rmdir('Xtest_backupdir with spaces')
  end)

  local args = { nvim_prog, '--clean', '--cmd', 'set nofsync directory=Xtest_startup_swapdir' }
  --- Starts a new nvim session and returns an attached screen.
  local function startup(extra_args)
    extra_args = extra_args or {}
    local argv = vim.tbl_flatten({ args, '--embed', extra_args })
    local screen_nvim = spawn(argv)
    set_session(screen_nvim)
    local screen = Screen.new(70, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.NvimDarkGrey4 },
      [2] = { background = Screen.colors.NvimDarkGrey1, foreground = Screen.colors.NvimLightGrey3 },
      [3] = { foreground = Screen.colors.NvimLightCyan },
    })
    return screen
  end

  it("fsync() with 'nofsync' #8304", function()
    clear({ args = { '--cmd', 'set nofsync directory=Xtest_startup_swapdir' } })

    -- These cases ALWAYS force fsync (regardless of 'fsync' option):

    -- 1. Idle (CursorHold) with modified buffers (+ 'swapfile').
    command('write Xtest_startup_file1')
    feed('Afoo<esc>h')
    command('write')
    eq(0, request('nvim__stats').fsync)
    command('set swapfile')
    command('set updatetime=1')
    feed('Azub<esc>h') -- File is 'modified'.
    sleep(3) -- Allow 'updatetime' to expire.
    retry(3, nil, function()
      eq(1, request('nvim__stats').fsync)
    end)
    command('set updatetime=100000 updatecount=100000')

    -- 2. Explicit :preserve command.
    command('preserve')
    -- TODO: should be exactly 2; where is the extra fsync() is coming from? #26404
    ok(request('nvim__stats').fsync == 2 or request('nvim__stats').fsync == 3)

    -- 3. Enable 'fsync' option, write file.
    command('set fsync')
    feed('Abaz<esc>h')
    command('write')
    -- TODO: should be exactly 4; where is the extra fsync() is coming from? #26404
    ok(request('nvim__stats').fsync == 4 or request('nvim__stats').fsync == 5)
    eq('foozubbaz', trim(read_file('Xtest_startup_file1')))

    -- 4. Exit caused by deadly signal (+ 'swapfile').
    local j = fn.jobstart(vim.tbl_flatten({ args, '--embed' }), { rpc = true })
    fn.rpcrequest(
      j,
      'nvim_exec2',
      [[
      set nofsync directory=Xtest_startup_swapdir
      edit Xtest_startup_file2
      write
      put ='fsyncd text'
    ]],
      {}
    )
    eq('Xtest_startup_swapdir', fn.rpcrequest(j, 'nvim_eval', '&directory'))
    fn.jobstop(j) -- Send deadly signal.

    local screen = startup()
    feed(':recover Xtest_startup_file2<cr>')
    screen:expect({ any = [[Using swap file "Xtest_startup_swapdir[/\]Xtest_startup_file2%.swp"]] })
    feed('<cr>')
    screen:expect({ any = 'fsyncd text' })

    -- 5. SIGPWR signal.
    -- oldtest: Test_signal_PWR()
  end)

  it('backup #9709', function()
    skip(is_ci('cirrus'))
    clear({
      args = {
        '-i',
        'Xtest_startup_shada',
        '--cmd',
        'set directory=Xtest_startup_swapdir',
      },
    })

    command('write Xtest_startup_file1')
    feed('ifoo<esc>')
    command('set backup')
    command('set backupcopy=yes')
    command('write')
    feed('Abar<esc>')
    command('write')

    local foobar_contents = trim(read_file('Xtest_startup_file1'))
    local bar_contents = trim(read_file('Xtest_startup_file1~'))

    eq('foobar', foobar_contents)
    eq('foo', bar_contents)
  end)

  it('backup with full path #11214', function()
    skip(is_ci('cirrus'))
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
    local backup_file_name = string.gsub(
      currentdir() .. '/Xtest_startup_file1',
      is_os('win') and '[:/\\]' or '/',
      '%%'
    ) .. '~'
    local foo_contents = trim(read_file('Xtest_backupdir/' .. backup_file_name))
    local foobar_contents = trim(read_file('Xtest_startup_file1'))

    eq('foobar', foobar_contents)
    eq('foo', foo_contents)
  end)

  it('backup with full path with spaces', function()
    skip(is_ci('cirrus'))
    clear()
    mkdir('Xtest_backupdir with spaces')
    command('set backup')
    command('set backupdir=Xtest_backupdir\\ with\\ spaces//')
    command('write Xtest_startup_file1')
    feed('ifoo<esc>')
    command('write')
    feed('Abar<esc>')
    command('write')

    -- Backup filename = fullpath, separators replaced with "%".
    local backup_file_name = string.gsub(
      currentdir() .. '/Xtest_startup_file1',
      is_os('win') and '[:/\\]' or '/',
      '%%'
    ) .. '~'
    local foo_contents = trim(read_file('Xtest_backupdir with spaces/' .. backup_file_name))
    local foobar_contents = trim(read_file('Xtest_startup_file1'))

    eq('foobar', foobar_contents)
    eq('foo', foo_contents)
  end)

  it('backup symlinked files #11349', function()
    skip(is_ci('cirrus'))
    clear()

    local initial_content = 'foo'
    local link_file_name = 'Xtest_startup_file2'
    local backup_file_name = link_file_name .. '~'

    write_file('Xtest_startup_file1', initial_content, false)
    uv.fs_symlink('Xtest_startup_file1', link_file_name)
    command('set backup')
    command('set backupcopy=yes')
    command('edit ' .. link_file_name)
    feed('Abar<esc>')
    command('write')

    local backup_raw = read_file(backup_file_name)
    neq(nil, backup_raw, 'Expected backup file ' .. backup_file_name .. 'to exist but did not')
    eq(initial_content, trim(backup_raw), 'Expected backup to contain original contents')
  end)

  it('backup symlinked files in first available backupdir #11349', function()
    skip(is_ci('cirrus'))
    clear()

    local initial_content = 'foo'
    local backup_dir = 'Xtest_backupdir'
    local sep = t.get_pathsep()
    local link_file_name = 'Xtest_startup_file2'
    local backup_file_name = backup_dir .. sep .. link_file_name .. '~'

    write_file('Xtest_startup_file1', initial_content, false)
    uv.fs_symlink('Xtest_startup_file1', link_file_name)
    mkdir(backup_dir)
    command('set backup')
    command('set backupcopy=yes')
    command('set backupdir=.__this_does_not_exist__,' .. backup_dir)
    command('edit ' .. link_file_name)
    feed('Abar<esc>')
    command('write')

    local backup_raw = read_file(backup_file_name)
    neq(nil, backup_raw, 'Expected backup file ' .. backup_file_name .. ' to exist but did not')
    eq(initial_content, trim(backup_raw), 'Expected backup to contain original contents')
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
    fn.writefile(text, fname, 's')
    table.insert(text, '')
    eq(text, fn.readfile(fname, 'b'))
  end)
  it("read invalid u8 over INT_MAX doesn't segfault", function()
    clear()
    command('call writefile(0zFFFFFFFF, "Xtest-u8-int-max")')
    -- This should not segfault
    command('edit ++enc=utf32 Xtest-u8-int-max')
    assert_alive()
  end)

  it(':w! does not show "file has been changed" warning', function()
    clear()
    write_file('Xtest-overwrite-forced', 'foobar')
    command('set nofixendofline')
    local screen = Screen.new(40, 4)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = { bold = true, foreground = Screen.colors.SeaGreen4 },
    })
    screen:attach()
    command('set shortmess-=F')

    command('e Xtest-overwrite-forced')
    screen:expect([[
      ^foobar                                  |
      {1:~                                       }|*2
      "Xtest-overwrite-forced" [noeol] 1L, 6B |
    ]])

    -- Get current unix time.
    local cur_unix_time = os.time(os.date('!*t'))
    local future_time = cur_unix_time + 999999
    -- Set the file's access/update time to be
    -- greater than the time at which it was created.
    uv.fs_utime('Xtest-overwrite-forced', future_time, future_time)
    -- use async feed_command because nvim basically hangs on the prompt
    feed_command('w')
    screen:expect([[
      {2:WARNING: The file has been changed since}|
      {2: reading it!!!}                          |
      {3:Do you really want to write to it (y/n)?}|
      ^                                        |
    ]])

    feed('n')
    feed('<cr>')
    screen:expect([[
      ^foobar                                  |
      {1:~                                       }|*2
                                              |
    ]])
    -- Use a screen test because the warning does not set v:errmsg.
    command('w!')
    screen:expect([[
      ^foobar                                  |
      {1:~                                       }|*2
      <erwrite-forced" [noeol] 1L, 6B written |
    ]])
  end)
end)

describe('tmpdir', function()
  local tmproot_pat = [=[.*[/\\]nvim%.[^/\\]+]=]
  local testlog = 'Xtest_tmpdir_log'
  local os_tmpdir

  before_each(function()
    -- Fake /tmp dir so that we can mess it up.
    os_tmpdir = vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname()) .. '/nvim_XXXXXXXXXX')
  end)

  after_each(function()
    check_close()
    os.remove(testlog)
  end)

  local function get_tmproot()
    -- Tempfiles typically look like: "…/nvim.<user>/xxx/0".
    --  - "…/nvim.<user>/xxx/" is the per-process tmpdir, not shared with other Nvims.
    --  - "…/nvim.<user>/" is the tmpdir root, shared by all Nvims (normally).
    local tmproot = (fn.tempname()):match(tmproot_pat)
    ok(tmproot:len() > 4, 'tmproot like "nvim.foo"', tmproot)
    return tmproot
  end

  it('failure modes', function()
    clear({ env = { NVIM_LOG_FILE = testlog, TMPDIR = os_tmpdir } })
    assert_nolog('tempdir is not a directory', testlog)
    assert_nolog('tempdir has invalid permissions', testlog)

    local tmproot = get_tmproot()

    -- Test how Nvim handles invalid tmpdir root (by hostile users or accidents).
    --
    -- "…/nvim.<user>/" is not a directory:
    expect_exit(command, ':qall!')
    rmdir(tmproot)
    write_file(tmproot, '') -- Not a directory, vim_mktempdir() should skip it.
    clear({ env = { NVIM_LOG_FILE = testlog, TMPDIR = os_tmpdir } })
    matches(tmproot_pat, fn.stdpath('run')) -- Tickle vim_mktempdir().
    -- Assert that broken tmpdir root was handled.
    assert_log('tempdir root not a directory', testlog, 100)

    -- "…/nvim.<user>/" has wrong permissions:
    skip(is_os('win'), 'TODO(justinmk): need setfperm/getfperm on Windows. #8244')
    os.remove(testlog)
    os.remove(tmproot)
    mkdir(tmproot)
    fn.setfperm(tmproot, 'rwxr--r--') -- Invalid permissions, vim_mktempdir() should skip it.
    clear({ env = { NVIM_LOG_FILE = testlog, TMPDIR = os_tmpdir } })
    matches(tmproot_pat, fn.stdpath('run')) -- Tickle vim_mktempdir().
    -- Assert that broken tmpdir root was handled.
    assert_log('tempdir root has invalid permissions', testlog, 100)
  end)

  it('too long', function()
    local bigname = ('%s/%s'):format(os_tmpdir, ('x'):rep(666))
    mkdir(bigname)
    clear({ env = { NVIM_LOG_FILE = testlog, TMPDIR = bigname } })
    matches(tmproot_pat, fn.stdpath('run')) -- Tickle vim_mktempdir().
    local len = (fn.tempname()):len()
    ok(len > 4 and len < 256, '4 < len < 256', tostring(len))
  end)

  it('disappeared #1432', function()
    clear({ env = { NVIM_LOG_FILE = testlog, TMPDIR = os_tmpdir } })
    assert_nolog('tempdir disappeared', testlog)

    local function rm_tmpdir()
      local tmpname1 = fn.tempname()
      local tmpdir1 = fn.fnamemodify(tmpname1, ':h')
      eq(fn.stdpath('run'), tmpdir1)

      rmdir(tmpdir1)
      retry(nil, 1000, function()
        eq(0, fn.isdirectory(tmpdir1))
      end)
      local tmpname2 = fn.tempname()
      local tmpdir2 = fn.fnamemodify(tmpname2, ':h')
      neq(tmpdir1, tmpdir2)
    end

    -- Your antivirus hates you...
    rm_tmpdir()
    assert_log('tempdir disappeared', testlog, 100)
    fn.tempname()
    fn.tempname()
    fn.tempname()
    eq('', api.nvim_get_vvar('errmsg'))
    rm_tmpdir()
    fn.tempname()
    fn.tempname()
    fn.tempname()
    eq('E5431: tempdir disappeared (2 times)', api.nvim_get_vvar('errmsg'))
    rm_tmpdir()
    eq('E5431: tempdir disappeared (3 times)', api.nvim_get_vvar('errmsg'))
  end)

  it('$NVIM_APPNAME relative path', function()
    clear({
      env = {
        NVIM_APPNAME = 'a/b',
        NVIM_LOG_FILE = testlog,
        TMPDIR = os_tmpdir,
      },
    })
    matches([=[.*[/\\]a%%b%.[^/\\]+]=], fn.tempname())
  end)
end)
