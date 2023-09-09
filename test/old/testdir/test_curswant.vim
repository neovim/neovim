" Tests for curswant not changing when setting an option

func Test_curswant()
  new
  call append(0, ['1234567890', '12345'])

  normal! ggf8j
  call assert_equal(7, winsaveview().curswant)
  let &tabstop=&tabstop
  call assert_equal(4, winsaveview().curswant)

  normal! ggf8j
  call assert_equal(7, winsaveview().curswant)
  let &timeoutlen=&timeoutlen
  call assert_equal(7, winsaveview().curswant)

  normal! ggf8j
  call assert_equal(7, winsaveview().curswant)
  let &ttimeoutlen=&ttimeoutlen
  call assert_equal(7, winsaveview().curswant)

  enew!
endfunc
