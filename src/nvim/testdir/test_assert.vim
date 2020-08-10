" Test that the methods used for testing work.

func Test_assert_equalfile()
  call assert_equal(1, assert_equalfile('abcabc', 'xyzxyz'))
  call assert_match("E485: Can't read file abcabc", v:errors[0])
  call remove(v:errors, 0)

  let goodtext = ["one", "two", "three"]
  call writefile(goodtext, 'Xone')
  call assert_equal(1, assert_equalfile('Xone', 'xyzxyz'))
  call assert_match("E485: Can't read file xyzxyz", v:errors[0])
  call remove(v:errors, 0)

  call writefile(goodtext, 'Xtwo')
  call assert_equal(0, assert_equalfile('Xone', 'Xtwo'))

  call writefile([goodtext[0]], 'Xone')
  call assert_equal(1, assert_equalfile('Xone', 'Xtwo'))
  call assert_match("first file is shorter", v:errors[0])
  call remove(v:errors, 0)

  call writefile(goodtext, 'Xone')
  call writefile([goodtext[0]], 'Xtwo')
  call assert_equal(1, assert_equalfile('Xone', 'Xtwo'))
  call assert_match("second file is shorter", v:errors[0])
  call remove(v:errors, 0)

  call writefile(['1234X89'], 'Xone')
  call writefile(['1234Y89'], 'Xtwo')
  call assert_equal(1, assert_equalfile('Xone', 'Xtwo'))
  call assert_match('difference at byte 4, line 1 after "1234X" vs "1234Y"', v:errors[0])
  call remove(v:errors, 0)

  call writefile([repeat('x', 234) .. 'X'], 'Xone')
  call writefile([repeat('x', 234) .. 'Y'], 'Xtwo')
  call assert_equal(1, assert_equalfile('Xone', 'Xtwo'))
  let xes = repeat('x', 134)
  call assert_match('difference at byte 234, line 1 after "' .. xes .. 'X" vs "' .. xes .. 'Y"', v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_equalfile('Xone', 'Xtwo', 'a message'))
  call assert_match("a message: difference at byte 234, line 1 after", v:errors[0])
  call remove(v:errors, 0)

  call delete('Xone')
  call delete('Xtwo')
endfunc

func Test_assert_fails_in_try_block()
  try
    call assert_equal(0, assert_fails('throw "error"'))
  endtry
endfunc

" Must be last.
func Test_zz_quit_detected()
  " Verify that if a test function ends Vim the test script detects this.
  quit
endfunc
