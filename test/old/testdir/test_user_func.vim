" Test for user functions.
" Also test an <expr> mapping calling a function.
" Also test that a builtin function cannot be replaced.
" Also test for regression when calling arbitrary expression.

source check.vim
source shared.vim
source vim9.vim

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
    :call assert_fails('let x = call("<SID>Xfunc", [])', ['E81:', 'E117:'])
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

" Test for memory allocation failure when defining a new function
func Test_funcdef_alloc_failure()
  CheckFunction test_alloc_fail
  new
  let lines =<< trim END
    func Xtestfunc()
      return 321
    endfunc
  END
  call setline(1, lines)
  call test_alloc_fail(GetAllocId('get_func'), 0, 0)
  call assert_fails('source', 'E342:')
  call assert_false(exists('*Xtestfunc'))
  call assert_fails('delfunc Xtestfunc', 'E117:')
  %d _
  let lines =<< trim END
    def g:Xvim9func(): number
      return 456
    enddef
  END
  call setline(1, lines)
  call test_alloc_fail(GetAllocId('get_func'), 0, 0)
  call assert_fails('source', 'E342:')
  call assert_false(exists('*Xvim9func'))
  "call test_alloc_fail(GetAllocId('get_func'), 0, 0)
  "call assert_fails('source', 'E342:')
  "call assert_false(exists('*Xtestfunc'))
  "call assert_fails('delfunc Xtestfunc', 'E117:')
  bw!
endfunc

func AddDefer(arg1, ...)
  call extend(g:deferred, [a:arg1])
  if a:0 == 1
    call extend(g:deferred, [a:1])
  endif
endfunc

func WithDeferTwo()
  call extend(g:deferred, ['in Two'])
  for nr in range(3)
    defer AddDefer('Two' .. nr)
  endfor
  call extend(g:deferred, ['end Two'])
endfunc

func WithDeferOne()
  call extend(g:deferred, ['in One'])
  call writefile(['text'], 'Xfuncdefer')
  defer delete('Xfuncdefer')
  defer AddDefer('One')
  call WithDeferTwo()
  call extend(g:deferred, ['end One'])
endfunc

func WithPartialDefer()
  call extend(g:deferred, ['in Partial'])
  let Part = funcref('AddDefer', ['arg1'])
  defer Part("arg2")
  call extend(g:deferred, ['end Partial'])
endfunc

func Test_defer()
  let g:deferred = []
  call WithDeferOne()

  call assert_equal(['in One', 'in Two', 'end Two', 'Two2', 'Two1', 'Two0', 'end One', 'One'], g:deferred)
  unlet g:deferred

  call assert_equal('', glob('Xfuncdefer'))

  call assert_fails('defer delete("Xfuncdefer")->Another()', 'E488:')
  call assert_fails('defer delete("Xfuncdefer").member', 'E488:')

  let g:deferred = []
  call WithPartialDefer()
  call assert_equal(['in Partial', 'end Partial', 'arg1', 'arg2'], g:deferred)
  unlet g:deferred

  let Part = funcref('AddDefer', ['arg1'], {})
  call assert_fails('defer Part("arg2")', 'E1300:')
endfunc

func DeferLevelTwo()
  call writefile(['text'], 'XDeleteTwo', 'D')
  throw 'someerror'
endfunc

" def DeferLevelOne()
func DeferLevelOne()
  call writefile(['text'], 'XDeleteOne', 'D')
  call g:DeferLevelTwo()
" enddef
endfunc

func Test_defer_throw()
  let caught = 'no'
  try
    call DeferLevelOne()
  catch /someerror/
    let caught = 'yes'
  endtry
  call assert_equal('yes', caught)
  call assert_false(filereadable('XDeleteOne'))
  call assert_false(filereadable('XDeleteTwo'))
endfunc

func Test_defer_quitall_func()
  let lines =<< trim END
      func DeferLevelTwo()
        call writefile(['text'], 'XQuitallFuncTwo', 'D')
        call writefile(['quit'], 'XQuitallFuncThree', 'a')
        qa!
      endfunc

      func DeferLevelOne()
        call writefile(['text'], 'XQuitalFunclOne', 'D')
        defer DeferLevelTwo()
      endfunc

      call DeferLevelOne()
  END
  call writefile(lines, 'XdeferQuitallFunc', 'D')
  call system(GetVimCommand() .. ' -X -S XdeferQuitallFunc')
  call assert_equal(0, v:shell_error)
  call assert_false(filereadable('XQuitallFuncOne'))
  call assert_false(filereadable('XQuitallFuncTwo'))
  call assert_equal(['quit'], readfile('XQuitallFuncThree'))

  call delete('XQuitallFuncThree')
endfunc

func Test_defer_quitall_def()
  throw 'Skipped: Vim9 script is N/A'
  let lines =<< trim END
      vim9script
      def DeferLevelTwo()
        call writefile(['text'], 'XQuitallDefTwo', 'D')
        call writefile(['quit'], 'XQuitallDefThree', 'a')
        qa!
      enddef

      def DeferLevelOne()
        call writefile(['text'], 'XQuitallDefOne', 'D')
        defer DeferLevelTwo()
      enddef

      DeferLevelOne()
  END
  call writefile(lines, 'XdeferQuitallDef', 'D')
  call system(GetVimCommand() .. ' -X -S XdeferQuitallDef')
  call assert_equal(0, v:shell_error)
  call assert_false(filereadable('XQuitallDefOne'))
  call assert_false(filereadable('XQuitallDefTwo'))
  call assert_equal(['quit'], readfile('XQuitallDefThree'))

  call delete('XQuitallDefThree')
endfunc

func Test_defer_quitall_autocmd()
  let lines =<< trim END
      func DeferLevelFive()
        defer writefile(['5'], 'XQuitallAutocmd', 'a')
        qa!
      endfunc

      autocmd User DeferAutocmdFive call DeferLevelFive()

      " def DeferLevelFour()
      func DeferLevelFour()
        defer writefile(['4'], 'XQuitallAutocmd', 'a')
        doautocmd User DeferAutocmdFive
      " enddef
      endfunc

      func DeferLevelThree()
        defer writefile(['3'], 'XQuitallAutocmd', 'a')
        call DeferLevelFour()
      endfunc

      autocmd User DeferAutocmdThree ++nested call DeferLevelThree()

      " def DeferLevelTwo()
      func DeferLevelTwo()
        defer writefile(['2'], 'XQuitallAutocmd', 'a')
        doautocmd User DeferAutocmdThree
      " enddef
      endfunc

      func DeferLevelOne()
        defer writefile(['1'], 'XQuitallAutocmd', 'a')
        call DeferLevelTwo()
      endfunc

      autocmd User DeferAutocmdOne ++nested call DeferLevelOne()

      doautocmd User DeferAutocmdOne
  END
  call writefile(lines, 'XdeferQuitallAutocmd', 'D')
  call system(GetVimCommand() .. ' -X -S XdeferQuitallAutocmd')
  call assert_equal(0, v:shell_error)
  call assert_equal(['5', '4', '3', '2', '1'], readfile('XQuitallAutocmd'))

  call delete('XQuitallAutocmd')
endfunc

func Test_defer_quitall_in_expr_func()
  throw 'Skipped: Vim9 script is N/A'
  let lines =<< trim END
      def DefIndex(idx: number, val: string): bool
        call writefile([idx .. ': ' .. val], 'Xentry' .. idx, 'D')
        if val == 'b'
          qa!
        endif
        return val == 'c'
      enddef

      def Test_defer_in_funcref()
        assert_equal(2, indexof(['a', 'b', 'c'], funcref('g:DefIndex')))
      enddef
      call Test_defer_in_funcref()
  END
  call writefile(lines, 'XdeferQuitallExpr', 'D')
  call system(GetVimCommand() .. ' -X -S XdeferQuitallExpr')
  call assert_equal(0, v:shell_error)
  call assert_false(filereadable('Xentry0'))
  call assert_false(filereadable('Xentry1'))
  call assert_false(filereadable('Xentry2'))
endfunc

func FuncIndex(idx, val)
  call writefile([a:idx .. ': ' .. a:val], 'Xentry' .. a:idx, 'D')
  return a:val == 'c'
endfunc

func Test_defer_wrong_arguments()
  call assert_fails('defer delete()', 'E119:')
  call assert_fails('defer FuncIndex(1)', 'E119:')
  call assert_fails('defer delete(1, 2, 3)', 'E118:')
  call assert_fails('defer FuncIndex(1, 2, 3)', 'E118:')

  throw 'Skipped: Vim9 script is N/A'
  let lines =<< trim END
      def DeferFunc0()
        defer delete()
      enddef
      defcompile
  END
  call v9.CheckScriptFailure(lines, 'E119:')
  let lines =<< trim END
      def DeferFunc3()
        defer delete(1, 2, 3)
      enddef
      defcompile
  END
  call v9.CheckScriptFailure(lines, 'E118:')
  let lines =<< trim END
      def DeferFunc2()
        defer delete(1, 2)
      enddef
      defcompile
  END
  call v9.CheckScriptFailure(lines, 'E1013: Argument 1: type mismatch, expected string but got number')

  def g:FuncOneArg(arg: string)
    echo arg
  enddef

  let lines =<< trim END
      def DeferUserFunc0()
        defer g:FuncOneArg()
      enddef
      defcompile
  END
  call v9.CheckScriptFailure(lines, 'E119:')
  let lines =<< trim END
      def DeferUserFunc2()
        defer g:FuncOneArg(1, 2)
      enddef
      defcompile
  END
  call v9.CheckScriptFailure(lines, 'E118:')
  let lines =<< trim END
      def DeferUserFunc1()
        defer g:FuncOneArg(1)
      enddef
      defcompile
  END
  call v9.CheckScriptFailure(lines, 'E1013: Argument 1: type mismatch, expected string but got number')
endfunc

" Test for calling a deferred function after an exception
func Test_defer_after_exception()
  let g:callTrace = []
  func Bar()
    let g:callTrace += [1]
    throw 'InnerException'
  endfunc

  func Defer()
    let g:callTrace += [2]
    let g:callTrace += [3]
    try
      call Bar()
    catch /InnerException/
      let g:callTrace += [4]
    endtry
    let g:callTrace += [5]
    let g:callTrace += [6]
  endfunc

  func Foo()
    defer Defer()
    throw "TestException"
  endfunc

  try
    call Foo()
  catch /TestException/
    let g:callTrace += [7]
  endtry
  call assert_equal([2, 3, 1, 4, 5, 6, 7], g:callTrace)

  delfunc Defer
  delfunc Foo
  delfunc Bar
  unlet g:callTrace
endfunc

" Test for multiple deferred function which throw exceptions.
" Exceptions thrown by deferred functions should result in error messages but
" not propagated into the calling functions.
func Test_multidefer_with_exception()
  let g:callTrace = []
  func Except()
    let g:callTrace += [1]
    throw 'InnerException'
    let g:callTrace += [2]
  endfunc

  func FirstDefer()
    let g:callTrace += [3]
    let g:callTrace += [4]
  endfunc

  func SecondDeferWithExcept()
    let g:callTrace += [5]
    call Except()
    let g:callTrace += [6]
  endfunc

  func ThirdDefer()
    let g:callTrace += [7]
    let g:callTrace += [8]
  endfunc

  func Foo()
    let g:callTrace += [9]
    defer FirstDefer()
    defer SecondDeferWithExcept()
    defer ThirdDefer()
    let g:callTrace += [10]
  endfunc

  let v:errmsg = ''
  try
    let g:callTrace += [11]
    call Foo()
    let g:callTrace += [12]
  catch /TestException/
    let g:callTrace += [13]
  catch
    let g:callTrace += [14]
  finally
    let g:callTrace += [15]
  endtry
  let g:callTrace += [16]

  call assert_equal('E605: Exception not caught: InnerException', v:errmsg)
  call assert_equal([11, 9, 10, 7, 8, 5, 1, 3, 4, 12, 15, 16], g:callTrace)

  unlet g:callTrace
  delfunc Except
  delfunc FirstDefer
  delfunc SecondDeferWithExcept
  delfunc ThirdDefer
  delfunc Foo
endfunc

func Test_func_curly_brace_invalid_name()
  func Fail()
    func Foo{'()'}bar()
    endfunc
  endfunc

  call assert_fails('call Fail()', 'E475: Invalid argument: Foo()bar')

  silent! call Fail()
  call assert_equal([], getcompletion('Foo', 'function'))

  set formatexpr=Fail()
  normal! gqq
  call assert_equal([], getcompletion('Foo', 'function'))

  set formatexpr&
  delfunc Fail
endfunc

" vim: shiftwidth=2 sts=2 expandtab
