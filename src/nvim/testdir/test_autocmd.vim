" Tests for autocommands

source shared.vim
source check.vim
source term_util.vim

func! s:cleanup_buffers() abort
  for bnr in range(1, bufnr('$'))
    if bufloaded(bnr) && bufnr('%') != bnr
      execute 'bd! ' . bnr
    endif
  endfor
endfunc

func Test_vim_did_enter()
  call assert_false(v:vim_did_enter)

  " This script will never reach the main loop, can't check if v:vim_did_enter
  " becomes one.
endfunc

if has('timers')
  source load.vim

  func ExitInsertMode(id)
    call feedkeys("\<Esc>")
  endfunc

  func Test_cursorhold_insert()
    " Need to move the cursor.
    call feedkeys("ggG", "xt")

    let g:triggered = 0
    au CursorHoldI * let g:triggered += 1
    set updatetime=20
    call timer_start(LoadAdjust(100), 'ExitInsertMode')
    call feedkeys('a', 'x!')
    call assert_equal(1, g:triggered)
    unlet g:triggered
    au! CursorHoldI
    set updatetime&
  endfunc

  func Test_cursorhold_insert_with_timer_interrupt()
    if !has('job')
      return
    endif
    " Need to move the cursor.
    call feedkeys("ggG", "xt")

    " Confirm the timer invoked in exit_cb of the job doesn't disturb
    " CursorHoldI event.
    let g:triggered = 0
    au CursorHoldI * let g:triggered += 1
    set updatetime=500
    call job_start(has('win32') ? 'cmd /c echo:' : 'echo',
          \ {'exit_cb': {-> timer_start(1000, 'ExitInsertMode')}})
    call feedkeys('a', 'x!')
    call assert_equal(1, g:triggered)
    unlet g:triggered
    au! CursorHoldI
    set updatetime&
  endfunc

  func Test_cursorhold_insert_ctrl_x()
    let g:triggered = 0
    au CursorHoldI * let g:triggered += 1
    set updatetime=20
    call timer_start(LoadAdjust(100), 'ExitInsertMode')
    " CursorHoldI does not trigger after CTRL-X
    call feedkeys("a\<C-X>", 'x!')
    call assert_equal(0, g:triggered)
    unlet g:triggered
    au! CursorHoldI
    set updatetime&
  endfunc

  func Test_OptionSet_modeline()
    CheckFunction test_override
    call test_override('starting', 1)
    au! OptionSet
    augroup set_tabstop
      au OptionSet tabstop call timer_start(1, {-> execute("echo 'Handler called'", "")})
    augroup END
    call writefile(['vim: set ts=7 sw=5 :', 'something'], 'XoptionsetModeline')
    set modeline
    let v:errmsg = ''
    call assert_fails('split XoptionsetModeline', 'E12:')
    call assert_equal(7, &ts)
    call assert_equal('', v:errmsg)

    augroup set_tabstop
      au!
    augroup END
    bwipe!
    set ts&
    call delete('XoptionsetModeline')
    call test_override('starting', 0)
  endfunc

endif "has('timers')

func Test_bufunload()
  augroup test_bufunload_group
    autocmd!
    autocmd BufUnload * call add(s:li, "bufunload")
    autocmd BufDelete * call add(s:li, "bufdelete")
    autocmd BufWipeout * call add(s:li, "bufwipeout")
  augroup END

  let s:li = []
  new
  setlocal bufhidden=
  bunload
  call assert_equal(["bufunload", "bufdelete"], s:li)

  let s:li = []
  new
  setlocal bufhidden=delete
  bunload
  call assert_equal(["bufunload", "bufdelete"], s:li)

  let s:li = []
  new
  setlocal bufhidden=unload
  bwipeout
  call assert_equal(["bufunload", "bufdelete", "bufwipeout"], s:li)

  au! test_bufunload_group
  augroup! test_bufunload_group
endfunc

" SEGV occurs in older versions.  (At least 7.4.2005 or older)
func Test_autocmd_bufunload_with_tabnext()
  tabedit
  tabfirst

  augroup test_autocmd_bufunload_with_tabnext_group
    autocmd!
    autocmd BufUnload <buffer> tabnext
  augroup END

  quit
  call assert_equal(2, tabpagenr('$'))

  autocmd! test_autocmd_bufunload_with_tabnext_group
  augroup! test_autocmd_bufunload_with_tabnext_group
  tablast
  quit
endfunc

func Test_autocmd_bufwinleave_with_tabfirst()
  tabedit
  augroup sample
    autocmd!
    autocmd BufWinLeave <buffer> tabfirst
  augroup END
  call setline(1, ['a', 'b', 'c'])
  edit! a.txt
  tabclose
endfunc

" SEGV occurs in older versions.  (At least 7.4.2321 or older)
func Test_autocmd_bufunload_avoiding_SEGV_01()
  split aa.txt
  let lastbuf = bufnr('$')

  augroup test_autocmd_bufunload
    autocmd!
    exe 'autocmd BufUnload <buffer> ' . (lastbuf + 1) . 'bwipeout!'
  augroup END

  call assert_fails('edit bb.txt', 'E937:')

  autocmd! test_autocmd_bufunload
  augroup! test_autocmd_bufunload
  bwipe! aa.txt
  bwipe! bb.txt
endfunc

" SEGV occurs in older versions.  (At least 7.4.2321 or older)
func Test_autocmd_bufunload_avoiding_SEGV_02()
  setlocal buftype=nowrite
  let lastbuf = bufnr('$')

  augroup test_autocmd_bufunload
    autocmd!
    exe 'autocmd BufUnload <buffer> ' . (lastbuf + 1) . 'bwipeout!'
  augroup END

  normal! i1
  call assert_fails('edit a.txt', 'E517:')

  autocmd! test_autocmd_bufunload
  augroup! test_autocmd_bufunload
  bwipe! a.txt
endfunc

func Test_autocmd_dummy_wipeout()
  " prepare files
  call writefile([''], 'Xdummywipetest1.txt')
  call writefile([''], 'Xdummywipetest2.txt')
  augroup test_bufunload_group
    autocmd!
    autocmd BufUnload * call add(s:li, "bufunload")
    autocmd BufDelete * call add(s:li, "bufdelete")
    autocmd BufWipeout * call add(s:li, "bufwipeout")
  augroup END

  let s:li = []
  split Xdummywipetest1.txt
  silent! vimgrep /notmatched/ Xdummywipetest*
  call assert_equal(["bufunload", "bufwipeout"], s:li)

  bwipeout
  call delete('Xdummywipetest1.txt')
  call delete('Xdummywipetest2.txt')
  au! test_bufunload_group
  augroup! test_bufunload_group
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
  call assert_match("TheWarning.*VimEnter", execute('au VimEnter'))
  redir => res
  augroup! TheWarning
  redir END
  call assert_match("W19:", res)
  call assert_match("-Deleted-.*VimEnter", execute('au VimEnter'))

  " check "Another" does not take the pace of the deleted entry
  augroup Another
  augroup END
  call assert_match("-Deleted-.*VimEnter", execute('au VimEnter'))
  augroup! Another

  " no warning for postpone aucmd delete
  augroup StartOK
    au VimEnter * call RemoveGroup()
  augroup END
  call assert_match("StartOK.*VimEnter", execute('au VimEnter'))
  redir => res
  doautocmd VimEnter
  redir END
  call assert_notmatch("W19:", res)
  au! VimEnter
endfunc

func Test_BufReadCmdHelp()
  " This used to cause access to free memory
  au BufReadCmd * e +h
  help

  au! BufReadCmd
endfunc

func Test_BufReadCmdHelpJump()
  " This used to cause access to free memory
  au BufReadCmd * e +h{
  " } to fix highlighting
  call assert_fails('help', 'E434:')

  au! BufReadCmd
endfunc

func Test_augroup_deleted()
  " This caused a crash before E936 was introduced
  augroup x
    call assert_fails('augroup! x', 'E936:')
    au VimEnter * echo
  augroup end
  augroup! x
  call assert_match("-Deleted-.*VimEnter", execute('au VimEnter'))
  au! VimEnter
endfunc

" Tests for autocommands on :close command.
" This used to be in test13.
func Test_three_windows()
  " Clean up buffers, because in some cases this function fails.
  call s:cleanup_buffers()

  " Write three files and open them, each in a window.
  " Then go to next window, with autocommand that deletes the previous one.
  " Do this twice, writing the file.
  e! Xtestje1
  call setline(1, 'testje1')
  w
  sp Xtestje2
  call setline(1, 'testje2')
  w
  sp Xtestje3
  call setline(1, 'testje3')
  w
  wincmd w
  au WinLeave Xtestje2 bwipe
  wincmd w
  call assert_equal('Xtestje1', expand('%'))

  au WinLeave Xtestje1 bwipe Xtestje3
  close
  call assert_equal('Xtestje1', expand('%'))

  " Test deleting the buffer on a Unload event.  If this goes wrong there
  " will be the ATTENTION prompt.
  e Xtestje1
  au!
  au! BufUnload Xtestje1 bwipe
  call assert_fails('e Xtestje3', 'E937:')
  call assert_equal('Xtestje3', expand('%'))

  e Xtestje2
  sp Xtestje1
  call assert_fails('e', 'E937:')
  call assert_equal('Xtestje2', expand('%'))

  " Test changing buffers in a BufWipeout autocommand.  If this goes wrong
  " there are ml_line errors and/or a Crash.
  au!
  only
  e Xanother
  e Xtestje1
  bwipe Xtestje2
  bwipe Xtestje3
  au BufWipeout Xtestje1 buf Xtestje1
  bwipe
  call assert_equal('Xanother', expand('%'))

  only

  help
  wincmd w
  1quit
  call assert_equal('Xanother', expand('%'))

  au!
  enew
  bwipe! Xtestje1
  call delete('Xtestje1')
  call delete('Xtestje2')
  call delete('Xtestje3')
endfunc

func Test_BufEnter()
  au! BufEnter
  au Bufenter * let val = val . '+'
  let g:val = ''
  split NewFile
  call assert_equal('+', g:val)
  bwipe!
  call assert_equal('++', g:val)

  " Also get BufEnter when editing a directory
  call mkdir('Xdir')
  split Xdir
  call assert_equal('+++', g:val)

  " On MS-Windows we can't edit the directory, make sure we wipe the right
  " buffer.
  bwipe! Xdir

  call delete('Xdir', 'd')
  au! BufEnter
endfunc

" Closing a window might cause an endless loop
" E814 for older Vims
func Test_autocmd_bufwipe_in_SessLoadPost()
  edit Xtest
  tabnew
  file Xsomething
  set noswapfile
  mksession!

  let content =<< trim [CODE]
    set nocp noswapfile
    let v:swapchoice = "e"
    augroup test_autocmd_sessionload
    autocmd!
    autocmd SessionLoadPost * exe bufnr("Xsomething") . "bw!"
    augroup END

    func WriteErrors()
      call writefile([execute("messages")], "Xerrors")
    endfunc
    au VimLeave * call WriteErrors()
  [CODE]

  call writefile(content, 'Xvimrc')
  call system(v:progpath. ' --headless -i NONE -u Xvimrc --noplugins -S Session.vim -c cq')
  let errors = join(readfile('Xerrors'))
  call assert_match('E814', errors)

  set swapfile
  for file in ['Session.vim', 'Xvimrc', 'Xerrors']
    call delete(file)
  endfor
endfunc

" Using :blast and :ball for many events caused a crash, because b_nwindows was
" not incremented correctly.
func Test_autocmd_blast_badd()
  let content =<< trim [CODE]
      au BufNew,BufAdd,BufWinEnter,BufEnter,BufLeave,BufWinLeave,BufUnload,VimEnter foo* blast
      edit foo1
      au BufNew,BufAdd,BufWinEnter,BufEnter,BufLeave,BufWinLeave,BufUnload,VimEnter foo* ball
      edit foo2
      call writefile(['OK'], 'Xerrors')
      qall
  [CODE]

  call writefile(content, 'XblastBall')
  call system(GetVimCommand() .. ' --clean -S XblastBall')
  " call assert_match('OK', readfile('Xerrors')->join())
  call assert_match('OK', join(readfile('Xerrors')))

  call delete('XblastBall')
  call delete('Xerrors')
endfunc

" SEGV occurs in older versions.
func Test_autocmd_bufwipe_in_SessLoadPost2()
  tabnew
  set noswapfile
  mksession!

  let content =<< trim [CODE]
    set nocp noswapfile
    function! DeleteInactiveBufs()
      tabfirst
      let tabblist = []
      for i in range(1, tabpagenr(''$''))
        call extend(tabblist, tabpagebuflist(i))
      endfor
      for b in range(1, bufnr(''$''))
        if bufexists(b) && buflisted(b) && (index(tabblist, b) == -1 || bufname(b) =~# ''^$'')
          exec ''bwipeout '' . b
        endif
      endfor
      echomsg "SessionLoadPost DONE"
    endfunction
    au SessionLoadPost * call DeleteInactiveBufs()

    func WriteErrors()
      call writefile([execute("messages")], "Xerrors")
    endfunc
    au VimLeave * call WriteErrors()
  [CODE]

  call writefile(content, 'Xvimrc')
  call system(v:progpath. ' --headless -i NONE -u Xvimrc --noplugins -S Session.vim -c cq')
  let errors = join(readfile('Xerrors'))
  " This probably only ever matches on unix.
  call assert_notmatch('Caught deadly signal SEGV', errors)
  call assert_match('SessionLoadPost DONE', errors)

  set swapfile
  for file in ['Session.vim', 'Xvimrc', 'Xerrors']
    call delete(file)
  endfor
endfunc

func Test_empty_doau()
  doau \|
endfunc

func s:AutoCommandOptionSet(match)
  let item     = remove(g:options, 0)
  let expected = printf("Option: <%s>, Oldval: <%s>, NewVal: <%s>, Scope: <%s>\n", item[0], item[1], item[2], item[3])
  let actual   = printf("Option: <%s>, Oldval: <%s>, NewVal: <%s>, Scope: <%s>\n", a:match, v:option_old, v:option_new, v:option_type)
  let g:opt    = [expected, actual]
  "call assert_equal(expected, actual)
endfunc

func Test_OptionSet()
  CheckFunction test_override
  if !has("eval") || !exists("+autochdir")
    return
  endif

  call test_override('starting', 1)
  set nocp
  au OptionSet * :call s:AutoCommandOptionSet(expand("<amatch>"))

  " 1: Setting number option"
  let g:options = [['number', 0, 1, 'global']]
  set nu
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 2: Setting local number option"
  let g:options = [['number', 1, 0, 'local']]
  setlocal nonu
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 3: Setting global number option"
  let g:options = [['number', 1, 0, 'global']]
  setglobal nonu
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 4: Setting local autoindent option"
  let g:options = [['autoindent', 0, 1, 'local']]
  setlocal ai
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 5: Setting global autoindent option"
  let g:options = [['autoindent', 0, 1, 'global']]
  setglobal ai
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 6: Setting global autoindent option"
  let g:options = [['autoindent', 1, 0, 'global']]
  set ai!
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " Should not print anything, use :noa
  " 7: don't trigger OptionSet"
  let g:options = [['invalid', 1, 1, 'invalid']]
  noa set nonu
  call assert_equal([['invalid', 1, 1, 'invalid']], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 8: Setting several global list and number option"
  let g:options = [['list', 0, 1, 'global'], ['number', 0, 1, 'global']]
  set list nu
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 9: don't trigger OptionSet"
  let g:options = [['invalid', 1, 1, 'invalid'], ['invalid', 1, 1, 'invalid']]
  noa set nolist nonu
  call assert_equal([['invalid', 1, 1, 'invalid'], ['invalid', 1, 1, 'invalid']], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 10: Setting global acd"
  let g:options = [['autochdir', 0, 1, 'local']]
  setlocal acd
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 11: Setting global autoread (also sets local value)"
  let g:options = [['autoread', 0, 1, 'global']]
  set ar
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 12: Setting local autoread"
  let g:options = [['autoread', 1, 1, 'local']]
  setlocal ar
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 13: Setting global autoread"
  let g:options = [['autoread', 1, 0, 'global']]
  setglobal invar
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 14: Setting option backspace through :let"
  let g:options = [['backspace', '', 'eol,indent,start', 'global']]
  let &bs = "eol,indent,start"
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 15: Setting option backspace through setbufvar()"
  let g:options = [['backup', 0, 1, 'local']]
  " try twice, first time, shouldn't trigger because option name is invalid,
  " second time, it should trigger
  call assert_fails("call setbufvar(1, '&l:bk', 1)", "E355")
  " should trigger, use correct option name
  call setbufvar(1, '&backup', 1)
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 16: Setting number option using setwinvar"
  let g:options = [['number', 0, 1, 'local']]
  call setwinvar(0, '&number', 1)
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 17: Setting key option, shouldn't trigger"
  let g:options = [['key', 'invalid', 'invalid1', 'invalid']]
  setlocal key=blah
  setlocal key=
  call assert_equal([['key', 'invalid', 'invalid1', 'invalid']], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 18: Setting string option"
  let oldval = &tags
  let g:options = [['tags', oldval, 'tagpath', 'global']]
  set tags=tagpath
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " 1l: Resetting string option"
  let g:options = [['tags', 'tagpath', oldval, 'global']]
  set tags&
  call assert_equal([], g:options)
  call assert_equal(g:opt[0], g:opt[1])

  " Cleanup
  au! OptionSet
  " set tags&
  for opt in ['nu', 'ai', 'acd', 'ar', 'bs', 'backup', 'cul', 'cp', 'tags']
    exe printf(":set %s&vim", opt)
  endfor
  call test_override('starting', 0)
  delfunc! AutoCommandOptionSet
endfunc

func Test_OptionSet_diffmode()
  CheckFunction test_override
  call test_override('starting', 1)
  " 18: Changing an option when entering diff mode
  new
  au OptionSet diff :let &l:cul = v:option_new

  call setline(1, ['buffer 1', 'line2', 'line3', 'line4'])
  call assert_equal(0, &l:cul)
  diffthis
  call assert_equal(1, &l:cul)

  vnew
  call setline(1, ['buffer 2', 'line 2', 'line 3', 'line4'])
  call assert_equal(0, &l:cul)
  diffthis
  call assert_equal(1, &l:cul)

  diffoff
  call assert_equal(0, &l:cul)
  call assert_equal(1, getwinvar(2, '&l:cul'))
  bw!

  call assert_equal(1, &l:cul)
  diffoff!
  call assert_equal(0, &l:cul)
  call assert_equal(0, getwinvar(1, '&l:cul'))
  bw!

  " Cleanup
  au! OptionSet
  call test_override('starting', 0)
endfunc

func Test_OptionSet_diffmode_close()
  CheckFunction test_override
  call test_override('starting', 1)
  " 19: Try to close the current window when entering diff mode
  " should not segfault
  new
  au OptionSet diff close

  call setline(1, ['buffer 1', 'line2', 'line3', 'line4'])
  call assert_fails(':diffthis', 'E788')
  call assert_equal(1, &diff)
  vnew
  call setline(1, ['buffer 2', 'line 2', 'line 3', 'line4'])
  call assert_fails(':diffthis', 'E788')
  call assert_equal(1, &diff)
  set diffopt-=closeoff
  bw!
  call assert_fails(':diffoff!', 'E788')
  bw!

  " Cleanup
  au! OptionSet
  call test_override('starting', 0)
  "delfunc! AutoCommandOptionSet
endfunc

" Test for Bufleave autocommand that deletes the buffer we are about to edit.
func Test_BufleaveWithDelete()
  new | edit Xfile1

  augroup test_bufleavewithdelete
      autocmd!
      autocmd BufLeave Xfile1 bwipe Xfile2
  augroup END

  call assert_fails('edit Xfile2', 'E143:')
  call assert_equal('Xfile1', bufname('%'))

  autocmd! test_bufleavewithdelete BufLeave Xfile1
  augroup! test_bufleavewithdelete

  new
  bwipe! Xfile1
endfunc

" Test for autocommand that changes the buffer list, when doing ":ball".
func Test_Acmd_BufAll()
  enew!
  %bwipe!
  call writefile(['Test file Xxx1'], 'Xxx1')
  call writefile(['Test file Xxx2'], 'Xxx2')
  call writefile(['Test file Xxx3'], 'Xxx3')

  " Add three files to the buffer list
  split Xxx1
  close
  split Xxx2
  close
  split Xxx3
  close

  " Wipe the buffer when the buffer is opened
  au BufReadPost Xxx2 bwipe

  call append(0, 'Test file Xxx4')
  ball

  call assert_equal(2, winnr('$'))
  call assert_equal('Xxx1', bufname(winbufnr(winnr('$'))))
  wincmd t

  au! BufReadPost
  %bwipe!
  call delete('Xxx1')
  call delete('Xxx2')
  call delete('Xxx3')
  enew! | only
endfunc

" Test for autocommand that changes current buffer on BufEnter event.
" Check if modelines are interpreted for the correct buffer.
func Test_Acmd_BufEnter()
  %bwipe!
  call writefile(['start of test file Xxx1',
	      \ "\<Tab>this is a test",
	      \ 'end of test file Xxx1'], 'Xxx1')
  call writefile(['start of test file Xxx2',
	      \ 'vim: set noai :',
	      \ "\<Tab>this is a test",
	      \ 'end of test file Xxx2'], 'Xxx2')

  au BufEnter Xxx2 brew
  set ai modeline modelines=3
  edit Xxx1
  " edit Xxx2, autocmd will do :brew
  edit Xxx2
  exe "normal G?this is a\<CR>"
  " Append text with autoindent to this file
  normal othis should be auto-indented
  call assert_equal("\<Tab>this should be auto-indented", getline('.'))
  call assert_equal(3, line('.'))
  " Remove autocmd and edit Xxx2 again
  au! BufEnter Xxx2
  buf! Xxx2
  exe "normal G?this is a\<CR>"
  " append text without autoindent to Xxx
  normal othis should be in column 1
  call assert_equal("this should be in column 1", getline('.'))
  call assert_equal(4, line('.'))

  %bwipe!
  call delete('Xxx1')
  call delete('Xxx2')
  set ai&vim modeline&vim modelines&vim
endfunc

" Test for issue #57
" do not move cursor on <c-o> when autoindent is set
func Test_ai_CTRL_O()
  enew!
  set ai
  let save_fo = &fo
  set fo+=r
  exe "normal o# abcdef\<Esc>2hi\<CR>\<C-O>d0\<Esc>"
  exe "normal o# abcdef\<Esc>2hi\<C-O>d0\<Esc>"
  call assert_equal(['# abc', 'def', 'def'], getline(2, 4))

  set ai&vim
  let &fo = save_fo
  enew!
endfunc

" Test for autocommand that deletes the current buffer on BufLeave event.
" Also test deleting the last buffer, should give a new, empty buffer.
func Test_BufLeave_Wipe()
  %bwipe!
  let content = ['start of test file Xxx',
	      \ 'this is a test',
	      \ 'end of test file Xxx']
  call writefile(content, 'Xxx1')
  call writefile(content, 'Xxx2')

  au BufLeave Xxx2 bwipe
  edit Xxx1
  split Xxx2
  " delete buffer Xxx2, we should be back to Xxx1
  bwipe
  call assert_equal('Xxx1', bufname('%'))
  call assert_equal(1, winnr('$'))

  " Create an alternate buffer
  %write! test.out
  call assert_equal('test.out', bufname('#'))
  " delete alternate buffer
  bwipe test.out
  call assert_equal('Xxx1', bufname('%'))
  call assert_equal('', bufname('#'))

  au BufLeave Xxx1 bwipe
  " delete current buffer, get an empty one
  bwipe!
  call assert_equal(1, line('$'))
  call assert_equal('', bufname('%'))
  let g:bufinfo = getbufinfo()
  call assert_equal(1, len(g:bufinfo))

  call delete('Xxx1')
  call delete('Xxx2')
  call delete('test.out')
  %bwipe
  au! BufLeave

  " check that bufinfo doesn't contain a pointer to freed memory
  call test_garbagecollect_now()
endfunc

func Test_QuitPre()
  edit Xfoo
  let winid = win_getid(winnr())
  split Xbar
  au! QuitPre * let g:afile = expand('<afile>')
  " Close the other window, <afile> should be correct.
  exe win_id2win(winid) . 'q'
  call assert_equal('Xfoo', g:afile)
 
  unlet g:afile
  bwipe Xfoo
  bwipe Xbar
endfunc

func Test_Cmdline()
  au! CmdlineChanged : let g:text = getcmdline()
  let g:text = 0
  call feedkeys(":echom 'hello'\<CR>", 'xt')
  call assert_equal("echom 'hello'", g:text)
  au! CmdlineChanged

  au! CmdlineChanged : let g:entered = expand('<afile>')
  let g:entered = 0
  call feedkeys(":echom 'hello'\<CR>", 'xt')
  call assert_equal(':', g:entered)
  au! CmdlineChanged

  au! CmdlineEnter : let g:entered = expand('<afile>')
  au! CmdlineLeave : let g:left = expand('<afile>')
  let g:entered = 0
  let g:left = 0
  call feedkeys(":echo 'hello'\<CR>", 'xt')
  call assert_equal(':', g:entered)
  call assert_equal(':', g:left)
  au! CmdlineEnter
  au! CmdlineLeave

  let save_shellslash = &shellslash
  set noshellslash
  au! CmdlineEnter / let g:entered = expand('<afile>')
  au! CmdlineLeave / let g:left = expand('<afile>')
  let g:entered = 0
  let g:left = 0
  new
  call setline(1, 'hello')
  call feedkeys("/hello\<CR>", 'xt')
  call assert_equal('/', g:entered)
  call assert_equal('/', g:left)
  bwipe!
  au! CmdlineEnter
  au! CmdlineLeave
  let &shellslash = save_shellslash
endfunc

" Test for BufWritePre autocommand that deletes or unloads the buffer.
func Test_BufWritePre()
  %bwipe
  au BufWritePre Xxx1 bunload
  au BufWritePre Xxx2 bwipe

  call writefile(['start of Xxx1', 'test', 'end of Xxx1'], 'Xxx1')
  call writefile(['start of Xxx2', 'test', 'end of Xxx2'], 'Xxx2')

  edit Xtest
  e! Xxx2
  bdel Xtest
  e Xxx1
  " write it, will unload it and give an error msg
  call assert_fails('w', 'E203')
  call assert_equal('Xxx2', bufname('%'))
  edit Xtest
  e! Xxx2
  bwipe Xtest
  " write it, will delete the buffer and give an error msg
  call assert_fails('w', 'E203')
  call assert_equal('Xxx1', bufname('%'))
  au! BufWritePre
  call delete('Xxx1')
  call delete('Xxx2')
endfunc

" Test for BufUnload autocommand that unloads all the other buffers
func Test_bufunload_all()
  call writefile(['Test file Xxx1'], 'Xxx1')"
  call writefile(['Test file Xxx2'], 'Xxx2')"

  let content =<< trim [CODE]
    func UnloadAllBufs()
      let i = 1
      while i <= bufnr('$')
        if i != bufnr('%') && bufloaded(i)
          exe  i . 'bunload'
        endif
        let i += 1
      endwhile
    endfunc
    au BufUnload * call UnloadAllBufs()
    au VimLeave * call writefile(['Test Finished'], 'Xout')
    edit Xxx1
    split Xxx2
    q
  [CODE]

  call writefile(content, 'Xtest')

  call delete('Xout')
  call system(v:progpath. ' -u NORC -i NONE -N -S Xtest')
  call assert_true(filereadable('Xout'))

  call delete('Xxx1')
  call delete('Xxx2')
  call delete('Xtest')
  call delete('Xout')
endfunc

" Some tests for buffer-local autocommands
func Test_buflocal_autocmd()
  let g:bname = ''
  edit xx
  au BufLeave <buffer> let g:bname = expand("%")
  " here, autocommand for xx should trigger.
  " but autocommand shall not apply to buffer named <buffer>.
  edit somefile
  call assert_equal('xx', g:bname)
  let g:bname = ''
  " here, autocommand shall be auto-deleted
  bwipe xx
  " autocmd should not trigger
  edit xx
  call assert_equal('', g:bname)
  " autocmd should not trigger
  edit somefile
  call assert_equal('', g:bname)
  enew
  unlet g:bname
endfunc

" Test for "*Cmd" autocommands
func Test_Cmd_Autocmds()
  call writefile(['start of Xxx', "\tabc2", 'end of Xxx'], 'Xxx')

  enew!
  au BufReadCmd XtestA 0r Xxx|$del
  edit XtestA			" will read text of Xxd instead
  call assert_equal('start of Xxx', getline(1))

  au BufWriteCmd XtestA call append(line("$"), "write")
  write				" will append a line to the file
  call assert_equal('write', getline('$'))
  call assert_fails('read XtestA', 'E484')	" should not read anything
  call assert_equal('write', getline(4))

  " now we have:
  " 1	start of Xxx
  " 2		abc2
  " 3	end of Xxx
  " 4	write

  au FileReadCmd XtestB '[r Xxx
  2r XtestB			" will read Xxx below line 2 instead
  call assert_equal('start of Xxx', getline(3))

  " now we have:
  " 1	start of Xxx
  " 2		abc2
  " 3	start of Xxx
  " 4		abc2
  " 5	end of Xxx
  " 6	end of Xxx
  " 7	write

  au FileWriteCmd XtestC '[,']copy $
  normal 4GA1
  4,5w XtestC			" will copy lines 4 and 5 to the end
  call assert_equal("\tabc21", getline(8))
  call assert_fails('r XtestC', 'E484')	" should not read anything
  call assert_equal("end of Xxx", getline(9))

  " now we have:
  " 1	start of Xxx
  " 2		abc2
  " 3	start of Xxx
  " 4		abc21
  " 5	end of Xxx
  " 6	end of Xxx
  " 7	write
  " 8		abc21
  " 9	end of Xxx

  let g:lines = []
  au FileAppendCmd XtestD call extend(g:lines, getline(line("'["), line("']")))
  w >>XtestD			" will add lines to 'lines'
  call assert_equal(9, len(g:lines))
  call assert_fails('$r XtestD', 'E484')	" should not read anything
  call assert_equal(9, line('$'))
  call assert_equal('end of Xxx', getline('$'))

  au BufReadCmd XtestE 0r Xxx|$del
  sp XtestE			" split window with test.out
  call assert_equal('end of Xxx', getline(3))

  let g:lines = []
  exe "normal 2Goasdf\<Esc>\<C-W>\<C-W>"
  au BufWriteCmd XtestE call extend(g:lines, getline(0, '$'))
  wall				" will write other window to 'lines'
  call assert_equal(4, len(g:lines), g:lines)
  call assert_equal("\tasdf", g:lines[2])

  au! BufReadCmd
  au! BufWriteCmd
  au! FileReadCmd
  au! FileWriteCmd
  au! FileAppendCmd
  %bwipe!
  call delete('Xxx')
  enew!
endfunc

func s:ReadFile()
  setl noswapfile nomodified
  let filename = resolve(expand("<afile>:p"))
  execute 'read' fnameescape(filename)
  1d_
  exe 'file' fnameescape(filename)
  setl buftype=acwrite
endfunc

func s:WriteFile()
  let filename = resolve(expand("<afile>:p"))
  setl buftype=
  noautocmd execute 'write' fnameescape(filename)
  setl buftype=acwrite
  setl nomodified
endfunc

func Test_BufReadCmd()
  autocmd BufReadCmd *.test call s:ReadFile()
  autocmd BufWriteCmd *.test call s:WriteFile()

  call writefile(['one', 'two', 'three'], 'Xcmd.test')
  edit Xcmd.test
  call assert_match('Xcmd.test" line 1 of 3', execute('file'))
  normal! Gofour
  write
  call assert_equal(['one', 'two', 'three', 'four'], readfile('Xcmd.test'))

  bwipe!
  call delete('Xcmd.test')
  au! BufReadCmd
  au! BufWriteCmd
endfunc

func SetChangeMarks(start, end)
  exe a:start .. 'mark ['
  exe a:end .. 'mark ]'
endfunc

" Verify the effects of autocmds on '[ and ']
func Test_change_mark_in_autocmds()
  edit! Xtest
  call feedkeys("ia\<CR>b\<CR>c\<CR>d\<C-g>u\<Esc>", 'xtn')

  call SetChangeMarks(2, 3)
  write
  call assert_equal([1, 4], [line("'["), line("']")])

  call SetChangeMarks(2, 3)
  au BufWritePre * call assert_equal([1, 4], [line("'["), line("']")])
  write
  au! BufWritePre

  if has('unix')
    write XtestFilter
    write >> XtestFilter

    call SetChangeMarks(2, 3)
    " Marks are set to the entire range of the write
    au FilterWritePre * call assert_equal([1, 4], [line("'["), line("']")])
    " '[ is adjusted to just before the line that will receive the filtered
    " data
    au FilterReadPre * call assert_equal([4, 4], [line("'["), line("']")])
    " The filtered data is read into the buffer, and the source lines are
    " still present, so the range is after the source lines
    au FilterReadPost * call assert_equal([5, 12], [line("'["), line("']")])
    %!cat XtestFilter
    " After the filtered data is read, the original lines are deleted
    call assert_equal([1, 8], [line("'["), line("']")])
    au! FilterWritePre,FilterReadPre,FilterReadPost
    undo

    call SetChangeMarks(1, 4)
    au FilterWritePre * call assert_equal([2, 3], [line("'["), line("']")])
    au FilterReadPre * call assert_equal([3, 3], [line("'["), line("']")])
    au FilterReadPost * call assert_equal([4, 11], [line("'["), line("']")])
    2,3!cat XtestFilter
    call assert_equal([2, 9], [line("'["), line("']")])
    au! FilterWritePre,FilterReadPre,FilterReadPost
    undo

    call delete('XtestFilter')
  endif

  call SetChangeMarks(1, 4)
  au FileWritePre * call assert_equal([2, 3], [line("'["), line("']")])
  2,3write Xtest2
  au! FileWritePre

  call SetChangeMarks(2, 3)
  au FileAppendPre * call assert_equal([1, 4], [line("'["), line("']")])
  write >> Xtest2
  au! FileAppendPre

  call SetChangeMarks(1, 4)
  au FileAppendPre * call assert_equal([2, 3], [line("'["), line("']")])
  2,3write >> Xtest2
  au! FileAppendPre

  call SetChangeMarks(1, 1)
  au FileReadPre * call assert_equal([3, 1], [line("'["), line("']")])
  au FileReadPost * call assert_equal([4, 11], [line("'["), line("']")])
  3read Xtest2
  au! FileReadPre,FileReadPost
  undo

  call SetChangeMarks(4, 4)
  " When the line is 0, it's adjusted to 1
  au FileReadPre * call assert_equal([1, 4], [line("'["), line("']")])
  au FileReadPost * call assert_equal([1, 8], [line("'["), line("']")])
  0read Xtest2
  au! FileReadPre,FileReadPost
  undo

  call SetChangeMarks(4, 4)
  " When the line is 0, it's adjusted to 1
  au FileReadPre * call assert_equal([1, 4], [line("'["), line("']")])
  au FileReadPost * call assert_equal([2, 9], [line("'["), line("']")])
  1read Xtest2
  au! FileReadPre,FileReadPost
  undo

  bwipe!
  call delete('Xtest')
  call delete('Xtest2')
endfunc

func Test_Filter_noshelltemp()
  if !executable('cat')
    return
  endif

  enew!
  call setline(1, ['a', 'b', 'c', 'd'])

  let shelltemp = &shelltemp
  set shelltemp

  let g:filter_au = 0
  au FilterWritePre * let g:filter_au += 1
  au FilterReadPre * let g:filter_au += 1
  au FilterReadPost * let g:filter_au += 1
  %!cat
  call assert_equal(3, g:filter_au)

  if has('filterpipe')
    set noshelltemp

    let g:filter_au = 0
    au FilterWritePre * let g:filter_au += 1
    au FilterReadPre * let g:filter_au += 1
    au FilterReadPost * let g:filter_au += 1
    %!cat
    call assert_equal(0, g:filter_au)
  endif

  au! FilterWritePre,FilterReadPre,FilterReadPost
  let &shelltemp = shelltemp
  bwipe!
endfunc

func Test_TextYankPost()
  enew!
  call setline(1, ['foo'])

  let g:event = []
  au TextYankPost * let g:event = copy(v:event)

  call assert_equal({}, v:event)
  call assert_fails('let v:event = {}', 'E46:')
  call assert_fails('let v:event.mykey = 0', 'E742:')

  norm "ayiw
  call assert_equal(
    \{'regcontents': ['foo'], 'inclusive': v:true, 'regname': 'a', 'operator': 'y', 'visual': v:false, 'regtype': 'v'},
    \g:event)
  norm y_
  call assert_equal(
    \{'regcontents': ['foo'], 'inclusive': v:false, 'regname': '',  'operator': 'y', 'visual': v:false, 'regtype': 'V'},
    \g:event)
  norm Vy
  call assert_equal(
    \{'regcontents': ['foo'], 'inclusive': v:true, 'regname': '',  'operator': 'y', 'visual': v:true, 'regtype': 'V'},
    \g:event)
  call feedkeys("\<C-V>y", 'x')
  call assert_equal(
    \{'regcontents': ['f'], 'inclusive': v:true, 'regname': '',  'operator': 'y', 'visual': v:true, 'regtype': "\x161"},
    \g:event)
  norm "xciwbar
  call assert_equal(
    \{'regcontents': ['foo'], 'inclusive': v:true, 'regname': 'x', 'operator': 'c', 'visual': v:false, 'regtype': 'v'},
    \g:event)
  norm "bdiw
  call assert_equal(
    \{'regcontents': ['bar'], 'inclusive': v:true, 'regname': 'b', 'operator': 'd', 'visual': v:false, 'regtype': 'v'},
    \g:event)

  call assert_equal({}, v:event)

  au! TextYankPost
  unlet g:event
  bwipe!
endfunc

func Test_autocommand_all_events()
  call assert_fails('au * * bwipe', 'E1155:')
  call assert_fails('au * x bwipe', 'E1155:')
endfunc

" Test TextChangedI and TextChangedP
" See test/functional/viml/completion_spec.lua'
func Test_ChangedP()
  CheckFunction test_override
  new
  call setline(1, ['foo', 'bar', 'foobar'])
  call test_override("char_avail", 1)
  set complete=. completeopt=menuone

  func! TextChangedAutocmd(char)
    let g:autocmd .= a:char
  endfunc

  au! TextChanged <buffer> :call TextChangedAutocmd('N')
  au! TextChangedI <buffer> :call TextChangedAutocmd('I')
  au! TextChangedP <buffer> :call TextChangedAutocmd('P')

  call cursor(3, 1)
  let g:autocmd = ''
  call feedkeys("o\<esc>", 'tnix')
  call assert_equal('I', g:autocmd)

  let g:autocmd = ''
  call feedkeys("Sf", 'tnix')
  call assert_equal('II', g:autocmd)

  let g:autocmd = ''
  call feedkeys("Sf\<C-N>", 'tnix')
  call assert_equal('IIP', g:autocmd)

  let g:autocmd = ''
  call feedkeys("Sf\<C-N>\<C-N>", 'tnix')
  call assert_equal('IIPP', g:autocmd)

  let g:autocmd = ''
  call feedkeys("Sf\<C-N>\<C-N>\<C-N>", 'tnix')
  call assert_equal('IIPPP', g:autocmd)

  let g:autocmd = ''
  call feedkeys("Sf\<C-N>\<C-N>\<C-N>\<C-N>", 'tnix')
  call assert_equal('IIPPPP', g:autocmd)

  call assert_equal(['foo', 'bar', 'foobar', 'foo'], getline(1, '$'))
  " TODO: how should it handle completeopt=noinsert,noselect?

  " CleanUp
  call test_override("char_avail", 0)
  au! TextChanged
  au! TextChangedI
  au! TextChangedP
  delfu TextChangedAutocmd
  unlet! g:autocmd
  set complete&vim completeopt&vim

  bw!
endfunc

let g:setline_handled = v:false
func SetLineOne()
  if !g:setline_handled
    call setline(1, "(x)")
    let g:setline_handled = v:true
  endif
endfunc

func Test_TextChangedI_with_setline()
  CheckFunction test_override
  new
  call test_override('char_avail', 1)
  autocmd TextChangedI <buffer> call SetLineOne()
  call feedkeys("i(\<CR>\<Esc>", 'tx')
  call assert_equal('(', getline(1))
  call assert_equal('x)', getline(2))
  undo
  call assert_equal('', getline(1))
  call assert_equal('', getline(2))

  call test_override('starting', 0)
  bwipe!
endfunc

func Test_Changed_FirstTime()
  CheckFeature terminal
  CheckNotGui
  " Starting a terminal to run Vim is always considered flaky.
  let g:test_is_flaky = 1

  " Prepare file for TextChanged event.
  call writefile([''], 'Xchanged.txt')
  let buf = term_start([GetVimProg(), '--clean', '-c', 'set noswapfile'], {'term_rows': 3})
  call assert_equal('running', term_getstatus(buf))
  " Wait for the ruler (in the status line) to be shown.
  call WaitForAssert({-> assert_match('\<All$', term_getline(buf, 3))})
  " It's only adding autocmd, so that no event occurs.
  call term_sendkeys(buf, ":au! TextChanged <buffer> call writefile(['No'], 'Xchanged.txt')\<cr>")
  call term_sendkeys(buf, "\<C-\\>\<C-N>:qa!\<cr>")
  call WaitForAssert({-> assert_equal('finished', term_getstatus(buf))})
  call assert_equal([''], readfile('Xchanged.txt'))

  " clean up
  call delete('Xchanged.txt')
  bwipe!
endfunc

func Test_autocmd_nested()
  let g:did_nested = 0
  augroup Testing
    au WinNew * edit somefile
    au BufNew * let g:did_nested = 1
  augroup END
  split
  call assert_equal(0, g:did_nested)
  close
  bwipe! somefile

  " old nested argument still works
  augroup Testing
    au!
    au WinNew * nested edit somefile
    au BufNew * let g:did_nested = 1
  augroup END
  split
  call assert_equal(1, g:did_nested)
  close
  bwipe! somefile

  " New ++nested argument works
  augroup Testing
    au!
    au WinNew * ++nested edit somefile
    au BufNew * let g:did_nested = 1
  augroup END
  split
  call assert_equal(1, g:did_nested)
  close
  bwipe! somefile

  augroup Testing
    au!
  augroup END

  call assert_fails('au WinNew * ++nested ++nested echo bad', 'E983:')
  call assert_fails('au WinNew * nested nested echo bad', 'E983:')
endfunc

func Test_autocmd_once()
  " Without ++once WinNew triggers twice
  let g:did_split = 0
  augroup Testing
    au WinNew * let g:did_split += 1
  augroup END
  split
  split
  call assert_equal(2, g:did_split)
  call assert_true(exists('#WinNew'))
  close
  close

  " With ++once WinNew triggers once
  let g:did_split = 0
  augroup Testing
    au!
    au WinNew * ++once let g:did_split += 1
  augroup END
  split
  split
  call assert_equal(1, g:did_split)
  call assert_false(exists('#WinNew'))
  close
  close

  call assert_fails('au WinNew * ++once ++once echo bad', 'E983:')
endfunc

func Test_autocmd_bufreadpre()
  new
  let b:bufreadpre = 1
  call append(0, range(100))
  w! XAutocmdBufReadPre.txt
  autocmd BufReadPre <buffer> :let b:bufreadpre += 1
  norm! 50gg
  sp
  norm! 100gg
  wincmd p
  let g:wsv1 = winsaveview()
  wincmd p
  let g:wsv2 = winsaveview()
  " triggers BufReadPre, should not move the cursor in either window
  " The topline may change one line in a large window.
  edit
  call assert_inrange(g:wsv2.topline - 1, g:wsv2.topline + 1, winsaveview().topline)
  call assert_equal(g:wsv2.lnum, winsaveview().lnum)
  call assert_equal(2, b:bufreadpre)
  wincmd p
  call assert_equal(g:wsv1.topline, winsaveview().topline)
  call assert_equal(g:wsv1.lnum, winsaveview().lnum)
  call assert_equal(2, b:bufreadpre)
  " Now set the cursor position in an BufReadPre autocommand
  " (even though the position will be invalid, this should make Vim reset the
  " cursor position in the other window.
  wincmd p
  1
  " won't do anything, but try to set the cursor on an invalid lnum
  autocmd BufReadPre <buffer> :norm! 70gg
  " triggers BufReadPre, should not move the cursor in either window
  e
  call assert_equal(1, winsaveview().topline)
  call assert_equal(1, winsaveview().lnum)
  call assert_equal(3, b:bufreadpre)
  wincmd p
  call assert_equal(g:wsv1.topline, winsaveview().topline)
  call assert_equal(g:wsv1.lnum, winsaveview().lnum)
  call assert_equal(3, b:bufreadpre)
  close
  close
  call delete('XAutocmdBufReadPre.txt')
endfunc

" Tests for the following autocommands:
" - FileWritePre	writing a compressed file
" - FileReadPost	reading a compressed file
" - BufNewFile		reading a file template
" - BufReadPre		decompressing the file to be read
" - FilterReadPre	substituting characters in the temp file
" - FilterReadPost	substituting characters after filtering
" - FileReadPre		set options for decompression
" - FileReadPost	decompress the file
func Test_ReadWrite_Autocmds()
  " Run this test only on Unix-like systems and if gzip is available
  if !has('unix') || !executable("gzip")
    return
  endif

  " Make $GZIP empty, "-v" would cause trouble.
  let $GZIP = ""

  " Use a FileChangedShell autocommand to avoid a prompt for 'Xtestfile.gz'
  " being modified outside of Vim (noticed on Solaris).
  au FileChangedShell * echo 'caught FileChangedShell'

  " Test for the FileReadPost, FileWritePre and FileWritePost autocmds
  augroup Test1
    au!
    au FileWritePre    *.gz   '[,']!gzip
    au FileWritePost   *.gz   undo
    au FileReadPost    *.gz   '[,']!gzip -d
  augroup END

  new
  set bin
  call append(0, [
	      \ 'line 2	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 4	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 6	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 8	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 10 Abcdefghijklmnopqrstuvwxyz'
	      \ ])
  1,9write! Xtestfile.gz
  enew! | close

  new
  " Read and decompress the testfile
  0read Xtestfile.gz
  call assert_equal([
	      \ 'line 2	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 4	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 6	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 8	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 10 Abcdefghijklmnopqrstuvwxyz'
	      \ ], getline(1, 9))
  enew! | close

  augroup Test1
    au!
  augroup END

  " Test for the FileAppendPre and FileAppendPost autocmds
  augroup Test2
    au!
    au BufNewFile      *.c    read Xtest.c
    au FileAppendPre   *.out  '[,']s/new/NEW/
    au FileAppendPost  *.out  !cat Xtest.c >> test.out
  augroup END

  call writefile(['/*', ' * Here is a new .c file', ' */'], 'Xtest.c')
  new foo.c			" should load Xtest.c
  call assert_equal(['/*', ' * Here is a new .c file', ' */'], getline(2, 4))
  w! >> test.out		" append it to the output file

  let contents = readfile('test.out')
  call assert_equal(' * Here is a NEW .c file', contents[2])
  call assert_equal(' * Here is a new .c file', contents[5])

  call delete('test.out')
  enew! | close
  augroup Test2
    au!
  augroup END

  " Test for the BufReadPre and BufReadPost autocmds
  augroup Test3
    au!
    " setup autocommands to decompress before reading and re-compress
    " afterwards
    au BufReadPre  *.gz  exe '!gzip -d ' . shellescape(expand("<afile>"))
    au BufReadPre  *.gz  call rename(expand("<afile>:r"), expand("<afile>"))
    au BufReadPost *.gz  call rename(expand("<afile>"), expand("<afile>:r"))
    au BufReadPost *.gz  exe '!gzip ' . shellescape(expand("<afile>:r"))
  augroup END

  e! Xtestfile.gz		" Edit compressed file
  call assert_equal([
	      \ 'line 2	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 4	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 6	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 8	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 10 Abcdefghijklmnopqrstuvwxyz'
	      \ ], getline(1, 9))

  w! >> test.out		" Append it to the output file

  augroup Test3
    au!
  augroup END

  " Test for the FilterReadPre and FilterReadPost autocmds.
  set shelltemp			" need temp files here
  augroup Test4
    au!
    au FilterReadPre   *.out  call rename(expand("<afile>"), expand("<afile>") . ".t")
    au FilterReadPre   *.out  exe 'silent !sed s/e/E/ ' . shellescape(expand("<afile>")) . ".t >" . shellescape(expand("<afile>"))
    au FilterReadPre   *.out  exe 'silent !rm ' . shellescape(expand("<afile>")) . '.t'
    au FilterReadPost  *.out  '[,']s/x/X/g
  augroup END

  e! test.out			" Edit the output file
  1,$!cat
  call assert_equal([
	      \ 'linE 2	AbcdefghijklmnopqrstuvwXyz',
	      \ 'linE 3	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
	      \ 'linE 4	AbcdefghijklmnopqrstuvwXyz',
	      \ 'linE 5	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
	      \ 'linE 6	AbcdefghijklmnopqrstuvwXyz',
	      \ 'linE 7	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
	      \ 'linE 8	AbcdefghijklmnopqrstuvwXyz',
	      \ 'linE 9	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
	      \ 'linE 10 AbcdefghijklmnopqrstuvwXyz'
	      \ ], getline(1, 9))
  call assert_equal([
	      \ 'line 2	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 4	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 6	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 8	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 10 Abcdefghijklmnopqrstuvwxyz'
	      \ ], readfile('test.out'))

  augroup Test4
    au!
  augroup END
  set shelltemp&vim

  " Test for the FileReadPre and FileReadPost autocmds.
  augroup Test5
    au!
    au FileReadPre *.gz exe 'silent !gzip -d ' . shellescape(expand("<afile>"))
    au FileReadPre *.gz call rename(expand("<afile>:r"), expand("<afile>"))
    au FileReadPost *.gz '[,']s/l/L/
  augroup END

  new
  0r Xtestfile.gz		" Read compressed file
  call assert_equal([
	      \ 'Line 2	Abcdefghijklmnopqrstuvwxyz',
	      \ 'Line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'Line 4	Abcdefghijklmnopqrstuvwxyz',
	      \ 'Line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'Line 6	Abcdefghijklmnopqrstuvwxyz',
	      \ 'Line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'Line 8	Abcdefghijklmnopqrstuvwxyz',
	      \ 'Line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'Line 10 Abcdefghijklmnopqrstuvwxyz'
	      \ ], getline(1, 9))
  call assert_equal([
	      \ 'line 2	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 3	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 4	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 5	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 6	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 7	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 8	Abcdefghijklmnopqrstuvwxyz',
	      \ 'line 9	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	      \ 'line 10 Abcdefghijklmnopqrstuvwxyz'
	      \ ], readfile('Xtestfile.gz'))

  augroup Test5
    au!
  augroup END

  au! FileChangedShell
  call delete('Xtestfile.gz')
  call delete('Xtest.c')
  call delete('test.out')
endfunc

func Test_throw_in_BufWritePre()
  new
  call setline(1, ['one', 'two', 'three'])
  call assert_false(filereadable('Xthefile'))
  augroup throwing
    au BufWritePre X* throw 'do not write'
  augroup END
  try
    w Xthefile
  catch
    let caught = 1
  endtry
  call assert_equal(1, caught)
  call assert_false(filereadable('Xthefile'))

  bwipe!
  au! throwing
endfunc

func Test_autocmd_CmdWinEnter()
  CheckRunVimInTerminal
  " There is not cmdwin switch, so
  " test for cmdline_hist
  " (both are available with small builds)
  CheckFeature cmdline_hist
  let lines =<< trim END
    let b:dummy_var = 'This is a dummy'
    autocmd CmdWinEnter * quit
    let winnr = winnr('$')
  END
  let filename = 'XCmdWinEnter'
  call writefile(lines, filename)
  let buf = RunVimInTerminal('-S '.filename, #{rows: 6})

  call term_sendkeys(buf, "q:")
  call term_wait(buf)
  call term_sendkeys(buf, ":echo b:dummy_var\<cr>")
  call WaitForAssert({-> assert_match('^This is a dummy', term_getline(buf, 6))}, 1000)
  call term_sendkeys(buf, ":echo &buftype\<cr>")
  call WaitForAssert({-> assert_notmatch('^nofile', term_getline(buf, 6))}, 1000)
  call term_sendkeys(buf, ":echo winnr\<cr>")
  call WaitForAssert({-> assert_match('^1', term_getline(buf, 6))}, 1000)

  " clean up
  call StopVimInTerminal(buf)
  call delete(filename)
endfunc

func Test_FileChangedShell_reload()
  if !has('unix')
    return
  endif
  augroup testreload
    au FileChangedShell Xchanged let g:reason = v:fcs_reason | let v:fcs_choice = 'reload'
  augroup END
  new Xchanged
  call setline(1, 'reload this')
  write
  " Need to wait until the timestamp would change by at least a second.
  sleep 2
  silent !echo 'extra line' >>Xchanged
  checktime
  call assert_equal('changed', g:reason)
  call assert_equal(2, line('$'))
  call assert_equal('extra line', getline(2))

  " Only triggers once
  let g:reason = ''
  checktime
  call assert_equal('', g:reason)

  " When deleted buffer is not reloaded
  silent !rm Xchanged
  let g:reason = ''
  checktime
  call assert_equal('deleted', g:reason)
  call assert_equal(2, line('$'))
  call assert_equal('extra line', getline(2))

  " When recreated buffer is reloaded
  call setline(1, 'buffer is changed')
  silent !echo 'new line' >>Xchanged
  let g:reason = ''
  checktime
  call assert_equal('conflict', g:reason)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  " Only mode changed
  silent !chmod +x Xchanged
  let g:reason = ''
  checktime
  call assert_equal('mode', g:reason)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  " Only time changed
  sleep 2
  silent !touch Xchanged
  let g:reason = ''
  checktime
  call assert_equal('time', g:reason)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  if has('persistent_undo')
    " With an undo file the reload can be undone and a change before the
    " reload.
    set undofile
    call setline(2, 'before write')
    write
    call setline(2, 'after write')
    sleep 2
    silent !echo 'different line' >>Xchanged
    let g:reason = ''
    checktime
    call assert_equal('conflict', g:reason)
    call assert_equal(3, line('$'))
    call assert_equal('before write', getline(2))
    call assert_equal('different line', getline(3))
    " undo the reload
    undo
    call assert_equal(2, line('$'))
    call assert_equal('after write', getline(2))
    " undo the change before reload
    undo
    call assert_equal(2, line('$'))
    call assert_equal('before write', getline(2))

    set noundofile
  endif


  au! testreload
  bwipe!
  call delete('Xchanged')
endfunc

func LogACmd()
  call add(g:logged, line('$'))
endfunc

func Test_TermChanged()
  throw 'skipped: Nvim does not support TermChanged event'
  CheckNotGui

  enew!
  tabnew
  call setline(1, ['a', 'b', 'c', 'd'])
  $
  au TermChanged * call LogACmd()
  let g:logged = []
  let term_save = &term
  set term=xterm
  call assert_equal([1, 4], g:logged)

  au! TermChanged
  let &term = term_save
  bwipe!
endfunc

" Test for FileReadCmd autocmd
func Test_autocmd_FileReadCmd()
  func ReadFileCmd()
    call append(line('$'), "v:cmdarg = " .. v:cmdarg)
  endfunc
  augroup FileReadCmdTest
    au!
    au FileReadCmd Xtest call ReadFileCmd()
  augroup END

  new
  read ++bin Xtest
  read ++nobin Xtest
  read ++edit Xtest
  read ++bad=keep Xtest
  read ++bad=drop Xtest
  read ++bad=- Xtest
  read ++ff=unix Xtest
  read ++ff=dos Xtest
  read ++ff=mac Xtest
  read ++enc=utf-8 Xtest

  call assert_equal(['',
        \ 'v:cmdarg =  ++bin',
        \ 'v:cmdarg =  ++nobin',
        \ 'v:cmdarg =  ++edit',
        \ 'v:cmdarg =  ++bad=keep',
        \ 'v:cmdarg =  ++bad=drop',
        \ 'v:cmdarg =  ++bad=-',
        \ 'v:cmdarg =  ++ff=unix',
        \ 'v:cmdarg =  ++ff=dos',
        \ 'v:cmdarg =  ++ff=mac',
        \ 'v:cmdarg =  ++enc=utf-8'], getline(1, '$'))

  close!
  augroup FileReadCmdTest
    au!
  augroup END
  delfunc ReadFileCmd
endfunc

" Tests for SigUSR1 autocmd event, which is only available on posix systems.
func Test_autocmd_sigusr1()
  CheckUnix

  let g:sigusr1_passed = 0
  au Signal SIGUSR1 let g:sigusr1_passed = 1
  call system('/bin/kill -s usr1 ' . getpid())
  call WaitForAssert({-> assert_true(g:sigusr1_passed)})

  au! Signal
  unlet g:sigusr1_passed
endfunc

" Test for the temporary internal window used to execute autocmds
func Test_autocmd_window()
  %bw!
  edit one.txt
  tabnew two.txt
  vnew three.txt
  tabnew four.txt
  tabprevious
  let g:blist = []
  augroup aucmd_win_test1
    au!
    au BufEnter * call add(g:blist, [expand('<afile>'),
          \ win_gettype(bufwinnr(expand('<afile>')))])
  augroup END

  doautoall BufEnter
  call assert_equal([
        \ ['one.txt', 'autocmd'],
        \ ['two.txt', ''],
        \ ['four.txt', 'autocmd'],
        \ ['three.txt', ''],
        \ ], g:blist)

  augroup aucmd_win_test1
    au!
  augroup END
  augroup! aucmd_win_test1
  %bw!
endfunc

" Test for trying to close the tab that has the temporary window for exeucing
" an autocmd.
func Test_close_autocmd_tab()
  edit one.txt
  tabnew two.txt
   augroup aucmd_win_test
    au!
    au BufEnter * if expand('<afile>') == 'one.txt' | tabfirst | tabonly | endif
  augroup END

  call assert_fails('doautoall BufEnter', 'E813:')

  tabonly
  augroup aucmd_win_test
    au!
  augroup END
  augroup! aucmd_win_test
  %bwipe!
endfunc

func Test_autocmd_closes_window()
  au BufNew,BufWinLeave * e %e
  file yyy
  au BufNew,BufWinLeave * ball
  call assert_fails('n xxx', 'E143:')

  bwipe %
  au! BufNew
  au! BufWinLeave
endfunc

func Test_autocmd_closing_cmdwin()
  au BufWinLeave * nested q
  call assert_fails("norm 7q?\n", 'E855:')

  au! BufWinLeave
  new
  only
endfunc

" vim: shiftwidth=2 sts=2 expandtab
