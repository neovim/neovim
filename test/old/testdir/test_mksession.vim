" Test for :mksession, :mkview and :loadview in latin1 encoding

scriptencoding latin1

source check.vim
CheckFeature mksession

source shared.vim
source term_util.vim

" Test for storing global and local argument list in a session file
" This one must be done first.
func Test__mksession_arglocal()
  enew | only
  n a b c
  new
  arglocal
  mksession! Xtest_mks.out

  %bwipe!
  %argdelete
  argglobal
  source Xtest_mks.out
  call assert_equal(2, winnr('$'))
  call assert_equal(2, arglistid(1))
  call assert_equal(0, arglistid(2))

  %bwipe!
  %argdelete
  argglobal
  call delete('Xtest_mks.out')
endfunc

func Test_mksession_arglocal_localdir()
  call mkdir('Xa', 'R')
  call writefile(['This is Xb'], 'Xa/Xb.txt', 'D')
  let olddir = getcwd()
  let oldargs = argv()

  for tabpage in [v:false, v:true]
    let msg = tabpage ? 'tabpage-local' : 'window-local'

    exe tabpage ? 'tabnew' : 'botright new'
    exe tabpage ? 'tcd Xa' : 'lcd Xa'
    let localdir = getcwd()
    arglocal
    $argadd Xb.txt
    let localargs = argv()
    exe tabpage ? 'tabprev' : 'wincmd p'
    call assert_equal(olddir, getcwd(), msg)
    call assert_equal(oldargs, argv(), msg)
    mksession! Xtest_mks_localdir.out
    exe tabpage ? '+tabclose' : '$close'
    bwipe! Xa/Xb.txt

    source Xtest_mks_localdir.out
    exe tabpage ? 'tabnext' : 'wincmd b'
    call assert_equal(localdir, getcwd(), msg)
    call assert_equal(localargs, argv(), msg)
    $argument
    call assert_equal('This is Xb', getline(1), msg)

    bwipe!
    call assert_equal(olddir, getcwd(), msg)
    call assert_equal(oldargs, argv(), msg)
    call delete('Xtest_mks_localdir.out')
  endfor
endfunc

func Test_mksession()
  tabnew
  let wrap_save = &wrap
  set sessionoptions=buffers splitbelow fileencoding=latin1
  call setline(1, [
    \   'start:',
    \   'no multibyte chAracter',
    \   '	one leaDing tab',
    \   '    four leadinG spaces',
    \   'two		consecutive tabs',
    \   'two	tabs	in one line',
    \   'one ä multibyteCharacter',
    \   'aä Ä  two multiByte characters',
    \   'Aäöü  three mulTibyte characters',
    \   'short line',
    \ ])
  let tmpfile = 'Xtemp'
  exec 'w! ' . tmpfile
  /^start:
  set wrap
  vsplit
  norm! j16|
  split
  norm! j16|
  split
  norm! j16|
  split
  norm! j8|
  split
  norm! j8|
  split
  norm! j16|
  split
  norm! j16|
  split
  norm! j16|
  split
  norm! j$
  wincmd l

  set nowrap
  /^start:
  norm! j16|3zl
  split
  norm! j016|3zl
  split
  norm! j016|3zl
  split
  norm! j08|3zl
  split
  norm! j08|3zl
  split
  norm! j016|3zl
  split
  norm! j016|3zl
  split
  norm! j016|3zl
  split
  call wincol()
  mksession! Xtest_mks.out
  let li = filter(readfile('Xtest_mks.out'), 'v:val =~# "\\(^ *normal! [0$]\\|^ *exe ''normal!\\)"')
  let expected = [
    \   'normal! 016|',
    \   'normal! 016|',
    \   'normal! 016|',
    \   'normal! 08|',
    \   'normal! 08|',
    \   'normal! 016|',
    \   'normal! 016|',
    \   'normal! 016|',
    \   'normal! $',
    \   "  exe 'normal! ' . s:c . '|zs' . 16 . '|'",
    \   "  normal! 016|",
    \   "  exe 'normal! ' . s:c . '|zs' . 16 . '|'",
    \   "  normal! 016|",
    \   "  exe 'normal! ' . s:c . '|zs' . 16 . '|'",
    \   "  normal! 016|",
    \   "  exe 'normal! ' . s:c . '|zs' . 8 . '|'",
    \   "  normal! 08|",
    \   "  exe 'normal! ' . s:c . '|zs' . 8 . '|'",
    \   "  normal! 08|",
    \   "  exe 'normal! ' . s:c . '|zs' . 16 . '|'",
    \   "  normal! 016|",
    \   "  exe 'normal! ' . s:c . '|zs' . 16 . '|'",
    \   "  normal! 016|",
    \   "  exe 'normal! ' . s:c . '|zs' . 16 . '|'",
    \   "  normal! 016|",
    \   "  exe 'normal! ' . s:c . '|zs' . 16 . '|'",
    \   "  normal! 016|"
    \ ]
  call assert_equal(expected, li)
  tabclose!

  call delete('Xtest_mks.out')
  call delete(tmpfile)
  let &wrap = wrap_save
  set sessionoptions&
endfunc

func Test_mksession_winheight()
  new
  set winheight=10
  set winminheight=2
  mksession! Xtest_mks.out
  source Xtest_mks.out

  call delete('Xtest_mks.out')
endfunc

func Test_mksession_large_winheight()
  set winheight=999
  mksession! Xtest_mks_winheight.out
  set winheight&
  source Xtest_mks_winheight.out
  call delete('Xtest_mks_winheight.out')
endfunc

func Test_mksession_zero_winheight()
  set winminheight=0
  edit SomeFile
  split
  wincmd _
  mksession! Xtest_mks_zero
  set winminheight&
  let text = readfile('Xtest_mks_zero')->join()
  call delete('Xtest_mks_zero')
  close
  " check there is no divide by zero
  call assert_notmatch('/ 0[^0-9]', text)
endfunc

func Test_mksession_rtp()
  if has('win32')
    " TODO: fix problem with backslashes
    return
  endif
  new
  let _rtp=&rtp
  " Make a real long (invalid) runtimepath value,
  " that should exceed PATH_MAX (hopefully)
  let newrtp=&rtp.',~'.repeat('/foobar', 1000)
  let newrtp.=",".expand("$HOME")."/.vim"
  let &rtp=newrtp

  " determine expected value
  let expected=split(&rtp, ',')
  let expected = map(expected, '"set runtimepath+=".v:val')
  let expected = ['set runtimepath='] + expected
  let expected = map(expected, {v,w -> substitute(w, $HOME, "~", "g")})

  mksession! Xtest_mks.out
  let &rtp=_rtp
  let li = filter(readfile('Xtest_mks.out'), 'v:val =~# "runtimepath"')
  call assert_equal(expected, li)

  call delete('Xtest_mks.out')
endfunc

func Test_mksession_arglist()
  %argdel
  next file1 file2 file3 file4
  new
  next | next
  mksession! Xtest_mks.out
  source Xtest_mks.out
  call assert_equal(['file1', 'file2', 'file3', 'file4'], argv())
  call assert_equal(2, argidx())
  wincmd w
  call assert_equal(0, argidx())

  call delete('Xtest_mks.out')
  enew | only
  argdel *
endfunc

func Test_mksession_one_buffer_two_windows()
  edit Xtest1
  new Xtest2
  split
  mksession! Xtest_mks.out
  let lines = readfile('Xtest_mks.out')
  let count1 = 0
  let count2 = 0
  let count2buf = 0
  let bufexists = 0
  for line in lines
    if line =~ 'edit \f*Xtest1$'
      let count1 += 1
    endif
    if line =~ 'edit \f\{-}Xtest2'
      let count2 += 1
    endif
    if line =~ 'buffer \f\{-}Xtest2'
      let count2buf += 1
    endif
    if line =~ 'bufexists(fnamemodify(.*, ":p")'
      let bufexists += 1
    endif
  endfor
  call assert_equal(1, count1, 'Xtest1 count')
  call assert_equal(2, count2, 'Xtest2 count')
  call assert_equal(2, count2buf, 'Xtest2 buffer count')
  call assert_equal(2, bufexists)

  close
  bwipe!
  call delete('Xtest_mks.out')
endfunc

func Test_mksession_lcd_multiple_tabs()
  tabnew
  tabnew
  lcd .
  tabfirst
  lcd .
  mksession! Xtest_mks.out
  tabonly
  source Xtest_mks.out
  call assert_true(haslocaldir(), 'Tab 1 localdir')
  tabnext 2
  call assert_true(!haslocaldir(), 'Tab 2 localdir')
  tabnext 3
  call assert_true(haslocaldir(), 'Tab 3 localdir')
  call delete('Xtest_mks.out')
endfunc

" Test for tabpage-local directory
func Test_mksession_tcd_multiple_tabs()
  let save_cwd = getcwd()
  call mkdir('Xtopdir')
  cd Xtopdir
  call mkdir('Xtabdir1')
  call mkdir('Xtabdir2')
  call mkdir('Xtabdir3')
  call mkdir('Xwindir1')
  call mkdir('Xwindir2')
  call mkdir('Xwindir3')
  tcd Xtabdir1
  botright new
  wincmd t
  lcd ../Xwindir1
  tabnew
  tcd ../Xtabdir2
  botright new
  lcd ../Xwindir2
  tabnew
  tcd ../Xtabdir3
  botright new
  lcd ../Xwindir3
  tabfirst
  1wincmd w
  mksession! Xtest_mks.out
  only | tabonly
  source Xtest_mks.out
  call assert_equal('Xtabdir1', fnamemodify(getcwd(-1, 1), ':t'))
  call assert_equal('Xwindir1', fnamemodify(getcwd(1, 1), ':t'))
  call assert_equal('Xtabdir1', fnamemodify(getcwd(2, 1), ':t'))
  call assert_equal('Xtabdir2', fnamemodify(getcwd(-1, 2), ':t'))
  call assert_equal('Xtabdir2', fnamemodify(getcwd(1, 2), ':t'))
  call assert_equal('Xwindir2', fnamemodify(getcwd(2, 2), ':t'))
  call assert_equal('Xtabdir3', fnamemodify(getcwd(-1, 3), ':t'))
  call assert_equal('Xtabdir3', fnamemodify(getcwd(1, 3), ':t'))
  call assert_equal('Xwindir3', fnamemodify(getcwd(2, 3), ':t'))
  %bwipe
  call chdir(save_cwd)
  call delete("Xtopdir", "rf")
endfunc

func Test_mksession_blank_tabs()
  tabnew
  tabnew
  tabnew
  tabnext 3
  mksession! Xtest_mks.out
  tabnew
  tabnew
  tabnext 2
  source Xtest_mks.out
  call assert_equal(4, tabpagenr('$'), 'session restore should restore number of tabs')
  call assert_equal(3, tabpagenr(), 'session restore should restore the active tab')
  call delete('Xtest_mks.out')
endfunc

func Test_mksession_buffer_count()
  set hidden

  " Edit exactly three files in the current session.
  %bwipe!
  e Xfoo | tabe Xbar | tabe Xbaz
  tabdo write
  mksession! Xtest_mks.out

  " Verify that loading the session does not create additional buffers.
  %bwipe!
  source Xtest_mks.out
  call assert_equal(3, len(getbufinfo()))

  " Clean up.
  call delete('Xfoo')
  call delete('Xbar')
  call delete('Xbaz')
  call delete('Xtest_mks.out')
  %bwipe!
  set hidden&
endfunc

func Test_mksession_buffer_order()
  %bwipe!
  e Xfoo | e Xbar | e Xbaz | e Xqux
  bufdo write
  mksession! Xtest_mks.out

  " Verify that loading the session preserves order of buffers
  %bwipe!
  source Xtest_mks.out

  let s:buf_info = getbufinfo()
  call assert_true(s:buf_info[0]['name'] =~# 'Xfoo$')
  call assert_true(s:buf_info[1]['name'] =~# 'Xbar$')
  call assert_true(s:buf_info[2]['name'] =~# 'Xbaz$')
  call assert_true(s:buf_info[3]['name'] =~# 'Xqux$')

  " Clean up.
  call delete('Xfoo')
  call delete('Xbar')
  call delete('Xbaz')
  call delete('Xqux')
  call delete('Xtest_mks.out')
  %bwipe!
endfunc

if has('extra_search')

func Test_mksession_hlsearch()
  set hlsearch
  mksession! Xtest_mks.out
  nohlsearch
  source Xtest_mks.out
  call assert_equal(1, v:hlsearch, 'session should restore search highlighting state')
  nohlsearch
  mksession! Xtest_mks.out
  source Xtest_mks.out
  call assert_equal(0, v:hlsearch, 'session should restore search highlighting state')
  call delete('Xtest_mks.out')
endfunc

endif


func Test_mksession_blank_windows()
  split
  split
  split
  3 wincmd w
  mksession! Xtest_mks.out
  split
  split
  2 wincmd w
  source Xtest_mks.out
  call assert_equal(4, winnr('$'), 'session restore should restore number of windows')
  call assert_equal(3, winnr(), 'session restore should restore the active window')
  call delete('Xtest_mks.out')
endfunc

if has('terminal')

func Test_mksession_terminal_shell()
  CheckFeature quickfix

  terminal
  mksession! Xtest_mks.out
  let lines = readfile('Xtest_mks.out')
  let term_cmd = ''
  for line in lines
    if line =~ '^terminal'
      let term_cmd = line
    elseif line =~ 'badd.*' . &shell
      call assert_report('unexpected shell line: ' . line)
    endif
  endfor
  call assert_match('terminal ++curwin ++cols=\d\+ ++rows=\d\+\s*.*$', term_cmd)

  call StopShellInTerminal(bufnr('%'))
  call delete('Xtest_mks.out')
endfunc

func Test_mksession_terminal_no_restore_cmdarg()
  terminal ++norestore
  mksession! Xtest_mks.out
  let lines = readfile('Xtest_mks.out')
  let term_cmd = ''
  for line in lines
    if line =~ '^terminal'
      call assert_report('session must not restore terminal')
    endif
  endfor

  call StopShellInTerminal(bufnr('%'))
  call delete('Xtest_mks.out')
endfunc

func Test_mksession_terminal_no_restore_funcarg()
  call term_start(&shell, {'norestore': 1})
  mksession! Xtest_mks.out
  let lines = readfile('Xtest_mks.out')
  let term_cmd = ''
  for line in lines
    if line =~ '^terminal'
      call assert_report('session must not restore terminal')
    endif
  endfor

  call StopShellInTerminal(bufnr('%'))
  call delete('Xtest_mks.out')
endfunc

func Test_mksession_terminal_no_restore_func()
  terminal
  call term_setrestore(bufnr('%'), 'NONE')
  mksession! Xtest_mks.out
  let lines = readfile('Xtest_mks.out')
  let term_cmd = ''
  for line in lines
    if line =~ '^terminal'
      call assert_report('session must not restore terminal')
    endif
  endfor

  call StopShellInTerminal(bufnr('%'))
  call delete('Xtest_mks.out')
endfunc

func Test_mksession_terminal_no_ssop()
  terminal
  set sessionoptions-=terminal
  mksession! Xtest_mks.out
  let lines = readfile('Xtest_mks.out')
  let term_cmd = ''
  for line in lines
    if line =~ '^terminal'
      call assert_report('session must not restore terminal')
    endif
  endfor

  call StopShellInTerminal(bufnr('%'))
  call delete('Xtest_mks.out')
  set sessionoptions&
endfunc

func Test_mksession_terminal_restore_other()
  CheckFeature quickfix

  terminal
  eval bufnr('%')->term_setrestore('other')
  mksession! Xtest_mks.out
  let lines = readfile('Xtest_mks.out')
  let term_cmd = ''
  for line in lines
    if line =~ '^terminal'
      let term_cmd = line
    endif
  endfor
  call assert_match('terminal ++curwin ++cols=\d\+ ++rows=\d\+.*other', term_cmd)

  call StopShellInTerminal(bufnr('%'))
  call delete('Xtest_mks.out')
endfunc

endif " has('terminal')

func Test_mkview_open_folds()
  enew!

  call append(0, ['a', 'b', 'c'])
  1,3fold
  write! Xtestfile

  call assert_notequal(-1, foldclosed(1))
  call assert_notequal(-1, foldclosed(2))
  call assert_notequal(-1, foldclosed(3))

  " Save the view with folds closed
  mkview! Xtestview

  " zR affects 'foldlevel', make sure the option is applied after the folds
  " have been recreated.
  " Open folds to ensure they get closed when restoring the view
  normal zR

  call assert_equal(-1, foldclosed(1))
  call assert_equal(-1, foldclosed(2))
  call assert_equal(-1, foldclosed(3))

  source Xtestview

  call assert_notequal(-1, foldclosed(1))
  call assert_notequal(-1, foldclosed(2))
  call assert_notequal(-1, foldclosed(3))

  call delete('Xtestview')
  call delete('Xtestfile')
  %bwipe
endfunc

func Test_mkview_no_balt()
  edit Xtestfile1
  edit Xtestfile2

  mkview! Xtestview
  bdelete Xtestfile1

  source Xtestview
  call assert_equal(0, buflisted('Xtestfile1'))

  call delete('Xtestview')
  %bwipe
endfunc

func Test_mksession_no_balt()
  edit Xtestfile1
  edit Xtestfile2

  bdelete Xtestfile1
  mksession! Xtestview

  source Xtestview
  call assert_equal(0, buflisted('Xtestfile1'))

  call delete('Xtestview')
  %bwipe
endfunc

" Test :mkview with a file argument.
func Test_mkview_file()
  " Create a view with line number and a fold.
  help :mkview
  set number
  norm! V}zf0
  let pos = getpos('.')
  let linefoldclosed1 = foldclosed('.')
  mkview! Xview
  set nonumber
  norm! zrj
  " We can close the help window, as mkview with a file name should
  " generate a command to edit the file.
  helpclose

  source Xview
  call assert_equal(1, &number)
  call assert_match('\*:mkview\*$', getline('.'))
  call assert_equal(pos, getpos('.'))
  call assert_equal(linefoldclosed1, foldclosed('.'))

  " Creating a view again with the same file name should fail (file
  " already exists). But with a !, the previous view should be
  " overwritten without error.
  help :loadview
  call assert_fails('mkview Xview', 'E189:')
  call assert_match('\*:loadview\*$', getline('.'))
  mkview! Xview
  call assert_match('\*:loadview\*$', getline('.'))

  call delete('Xview')
  bwipe
endfunc

" Test :mkview and :loadview with a custom 'viewdir'.
func Test_mkview_loadview_with_viewdir()
  set viewdir=Xviewdir

  help :mkview
  set number
  norm! V}zf
  let pos = getpos('.')
  let linefoldclosed1 = foldclosed('.')
  mkview 1
  set nonumber
  norm! zrj

  loadview 1

  " The directory Xviewdir/ should have been created and the view
  " should be stored in that directory.
  call assert_equal('Xviewdir/' .
        \           substitute(
        \             substitute(
        \               expand('%:p'), '/', '=+', 'g'), ':', '=-', 'g') . '=1.vim',
        \           glob('Xviewdir/*'))
  call assert_equal(1, &number)
  call assert_match('\*:mkview\*$', getline('.'))
  call assert_equal(pos, getpos('.'))
  call assert_equal(linefoldclosed1, foldclosed('.'))

  call delete('Xviewdir', 'rf')
  set viewdir&
  helpclose
endfunc

func Test_mkview_no_file_name()
  new
  " :mkview or :mkview {nr} should fail in an unnamed buffer.
  call assert_fails('mkview', 'E32:')
  call assert_fails('mkview 1', 'E32:')

  " :mkview {file} should succeed in an unnamed buffer.
  mkview Xview
  help
  source Xview
  call assert_equal('', bufname('%'))

  call delete('Xview')
  %bwipe
endfunc

func Test_mkview_loadview_jumplist()
  set viewdir=Xviewdir
  au BufWinLeave * silent mkview
  " au BufWinEnter * silent loadview

  edit Xfile1
  call setline(1, ['a', 'bbbbbbb', 'c'])
  normal j3l
  call assert_equal([2, 4], getcurpos()[1:2])
  write

  edit Xfile2
  call setline(1, ['d', 'eeeeeee', 'f'])
  normal j5l
  call assert_equal([2, 6], getcurpos()[1:2])
  write

  edit Xfile3
  call setline(1, ['g', 'h', 'iiiii'])
  normal jj3l
  call assert_equal([3, 4], getcurpos()[1:2])
  write

  " The commented :au above was moved here so that :mkview (on BufWinLeave) can
  " run before :loadview. This is needed because Nvim's :loadview raises E484 if
  " the view can't be opened, while Vim's silently fails instead.
  au BufWinEnter * silent loadview

  edit Xfile1
  call assert_equal([2, 4], getcurpos()[1:2])
  edit Xfile2
  call assert_equal([2, 6], getcurpos()[1:2])
  edit Xfile3
  call assert_equal([3, 4], getcurpos()[1:2])

  exe "normal \<C-O>"
  call assert_equal('Xfile2', expand('%'))
  call assert_equal([2, 6], getcurpos()[1:2])
  exe "normal \<C-O>"
  call assert_equal('Xfile1', expand('%'))
  call assert_equal([2, 4], getcurpos()[1:2])

  au! BufWinLeave
  au! BufWinEnter
  bwipe!
  call delete('Xviewdir', 'rf')
  call delete('Xfile1')
  call delete('Xfile2')
  call delete('Xfile3')
  set viewdir&
endfunc

" A clean session (one empty buffer, one window, and one tab) should not
" set any error messages when sourced because no commands should fail.
func Test_mksession_no_errmsg()
  let v:errmsg = ''
  %bwipe!
  mksession! Xtest_mks.out
  source Xtest_mks.out
  call assert_equal('', v:errmsg)
  call delete('Xtest_mks.out')
endfunc

func Test_mksession_quote_in_filename()
  if !has('unix')
    " only Unix can handle this weird filename
    return
  endif
  let v:errmsg = ''
  let filename = has('win32') ? 'x''y' : 'x''y"z'
  %bwipe!
  split another
  execute 'split' escape(filename, '"')
  mksession! Xtest_mks_quoted.out
  %bwipe!
  source Xtest_mks_quoted.out
  call assert_true(bufexists(filename))

  %bwipe!
  call delete('Xtest_mks_quoted.out')
endfunc

" Test for storing global variables in a session file
func Test_mksession_globals()
  set sessionoptions+=globals

  " create different global variables
  let g:Global_string = "Sun is shining\r\n"
  let g:Global_count = 100
  let g:Global_pi = 3.14
  let g:Global_neg_float = -2.68

  mksession! Xtest_mks.out

  unlet g:Global_string
  unlet g:Global_count
  unlet g:Global_pi
  unlet g:Global_neg_float

  source Xtest_mks.out
  call assert_equal("Sun is shining\r\n", g:Global_string)
  call assert_equal(100, g:Global_count)
  call assert_equal(3.14, g:Global_pi)
  call assert_equal(-2.68, g:Global_neg_float)

  unlet g:Global_string
  unlet g:Global_count
  unlet g:Global_pi
  unlet g:Global_neg_float
  call delete('Xtest_mks.out')
  set sessionoptions&
endfunc

" Test for changing backslash to forward slash in filenames
func Test_mksession_slash()
  if exists('+shellslash')
    throw 'Skipped: cannot use backslash in file name'
  endif
  enew
  %bwipe!
  e a\\b\\c
  mksession! Xtest_mks1.out
  set sessionoptions+=slash
  mksession! Xtest_mks2.out

  %bwipe!
  source Xtest_mks1.out
  call assert_equal('a/b/c', bufname(''))
  %bwipe!
  source Xtest_mks2.out
  call assert_equal('a/b/c', bufname(''))

  %bwipe!
  call delete('Xtest_mks1.out')
  call delete('Xtest_mks2.out')
  set sessionoptions&
endfunc

" Test for changing directory to the session file directory
func Test_mksession_sesdir()
  let save_cwd = getcwd()
  call mkdir('Xproj')
  mksession! Xproj/Xtest_mks1.out
  set sessionoptions-=curdir
  set sessionoptions+=sesdir
  mksession! Xproj/Xtest_mks2.out

  source Xproj/Xtest_mks1.out
  call assert_equal('testdir', fnamemodify(getcwd(), ':t'))
  source Xproj/Xtest_mks2.out
  call assert_equal('Xproj', fnamemodify(getcwd(), ':t'))
  call chdir(save_cwd)
  %bwipe

  set sessionoptions&
  call delete('Xproj', 'rf')
endfunc

" Test for saving and restoring the tab-local working directory when there is
" only a single tab and 'tabpages' is not in 'sessionoptions'.
func Test_mksession_tcd_single_tabs()
  only | tabonly

  let save_cwd = getcwd()
  set sessionoptions-=tabpages
  set sessionoptions+=curdir
  call mkdir('Xtopdir1')
  call mkdir('Xtopdir2')

  " There are two tab pages, the current one has local cwd set to 'Xtopdir2'.
  exec 'tcd ' .. save_cwd .. '/Xtopdir1'
  tabnew
  exec 'tcd ' .. save_cwd .. '/Xtopdir2'
  mksession! Xtest_tcd_single

  source Xtest_tcd_single
  " call assert_equal(2, haslocaldir())
  call assert_equal(1, haslocaldir(-1))
  call assert_equal('Xtopdir2', fnamemodify(getcwd(-1, 0), ':t'))
  %bwipe

  set sessionoptions&
  call chdir(save_cwd)
  call delete('Xtopdir1', 'rf')
  call delete('Xtopdir2', 'rf')
endfunc

" Test for storing the 'lines' and 'columns' settings
func Test_mksession_resize()
  mksession! Xtest_mks1.out
  set sessionoptions+=resize
  mksession! Xtest_mks2.out

  let lines = readfile('Xtest_mks1.out')
  let found_resize = v:false
  for line in lines
    if line =~ '^set lines='
      let found_resize = v:true
      break
    endif
  endfor
  call assert_false(found_resize)
  let lines = readfile('Xtest_mks2.out')
  let found_resize = v:false
  for line in lines
    if line =~ '^set lines='
      let found_resize = v:true
      break
    endif
  endfor
  call assert_true(found_resize)

  call delete('Xtest_mks1.out')
  call delete('Xtest_mks2.out')
  set sessionoptions&
endfunc

" Test for mksession with a named scratch buffer
func Test_mksession_scratch()
  enew | only
  file Xscratch
  set buftype=nofile
  mksession! Xtest_mks.out
  %bwipe
  source Xtest_mks.out
  call assert_equal('Xscratch', bufname(''))
  call assert_equal('nofile', &buftype)
  %bwipe
  call delete('Xtest_mks.out')
endfunc

" Test for mksession with fold options
func Test_mksession_foldopt()
  set sessionoptions-=options
  set sessionoptions+=folds
  new
  setlocal foldenable
  setlocal foldmethod=expr
  setlocal foldmarker=<<<,>>>
  setlocal foldignore=%
  setlocal foldlevel=2
  setlocal foldminlines=10
  setlocal foldnestmax=15
  mksession! Xtest_mks.out
  close
  %bwipe

  source Xtest_mks.out
  call assert_true(&foldenable)
  call assert_equal('expr', &foldmethod)
  call assert_equal('<<<,>>>', &foldmarker)
  call assert_equal('%', &foldignore)
  call assert_equal(2, &foldlevel)
  call assert_equal(10, &foldminlines)
  call assert_equal(15, &foldnestmax)

  close
  %bwipe
  set sessionoptions&
  call delete('Xtest_mks.out')
endfunc

" Test for mksession with "help" but not "options" in 'sessionoptions'
func Test_mksession_help_noopt()
  set sessionoptions-=options
  set sessionoptions+=help
  help
  let fname = expand('%')
  mksession! Xtest_mks.out
  bwipe

  source Xtest_mks.out
  call assert_equal('help', &buftype)
  call assert_equal('help', &filetype)
  call assert_equal(fname, expand('%'))
  call assert_false(&modifiable)
  call assert_true(&readonly)

  helpclose
  help index
  let fname = expand('%')
  mksession! Xtest_mks.out
  bwipe

  source Xtest_mks.out
  call assert_equal('help', &buftype)
  call assert_equal(fname, expand('%'))

  call delete('Xtest_mks.out')
  set sessionoptions&
endfunc

" Test for mksession with window position
func Test_mksession_winpos()
  if !has('gui_running')
    " Only applicable in GUI Vim
    return
  endif
  set sessionoptions+=winpos
  mksession! Xtest_mks.out
  let found_winpos = v:false
  let lines = readfile('Xtest_mks.out')
  for line in lines
    if line =~ '^winpos '
      let found_winpos = v:true
      break
    endif
  endfor
  call assert_true(found_winpos)
  call delete('Xtest_mks.out')
  set sessionoptions&
endfunc

" Test for mksession without options restores winminheight
func Test_mksession_winminheight()
  set sessionoptions-=options
  split
  mksession! Xtest_mks.out
  let found_restore = 0
  let lines = readfile('Xtest_mks.out')
  for line in lines
    if line =~ '= s:save_winmin\(width\|height\)'
      let found_restore += 1
    endif
  endfor
  call assert_equal(2, found_restore)
  call delete('Xtest_mks.out')
  close
  set sessionoptions&
endfunc

" Test for mksession with and without options restores shortmess
func Test_mksession_shortmess()
  " Without options
  set sessionoptions-=options
  split
  mksession! Xtest_mks.out
  let found_save = 0
  let found_restore = 0
  let lines = readfile('Xtest_mks.out')
  for line in lines
    let line = trim(line)

    if line ==# 'let s:shortmess_save = &shortmess'
      let found_save += 1
    endif

    if found_save !=# 0 && line ==# 'let &shortmess = s:shortmess_save'
      let found_restore += 1
    endif
  endfor
  call assert_equal(1, found_save)
  call assert_equal(1, found_restore)
  call delete('Xtest_mks.out')
  close
  set sessionoptions&

  " With options
  set sessionoptions+=options
  split
  mksession! Xtest_mks.out
  let found_restore = 0
  let lines = readfile('Xtest_mks.out')
  for line in lines
    if line =~# 's:shortmess_save'
      let found_restore += 1
    endif
  endfor
  call assert_equal(0, found_restore)
  call delete('Xtest_mks.out')
  close
  set sessionoptions&
endfunc

" Test that when Vim loading session has 'A' in 'shortmess' it does not
" complain about an existing swapfile.
func Test_mksession_shortmess_with_A()
  edit Xtestfile
  write
  let fname = swapname('%')
  let cont = readblob(fname)
  set sessionoptions-=options
  mksession Xtestsession
  bwipe!

  " Recreate the swap file to pretend the file is being edited
  call writefile(cont, fname, 'D')
  set shortmess+=A
  source Xtestsession

  set shortmess&
  set sessionoptions&
  call delete('Xtestsession')
  call delete('Xtestfile')
endfunc

" Test for mksession with 'compatible' option
func Test_mksession_compatible()
  throw 'skipped: Nvim does not support "compatible" option'
  mksession! Xtest_mks1.out
  set compatible
  mksession! Xtest_mks2.out
  set nocp

  let test_success = v:false
  let lines = readfile('Xtest_mks1.out')
  for line in lines
    if line =~ '^if &cp | set nocp | endif'
      let test_success = v:true
      break
    endif
  endfor
  call assert_true(test_success)

  let test_success = v:false
  let lines = readfile('Xtest_mks2.out')
  for line in lines
    if line =~ '^if !&cp | set cp | endif'
      let test_success = v:true
      break
    endif
  endfor
  call assert_true(test_success)

  call delete('Xtest_mks1.out')
  call delete('Xtest_mks2.out')
  set compatible&
  set sessionoptions&
endfunc

func s:ClearMappings()
  mapclear
  omapclear
  mapclear!
  lmapclear
  tmapclear
endfunc

func Test_mkvimrc()
  let entries = [
        \ ['', 'nothing', '<Nop>'],
        \ ['n', 'normal', 'NORMAL<Up>'],
        \ ['v', 'visual', 'VISUAL<S-Down>'],
        \ ['s', 'select', 'SELECT<C-Left>'],
        \ ['x', 'visualonly', 'VISUALONLY<M-Right>'],
        \ ['o', 'operator', 'OPERATOR'],
        \ ['i', 'insert', 'INSERT'],
        \ ['l', 'lang', 'LANG'],
        \ ['c', 'command', 'COMMAND'],
        \ ['t', 'terminal', 'TERMINAL'],
        \ ]
  for entry in entries
    exe entry[0] .. 'map ' .. entry[1] .. ' ' .. entry[2]
  endfor

  mkvimrc Xtestvimrc

  call s:ClearMappings()
  for entry in entries
    call assert_equal('', maparg(entry[1], entry[0]))
  endfor

  source Xtestvimrc

  for entry in entries
    call assert_equal(entry[2], maparg(entry[1], entry[0]))
  endfor

  call s:ClearMappings()

  " the 'pastetoggle', 'wildchar' and 'wildcharm' option values should be
  " stored as key names in the vimrc file
  " set pastetoggle=<F5>
  set wildchar=<F6>
  set wildcharm=<F7>
  call assert_fails('mkvimrc Xtestvimrc')
  mkvimrc! Xtestvimrc
  " call assert_notequal(-1, index(readfile('Xtestvimrc'), 'set pastetoggle=<F5>'))
  call assert_notequal(-1, index(readfile('Xtestvimrc'), 'set wildchar=<F6>'))
  call assert_notequal(-1, index(readfile('Xtestvimrc'), 'set wildcharm=<F7>'))
  " set pastetoggle& wildchar& wildcharm&
  set wildchar& wildcharm&

  call delete('Xtestvimrc')
endfunc

func Test_scrolloff()
  set sessionoptions+=localoptions
  setlocal so=1 siso=1
  mksession! Xtest_mks.out
  setlocal so=-1 siso=-1
  source Xtest_mks.out
  call assert_equal(1, &l:so)
  call assert_equal(1, &l:siso)
  call delete('Xtest_mks.out')
  setlocal so& siso&
  set sessionoptions&
endfunc

func Test_altfile()
  edit Xone
  split Xtwo
  edit Xtwoalt
  edit #
  wincmd w
  edit Xonealt
  edit #
  mksession! Xtest_altfile
  only
  bwipe Xonealt
  bwipe Xtwoalt
  bwipe!
  source Xtest_altfile
  call assert_equal('Xone', bufname())
  call assert_equal('Xonealt', bufname('#'))
  wincmd w
  call assert_equal('Xtwo', bufname())
  call assert_equal('Xtwoalt', bufname('#'))
  only
  bwipe!
  call delete('Xtest_altfile')
endfunc

" Test for creating views with manual folds
func Test_mkview_manual_fold()
  call writefile(range(1,10), 'Xmkvfile', 'D')
  new Xmkvfile
  " create recursive folds
  5,6fold
  4,7fold
  mkview Xview
  normal zE
  source Xview
  call assert_equal([-1, 4, 4, 4, 4, -1], [foldclosed(3), foldclosed(4),
        \ foldclosed(5), foldclosed(6), foldclosed(7), foldclosed(8)])
  " open one level of fold
  4foldopen
  mkview! Xview
  normal zE
  source Xview
  call assert_equal([-1, -1, 5, 5, -1, -1], [foldclosed(3), foldclosed(4),
        \ foldclosed(5), foldclosed(6), foldclosed(7), foldclosed(8)])
  " open all the folds
  %foldopen!
  mkview! Xview
  normal zE
  source Xview
  call assert_equal([-1, -1, -1, -1, -1, -1], [foldclosed(3), foldclosed(4),
        \ foldclosed(5), foldclosed(6), foldclosed(7), foldclosed(8)])
  call delete('Xview')
  bw!
endfunc

" Test for handling invalid folds within views
func Test_mkview_ignore_invalid_folds()
  call writefile(range(1,10), 'Xmkvfile', 'D')
  new Xmkvfile
  " create some folds
  5,6fold
  4,7fold
  mkview Xview
  normal zE
  " delete lines to make folds invalid
  call deletebufline('', 6, '$')
  source Xview
  call assert_equal([-1, -1, -1, -1, -1, -1], [foldclosed(3), foldclosed(4),
        \ foldclosed(5), foldclosed(6), foldclosed(7), foldclosed(8)])
  call delete('Xview')
  bw!
endfunc

" Test default 'viewdir' value
func Test_mkview_default_home()
  throw 'Skipped: N/A'
  if has('win32')
    " use escape() to handle backslash path separators
    call assert_match('^' .. escape($ORIGHOME, '\') .. '/vimfiles', &viewdir)
  elseif has('unix')
    call assert_match(
          \ '^' .. $ORIGHOME .. '/.vim\|' ..
          \ '^' .. $XDG_CONFIG_HOME .. '/vim'
          \ , &viewdir)
  elseif has('amiga')
    call assert_match('^home:vimfiles', &viewdir)
  elseif has('mac')
    call assert_match('^' .. $VIM .. '/vimfiles', &viewdir)
  endif
endfunc

" vim: shiftwidth=2 sts=2 expandtab
