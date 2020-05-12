local lfs = require('lfs')
local h = require('test.functional.helpers')(after_each)

local clear = h.clear
local command = h.command
local eq = h.eq
local eval = h.eval
local request = h.request

describe('autocmd DirChanged', function()
  local curdir = string.gsub(lfs.currentdir(), '\\', '/')
  local dirs = {
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir1',
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir2',
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir3',
  }

  setup(function()    for _, dir in pairs(dirs) do h.mkdir(dir) end end)
  teardown(function() for _, dir in pairs(dirs) do h.rmdir(dir) end end)

  before_each(function()
    clear()
    command('autocmd DirChanged * let [g:getcwd, g:ev, g:amatch, g:cdcount] '
        ..'  = [getcwd(), copy(v:event), expand("<amatch>"), 1 + get(g:, "cdcount", 0)]')
    -- Normalize path separators.
    command([[autocmd DirChanged * let g:ev['cwd'] = substitute(g:ev['cwd'], '\\', '/', 'g')]])
    command([[autocmd DirChanged * let g:getcwd    = substitute(g:getcwd,    '\\', '/', 'g')]])
  end)

  it('sets v:event', function()
    command('lcd '..dirs[1])
    eq({cwd=dirs[1], scope='window'}, eval('g:ev'))
    eq(1, eval('g:cdcount'))

    command('tcd '..dirs[2])
    eq({cwd=dirs[2], scope='tab'}, eval('g:ev'))
    eq(2, eval('g:cdcount'))

    command('cd '..dirs[3])
    eq({cwd=dirs[3], scope='global'}, eval('g:ev'))
    eq(3, eval('g:cdcount'))
  end)

  it('sets getcwd() during event #6260', function()
    command('lcd '..dirs[1])
    eq(dirs[1], eval('g:getcwd'))

    command('tcd '..dirs[2])
    eq(dirs[2], eval('g:getcwd'))

    command('cd '..dirs[3])
    eq(dirs[3], eval('g:getcwd'))
  end)

  it('disallows recursion', function()
    command('set shellslash')
    -- Set up a _nested_ handler.
    command('autocmd DirChanged * nested lcd '..dirs[3])
    command('lcd '..dirs[1])
    eq({cwd=dirs[1], scope='window'}, eval('g:ev'))
    eq(1, eval('g:cdcount'))
    -- autocmd changed to dirs[3], but did NOT trigger another DirChanged.
    eq(dirs[3], eval('getcwd()'))
  end)

  it('sets <amatch> to CWD "scope"', function()
    command('lcd '..dirs[1])
    eq('window', eval('g:amatch'))

    command('tcd '..dirs[2])
    eq('tab', eval('g:amatch'))

    command('cd '..dirs[3])
    eq('global', eval('g:amatch'))
  end)

  it('does not trigger if :cd fails', function()
    command('let g:ev = {}')

    local status1, err1 = pcall(function()
      command('lcd '..dirs[1] .. '/doesnotexist')
    end)
    eq({}, eval('g:ev'))

    local status2, err2 = pcall(function()
      command('lcd '..dirs[2] .. '/doesnotexist')
    end)
    eq({}, eval('g:ev'))

    local status3, err3 = pcall(function()
      command('lcd '..dirs[3] .. '/doesnotexist')
    end)
    eq({}, eval('g:ev'))

    eq(false, status1)
    eq(false, status2)
    eq(false, status3)

    eq('E344:', string.match(err1, "E%d*:"))
    eq('E344:', string.match(err2, "E%d*:"))
    eq('E344:', string.match(err3, "E%d*:"))
  end)

  it("is triggered by 'autochdir'", function()
    command('set autochdir')

    command('split '..dirs[1]..'/foo')
    eq({cwd=dirs[1], scope='window'}, eval('g:ev'))

    command('split '..dirs[2]..'/bar')
    eq({cwd=dirs[2], scope='window'}, eval('g:ev'))

    eq(2, eval('g:cdcount'))
  end)

  it("is triggered by switching to win/tab with different CWD #6054", function()
    command('lcd '..dirs[3])            -- window 3
    command('split '..dirs[2]..'/foo')  -- window 2
    command('lcd '..dirs[2])
    command('split '..dirs[1]..'/bar')  -- window 1
    command('lcd '..dirs[1])

    command('2wincmd w')                -- window 2
    eq({cwd=dirs[2], scope='window'}, eval('g:ev'))

    eq(4, eval('g:cdcount'))
    command('tabnew')                   -- tab 2 (tab-local CWD)
    eq(4, eval('g:cdcount'))            -- same CWD, no DirChanged event
    command('tcd '..dirs[3])
    command('tabnext')                  -- tab 1 (no tab-local CWD)
    eq({cwd=dirs[2], scope='window'}, eval('g:ev'))
    command('tabnext')                  -- tab 2
    eq({cwd=dirs[3], scope='tab'}, eval('g:ev'))
    eq(7, eval('g:cdcount'))

    command('tabnext')                  -- tab 1
    command('3wincmd w')                -- window 3
    eq(9, eval('g:cdcount'))
    command('tabnext')                  -- tab 2 (has the *same* CWD)
    eq(9, eval('g:cdcount'))            -- same CWD, no DirChanged event
  end)

  it('is triggered by nvim_set_current_dir()', function()
    request('nvim_set_current_dir', dirs[1])
    eq({cwd=dirs[1], scope='global'}, eval('g:ev'))

    request('nvim_set_current_dir', dirs[2])
    eq({cwd=dirs[2], scope='global'}, eval('g:ev'))

    local status, err = pcall(function()
      request('nvim_set_current_dir', '/doesnotexist')
    end)
    eq(false, status)
    eq('Failed to change directory', string.match(err, ': (.*)'))
    eq({cwd=dirs[2], scope='global'}, eval('g:ev'))
  end)

  it('works when local to buffer', function()
    command('let g:triggered = 0')
    command('autocmd DirChanged <buffer> let g:triggered = 1')
    command('cd '..dirs[1])
    eq(1, eval('g:triggered'))
  end)
end)
