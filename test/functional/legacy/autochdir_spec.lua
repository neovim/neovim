local t = require('test.functional.testutil')(after_each)
local clear, eq, matches = t.clear, t.eq, t.matches
local eval, command, call, api = t.eval, t.command, t.call, t.api
local source, exec_capture = t.source, t.exec_capture
local mkdir = t.mkdir

local function expected_empty()
  eq({}, api.nvim_get_vvar('errors'))
end

describe('autochdir behavior', function()
  local dir = 'Xtest_functional_legacy_autochdir'

  before_each(function()
    mkdir(dir)
    clear()
    command('set shellslash')
  end)

  after_each(function()
    t.rmdir(dir)
  end)

  -- Tests vim/vim#777 without test_autochdir().
  it('sets filename', function()
    command('set acd')
    command('new')
    command('w ' .. dir .. '/Xtest')
    eq('Xtest', eval("expand('%')"))
    eq(dir, eval([[substitute(getcwd(), '.*/\(\k*\)', '\1', '')]]))
  end)

  it(':file in win_execute() does not cause wrong directory', function()
    command('cd ' .. dir)
    source([[
      func Test_set_filename_other_window()
        let cwd = getcwd()
        call mkdir('Xa')
        call mkdir('Xb')
        call mkdir('Xc')
        try
          args Xa/aaa.txt Xb/bbb.txt
          set acd
          let winid = win_getid()
          snext
          call assert_equal('Xb', substitute(getcwd(), '.*/\([^/]*\)$', '\1', ''))
          call win_execute(winid, 'file ' .. cwd .. '/Xc/ccc.txt')
          call assert_equal('Xb', substitute(getcwd(), '.*/\([^/]*\)$', '\1', ''))
        finally
          set noacd
          call chdir(cwd)
          call delete('Xa', 'rf')
          call delete('Xb', 'rf')
          call delete('Xc', 'rf')
          bwipe! aaa.txt
          bwipe! bbb.txt
          bwipe! ccc.txt
        endtry
      endfunc
    ]])
    call('Test_set_filename_other_window')
    expected_empty()
  end)

  it('win_execute() does not change directory', function()
    local subdir = 'Xfile'
    command('cd ' .. dir)
    command('set acd')
    call('mkdir', subdir)
    local winid = eval('win_getid()')
    command('new ' .. subdir .. '/file')
    matches(dir .. '/' .. subdir .. '$', eval('getcwd()'))
    command('cd ..')
    matches(dir .. '$', eval('getcwd()'))
    call('win_execute', winid, 'echo')
    matches(dir .. '$', eval('getcwd()'))
  end)

  it(':verbose pwd shows whether autochdir is used', function()
    local subdir = 'Xautodir'
    command('cd ' .. dir)
    local cwd = eval('getcwd()')
    command('edit global.txt')
    matches('%[global%].*' .. dir .. '$', exec_capture('verbose pwd'))
    call('mkdir', subdir)
    command('split ' .. subdir .. '/local.txt')
    command('lcd ' .. subdir)
    matches('%[window%].*' .. dir .. '/' .. subdir .. '$', exec_capture('verbose pwd'))
    command('set acd')
    command('wincmd w')
    matches('%[autochdir%].*' .. dir .. '$', exec_capture('verbose pwd'))
    command('tcd ' .. cwd)
    matches('%[tabpage%].*' .. dir .. '$', exec_capture('verbose pwd'))
    command('cd ' .. cwd)
    matches('%[global%].*' .. dir .. '$', exec_capture('verbose pwd'))
    command('lcd ' .. cwd)
    matches('%[window%].*' .. dir .. '$', exec_capture('verbose pwd'))
    command('edit')
    matches('%[autochdir%].*' .. dir .. '$', exec_capture('verbose pwd'))
    command('enew')
    command('wincmd w')
    matches('%[autochdir%].*' .. dir .. '/' .. subdir .. '$', exec_capture('verbose pwd'))
    command('wincmd w')
    matches('%[window%].*' .. dir .. '$', exec_capture('verbose pwd'))
    command('wincmd w')
    matches('%[autochdir%].*' .. dir .. '/' .. subdir .. '$', exec_capture('verbose pwd'))
    command('set noacd')
    matches('%[autochdir%].*' .. dir .. '/' .. subdir .. '$', exec_capture('verbose pwd'))
    command('wincmd w')
    matches('%[window%].*' .. dir .. '$', exec_capture('verbose pwd'))
    command('cd ' .. cwd)
    matches('%[global%].*' .. dir .. '$', exec_capture('verbose pwd'))
    command('wincmd w')
    matches('%[window%].*' .. dir .. '/' .. subdir .. '$', exec_capture('verbose pwd'))
  end)
end)
