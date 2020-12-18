" Test for :mksession, :mkview and :loadview in latin1 encoding

scriptencoding latin1

if !has('mksession')
  finish
endif

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

func Test_mksession_rtp()
  if has('win32')
    " TODO: fix problem with backslashes
    return
  endif
  new
  set sessionoptions&vi
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
  set sessionoptions&
endfunc

" Verify that arglist is stored correctly to the session file.
func Test_mksession_arglist()
  %argdel
  next file1 file2 file3 file4
  mksession! Xtest_mks.out
  source Xtest_mks.out
  call assert_equal(['file1', 'file2', 'file3', 'file4'], argv())

  call delete('Xtest_mks.out')
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
  endfor
  call assert_equal(1, count1, 'Xtest1 count')
  call assert_equal(2, count2, 'Xtest2 count')
  call assert_equal(2, count2buf, 'Xtest2 buffer count')

  close
  bwipe!
  call delete('Xtest_mks.out')
endfunc

if has('extra_search')

func Test_mksession_hlsearch()
  set sessionoptions&vi
  set hlsearch
  mksession! Xtest_mks.out
  nohlsearch
  source Xtest_mks.out
  call assert_equal(1, v:hlsearch, 'session should restore search highlighting state')
  nohlsearch
  mksession! Xtest_mks.out
  source Xtest_mks.out
  call assert_equal(0, v:hlsearch, 'session should restore search highlighting state')
  set sessionoptions&
  call delete('Xtest_mks.out')
endfunc

endif

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
  " :mkview or :mkview {nr} should fail in a unnamed buffer.
  call assert_fails('mkview', 'E32:')
  call assert_fails('mkview 1', 'E32:')

  " :mkview {file} should succeed in a unnamed buffer.
  mkview Xview
  help
  source Xview
  call assert_equal('', bufname('%'))

  call delete('Xview')
  %bwipe
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
  let g:Global_string = "Sun is shining"
  let g:Global_count = 100
  let g:Global_pi = 3.14

  mksession! Xtest_mks.out

  unlet g:Global_string
  unlet g:Global_count
  unlet g:Global_pi

  source Xtest_mks.out
  call assert_equal("Sun is shining", g:Global_string)
  call assert_equal(100, g:Global_count)
  call assert_equal(3.14, g:Global_pi)

  unlet g:Global_string
  unlet g:Global_count
  unlet g:Global_pi
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
  call mkdir('Xproj')
  mksession! Xproj/Xtest_mks1.out
  set sessionoptions-=curdir
  set sessionoptions+=sesdir
  mksession! Xproj/Xtest_mks2.out

  source Xproj/Xtest_mks1.out
  call assert_equal('testdir', fnamemodify(getcwd(), ':t'))
  source Xproj/Xtest_mks2.out
  call assert_equal('Xproj', fnamemodify(getcwd(), ':t'))
  cd ..

  set sessionoptions&
  call delete('Xproj', 'rf')
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
    endif
  endfor
  call assert_equal(v:false, found_resize)
  let lines = readfile('Xtest_mks2.out')
  let found_resize = v:false
  for line in lines
    if line =~ '^set lines='
      let found_resize = v:true
    endif
  endfor
  call assert_equal(v:true, found_resize)

  call delete('Xtest_mks1.out')
  call delete('Xtest_mks2.out')
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
        \ ['n', 'normal', 'NORMAL'],
        \ ['v', 'visual', 'VISUAL'],
        \ ['s', 'select', 'SELECT'],
        \ ['x', 'visualonly', 'VISUALONLY'],
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

" vim: shiftwidth=2 sts=2 expandtab
