" Test matchstrpos

func Test_matchstrpos()
  call assert_equal(['ing', 4, 7], matchstrpos('testing', 'ing'))

  call assert_equal(['ing', 4, 7], matchstrpos('testing', 'ing', 2))

  call assert_equal(['', -1, -1], matchstrpos('testing', 'ing', 5))

  call assert_equal(['ing', 1, 4, 7], matchstrpos(['vim', 'testing', 'execute'], 'ing'))

  call assert_equal(['', -1, -1, -1], matchstrpos(['vim', 'testing', 'execute'], 'img'))
endfunc
