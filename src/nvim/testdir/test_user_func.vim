" Test for user functions.
" Also test an <expr> mapping calling a function.
" Also test that a builtin function cannot be replaced.
" Also test for regression when calling arbitrary expression.

func Table(title, ...)
  let ret = a:title
  let idx = 1
  while idx <= a:0
    exe "let ret = ret . a:" . idx
    let idx = idx + 1
  endwhile
  return ret
endfunc

func Compute(n1, n2, divname)
  if a:n2 == 0
    return "fail"
  endif
  exe "let g:" . a:divname . " = ". a:n1 / a:n2
  return "ok"
endfunc

func Expr1()
  silent! normal! v
  return "111"
endfunc

func Expr2()
  call search('XX', 'b')
  return "222"
endfunc

func ListItem()
  let g:counter += 1
  return g:counter . '. '
endfunc

func ListReset()
  let g:counter = 0
  return ''
endfunc

func FuncWithRef(a)
  unlet g:FuncRef
  return a:a
endfunc

func Test_user_func()
  let g:FuncRef = function("FuncWithRef")
  let g:counter = 0
  inoremap <expr> ( ListItem()
  inoremap <expr> [ ListReset()
  imap <expr> + Expr1()
  imap <expr> * Expr2()
  let g:retval = "nop"

  call assert_equal('xxx4asdf', Table("xxx", 4, "asdf"))
  call assert_equal('fail', Compute(45, 0, "retval"))
  call assert_equal('nop', g:retval)
  call assert_equal('ok', Compute(45, 5, "retval"))
  call assert_equal(9, g:retval)
  call assert_equal(333, g:FuncRef(333))

  let g:retval = "nop"
  call assert_equal('xxx4asdf', "xxx"->Table(4, "asdf"))
  call assert_equal('fail', 45->Compute(0, "retval"))
  call assert_equal('nop', g:retval)
  call assert_equal('ok', 45->Compute(5, "retval"))
  call assert_equal(9, g:retval)
  " call assert_equal(333, 333->g:FuncRef())

  enew

  normal oXX+-XX
  call assert_equal('XX111-XX', getline('.'))
  normal o---*---
  call assert_equal('---222---', getline('.'))
  normal o(one
  call assert_equal('1. one', getline('.'))
  normal o(two
  call assert_equal('2. two', getline('.'))
  normal o[(one again
  call assert_equal('1. one again', getline('.'))

  call assert_equal(3, max([1, 2, 3]))
  call assert_fails("call extend(g:, {'max': function('min')})", 'E704')
  call assert_equal(3, max([1, 2, 3]))

  " Regression: the first line below used to throw ?E110: Missing ')'?
  " Second is here just to prove that this line is correct when not skipping
  " rhs of &&.
  call assert_equal(0, (0 && (function('tr'))(1, 2, 3)))
  call assert_equal(1, (1 && (function('tr'))(1, 2, 3)))

  delfunc Table
  delfunc Compute
  delfunc Expr1
  delfunc Expr2
  delfunc ListItem
  delfunc ListReset
  unlet g:retval g:counter
  enew!
endfunc

func Log(val, base = 10)
  return log(a:val) / log(a:base)
endfunc

func Args(mandatory, optional = v:null, ...)
  return deepcopy(a:)
endfunc

func Args2(a = 1, b = 2, c = 3)
  return deepcopy(a:)
endfunc

func MakeBadFunc()
  func s:fcn(a, b=1, c)
  endfunc
endfunc

func Test_default_arg()
  if has('float')
    call assert_equal(1.0, Log(10))
    call assert_equal(log(10), Log(10, exp(1)))
    call assert_fails("call Log(1,2,3)", 'E118')
  endif

  let res = Args(1)
  call assert_equal(res.mandatory, 1)
  call assert_equal(res.optional, v:null)
  call assert_equal(res['0'], 0)

  let res = Args(1,2)
  call assert_equal(res.mandatory, 1)
  call assert_equal(res.optional, 2)
  call assert_equal(res['0'], 0)

  let res = Args(1,2,3)
  call assert_equal(res.mandatory, 1)
  call assert_equal(res.optional, 2)
  call assert_equal(res['0'], 1)

  call assert_fails("call MakeBadFunc()", 'E989')
  call assert_fails("fu F(a=1 ,) | endf", 'E475')

  " Since neovim does not have v:none, the ability to use the default
  " argument with the intermediate argument set to v:none has been omitted.
  " Therefore, this test is not performed.
  " let d = Args2(7, v:none, 9)
  " call assert_equal([7, 2, 9], [d.a, d.b, d.c])

  call assert_equal("\n"
	\ .. "   function Args2(a = 1, b = 2, c = 3)\n"
	\ .. "1    return deepcopy(a:)\n"
	\ .. "   endfunction",
	\ execute('func Args2'))
endfunc

func s:addFoo(lead)
  return a:lead .. 'foo'
endfunc

func Test_user_method()
  eval 'bar'->s:addFoo()->assert_equal('barfoo')
endfunc

func Test_failed_call_in_try()
  try | call UnknownFunc() | catch | endtry
endfunc
