" Test that the methods used for testing work.

func Test_assert_false()
  call assert_false(0)
endfunc

func Test_assert_true()
  call assert_true(1)
  call assert_true(123)
endfunc

func Test_assert_equal()
  let s = 'foo'
  call assert_equal('foo', s)
  let n = 4
  call assert_equal(4, n)
  let l = [1, 2, 3]
  call assert_equal([1, 2, 3], l)
endfunc
