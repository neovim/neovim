" Test :z

func Test_z()
  call setline(1, range(1, 100))

  let a = execute('20z3')
  call assert_equal("\n20\n21\n22", a)
  call assert_equal(22, line('.'))
  " 'window' should be set to the {count} value.
  call assert_equal(3, &window)

  " If there is only one window, then twice the amount of 'scroll' is used.
  set scroll=2
  let a = execute('20z')
  call assert_equal("\n20\n21\n22\n23", a)
  call assert_equal(23, line('.'))

  let a = execute('20z+3')
  " FIXME: I would expect the same result as '20z3' but it
  " gives "\n21\n22\n23" instead. Bug in Vim or in ":help :z"?
  "call assert_equal("\n20\n21\n22", a)
  "call assert_equal(22, line('.'))

  let a = execute('20z-3')
  call assert_equal("\n18\n19\n20", a)
  call assert_equal(20, line('.'))

  let a = execute('20z=3')
  call assert_match("^\n18\n19\n-\\+\n20\n-\\+\n21\n22$", a)
  call assert_equal(20, line('.'))

  let a = execute('20z^3')
  call assert_equal("\n14\n15\n16\n17", a)
  call assert_equal(17, line('.'))

  let a = execute('20z.3')
  call assert_equal("\n19\n20\n21", a)
  call assert_equal(21, line('.'))

  let a = execute('20z#3')
  call assert_equal("\n 20 20\n 21 21\n 22 22", a)
  call assert_equal(22, line('.'))

  let a = execute('20z#-3')
  call assert_equal("\n 18 18\n 19 19\n 20 20", a)
  call assert_equal(20, line('.'))

  let a = execute('20z#=3')
  call assert_match("^\n 18 18\n 19 19\n-\\+\n 20 20\n-\\+\n 21 21\n 22 22$", a)
  call assert_equal(20, line('.'))

  " Test with {count} bigger than the number of lines in buffer.
  let a = execute('20z1000')
  call assert_match("^\n20\n21\n.*\n99\n100$", a)
  call assert_equal(100, line('.'))

  let a = execute('20z-1000')
  call assert_match("^\n1\n2\n.*\n19\n20$", a)
  call assert_equal(20, line('.'))

  let a = execute('20z=1000')
  call assert_match("^\n1\n.*\n-\\+\n20\n-\\\+\n.*\n100$", a)
  call assert_equal(20, line('.'))

  call assert_fails('20z=a', 'E144:')

  set window& scroll&
  bw!
endfunc

func Test_z_bug()
  " This used to access invalid memory as a result of an integer overflow
  " and freeze vim.
  normal ox
  normal Heat
  z777777776666666
  ')
endfunc
