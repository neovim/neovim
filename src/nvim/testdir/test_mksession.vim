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
    \   'Aäöü  three mulTibyte characters'
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
  let li = filter(readfile('Xtest_mks.out'), 'v:val =~# "\\(^ *normal! 0\\|^ *exe ''normal!\\)"')
  let expected = [
    \   'normal! 016|',
    \   'normal! 016|',
    \   'normal! 016|',
    \   'normal! 08|',
    \   'normal! 08|',
    \   'normal! 016|',
    \   'normal! 016|',
    \   'normal! 016|',
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


" vim: shiftwidth=2 sts=2 expandtab
