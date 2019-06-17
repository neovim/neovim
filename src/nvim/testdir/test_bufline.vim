" Tests for setbufline() and getbufline()

func Test_setbufline_getbufline()
  new
  let b = bufnr('%')
  hide
  call assert_equal(0, setbufline(b, 1, ['foo', 'bar']))
  call assert_equal(['foo'], getbufline(b, 1))
  call assert_equal(['bar'], getbufline(b, 2))
  call assert_equal(['foo', 'bar'], getbufline(b, 1, 2))
  exe "bd!" b
  call assert_equal([], getbufline(b, 1, 2))

  split Xtest
  call setline(1, ['a', 'b', 'c'])
  let b = bufnr('%')
  wincmd w
  call assert_equal(1, setbufline(b, 5, ['x']))
  call assert_equal(1, setbufline(1234, 1, ['x']))
  call assert_equal(0, setbufline(b, 4, ['d', 'e']))
  call assert_equal(['c'], getbufline(b, 3))
  call assert_equal(['d'], getbufline(b, 4))
  call assert_equal(['e'], getbufline(b, 5))
  call assert_equal([], getbufline(b, 6))
  exe "bwipe! " . b
endfunc
