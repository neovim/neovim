" Tests for srand() and rand()

source check.vim
source shared.vim

func Test_Rand()
  let r = srand(123456789)
  call assert_equal([1573771921, 319883699, 2742014374, 1324369493], r)
  call assert_equal(4284103975, rand(r))
  call assert_equal(1001954530, rand(r))
  call assert_equal(2701803082, rand(r))
  call assert_equal(2658065534, rand(r))
  call assert_equal(3104308804, rand(r))

  let s = srand()
  " using /dev/urandom or used time, result is different each time
  call assert_notequal(s, srand())

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
  call assert_fails('echo rand([1, 2, 3])', 'E730:')
  call assert_fails('echo rand([[1], 2, 3, 4])', 'E730:')
  call assert_fails('echo rand([1, [2], 3, 4])', 'E730:')
  call assert_fails('echo rand([1, 2, [3], 4])', 'E730:')
  call assert_fails('echo rand([1, 2, 3, [4]])', 'E730:')
endfunc

func Test_issue_5587()
  call rand()
  call garbagecollect()
  call rand()
endfunc

func Test_srand()
  CheckNotGui

  let cmd = GetVimCommand() .. ' -V -es -c "echo rand()" -c qa!'
  let bad = 0
  for _ in range(10)
    echo cmd
    let result1 = system(cmd)
    let result2 = system(cmd)
    if result1 ==# result2
      let bad += 1
    endif
  endfor
  call assert_inrange(0, 4, bad)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
