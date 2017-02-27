" Test behavior of boolean-like values.

" Test what is explained at ":help TRUE" and ":help FALSE".
func Test_if()
  if v:false
    call assert_true(false, 'v:false is false')
  endif
  if 0
    call assert_true(false, 'zero is false')
  endif
  if "0"
    call assert_true(false, 'zero string is false')
  endif
  if "foo"
    call assert_true(false, 'foo is false')
  endif
  if " "
    call assert_true(false, 'space is false')
  endif
  if empty("foo")
    call assert_true(false, 'foo is not empty')
  endif

  if v:true
  else
    call assert_true(false, 'v:true is true')
  endif
  if 1
  else
    call assert_true(false, 'one is true')
  endif
  if "1"
  else
    call assert_true(false, 'one string is true')
  endif
  if "1foo"
  else
    call assert_true(false, 'one in string is true')
  endif

  call assert_fails('if [1]', 'E745')
  call assert_fails('if {1: 1}', 'E728')
  call assert_fails('if function("string")', 'E703')
  call assert_fails('if 1.3")', 'E805')
endfunc

function Try_arg_true_false(expr, false_val, true_val)
  for v in ['v:false', '0', '"0"', '"foo"', '" "'] 
    let r = eval(substitute(a:expr, '%v%', v, ''))
    call assert_equal(a:false_val, r, 'result for ' . v . ' is not ' . string(a:false_val) . ' but ' . string(r))
  endfor
  for v in ['v:true', '1', '"1"', '"1foo"'] 
    let r = eval(substitute(a:expr, '%v%', v, ''))
    call assert_equal(a:true_val, r, 'result for ' . v . ' is not ' . string(a:true_val) . ' but ' . string(r))
  endfor
endfunc

" Test using TRUE or FALSE values for an argument.
func Test_true_false_arg()
  call Try_arg_true_false('count(["a", "A"], "a", %v%)', 1, 2)

  set wildignore=*.swp
  call Try_arg_true_false('expand("foo.swp", %v%)', "", "foo.swp")
  call Try_arg_true_false('expand("foo.vim", 0, %v%)', "foo.vim", ["foo.vim"])

  call setreg('a', ['x', 'y'])
  call Try_arg_true_false('getreg("a", 1, %v%)', "x\ny\n", ['x', 'y'])

  set wildignore=*.vim
  call Try_arg_true_false('glob("runtest.vim", %v%)', "", "runtest.vim")
  set wildignore=*.swp
  call Try_arg_true_false('glob("runtest.vim", 0, %v%)', "runtest.vim", ["runtest.vim"])
  if has('unix')
    silent !ln -s doesntexit Xlink
    call Try_arg_true_false('glob("Xlink", 0, 0, %v%)', "", "Xlink")
    silent !rm Xlink
  endif

  set wildignore=*.vim
  call Try_arg_true_false('globpath(".", "runtest.vim", %v%)', "", "./runtest.vim")
  set wildignore=*.swp
  call Try_arg_true_false('globpath(".", "runtest.vim", 0, %v%)', "./runtest.vim", ["./runtest.vim"])
  if has('unix')
    silent !ln -s doesntexit Xlink
    call Try_arg_true_false('globpath(".", "Xlink", 0, 0, %v%)', "", "./Xlink")
    silent !rm Xlink
  endif

  abbr asdf asdff
  call Try_arg_true_false('hasmapto("asdff", "i", %v%)', 0, 1)

  call Try_arg_true_false('index(["a", "A"], "A", 0, %v%)', 1, 0)

  function FilterMapArg(d)
    if type(a:d) == type({})
      return filter(a:d, 'v:key == "rhs"')
    endif
    return a:d
  endfunction
  call Try_arg_true_false('maparg("asdf", "i", %v%)', "", "asdff")
  call Try_arg_true_false('FilterMapArg(maparg("asdf", "i", 1, %v%))', "asdff", {'rhs': 'asdff'})

  call Try_arg_true_false('hasmapto("asdf", "i", %v%)', 0, 1)

  new colored
  call setline(1, '<here>')
  syn match brackets "<.*>"
  syn match here "here" transparent
  let brackets_id = synID(1, 1, 0)
  let here_id = synID(1, 3, 0)
  call Try_arg_true_false('synID(1, 3, %v%)', here_id, brackets_id)
  bwipe!
endfunc

function Try_arg_non_zero(expr, false_val, true_val)
  for v in ['v:false', '0', '[1]', '{2:3}', '3.4'] 
    let r = eval(substitute(a:expr, '%v%', v, ''))
    call assert_equal(a:false_val, r, 'result for ' . v . ' is not ' . a:false_val . ' but ' . r)
  endfor
  for v in ['v:true', '1', '" "', '"0"'] 
    let r = eval(substitute(a:expr, '%v%', v, ''))
    call assert_equal(a:true_val, r, 'result for ' . v . ' is not ' . a:true_val . ' but ' . r)
  endfor
endfunc


" Test using non-zero-arg for an argument.
func Test_non_zero_arg()
  " call test_settime(93784)
  " call Try_arg_non_zero("mode(%v%)", 'x', 'x!')
  " call test_settime(0)

  call Try_arg_non_zero("shellescape('foo%', %v%)", "'foo%'", "'foo\\%'")

  " visualmode() needs to be called twice to check
  for v in [v:false, 0, [1], {2:3}, 3.4] 
    normal vv
    let r = visualmode(v)
    call assert_equal('v', r, 'result for ' . string(v) . ' is not "v" but ' . r)
    let r = visualmode(v)
    call assert_equal('v', r, 'result for ' . string(v) . ' is not "v" but ' . r)
  endfor
  for v in [v:true, 1, " ", "0"] 
    normal vv
    let r = visualmode(v)
    call assert_equal('v', r, 'result for ' . v . ' is not "v" but ' . r)
    let r = visualmode(v)
    call assert_equal('', r, 'result for ' . v . ' is not "" but ' . r)
  endfor
endfunc
