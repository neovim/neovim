" Tests for Vim buffer

" Test for the :bunload command with an offset
func Test_bunload_with_offset()
  %bwipe!
  call writefile(['B1'], 'b1')
  call writefile(['B2'], 'b2')
  call writefile(['B3'], 'b3')
  call writefile(['B4'], 'b4')

  " Load four buffers. Unload the second and third buffers and then
  " execute .+3bunload to unload the last buffer.
  edit b1
  new b2
  new b3
  new b4

  bunload b2
  bunload b3
  exe bufwinnr('b1') . 'wincmd w'
  .+3bunload
  call assert_equal(0, getbufinfo('b4')[0].loaded)
  call assert_equal('b1',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the third and fourth buffers. Execute .+3bunload
  " and check whether the second buffer is unloaded.
  ball
  bunload b3
  bunload b4
  exe bufwinnr('b1') . 'wincmd w'
  .+3bunload
  call assert_equal(0, getbufinfo('b2')[0].loaded)
  call assert_equal('b1',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the second and third buffers and from the last
  " buffer execute .-3bunload to unload the first buffer.
  ball
  bunload b2
  bunload b3
  exe bufwinnr('b4') . 'wincmd w'
  .-3bunload
  call assert_equal(0, getbufinfo('b1')[0].loaded)
  call assert_equal('b4',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the first and second buffers. Execute .-3bunload
  " from the last buffer and check whether the third buffer is unloaded.
  ball
  bunload b1
  bunload b2
  exe bufwinnr('b4') . 'wincmd w'
  .-3bunload
  call assert_equal(0, getbufinfo('b3')[0].loaded)
  call assert_equal('b4',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  %bwipe!
  call delete('b1')
  call delete('b2')
  call delete('b3')
  call delete('b4')
endfunc

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
