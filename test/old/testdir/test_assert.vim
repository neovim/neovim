" Test that the methods used for testing work.

source check.vim
source term_util.vim

func Test_assert_false()
  call assert_equal(0, assert_false(0))
  call assert_equal(0, assert_false(v:false))
  call assert_equal(0, v:false->assert_false())

  call assert_equal(1, assert_false(123))
  call assert_match("Expected False but got 123", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, 123->assert_false())
  call assert_match("Expected False but got 123", v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_assert_true()
  call assert_equal(0, assert_true(1))
  call assert_equal(0, assert_true(123))
  call assert_equal(0, assert_true(v:true))
  call assert_equal(0, v:true->assert_true())

  call assert_equal(1, assert_true(0))
  call assert_match("Expected True but got 0", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, 0->assert_true())
  call assert_match("Expected True but got 0", v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_assert_equal()
  let s = 'foo'
  call assert_equal(0, assert_equal('foo', s))
  let n = 4
  call assert_equal(0, assert_equal(4, n))
  let l = [1, 2, 3]
  call assert_equal(0, assert_equal([1, 2, 3], l))
  call assert_equal(v:_null_list, v:_null_list)
  call assert_equal(v:_null_list, [])
  call assert_equal([], v:_null_list)

  let s = 'foo'
  call assert_equal(1, assert_equal('bar', s))
  call assert_match("Expected 'bar' but got 'foo'", v:errors[0])
  call remove(v:errors, 0)

  let s = 'αβγ'
  call assert_equal(1, assert_equal('δεζ', s))
  call assert_match("Expected 'δεζ' but got 'αβγ'", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal('XxxxxxxxxxxxxxxxxxxxxxX', 'XyyyyyyyyyyyyyyyyyyyyyyyyyX')
  call assert_match("Expected 'X\\\\\\[x occurs 21 times]X' but got 'X\\\\\\[y occurs 25 times]X'", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal('ΩωωωωωωωωωωωωωωωωωωωωωΩ', 'ΩψψψψψψψψψψψψψψψψψψψψψψψψψΩ')
  call assert_match("Expected 'Ω\\\\\\[ω occurs 21 times]Ω' but got 'Ω\\\\\\[ψ occurs 25 times]Ω'", v:errors[0])
  call remove(v:errors, 0)

  " special characters are escaped
  call assert_equal("\b\e\f\n\t\r\\\x01\x7f", 'x')
  call assert_match('Expected ''\\b\\e\\f\\n\\t\\r\\\\\\x01\\x7f'' but got ''x''', v:errors[0])
  call remove(v:errors, 0)

  " many composing characters are handled properly
  call setline(1, ' ')
  norm 100gr݀
  call assert_equal(1, getline(1))
  call assert_match("Expected 1 but got '.* occurs 100 times]'", v:errors[0])
  call remove(v:errors, 0)
  bwipe!
endfunc

func Test_assert_equal_dict()
  call assert_equal(0, assert_equal(#{one: 1, two: 2}, #{two: 2, one: 1}))

  call assert_equal(1, assert_equal(#{one: 1, two: 2}, #{two: 2, one: 3}))
  call assert_match("Expected {'one': 1} but got {'one': 3} - 1 equal item omitted", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_equal(#{one: 1, two: 2}, #{two: 22, one: 11}))
  call assert_match("Expected {'one': 1, 'two': 2} but got {'one': 11, 'two': 22}", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_equal(#{}, #{two: 2, one: 1}))
  call assert_match("Expected {} but got {'one': 1, 'two': 2}", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_equal(#{two: 2, one: 1}, #{}))
  call assert_match("Expected {'one': 1, 'two': 2} but got {}", v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_assert_equalfile()
  call assert_equal(1, assert_equalfile('abcabc', 'xyzxyz'))
  call assert_match("E485: Can't read file abcabc", v:errors[0])
  call remove(v:errors, 0)

  let goodtext = ["one", "two", "three"]
  call writefile(goodtext, 'Xone', 'D')
  call assert_equal(1, 'Xone'->assert_equalfile('xyzxyz'))
  call assert_match("E485: Can't read file xyzxyz", v:errors[0])
  call remove(v:errors, 0)

  call writefile(goodtext, 'Xtwo', 'D')
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
endfunc

func Test_assert_notequal()
  let n = 4
  call assert_equal(0, assert_notequal('foo', n))
  let s = 'foo'
  call assert_equal(0, assert_notequal([1, 2, 3], s))

  call assert_equal(1, assert_notequal('foo', s))
  call assert_match("Expected not equal to 'foo'", v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_assert_report()
  call assert_equal(1, assert_report('something is wrong'))
  call assert_match('something is wrong', v:errors[0])
  call remove(v:errors, 0)
  call assert_equal(1, 'also wrong'->assert_report())
  call assert_match('also wrong', v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_assert_exception()
  try
    nocommand
  catch
    call assert_equal(0, assert_exception('E492:'))
  endtry

  try
    nocommand
  catch
    call assert_equal(1, assert_exception('E12345:'))
  endtry
  call assert_match("Expected 'E12345:' but got 'Vim:E492: ", v:errors[0])
  call remove(v:errors, 0)

  try
    nocommand
  catch
    try
      " illegal argument, get NULL for error
      call assert_equal(1, assert_exception([]))
    catch
      call assert_equal(0, assert_exception('E730:'))
    endtry
  endtry

  call assert_equal(1, assert_exception('E492:'))
  call assert_match('v:exception is not set', v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_wrong_error_type()
  let save_verrors = v:errors
  let v:['errors'] = {'foo': 3}
  call assert_equal('yes', 'no')
  let verrors = v:errors
  let v:errors = save_verrors
  call assert_equal(type([]), type(verrors))
endfunc

func Test_compare_fail()
  let s:v = {}
  let s:x = {"a": s:v}
  let s:v["b"] = s:x
  let s:w = {"c": s:x, "d": ''}
  try
    call assert_equal(s:w, '')
  catch
    call assert_equal(0, assert_exception('E724:'))
    " Nvim: expected value isn't shown as NULL
    " call assert_match("Expected NULL but got ''", v:errors[0])
    call assert_match("Expected .* but got ''", v:errors[0])
    call remove(v:errors, 0)
  endtry
endfunc

func Test_match()
  call assert_equal(0, assert_match('^f.*b.*r$', 'foobar'))

  call assert_equal(1, assert_match('bar.*foo', 'foobar'))
  call assert_match("Pattern 'bar.*foo' does not match 'foobar'", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_match('bar.*foo', 'foobar', 'wrong'))
  call assert_match('wrong', v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, 'foobar'->assert_match('bar.*foo', 'wrong'))
  call assert_match('wrong', v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_notmatch()
  call assert_equal(0, assert_notmatch('foo', 'bar'))
  call assert_equal(0, assert_notmatch('^foobar$', 'foobars'))

  call assert_equal(1, assert_notmatch('foo', 'foobar'))
  call assert_match("Pattern 'foo' does match 'foobar'", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, 'foobar'->assert_notmatch('foo'))
  call assert_match("Pattern 'foo' does match 'foobar'", v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_assert_fail_fails()
  call assert_equal(1, assert_fails('xxx', 'E12345'))
  call assert_match("Expected 'E12345' but got 'E492:", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_fails('xxx', 'E9876', 'stupid'))
  call assert_match("stupid: Expected 'E9876' but got 'E492:", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_fails('xxx', ['E9876']))
  call assert_match("Expected 'E9876' but got 'E492:", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_fails('xxx', ['E492:', 'E9876']))
  call assert_match("Expected 'E9876' but got 'E492:", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, assert_fails('echo', '', 'echo command'))
  call assert_match("command did not fail: echo command", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(1, 'echo'->assert_fails('', 'echo command'))
  call assert_match("command did not fail: echo command", v:errors[0])
  call remove(v:errors, 0)

  try
    call assert_equal(1, assert_fails('xxx', []))
  catch
    let exp = v:exception
  endtry
  call assert_match("E856: \"assert_fails()\" second argument", exp)

  try
    call assert_equal(1, assert_fails('xxx', ['1', '2', '3']))
  catch
    let exp = v:exception
  endtry
  call assert_match("E856: \"assert_fails()\" second argument", exp)

  try
    call assert_equal(1, assert_fails('xxx', v:_null_list))
  catch
    let exp = v:exception
  endtry
  call assert_match("E856: \"assert_fails()\" second argument", exp)

  try
    call assert_equal(1, assert_fails('xxx', []))
  catch
    let exp = v:exception
  endtry
  call assert_match("E856: \"assert_fails()\" second argument", exp)

  try
    call assert_equal(1, assert_fails('xxx', #{one: 1}))
  catch
    let exp = v:exception
  endtry
  call assert_match("E1222: String or List required for argument 2", exp)

  try
    call assert_equal(0, assert_fails('xxx', [#{one: 1}]))
  catch
    let exp = v:exception
  endtry
  call assert_match("E731: Using a Dictionary as a String", exp)

  let exp = ''
  try
    call assert_equal(0, assert_fails('xxx', ['E492', #{one: 1}]))
  catch
    let exp = v:exception
  endtry
  call assert_match("E731: Using a Dictionary as a String", exp)

  try
    call assert_equal(1, assert_fails('xxx', 'E492', '', 'burp'))
  catch
    let exp = v:exception
  endtry
  call assert_match("E1210: Number required for argument 4", exp)

  try
    call assert_equal(1, assert_fails('xxx', 'E492', '', 54, 123))
  catch
    let exp = v:exception
  endtry
  call assert_match("E1174: String required for argument 5", exp)

  call assert_equal(1, assert_fails('c0', ['', '\(.\)\1']))
  call assert_match("Expected '\\\\\\\\(.\\\\\\\\)\\\\\\\\1' but got 'E939: Positive count required: c0': c0", v:errors[0])
  call remove(v:errors, 0)

  " Test for matching the line number and the script name in an error message
  call writefile(['', 'call Xnonexisting()'], 'Xassertfails.vim', 'D')
  call assert_fails('source Xassertfails.vim', 'E117:', '', 10)
  call assert_match("Expected 10 but got 2", v:errors[0])
  call remove(v:errors, 0)
  call assert_fails('source Xassertfails.vim', 'E117:', '', 2, 'Xabc')
  call assert_match("Expected 'Xabc' but got .*Xassertfails.vim", v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_assert_wrong_arg_emsg_off()
  CheckFeature folding

  new
  call setline(1, ['foo', 'bar'])
  1,2fold

  " This used to crash Vim
  let &l:foldtext = 'assert_match({}, {})'
  redraw!

  let &l:foldtext = 'assert_equalfile({}, {})'
  redraw!

  bwipe!
endfunc

func Test_assert_fails_in_try_block()
  try
    call assert_equal(0, assert_fails('throw "error"'))
  endtry
endfunc

" Test that assert_fails() in a timer does not cause a hit-enter prompt.
" Requires using a terminal, in regular tests the hit-enter prompt won't be
" triggered.
func Test_assert_fails_in_timer()
  CheckRunVimInTerminal

  let buf = RunVimInTerminal('', {'rows': 6})
  let cmd = ":call timer_start(0, {-> assert_fails('call', 'E471:')})"
  call term_sendkeys(buf, cmd)
  call WaitForAssert({-> assert_equal(cmd, term_getline(buf, 6))})
  call term_sendkeys(buf, "\<CR>")
  call TermWait(buf, 100)
  call assert_match('E471: Argument required', term_getline(buf, 6))

  call StopVimInTerminal(buf)
endfunc

func Test_assert_beeps()
  new
  call assert_equal(0, assert_beeps('normal h'))

  call assert_equal(1, assert_beeps('normal 0'))
  call assert_match("command did not beep: normal 0", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(0, 'normal h'->assert_beeps())
  call assert_equal(1, 'normal 0'->assert_beeps())
  call assert_match("command did not beep: normal 0", v:errors[0])
  call remove(v:errors, 0)

  bwipe
endfunc

func Test_assert_nobeep()
  call assert_equal(1, assert_nobeep('normal! cr'))
  call assert_match("command did beep: normal! cr", v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_assert_inrange()
  call assert_equal(0, assert_inrange(7, 7, 7))
  call assert_equal(0, assert_inrange(5, 7, 5))
  call assert_equal(0, assert_inrange(5, 7, 6))
  call assert_equal(0, assert_inrange(5, 7, 7))

  call assert_equal(1, assert_inrange(5, 7, 4))
  call assert_match("Expected range 5 - 7, but got 4", v:errors[0])
  call remove(v:errors, 0)
  call assert_equal(1, assert_inrange(5, 7, 8))
  call assert_match("Expected range 5 - 7, but got 8", v:errors[0])
  call remove(v:errors, 0)

  call assert_equal(0, 5->assert_inrange(5, 7))
  call assert_equal(0, 7->assert_inrange(5, 7))
  call assert_equal(1, 8->assert_inrange(5, 7))
  call assert_match("Expected range 5 - 7, but got 8", v:errors[0])
  call remove(v:errors, 0)

  call assert_fails('call assert_inrange(1, 1)', 'E119:')

  call assert_equal(0, assert_inrange(7.0, 7, 7))
  call assert_equal(0, assert_inrange(7, 7.0, 7))
  call assert_equal(0, assert_inrange(7, 7, 7.0))
  call assert_equal(0, assert_inrange(5, 7, 5.0))
  call assert_equal(0, assert_inrange(5, 7, 6.0))
  call assert_equal(0, assert_inrange(5, 7, 7.0))

  call assert_equal(1, assert_inrange(5, 7, 4.0))
  call assert_match("Expected range 5.0 - 7.0, but got 4.0", v:errors[0])
  call remove(v:errors, 0)
  call assert_equal(1, assert_inrange(5, 7, 8.0))
  call assert_match("Expected range 5.0 - 7.0, but got 8.0", v:errors[0])
  call remove(v:errors, 0)

  " Use a custom message
  call assert_equal(1, assert_inrange(5, 7, 8, "Higher"))
  call assert_match("Higher: Expected range 5 - 7, but got 8", v:errors[0])
  call remove(v:errors, 0)
  call assert_equal(1, assert_inrange(5, 7, 8.0, "Higher"))
  call assert_match("Higher: Expected range 5.0 - 7.0, but got 8.0", v:errors[0])
  call remove(v:errors, 0)

  " Invalid arguments
  call assert_fails("call assert_inrange([], 2, 3)", 'E1219:')
  call assert_fails("call assert_inrange(1, [], 3)", 'E1219:')
  call assert_fails("call assert_inrange(1, 2, [])", 'E1219:')
endfunc

func Test_assert_with_msg()
  call assert_equal('foo', 'bar', 'testing')
  call assert_match("testing: Expected 'foo' but got 'bar'", v:errors[0])
  call remove(v:errors, 0)
endfunc

func Test_override()
  throw 'Skipped: Nvim does not support test_override()'
  call test_override('char_avail', 1)
  eval 1->test_override('redraw')
  call test_override('ALL', 0)
  call assert_fails("call test_override('xxx', 1)", 'E475:')
  call assert_fails("call test_override('redraw', 'yes')", 'E474:')
  call assert_fails("call test_override('redraw', 'yes')", 'E1210:')
endfunc

func Test_mouse_position()
  let save_mouse = &mouse
  set mouse=a
  new
  call setline(1, ['line one', 'line two'])
  call assert_equal([0, 1, 1, 0], getpos('.'))
  call Ntest_setmouse(1, 5)
  call feedkeys("\<LeftMouse>", "xt")
  call assert_equal([0, 1, 5, 0], getpos('.'))
  call Ntest_setmouse(2, 20)
  call feedkeys("\<LeftMouse>", "xt")
  call assert_equal([0, 2, 8, 0], getpos('.'))
  call Ntest_setmouse(5, 1)
  call feedkeys("\<LeftMouse>", "xt")
  call assert_equal([0, 2, 1, 0], getpos('.'))
  bwipe!
  let &mouse = save_mouse
endfunc

" Test for the test_alloc_fail() function
func Test_test_alloc_fail()
  throw 'Skipped: Nvim does not support test_alloc_fail()'
  call assert_fails('call test_alloc_fail([], 1, 1)', 'E474:')
  call assert_fails('call test_alloc_fail(10, [], 1)', 'E474:')
  call assert_fails('call test_alloc_fail(10, 1, [])', 'E474:')
  call assert_fails('call test_alloc_fail(999999, 1, 1)', 'E474:')
endfunc

" Test for the test_option_not_set() function
func Test_test_option_not_set()
  throw 'Skipped: Nvim does not support test_option_not_set()'
  call assert_fails('call test_option_not_set("Xinvalidopt")', 'E475:')
endfunc

" Must be last.
func Test_zz_quit_detected()
  " Verify that if a test function ends Vim the test script detects this.
  quit
endfunc
