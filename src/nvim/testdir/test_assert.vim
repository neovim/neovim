" Test that the methods used for testing work.

func Test_assert_inrange()
  call assert_inrange(7, 7, 7)
  call assert_inrange(5, 7, 5)
  call assert_inrange(5, 7, 6)
  call assert_inrange(5, 7, 7)

  call assert_inrange(5, 7, 4)
  call assert_match("Expected range 5 - 7, but got 4", v:errors[0])
  call remove(v:errors, 0)
  call assert_inrange(5, 7, 8)
  call assert_match("Expected range 5 - 7, but got 8", v:errors[0])
  call remove(v:errors, 0)

  call assert_fails('call assert_inrange(1, 1)', 'E119:')
endfunc
