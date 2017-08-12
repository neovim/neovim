" Test that the methods used for testing work.

func Test_assert_notequal()
  let n = 4
  call assert_notequal('foo', n)
  let s = 'foo'
  call assert_notequal([1, 2, 3], s)

  call assert_notequal('foo', s)
  call assert_match("Expected not equal to 'foo'", v:errors[0])
  call remove(v:errors, 0)
endfunc
