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
  " FIXME: I would expect the same result as '20z3' since 'help z'
  " says: Specifying no mark at all is the same as "+".
  " However it " gives "\n21\n22\n23" instead. Bug in Vim or in ":help :z"?
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
  call assert_equal(20, line('.'))

  let a = execute('20z=1000')
  call assert_match("^\n1\n.*\n-\\+\n20\n-\\\+\n.*\n100$", a)
  call assert_equal(20, line('.'))

  " Tests with multiple windows.
  5split
  call setline(1, range(1, 100))
  " Without a count, the number line is window height - 3.
  let a = execute('20z')
  call assert_equal("\n20\n21", a)
  call assert_equal(21, line('.'))
  " If window height - 3 is less than 1, it should be clamped to 1.
  resize 2
  let a = execute('20z')
  call assert_equal("\n20", a)
  call assert_equal(20, line('.'))

  call assert_fails('20z=a', 'E144:')

  set window& scroll&
  bw!
endfunc

" :z! is the same as :z but count uses the Vim window height when not specified.
func Test_z_bang()
  4split
  call setline(1, range(1, 20))

  let a = execute('10z!')
  call assert_equal("\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20", a)

  let a = execute('10z!#')
  call assert_equal("\n 10 10\n 11 11\n 12 12\n 13 13\n 14 14\n 15 15\n 16 16\n 17 17\n 18 18\n 19 19\n 20 20", a)

  let a = execute('10z!3')
  call assert_equal("\n10\n11\n12", a)

  %bwipe!
endfunc

func Test_z_overflow()
  " This used to access invalid memory as a result of an integer overflow
  " and freeze vim.
  normal ox
  normal Heat
  z777777776666666
  ')
endfunc

func Test_z_negative_lnum()
  new
  z^
  call assert_equal(1, line('.'))
  bwipe!
endfunc
