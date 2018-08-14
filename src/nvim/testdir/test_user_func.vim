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
  let g:FuncRef=function("FuncWithRef")
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
