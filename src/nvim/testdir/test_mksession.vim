" Test for :mksession, :mkview and :loadview in latin1 encoding

scriptencoding latin1

if !has('multi_byte') || !has('mksession')
  finish
endif

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
endfunc

func Test_mksession_winheight()
  new
  set winheight=10 winminheight=2
  mksession! Xtest_mks.out
  source Xtest_mks.out

  call delete('Xtest_mks.out')
endfunc

" Verify that arglist is stored correctly to the session file.
func Test_mksession_arglist()
  argdel *
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

" vim: shiftwidth=2 sts=2 expandtab
