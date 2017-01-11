local lfs = require('lfs')
local h = require('test.functional.helpers')(after_each)

local clear = h.clear
local command = h.command
local eq = h.eq
local eval = h.eval
local request = h.request

describe('DirChanged ->', function()
  local curdir = lfs.currentdir()
  local dirs = {
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir1',
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir2',
    curdir .. '/Xtest-functional-autocmd-dirchanged.dir3',
  }

  setup(function()    for _, dir in pairs(dirs) do h.mkdir(dir) end end)
  teardown(function() for _, dir in pairs(dirs) do h.rmdir(dir) end end)

  before_each(function()
    clear()
    command('autocmd DirChanged * let g:event = copy(v:event)')
  end)

  it('"autocmd DirChanged *" sets v:event for all :cd variants', function()
    command('lcd '..dirs[1])
    eq({cwd=dirs[1], scope='window'}, eval('g:event'))

    command('tcd '..dirs[2])
    eq({cwd=dirs[2], scope='tab'}, eval('g:event'))

    command('cd '..dirs[3])
    eq({cwd=dirs[3], scope='global'}, eval('g:event'))
  end)

  it('"autocmd DirChanged *" does not trigger for failing :cd variants', function()
    command('let g:event = {}')

    local status1, err1 = pcall(function()
      command('lcd '..dirs[1] .. '/doesnotexist')
    end)
    eq({}, eval('g:event'))

    local status2, err2 = pcall(function()
      command('lcd '..dirs[2] .. '/doesnotexist')
    end)
    eq({}, eval('g:event'))

    local status3, err3 = pcall(function()
      command('lcd '..dirs[3] .. '/doesnotexist')
    end)
    eq({}, eval('g:event'))

    eq(false, status1)
    eq(false, status2)
    eq(false, status3)

    eq('E344', string.match(err1, 'Vim.*:(.*):'))
    eq('E344', string.match(err2, 'Vim.*:(.*):'))
    eq('E344', string.match(err3, 'Vim.*:(.*):'))
  end)

  it("'autochdir' triggers DirChanged", function()
    command('set autochdir')

    command('split '..dirs[1]..'/foo')
    eq({cwd=dirs[1], scope='window'}, eval('g:event'))

    command('split '..dirs[2]..'/bar')
    eq({cwd=dirs[2], scope='window'}, eval('g:event'))
  end)

  it('nvim_set_current_dir() triggers DirChanged', function()
    request('nvim_set_current_dir', dirs[1])
    eq({cwd=dirs[1], scope='global'}, eval('g:event'))

    request('nvim_set_current_dir', dirs[2])
    eq({cwd=dirs[2], scope='global'}, eval('g:event'))

    local status, err = pcall(function()
      request('nvim_set_current_dir', '/doesnotexist')
    end)
    eq(false, status)
    eq('Failed to change directory', string.match(err, ': (.*)'))
    eq({cwd=dirs[2], scope='global'}, eval('g:event'))
  end)
end)
