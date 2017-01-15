" Tests for autocommands

func Test_vim_did_enter()
  call assert_false(v:vim_did_enter)

  " This script will never reach the main loop, can't check if v:vim_did_enter
  " becomes one.
endfunc

if has('timers')
  func ExitInsertMode(id)
    call feedkeys("\<Esc>")
  endfunc

  func Test_cursorhold_insert()
    let g:triggered = 0
    au CursorHoldI * let g:triggered += 1
    set updatetime=20
    call timer_start(100, 'ExitInsertMode')
    call feedkeys('a', 'x!')
    call assert_equal(1, g:triggered)
    au! CursorHoldI
  endfunc

  func Test_cursorhold_insert_ctrl_x()
    let g:triggered = 0
    au CursorHoldI * let g:triggered += 1
    set updatetime=20
    call timer_start(100, 'ExitInsertMode')
    " CursorHoldI does not trigger after CTRL-X
    call feedkeys("a\<C-X>", 'x!')
    call assert_equal(0, g:triggered)
    au! CursorHoldI
  endfunc
endif

function Test_bufunload()
  augroup test_bufunload_group
    autocmd!
    autocmd BufUnload * call add(s:li, "bufunload")
    autocmd BufDelete * call add(s:li, "bufdelete")
    autocmd BufWipeout * call add(s:li, "bufwipeout")
  augroup END

  let s:li=[]
  new
  setlocal bufhidden=
  bunload
  call assert_equal(["bufunload", "bufdelete"], s:li)

  let s:li=[]
  new
  setlocal bufhidden=delete
  bunload
  call assert_equal(["bufunload", "bufdelete"], s:li)

  let s:li=[]
  new
  setlocal bufhidden=unload
  bwipeout
  call assert_equal(["bufunload", "bufdelete", "bufwipeout"], s:li)

  au! test_bufunload_group
  augroup! test_bufunload_group
endfunc

" SEGV occurs in older versions.  (At least 7.4.2005 or older)
function Test_autocmd_bufunload_with_tabnext()
  tabedit
  tabfirst

  augroup test_autocmd_bufunload_with_tabnext_group
    autocmd!
    autocmd BufUnload <buffer> tabnext
  augroup END

  quit
  call assert_equal(2, tabpagenr('$'))

  augroup! test_autocmd_bufunload_with_tabnext_group
  tablast
  quit
endfunc

func Test_win_tab_autocmd()
  let g:record = []

  augroup testing
    au WinNew * call add(g:record, 'WinNew')
    au WinEnter * call add(g:record, 'WinEnter') 
    au WinLeave * call add(g:record, 'WinLeave') 
    au TabNew * call add(g:record, 'TabNew')
    au TabClosed * call add(g:record, 'TabClosed')
    au TabEnter * call add(g:record, 'TabEnter')
    au TabLeave * call add(g:record, 'TabLeave')
  augroup END

  split
  tabnew
  close
  close

  call assert_equal([
	\ 'WinLeave', 'WinNew', 'WinEnter',
	\ 'WinLeave', 'TabLeave', 'WinNew', 'WinEnter', 'TabNew', 'TabEnter',
	\ 'WinLeave', 'TabLeave', 'TabClosed', 'WinEnter', 'TabEnter',
	\ 'WinLeave', 'WinEnter'
	\ ], g:record)

  let g:record = []
  tabnew somefile
  tabnext
  bwipe somefile

  call assert_equal([
	\ 'WinLeave', 'TabLeave', 'WinNew', 'WinEnter', 'TabNew', 'TabEnter',
	\ 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter',
	\ 'TabClosed'
	\ ], g:record)

  augroup testing
    au!
  augroup END
  unlet g:record
endfunc

func s:AddAnAutocmd()
  augroup vimBarTest
    au BufReadCmd * echo 'hello'
  augroup END
  call assert_equal(3, len(split(execute('au vimBarTest'), "\n")))
endfunc

func Test_early_bar()
  " test that a bar is recognized before the {event}
  call s:AddAnAutocmd()
  augroup vimBarTest | au! | augroup END
  call assert_equal(1, len(split(execute('au vimBarTest'), "\n")))

  call s:AddAnAutocmd()
  augroup vimBarTest| au!| augroup END
  call assert_equal(1, len(split(execute('au vimBarTest'), "\n")))

  " test that a bar is recognized after the {event}
  call s:AddAnAutocmd()
  augroup vimBarTest| au!BufReadCmd| augroup END
  call assert_equal(1, len(split(execute('au vimBarTest'), "\n")))

  " test that a bar is recognized after the {group}
  call s:AddAnAutocmd()
  au! vimBarTest|echo 'hello'
  call assert_equal(1, len(split(execute('au vimBarTest'), "\n")))
endfunc

func RemoveGroup()
  autocmd! StartOK
  augroup! StartOK
endfunc

func Test_augroup_warning()
  augroup TheWarning
    au VimEnter * echo 'entering'
  augroup END
  call assert_true(match(execute('au VimEnter'), "TheWarning.*VimEnter") >= 0)
  redir => res
  augroup! TheWarning
  redir END
  call assert_true(match(res, "W19:") >= 0)
  call assert_true(match(execute('au VimEnter'), "-Deleted-.*VimEnter") >= 0)

  " check "Another" does not take the pace of the deleted entry
  augroup Another
  augroup END
  call assert_true(match(execute('au VimEnter'), "-Deleted-.*VimEnter") >= 0)

  " no warning for postpone aucmd delete
  augroup StartOK
    au VimEnter * call RemoveGroup()
  augroup END
  call assert_true(match(execute('au VimEnter'), "StartOK.*VimEnter") >= 0)
  redir => res
  doautocmd VimEnter
  redir END
  call assert_true(match(res, "W19:") < 0)
  au! VimEnter
endfunc

func Test_augroup_deleted()
  " This caused a crash before E936 was introduced
  augroup x
    call assert_fails('augroup! x', 'E936:')
    au VimEnter * echo
  augroup end
  augroup! x
  call assert_true(match(execute('au VimEnter'), "-Deleted-.*VimEnter") >= 0)
  au! VimEnter
endfunc

