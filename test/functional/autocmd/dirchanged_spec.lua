local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, setup, teardown =
  t.describe, t.it, t.before_each, t.setup, t.teardown
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
  -- The same directories spelled with backslashes and uppercase: on Windows (case-insensitive)
  -- filesystem) they name the same directories, so changing to them must not fire DirChanged.
  local win_dirs = vim.tbl_map(function(d)
    return (d:upper():gsub('/', '\\'))
  end, dirs)

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

  --- Runs `cmd` and asserts that it fires no DirChangedPre/DirChanged event.
  local function assert_no_event(cmd)
    local counts = eval('[g:cdprecount, g:cdcount]')
    command('let [g:evpre, g:ev] = [{}, {}]')
    command(cmd)
    eq({}, eval('g:evpre'))
    eq({}, eval('g:ev'))
    eq(counts, eval('[g:cdprecount, g:cdcount]'))
  end

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

  it("triggered by 'autochdir'", function()
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

  it('not triggered if directory has not changed', function()
    local scopes = { lcd = 'window', bcd = 'buffer', tcd = 'tabpage', cd = 'global' }
    for i, cmd in ipairs({ 'lcd', 'bcd', 'tcd', 'cd' }) do
      local scope = scopes[cmd]
      command(('%s %s'):format(cmd, dirs[i]))
      eq({ directory = dirs[i], scope = scope, changed_window = false }, eval('g:evpre'))
      eq({ cwd = dirs[i], scope = scope, changed_window = false }, eval('g:ev'))
      eq(scope, eval('g:amatchpre'))
      eq(scope, eval('g:amatch'))
      eq(i, eval('g:cdprecount'))
      eq(i, eval('g:cdcount'))
      assert_no_event(('%s %s'):format(cmd, dirs[i]))
      if is_os('win') then
        assert_no_event(('%s %s'):format(cmd, win_dirs[i]))
      end
    end

    command('set autochdir')

    command(('split %s/foo'):format(dirs[2]))
    eq({ directory = dirs[2], scope = 'window', changed_window = false }, eval('g:evpre'))
    eq({ cwd = dirs[2], scope = 'window', changed_window = false }, eval('g:ev'))
    eq('auto', eval('g:amatchpre'))
    eq('auto', eval('g:amatch'))
    eq(5, eval('g:cdprecount'))
    eq(5, eval('g:cdcount'))
    assert_no_event(('split %s/bar'):format(dirs[2]))
    if is_os('win') then
      assert_no_event(('split %s/baz'):format(win_dirs[2]))
    end
  end)

  it('triggered by switching to win/tab with different CWD #6054', function()
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
    assert_no_event('tabnew') -- tab 2 (same CWD)
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
    assert_no_event('tabnext') -- tab 2 (has the *same* CWD)

    if is_os('win') then
      assert_no_event('tabnew') -- tab 3 (same CWD)
      assert_no_event('tcd ' .. win_dirs[3])
      assert_no_event('tabnext') -- tab 1
      assert_no_event('tabprevious') -- tab 3
      assert_no_event('tabprevious') -- tab 2
      assert_no_event('tabprevious') -- tab 1
      assert_no_event('lcd ' .. win_dirs[3]) -- window 3
      assert_no_event('tabnext') -- tab 2
      assert_no_event('tabnext') -- tab 3
      assert_no_event('tabnext') -- tab 1
      assert_no_event('tabprevious') -- tab 3
    end
  end)

  it('triggered by switching to buf/tab with different CWD', function()
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
    command('tabnew') -- tab 2: its new empty buffer has no local CWD, reverts to global
    eq({ cwd = curdir, scope = 'global', changed_window = false }, eval('g:ev'))
    eq(6, eval('g:cdprecount'))
    eq(6, eval('g:cdcount'))
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
    eq(9, eval('g:cdprecount'))
    eq(9, eval('g:cdcount'))

    command('tabnext') -- tab 1
    command('b ' .. files[2]) -- buffer 2
    eq(11, eval('g:cdprecount'))
    eq(11, eval('g:cdcount'))
    assert_no_event('tabnext') -- tab 2 (has the *same* CWD)

    if is_os('win') then
      assert_no_event('tabnew') -- tab 3 (same CWD: inherits the tab-local CWD)
      assert_no_event('tcd ' .. win_dirs[2])
      assert_no_event('tabnext') -- tab 1
      assert_no_event('tabprevious') -- tab 3
      assert_no_event('tabprevious') -- tab 2
      assert_no_event('tabprevious') -- tab 1
      assert_no_event('bcd ' .. win_dirs[2]) -- buffer 2
      assert_no_event('tabnext') -- tab 2
      assert_no_event('tabnext') -- tab 3
      assert_no_event('tabnext') -- tab 1
      assert_no_event('tabprevious') -- tab 3
    end
  end)

  it('triggered by switching to buf/win with different CWD', function()
    command('lcd ' .. dirs[3]) -- window 3
    command(('split %s/file'):format(dirs[2])) -- window 2
    command('lcd ' .. dirs[2])
    command(('split %s/file'):format(dirs[1])) -- window 1
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

    assert_no_event('1wincmd w') -- window 1 (window-local cwd)
    -- No event: window-local CWD has higher priority than the buffer-local CWD.
    assert_no_event(('b %s/file'):format(dirs[2])) -- buffer 2 (has buffer-local cwd)
  end)

  it('triggered by nvim_set_current_dir()', function()
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
