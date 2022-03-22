" Tests for srand() and rand()

func Test_Rand()
  let r = srand(123456789)
  call assert_equal([1573771921, 319883699, 2742014374, 1324369493], r)
  call assert_equal(4284103975, rand(r))
  call assert_equal(1001954530, rand(r))
  call assert_equal(2701803082, rand(r))
  call assert_equal(2658065534, rand(r))
  call assert_equal(3104308804, rand(r))

  " Nvim does not support test_settime
  " call test_settime(12341234)
  let s = srand()
  if !has('win32') && filereadable('/dev/urandom')
    " using /dev/urandom
    call assert_notequal(s, srand())
  " else
  "   " using time()
  "   call assert_equal(s, srand())
  "   call test_settime(12341235)
  "   call assert_notequal(s, srand())
  endif

  " Nvim does not support test_srand_seed
  " call test_srand_seed(123456789)
  " call assert_equal(4284103975, rand())
  " call assert_equal(1001954530, rand())
  " call test_srand_seed()

  if has('float')
    call assert_fails('echo srand(1.2)', 'E805:')
  endif
  call assert_fails('echo srand([1])', 'E745:')
  call assert_fails('echo rand("burp")', 'E475:')
  call assert_fails('echo rand([1, 2, 3])', 'E475:')
  call assert_fails('echo rand([[1], 2, 3, 4])', 'E475:')
  call assert_fails('echo rand([1, [2], 3, 4])', 'E475:')
  call assert_fails('echo rand([1, 2, [3], 4])', 'E475:')
  call assert_fails('echo rand([1, 2, 3, [4]])', 'E475:')

  " call test_settime(0)
endfunc

func Test_issue_5587()
  call rand()
  call garbagecollect()
  call rand()
endfunc

" vim: shiftwidth=2 sts=2 expandtab
