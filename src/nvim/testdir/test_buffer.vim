" Tests for Vim buffer

func Test_buffer_error()
  new foo1
  new foo2

  call assert_fails('buffer foo', 'E93:')
  call assert_fails('buffer bar', 'E94:')
  call assert_fails('buffer 0', 'E939:')

  %bwipe
endfunc

func Test_badd_options()
  new SomeNewBuffer
  setlocal numberwidth=3
  wincmd p
  badd +1 SomeNewBuffer
  new SomeNewBuffer
  call assert_equal(3, &numberwidth)
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
