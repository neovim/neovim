" Test for user functions.
" Also test an <expr> mapping calling a function.
" Also test that a builtin function cannot be replaced.
" Also test for regression when calling arbitrary expression.

source check.vim
source shared.vim

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

  " Try to overwrite a function in the global (g:) scope
  call assert_equal(3, max([1, 2, 3]))
  call assert_fails("call extend(g:, {'max': function('min')})", 'E704')
  call assert_equal(3, max([1, 2, 3]))

  " Try to overwrite an user defined function with a function reference
  call assert_fails("let Expr1 = function('min')", 'E705:')

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

  call assert_fails("call MakeBadFunc()", 'E989:')
  call assert_fails("fu F(a=1 ,) | endf", 'E1068:')

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

  " Error in default argument expression
  let l =<< trim END
    func F1(x = y)
      return a:x * 2
    endfunc
    echo F1()
  END
  let @a = l->join("\n")
  call assert_fails("exe @a", 'E121:')
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

" Test for listing user-defined functions
func Test_function_list()
  call assert_fails("function Xabc", 'E123:')
endfunc

" Test for <sfile>, <slnum> in a function
func Test_sfile_in_function()
  func Xfunc()
    call assert_match('..Test_sfile_in_function\[5]..Xfunc', expand('<sfile>'))
    call assert_equal('2', expand('<slnum>'))
  endfunc
  call Xfunc()
  delfunc Xfunc
endfunc

" Test trailing text after :endfunction				    {{{1
func Test_endfunction_trailing()
  call assert_false(exists('*Xtest'))

  exe "func Xtest()\necho 'hello'\nendfunc\nlet done = 'yes'"
  call assert_true(exists('*Xtest'))
  call assert_equal('yes', done)
  delfunc Xtest
  unlet done

  exe "func Xtest()\necho 'hello'\nendfunc|let done = 'yes'"
  call assert_true(exists('*Xtest'))
  call assert_equal('yes', done)
  delfunc Xtest
  unlet done

  " trailing line break
  exe "func Xtest()\necho 'hello'\nendfunc\n"
  call assert_true(exists('*Xtest'))
  delfunc Xtest

  set verbose=1
  exe "func Xtest()\necho 'hello'\nendfunc \" garbage"
  call assert_notmatch('W22:', split(execute('1messages'), "\n")[0])
  call assert_true(exists('*Xtest'))
  delfunc Xtest

  exe "func Xtest()\necho 'hello'\nendfunc garbage"
  call assert_match('W22:', split(execute('1messages'), "\n")[0])
  call assert_true(exists('*Xtest'))
  delfunc Xtest
  set verbose=0

  func Xtest(a1, a2)
    echo a:a1 .. a:a2
  endfunc
  set verbose=15
  redir @a
  call Xtest(123, repeat('x', 100))
  redir END
  call assert_match('calling Xtest(123, ''xxxxxxx.*x\.\.\.x.*xxxx'')', getreg('a'))
  delfunc Xtest
  set verbose=0

  function Foo()
    echo 'hello'
  endfunction | echo 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  delfunc Foo
endfunc

func Test_delfunction_force()
  delfunc! Xtest
  delfunc! Xtest
  func Xtest()
    echo 'nothing'
  endfunc
  delfunc! Xtest
  delfunc! Xtest

  " Try deleting the current function
  call assert_fails('delfunc Test_delfunction_force', 'E131:')
endfunc

func Test_function_defined_line()
  CheckNotGui

  let lines =<< trim [CODE]
  " F1
  func F1()
    " F2
    func F2()
      "
      "
      "
      return
    endfunc
    " F3
    execute "func F3()\n\n\n\nreturn\nendfunc"
    " F4
    execute "func F4()\n
                \\n
                \\n
                \\n
                \return\n
                \endfunc"
  endfunc
  " F5
  execute "func F5()\n\n\n\nreturn\nendfunc"
  " F6
  execute "func F6()\n
              \\n
              \\n
              \\n
              \return\n
              \endfunc"
  call F1()
  verbose func F1
  verbose func F2
  verbose func F3
  verbose func F4
  verbose func F5
  verbose func F6
  qall!
  [CODE]

  call writefile(lines, 'Xtest.vim')
  let res = system(GetVimCommandClean() .. ' -es -X -S Xtest.vim')
  call assert_equal(0, v:shell_error)

  let m = matchstr(res, 'function F1()[^[:print:]]*[[:print:]]*')
  call assert_match(' line 2$', m)

  let m = matchstr(res, 'function F2()[^[:print:]]*[[:print:]]*')
  call assert_match(' line 4$', m)

  let m = matchstr(res, 'function F3()[^[:print:]]*[[:print:]]*')
  call assert_match(' line 11$', m)

  let m = matchstr(res, 'function F4()[^[:print:]]*[[:print:]]*')
  call assert_match(' line 13$', m)

  let m = matchstr(res, 'function F5()[^[:print:]]*[[:print:]]*')
  call assert_match(' line 21$', m)

  let m = matchstr(res, 'function F6()[^[:print:]]*[[:print:]]*')
  call assert_match(' line 23$', m)

  call delete('Xtest.vim')
endfunc

" Test for defining a function reference in the global scope
func Test_add_funcref_to_global_scope()
  let x = g:
  let caught_E862 = 0
  try
    func x.Xfunc()
      return 1
    endfunc
  catch /E862:/
    let caught_E862 = 1
  endtry
  call assert_equal(1, caught_E862)
endfunc

func Test_funccall_garbage_collect()
  func Func(x, ...)
    call add(a:x, a:000)
  endfunc
  call Func([], [])
  " Must not crash cause by invalid freeing
  call test_garbagecollect_now()
  call assert_true(v:true)
  delfunc Func
endfunc

" Test for script-local function
func <SID>DoLast()
  call append(line('$'), "last line")
endfunc

func s:DoNothing()
  call append(line('$'), "nothing line")
endfunc

func Test_script_local_func()
  set nocp nomore viminfo+=nviminfo
  new
  nnoremap <buffer> _x	:call <SID>DoNothing()<bar>call <SID>DoLast()<bar>delfunc <SID>DoNothing<bar>delfunc <SID>DoLast<cr>

  normal _x
  call assert_equal('nothing line', getline(2))
  call assert_equal('last line', getline(3))
  close!

  " Try to call a script local function in global scope
  let lines =<< trim [CODE]
    :call assert_fails('call s:Xfunc()', 'E81:')
    :call assert_fails('let x = call("<SID>Xfunc", [])', 'E120:')
    :call writefile(v:errors, 'Xresult')
    :qall

  [CODE]
  call writefile(lines, 'Xscript')
  if RunVim([], [], '-s Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xresult')
  call delete('Xscript')
endfunc

" Test for errors in defining new functions
func Test_func_def_error()
  call assert_fails('func Xfunc abc ()', 'E124:')
  call assert_fails('func Xfunc(', 'E125:')
  call assert_fails('func xfunc()', 'E128:')

  " Try to redefine a function that is in use
  let caught_E127 = 0
  try
    func! Test_func_def_error()
    endfunc
  catch /E127:/
    let caught_E127 = 1
  endtry
  call assert_equal(1, caught_E127)

  " Try to define a function in a dict twice
  let d = {}
  let lines =<< trim END
    func d.F1()
      return 1
    endfunc
  END
  let l = join(lines, "\n") . "\n"
  exe l
  call assert_fails('exe l', 'E717:')

  " Define an autoload function with an incorrect file name
  call writefile(['func foo#Bar()', 'return 1', 'endfunc'], 'Xscript')
  call assert_fails('source Xscript', 'E746:')
  call delete('Xscript')

  " Try to list functions using an invalid search pattern
  call assert_fails('function /\%(/', 'E53:')
endfunc

" Test for deleting a function
func Test_del_func()
  call assert_fails('delfunction Xabc', 'E130:')
  let d = {'a' : 10}
  call assert_fails('delfunc d.a', 'E718:')
  func d.fn()
    return 1
  endfunc

  " cannot delete the dict function by number
  let nr = substitute(execute('echo d'), '.*function(''\(\d\+\)'').*', '\1', '')
  call assert_fails('delfunction g:' .. nr, 'E475: Invalid argument: g:')

  delfunc d.fn
  call assert_equal({'a' : 10}, d)
endfunc

" Test for calling return outside of a function
func Test_return_outside_func()
  call writefile(['return 10'], 'Xscript')
  call assert_fails('source Xscript', 'E133:')
  call delete('Xscript')
endfunc

" Test for errors in calling a function
func Test_func_arg_error()
  " Too many arguments
  call assert_fails("call call('min', range(1,20))", 'E118:')
  call assert_fails("call call('min', range(1,21))", 'E699:')
  call assert_fails('echo min(0,1,2,3,4,5,6,7,8,9,1,2,3,4,5,6,7,8,9,0,1)',
        \ 'E740:')

  " Missing dict argument
  func Xfunc() dict
    return 1
  endfunc
  call assert_fails('call Xfunc()', 'E725:')
  delfunc Xfunc
endfunc

func Test_func_dict()
  let mydict = {'a': 'b'}
  function mydict.somefunc() dict
    return len(self)
  endfunc

  call assert_equal("{'a': 'b', 'somefunc': function('3')}", string(mydict))
  call assert_equal(2, mydict.somefunc())
  call assert_match("^\n   function \\d\\\+() dict"
  \              .. "\n1      return len(self)"
  \              .. "\n   endfunction$", execute('func mydict.somefunc'))
  call assert_fails('call mydict.nonexist()', 'E716:')
endfunc

func Test_func_range()
  new
  call setline(1, range(1, 8))
  func FuncRange() range
    echo a:firstline
    echo a:lastline
  endfunc
  3
  call assert_equal("\n3\n3", execute('call FuncRange()'))
  call assert_equal("\n4\n6", execute('4,6 call FuncRange()'))
  call assert_equal("\n   function FuncRange() range"
  \              .. "\n1      echo a:firstline"
  \              .. "\n2      echo a:lastline"
  \              .. "\n   endfunction",
  \                 execute('function FuncRange'))

  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
