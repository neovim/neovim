local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local request = n.request
local is_os = t.is_os

describe('autocmd DirChanged and DirChangedPre', function()
  local curdir = t.fix_slashes(vim.uv.cwd())
  local dirs = {
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir1',
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir2',
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir3',
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir4',
  }
  local win_dirs = {
    curdir .. '\\XTEST-FUNCTIONAL-AUTOCMD-DIRCHANGED.DIR1',
    curdir .. '\\XTEST-FUNCTIONAL-AUTOCMD-DIRCHANGED.DIR2',
    curdir .. '\\XTEST-FUNCTIONAL-AUTOCMD-DIRCHANGED.DIR3',
  }

  setup(function()
    for _, dir in pairs(dirs) do
      t.mkdir(dir)
    end
  end)
  teardown(function()
    for _, dir in pairs(dirs) do
      n.rmdir(dir)
    end
  end)

  before_each(function()
    clear()
    command(
      'autocmd DirChangedPre * let [g:evpre, g:amatchpre, g:cdprecount] '
        .. '= [copy(v:event), expand("<amatch>"), 1 + get(g:, "cdprecount", 0)]'
    )
    command(
      'autocmd DirChanged * let [g:getcwd, g:ev, g:amatch, g:cdcount] '
        .. '= [getcwd(), copy(v:event), expand("<amatch>"), 1 + get(g:, "cdcount", 0)]'
    )
    -- Normalize path separators.
    command(
      [[autocmd DirChangedPre * let g:evpre['directory'] = substitute(g:evpre['directory'], '\\', '/', 'g')]]
    )
    command([[autocmd DirChanged * let g:ev['cwd'] = substitute(g:ev['cwd'], '\\', '/', 'g')]])
    command([[autocmd DirChanged * let g:getcwd = substitute(g:getcwd, '\\', '/', 'g')]])
  end)

  it('set v:event and <amatch>', function()
    command('lcd ' .. dirs[1])
    eq({ directory = dirs[1], scope = 'window', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[1], scope = 'window', changed_window = false }, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq('window', eval('g:amatch'))
    eq(1, eval('g:cdprecount'))
    eq(1, eval('g:cdcount'))

    command('bcd ' .. dirs[2])
    eq({ directory = dirs[2], scope = 'buffer', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'buffer', changed_window = false }, eval('g:ev'))
    eq('buffer', eval('g:amatchpre'))
    eq('buffer', eval('g:amatch'))
    eq(2, eval('g:cdprecount'))
    eq(2, eval('g:cdcount'))

    command('tcd ' .. dirs[3])
    eq({ directory = dirs[3], scope = 'tabpage', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[3], scope = 'tabpage', changed_window = false }, eval('g:ev'))
    eq('tabpage', eval('g:amatchpre'))
    eq('tabpage', eval('g:amatch'))
    eq(3, eval('g:cdprecount'))
    eq(3, eval('g:cdcount'))

    command('cd ' .. dirs[4])
    eq({ directory = dirs[4], scope = 'global', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[4], scope = 'global', changed_window = false }, eval('g:ev'))
    eq('global', eval('g:amatchpre'))
    eq('global', eval('g:amatch'))
    eq(4, eval('g:cdprecount'))
    eq(4, eval('g:cdcount'))
  end)

  it('DirChanged set getcwd() during event #6260', function()
    command('lcd ' .. dirs[1])
    eq(dirs[1], eval('g:getcwd'))

    command('bcd ' .. dirs[2])
    eq(dirs[2], eval('g:getcwd'))

    command('tcd ' .. dirs[3])
    eq(dirs[3], eval('g:getcwd'))

    command('cd ' .. dirs[4])
    eq(dirs[4], eval('g:getcwd'))
  end)

  it('disallow recursion', function()
    command('set shellslash')
    -- Set up a _nested_ handler.
    command('autocmd DirChanged * nested lcd ' .. dirs[3])
    command('lcd ' .. dirs[1])
    eq({ cwd = dirs[1], scope = 'window', changed_window = false }, eval('g:ev'))
    eq(1, eval('g:cdcount'))
    -- autocmd changed to dirs[3], but did NOT trigger another DirChanged.
    eq(dirs[3], eval('getcwd()'))
  end)

  it('only DirChangedPre is triggered if :cd fails', function()
    command('let g:ev = {}')
    command('let g:cdcount = 0')

    local status1, err1 = pcall(function()
      command('lcd ' .. dirs[1] .. '/doesnotexist')
    end)
    eq(
      { directory = dirs[1] .. '/doesnotexist', scope = 'window', changed_window = false },
      eval('g:evpre')
    )
    eq({}, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq(1, eval('g:cdprecount'))
    eq(0, eval('g:cdcount'))

    local status2, err2 = pcall(function()
      command('lcd ' .. dirs[2] .. '/doesnotexist')
    end)
    eq(
      { directory = dirs[2] .. '/doesnotexist', scope = 'window', changed_window = false },
      eval('g:evpre')
    )
    eq({}, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq(2, eval('g:cdprecount'))
    eq(0, eval('g:cdcount'))

    local status3, err3 = pcall(function()
      command('lcd ' .. dirs[3] .. '/doesnotexist')
    end)
    eq(
      { directory = dirs[3] .. '/doesnotexist', scope = 'window', changed_window = false },
      eval('g:evpre')
    )
    eq({}, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq(3, eval('g:cdprecount'))
    eq(0, eval('g:cdcount'))

    eq(false, status1)
    eq(false, status2)
    eq(false, status3)

    eq('E344:', string.match(err1, 'E%d*:'))
    eq('E344:', string.match(err2, 'E%d*:'))
    eq('E344:', string.match(err3, 'E%d*:'))
  end)

  it("are triggered by 'autochdir'", function()
    command('set autochdir')

    command('split ' .. dirs[1] .. '/foo')
    eq({ directory = dirs[1], scope = 'window', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[1], scope = 'window', changed_window = false }, eval('g:ev'))
    eq('auto', eval('g:amatchpre'))
    eq('auto', eval('g:amatch'))
    eq(1, eval('g:cdprecount'))
    eq(1, eval('g:cdcount'))

    command('split ' .. dirs[2] .. '/bar')
    eq({ directory = dirs[2], scope = 'window', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'window', changed_window = false }, eval('g:ev'))
    eq('auto', eval('g:amatch'))
    eq(2, eval('g:cdprecount'))
    eq(2, eval('g:cdcount'))
  end)

  it('do not trigger if directory has not changed', function()
    command('lcd ' .. dirs[1])
    eq({ directory = dirs[1], scope = 'window', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[1], scope = 'window', changed_window = false }, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq('window', eval('g:amatch'))
    eq(1, eval('g:cdprecount'))
    eq(1, eval('g:cdcount'))
    command('let g:evpre = {}')
    command('let g:ev = {}')
    command('lcd ' .. dirs[1])
    eq({}, eval('g:evpre'))
    eq({}, eval('g:ev'))
    eq(1, eval('g:cdprecount'))
    eq(1, eval('g:cdcount'))

    if is_os('win') then
      command('lcd ' .. win_dirs[1])
      eq({}, eval('g:evpre'))
      eq({}, eval('g:ev'))
      eq(1, eval('g:cdprecount'))
      eq(1, eval('g:cdcount'))
    end

    command('tcd ' .. dirs[2])
    eq({ directory = dirs[2], scope = 'tabpage', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'tabpage', changed_window = false }, eval('g:ev'))
    eq('tabpage', eval('g:amatchpre'))
    eq('tabpage', eval('g:amatch'))
    eq(2, eval('g:cdprecount'))
    eq(2, eval('g:cdcount'))
    command('let g:evpre = {}')
    command('let g:ev = {}')
    command('tcd ' .. dirs[2])
    eq({}, eval('g:evpre'))
    eq({}, eval('g:ev'))
    eq(2, eval('g:cdprecount'))
    eq(2, eval('g:cdcount'))

    if is_os('win') then
      command('tcd ' .. win_dirs[2])
      eq({}, eval('g:evpre'))
      eq({}, eval('g:ev'))
      eq(2, eval('g:cdprecount'))
      eq(2, eval('g:cdcount'))
    end

    command('tcd ' .. dirs[3])
    eq({ directory = dirs[3], scope = 'tabpage', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[3], scope = 'tabpage', changed_window = false }, eval('g:ev'))
    eq('tabpage', eval('g:amatchpre'))
    eq('tabpage', eval('g:amatch'))
    eq(3, eval('g:cdprecount'))
    eq(3, eval('g:cdcount'))
    command('let g:evpre = {}')
    command('let g:ev = {}')
    command('tcd ' .. dirs[3])
    eq({}, eval('g:evpre'))
    eq({}, eval('g:ev'))
    eq(3, eval('g:cdprecount'))
    eq(3, eval('g:cdcount'))

    if is_os('win') then
      command('tcd ' .. win_dirs[3])
      eq({}, eval('g:evpre'))
      eq({}, eval('g:ev'))
      eq(3, eval('g:cdprecount'))
      eq(3, eval('g:cdcount'))
    end

    command('cd ' .. dirs[4])
    eq({ directory = dirs[4], scope = 'global', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[4], scope = 'global', changed_window = false }, eval('g:ev'))
    eq('global', eval('g:amatch'))
    eq(4, eval('g:cdprecount'))
    eq(4, eval('g:cdcount'))
    command('let g:evpre = {}')
    command('let g:ev = {}')
    command('cd ' .. dirs[4])
    eq({}, eval('g:evpre'))
    eq({}, eval('g:ev'))
    eq(4, eval('g:cdprecount'))
    eq(4, eval('g:cdcount'))

    if is_os('win') then
      command('cd ' .. dirs[4])
      eq({}, eval('g:evpre'))
      eq({}, eval('g:ev'))
      eq(4, eval('g:cdprecount'))
      eq(4, eval('g:cdcount'))
    end

    command('set autochdir')

    command('split ' .. dirs[2] .. '/foo')
    eq({ directory = dirs[2], scope = 'window', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'window', changed_window = false }, eval('g:ev'))
    eq('auto', eval('g:amatchpre'))
    eq('auto', eval('g:amatch'))
    eq(5, eval('g:cdprecount'))
    eq(5, eval('g:cdcount'))
    command('let g:evpre = {}')
    command('let g:ev = {}')
    command('split ' .. dirs[2] .. '/bar')
    eq({}, eval('g:evpre'))
    eq({}, eval('g:ev'))
    eq(5, eval('g:cdprecount'))
    eq(5, eval('g:cdcount'))

    if is_os('win') then
      command('split ' .. win_dirs[2] .. '/baz')
      eq({}, eval('g:evpre'))
      eq({}, eval('g:ev'))
      eq(5, eval('g:cdprecount'))
      eq(5, eval('g:cdcount'))
    end
  end)

  it('are triggered by switching to win/tab with different CWD #6054', function()
    command('lcd ' .. dirs[3]) -- window 3
    command('split ' .. dirs[2] .. '/foo') -- window 2
    command('lcd ' .. dirs[2])
    command('split ' .. dirs[1] .. '/bar') -- window 1
    command('lcd ' .. dirs[1])

    command('2wincmd w') -- window 2
    eq({ directory = dirs[2], scope = 'window', changed_window = true }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'window', changed_window = true }, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq('window', eval('g:amatch'))

    eq(4, eval('g:cdprecount'))
    eq(4, eval('g:cdcount'))
    command('tabnew') -- tab 2 (tab-local CWD)
    eq(4, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
    eq(4, eval('g:cdcount')) -- same CWD, no DirChanged event
    command('tcd ' .. dirs[3])
    command('tabnext') -- tab 1 (no tab-local CWD)
    eq({ directory = dirs[2], scope = 'window', changed_window = true }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'window', changed_window = true }, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq('window', eval('g:amatch'))
    command('tabnext') -- tab 2
    eq({ directory = dirs[3], scope = 'tabpage', changed_window = true }, eval('g:evpre'))
    eq({ cwd = dirs[3], scope = 'tabpage', changed_window = true }, eval('g:ev'))
    eq('tabpage', eval('g:amatchpre'))
    eq('tabpage', eval('g:amatch'))
    eq(7, eval('g:cdprecount'))
    eq(7, eval('g:cdcount'))

    command('tabnext') -- tab 1
    command('3wincmd w') -- window 3
    eq(9, eval('g:cdprecount'))
    eq(9, eval('g:cdcount'))
    command('tabnext') -- tab 2 (has the *same* CWD)
    eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
    eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event

    if is_os('win') then
      command('tabnew') -- tab 3
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tcd ' .. win_dirs[3])
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabnext') -- tab 1
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabprevious') -- tab 3
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabprevious') -- tab 2
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabprevious') -- tab 1
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('lcd ' .. win_dirs[3]) -- window 3
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabnext') -- tab 2
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabnext') -- tab 3
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabnext') -- tab 1
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabprevious') -- tab 3
      eq(9, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(9, eval('g:cdcount')) -- same CWD, no DirChanged event
    end
  end)

  it('are triggered by switching to buf/tab with different CWD', function()
    local files = {
      dirs[1] .. '/file',
      dirs[2] .. '/file',
      dirs[3] .. '/file',
    }

    command('e ' .. files[3]) -- buffer 3
    command('e ' .. files[2]) -- buffer 2
    command('e ' .. files[1]) -- buffer 1

    command('bcd ' .. dirs[1])
    command('b ' .. files[2]) -- Switch to buffer 2
    command('bcd ' .. dirs[2])
    command('b ' .. files[3]) -- Switch to buffer 3
    command('bcd ' .. dirs[3])

    eq({ directory = dirs[3], scope = 'buffer', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[3], scope = 'buffer', changed_window = false }, eval('g:ev'))
    eq('buffer', eval('g:amatchpre'))
    eq('buffer', eval('g:amatch'))

    eq(5, eval('g:cdprecount'))
    eq(5, eval('g:cdcount'))
    command('tabnew') -- tab 2 (tab-local CWD)
    eq(5, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
    eq(5, eval('g:cdcount')) -- same CWD, no DirChanged event
    command('tcd ' .. dirs[2])
    command('tabnext') -- tab 1 (no tab-local CWD)
    eq({ directory = dirs[3], scope = 'buffer', changed_window = true }, eval('g:evpre'))
    eq({ cwd = dirs[3], scope = 'buffer', changed_window = true }, eval('g:ev'))
    eq('buffer', eval('g:amatchpre'))
    eq('buffer', eval('g:amatch'))
    command('tabnext') -- tab 2
    eq({ directory = dirs[2], scope = 'tabpage', changed_window = true }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'tabpage', changed_window = true }, eval('g:ev'))
    eq('tabpage', eval('g:amatchpre'))
    eq('tabpage', eval('g:amatch'))
    eq(8, eval('g:cdprecount'))
    eq(8, eval('g:cdcount'))

    command('tabnext') -- tab 1
    command('b ' .. files[2]) -- buffer 2
    eq(10, eval('g:cdprecount'))
    eq(10, eval('g:cdcount'))
    command('tabnext') -- tab 2 (has the *same* CWD)
    eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
    eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event

    if is_os('win') then
      command('tabnew') -- tab 3
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tcd ' .. dirs[2])
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabnext') -- tab 1
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabprevious') -- tab 3
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabprevious') -- tab 2
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabprevious') -- tab 1
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('bcd ' .. dirs[2]) -- buffer 2
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabnext') -- tab 2
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabnext') -- tab 3
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabnext') -- tab 1
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
      command('tabprevious') -- tab 3
      eq(10, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
      eq(10, eval('g:cdcount')) -- same CWD, no DirChanged event
    end
  end)

  it('are triggered by switching to buf/win with different CWD', function()
    command('lcd ' .. dirs[3]) -- window 3
    command('split ' .. dirs[2] .. '/file') -- window 2
    command('lcd ' .. dirs[2])
    command('split ' .. dirs[1] .. '/file') -- window 1
    command('lcd ' .. dirs[1])

    -- All windows have a window-local CWD

    command('2wincmd w') -- window 2
    eq({ directory = dirs[2], scope = 'window', changed_window = true }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'window', changed_window = true }, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq('window', eval('g:amatch'))

    eq(4, eval('g:cdprecount'))
    eq(4, eval('g:cdcount'))
    command('bcd ' .. dirs[1]) -- window 2 now has a buffer with buffer-local CWD (and no window-local CWD)
    eq({ directory = dirs[1], scope = 'buffer', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[1], scope = 'buffer', changed_window = false }, eval('g:ev'))
    eq('buffer', eval('g:amatchpre'))
    eq('buffer', eval('g:amatch'))
    eq(5, eval('g:cdprecount'))
    eq(5, eval('g:cdcount'))
    command('3wincmd w') -- window 3 (window-local CWD)
    eq(6, eval('g:cdprecount'))
    eq(6, eval('g:cdcount'))
    command('bcd ' .. dirs[2]) -- window 3 now has a buffer with buffer-local CWD (and no window-local CWD)
    command('1wincmd w') -- window 1 (window-local CWD)
    eq({ directory = dirs[1], scope = 'window', changed_window = true }, eval('g:evpre'))
    eq({ cwd = dirs[1], scope = 'window', changed_window = true }, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq('window', eval('g:amatch'))
    command('2wincmd w') -- window 2 (buffer-local CWD)
    eq({ directory = dirs[1], scope = 'window', changed_window = true }, eval('g:evpre')) -- buffer-local CWD
    eq({ cwd = dirs[1], scope = 'window', changed_window = true }, eval('g:ev'))
    eq('window', eval('g:amatchpre'))
    eq('window', eval('g:amatch'))
    eq(8, eval('g:cdprecount'))
    eq(8, eval('g:cdcount'))

    command('1wincmd w') -- window 1 (window-local cwd)
    eq(8, eval('g:cdprecount')) -- same CWD, no DirChangedPre event
    eq(8, eval('g:cdcount')) -- same CWD, no DirChanged event
    command('b ' .. dirs[2] .. '/file') -- buffer 2 (has buffer-local cwd)
    eq(8, eval('g:cdprecount')) -- no DirChangedPre event, window-local CWD has higher priority
    eq(8, eval('g:cdcount')) -- no DirChanged event, window-local CWD has higher priority
  end)

  it('are triggered by nvim_set_current_dir()', function()
    request('nvim_set_current_dir', dirs[1])
    eq({ directory = dirs[1], scope = 'global', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[1], scope = 'global', changed_window = false }, eval('g:ev'))
    eq(1, eval('g:cdprecount'))
    eq(1, eval('g:cdcount'))

    request('nvim_set_current_dir', dirs[2])
    eq({ directory = dirs[2], scope = 'global', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'global', changed_window = false }, eval('g:ev'))
    eq(2, eval('g:cdprecount'))
    eq(2, eval('g:cdcount'))

    eq(
      'Vim:E344: Can\'t find directory "/doesnotexist" in cdpath',
      t.pcall_err(request, 'nvim_set_current_dir', '/doesnotexist')
    )
    eq({ directory = '/doesnotexist', scope = 'global', changed_window = false }, eval('g:evpre'))
    eq(3, eval('g:cdprecount'))
    eq(2, eval('g:cdcount'))
  end)

  it('work when local to buffer', function()
    command('let g:triggeredpre = 0')
    command('let g:triggered = 0')
    command('autocmd DirChangedPre <buffer> let g:triggeredpre = 1')
    command('autocmd DirChanged <buffer> let g:triggered = 1')
    command('cd ' .. dirs[1])
    eq(1, eval('g:triggeredpre'))
    eq(1, eval('g:triggered'))
  end)
end)
