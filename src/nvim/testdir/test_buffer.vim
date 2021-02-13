" Tests for Vim buffer

func Test_badd_options()
  new SomeNewBuffer
  setlocal cole=3
  wincmd p
  badd SomeNewBuffer
  new SomeNewBuffer
  call assert_equal(3, &cole)
  close
  close
  bwipe! SomeNewBuffer
endfunc

func Test_balt()
  new SomeNewBuffer
  balt +3 OtherBuffer
  e #
  call assert_equal('OtherBuffer', bufname())
endfunc

" vim: shiftwidth=2 sts=2 expandtab
