" Tests for Vim buffer

func Test_balt()
  new SomeNewBuffer
  balt +3 OtherBuffer
  e #
  call assert_equal('OtherBuffer', bufname())
endfunc

" vim: shiftwidth=2 sts=2 expandtab
