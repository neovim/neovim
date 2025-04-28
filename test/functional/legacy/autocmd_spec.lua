local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local write_file = t.write_file
local command = n.command
local feed = n.feed
local api = n.api
local eq = t.eq

before_each(clear)

-- oldtest: Test_autocmd_invalidates_undo_on_textchanged()
it('no E440 in quickfix window when autocommand invalidates undo', function()
  write_file(
    'XTest_autocmd_invalidates_undo_on_textchanged',
    [[
    set hidden
    " create quickfix list (at least 2 lines to move line)
    vimgrep /u/j %

    " enter quickfix window
    cwindow

    " set modifiable
    setlocal modifiable

    " set autocmd to clear quickfix list

    autocmd! TextChanged <buffer> call setqflist([])
    " move line
    move+1
    ]]
  )
  finally(function()
    os.remove('XTest_autocmd_invalidates_undo_on_textchanged')
  end)
  command('edit XTest_autocmd_invalidates_undo_on_textchanged')
  command('so %')
  feed('G')
  eq('', api.nvim_get_vvar('errmsg'))
end)

-- oldtest: Test_WinScrolled_Resized_eiw()
it('WinScrolled and WinResized events can be ignored in a window', function()
  local screen = Screen.new()
  n.exec([[
    call setline(1, ['foo']->repeat(32))
    set eventignorewin=WinScrolled,WinResized
    split
    let [g:afile,g:resized,g:scrolled] = ['none',0,0]
    au WinScrolled * let [g:afile,g:scrolled] = [expand('<afile>'),g:scrolled+1]
    au WinResized * let [g:afile,g:resized] = [expand('<afile>'),g:resized+1]
  ]])
  feed('<C-W>-')
  screen:expect([[
    ^foo                                                  |
    foo                                                  |*4
    {3:[No Name] [+]                                        }|
    foo                                                  |*6
    {2:[No Name] [+]                                        }|
                                                         |
  ]])
  feed(':echo g:afile g:resized g:scrolled<CR>')
  screen:expect({ any = 'none 0 0.*' })
  feed('G')
  screen:expect([[
    foo                                                  |*4
    ^foo                                                  |
    {3:[No Name] [+]                                        }|
    foo                                                  |*6
    {2:[No Name] [+]                                        }|
    none 0 0                                             |
  ]])
  feed('gg')
  screen:expect([[
    ^foo                                                  |
    foo                                                  |*4
    {3:[No Name] [+]                                        }|
    foo                                                  |*6
    {2:[No Name] [+]                                        }|
    none 0 0                                             |
  ]])
  feed(':echo g:afile g:resized g:scrolled')
  screen:expect({ any = ':echo g:afile g:resized g:scrolled.*' })
  feed('<CR>')
  screen:expect({ any = 'none 0 0.*' })
  feed(':set eventignorewin=<CR><C-W>w<C-W>+')
  screen:expect({ any = ':set eventignorewin=.*' })
  feed(':echo win_getid() g:afile g:resized g:scrolled<CR>')
  screen:expect({ any = '1000 1001 1 1.*' })
end)

-- oldtest: Test_CmdlineLeavePre_cabbr()
it(':cabbr does not cause a spurious CmdlineLeavePre', function()
  command('let g:a = 0')
  command('cabbr v v')
  command('command! -nargs=* Foo echo')
  command('au! CmdlineLeavePre * let g:a += 1')
  feed(':Foo v<CR>')
  eq(1, api.nvim_get_var('a'))
end)
