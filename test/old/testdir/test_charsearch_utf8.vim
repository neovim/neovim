" Tests for related f{char} and t{char} using utf-8.

" Test for t,f,F,T movement commands
func Test_search_cmds()
  new!
  call setline(1, "・最初から最後まで最強のVimは最高")
  1
  normal! f最
  call assert_equal([0, 1, 4, 0], getpos('.'))
  normal! ;
  call assert_equal([0, 1, 16, 0], getpos('.'))
  normal! 2;
  call assert_equal([0, 1, 43, 0], getpos('.'))
  normal! ,
  call assert_equal([0, 1, 28, 0], getpos('.'))
  call assert_equal('最', getcharsearch().char)
  call setcharsearch({'char' : ''})
  call assert_equal('', getcharsearch().char)
  call assert_beeps('normal ;')
  call assert_equal([0, 1, 28, 0], getpos('.'))
  call assert_beeps('normal ,')
  call assert_equal([0, 1, 28, 0], getpos('.'))
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
