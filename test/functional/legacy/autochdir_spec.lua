local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)
local clear, eq, matches = helpers.clear, helpers.eq, helpers.matches
local eval, command, call = helpers.eval, helpers.command, helpers.call
local exec_capture = helpers.exec_capture

describe('autochdir behavior', function()
  local dir = 'Xtest_functional_legacy_autochdir'

  before_each(function()
    lfs.mkdir(dir)
    clear()
  end)

  after_each(function()
    helpers.rmdir(dir)
  end)

  -- Tests vim/vim/777 without test_autochdir().
  it('sets filename', function()
    command('set acd')
    command('new')
    command('w '..dir..'/Xtest')
    eq('Xtest', eval("expand('%')"))
    eq(dir, eval([[substitute(getcwd(), '.*[/\\]\(\k*\)', '\1', '')]]))
  end)

  it(':verbose pwd shows whether autochdir is used', function()
    local subdir = 'Xautodir'
    command('cd '..dir)
    local cwd = eval('getcwd()')
    command('edit global.txt')
    matches('%[global%].*'..dir, exec_capture('verbose pwd'))
    call('mkdir', subdir)
    command('split '..subdir..'/local.txt')
    command('lcd '..subdir)
    matches('%[window%].*'..dir..'[/\\]'..subdir, exec_capture('verbose pwd'))
    command('set autochdir')
    command('wincmd w')
    matches('%[autochdir%].*'..dir, exec_capture('verbose pwd'))
    command('lcd '..cwd)
    matches('%[window%].*'..dir, exec_capture('verbose pwd'))
    command('tcd '..cwd)
    matches('%[tabpage%].*'..dir, exec_capture('verbose pwd'))
    command('cd '..cwd)
    matches('%[global%].*'..dir, exec_capture('verbose pwd'))
    command('edit')
    matches('%[autochdir%].*'..dir, exec_capture('verbose pwd'))
    command('wincmd w')
    matches('%[autochdir%].*'..dir..'[/\\]'..subdir, exec_capture('verbose pwd'))
    command('set noautochdir')
    matches('%[autochdir%].*'..dir..'[/\\]'..subdir, exec_capture('verbose pwd'))
    command('wincmd w')
    matches('%[global%].*'..dir, exec_capture('verbose pwd'))
    command('wincmd w')
    matches('%[window%].*'..dir..'[/\\]'..subdir, exec_capture('verbose pwd'))
  end)
end)
