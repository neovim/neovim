" Tests for the Vim script debug commands

source shared.vim
source screendump.vim
source check.vim

func CheckCWD()
  " Check that the longer lines don't wrap due to the length of the script name
  " in cwd
  let script_len = len( getcwd() .. '/Xtest1.vim' )
  let longest_line = len( 'Breakpoint in "" line 1' )
  if script_len > ( 75 - longest_line )
    throw 'Skipped: Your CWD has too many characters'
  endif
endfunc
command! -nargs=0 -bar CheckCWD call CheckCWD()

" "options" argument can contain:
" 'msec' - time to wait for a match
" 'match' - "pattern" to use "lines" as pattern instead of text
func CheckDbgOutput(buf, lines, options = {})
  " Verify the expected output
  let lnum = 20 - len(a:lines)
  let msec = get(a:options, 'msec', 1000)
  for l in a:lines
    if get(a:options, 'match', 'equal') ==# 'pattern'
      call WaitForAssert({-> assert_match(l, term_getline(a:buf, lnum))}, msec)
    else
      call WaitForAssert({-> assert_equal(l, term_getline(a:buf, lnum))}, msec)
    endif
    let lnum += 1
  endfor
endfunc

" Run a Vim debugger command
" If the expected output argument is supplied, then check for it.
func RunDbgCmd(buf, cmd, ...)
  call term_sendkeys(a:buf, a:cmd . "\r")
  call TermWait(a:buf)

  if a:0 != 0
    let options = #{match: 'equal'}
    if a:0 > 1
      call extend(options, a:2)
    endif
    call CheckDbgOutput(a:buf, a:1, options)
  endif
endfunc

" Debugger tests
func Test_Debugger()
  CheckRunVimInTerminal

  " Create a Vim script with some functions
  let lines =<< trim END
	func Foo()
	  let var1 = 1
	  let var2 = Bar(var1) + 9
	  return var2
	endfunc
	func Bar(var)
	  let var1 = 2 + a:var
	  let var2 = Bazz(var1) + 4
	  return var2
	endfunc
	func Bazz(var)
	  try
	    let var1 = 3 + a:var
	    let var3 = "another var"
	    let var3 = "value2"
	  catch
	    let var4 = "exception"
	  endtry
	  return var1
	endfunc
        def Vim9Func()
          for cmd in ['confirm', 'xxxxxxx']
            for _ in [1, 2]
              echo cmd
            endfor
          endfor
        enddef
  END
  call writefile(lines, 'XtestDebug.vim', 'D')

  " Start Vim in a terminal
  let buf = RunVimInTerminal('-S XtestDebug.vim', {})

  " Start the Vim debugger
  call RunDbgCmd(buf, ':debug echo Foo()', ['cmd: echo Foo()'])

  " Create a few stack frames by stepping through functions
  call RunDbgCmd(buf, 'step', ['line 1: let var1 = 1'])
  call RunDbgCmd(buf, 'step', ['line 2: let var2 = Bar(var1) + 9'])
  call RunDbgCmd(buf, 'step', ['line 1: let var1 = 2 + a:var'])
  call RunDbgCmd(buf, 'step', ['line 2: let var2 = Bazz(var1) + 4'])
  call RunDbgCmd(buf, 'step', ['line 1: try'])
  call RunDbgCmd(buf, 'step', ['line 2: let var1 = 3 + a:var'])
  call RunDbgCmd(buf, 'step', ['line 3: let var3 = "another var"'])

  " check backtrace
  call RunDbgCmd(buf, 'backtrace', [
	      \ '  2 function Foo[2]',
	      \ '  1 Bar[2]',
	      \ '->0 Bazz',
	      \ 'line 3: let var3 = "another var"'])

  " Check variables in different stack frames
  call RunDbgCmd(buf, 'echo var1', ['6'])

  call RunDbgCmd(buf, 'up')
  call RunDbgCmd(buf, 'back', [
	      \ '  2 function Foo[2]',
	      \ '->1 Bar[2]',
	      \ '  0 Bazz',
	      \ 'line 3: let var3 = "another var"'])
  call RunDbgCmd(buf, 'echo var1', ['3'])

  call RunDbgCmd(buf, 'u')
  call RunDbgCmd(buf, 'bt', [
	      \ '->2 function Foo[2]',
	      \ '  1 Bar[2]',
	      \ '  0 Bazz',
	      \ 'line 3: let var3 = "another var"'])
  call RunDbgCmd(buf, 'echo var1', ['1'])

  " Undefined variables
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'frame 2')
  call RunDbgCmd(buf, 'echo var3', [
	\ 'Error detected while processing function Foo[2]..Bar[2]..Bazz:',
	\ 'line    4:',
	\ 'E121: Undefined variable: var3'])

  " var3 is defined in this level with some other value
  call RunDbgCmd(buf, 'fr 0')
  call RunDbgCmd(buf, 'echo var3', ['another var'])

  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, '')
  call RunDbgCmd(buf, '')
  call RunDbgCmd(buf, '')
  call RunDbgCmd(buf, '')
  call RunDbgCmd(buf, 'step', [
	      \ 'function Foo[2]..Bar',
	      \ 'line 3: End of function'])
  call RunDbgCmd(buf, 'up')

  " Undefined var2
  call RunDbgCmd(buf, 'echo var2', [
	      \ 'Error detected while processing function Foo[2]..Bar:',
	      \ 'line    3:',
	      \ 'E121: Undefined variable: var2'])

  " Var2 is defined with 10
  call RunDbgCmd(buf, 'down')
  call RunDbgCmd(buf, 'echo var2', ['10'])

  " Backtrace movements
  call RunDbgCmd(buf, 'b', [
	      \ '  1 function Foo[2]',
	      \ '->0 Bar',
	      \ 'line 3: End of function'])

  " next command cannot go down, we are on bottom
  call RunDbgCmd(buf, 'down', ['frame is zero'])
  call RunDbgCmd(buf, 'up')

  " next command cannot go up, we are on top
  call RunDbgCmd(buf, 'up', ['frame at highest level: 1'])
  call RunDbgCmd(buf, 'where', [
	      \ '->1 function Foo[2]',
	      \ '  0 Bar',
	      \ 'line 3: End of function'])

  " fil is not frame or finish, it is file
  call RunDbgCmd(buf, 'fil', ['"[No Name]" --No lines in buffer--'])

  " relative backtrace movement
  call RunDbgCmd(buf, 'fr -1')
  call RunDbgCmd(buf, 'frame', [
	      \ '  1 function Foo[2]',
	      \ '->0 Bar',
	      \ 'line 3: End of function'])

  call RunDbgCmd(buf, 'fr +1')
  call RunDbgCmd(buf, 'fram', [
	      \ '->1 function Foo[2]',
	      \ '  0 Bar',
	      \ 'line 3: End of function'])

  " go beyond limits does not crash
  call RunDbgCmd(buf, 'fr 100', ['frame at highest level: 1'])
  call RunDbgCmd(buf, 'fra', [
	      \ '->1 function Foo[2]',
	      \ '  0 Bar',
	      \ 'line 3: End of function'])

  call RunDbgCmd(buf, 'frame -40', ['frame is zero'])
  call RunDbgCmd(buf, 'fram', [
	      \ '  1 function Foo[2]',
	      \ '->0 Bar',
	      \ 'line 3: End of function'])

  " final result 19
  call RunDbgCmd(buf, 'cont', ['19'])

  " breakpoints tests

  " Start a debug session, so that reading the last line from the terminal
  " works properly.
  call RunDbgCmd(buf, ':debug echo Foo()', ['cmd: echo Foo()'])

  " No breakpoints
  call RunDbgCmd(buf, 'breakl', ['No breakpoints defined'])

  " Place some breakpoints
  call RunDbgCmd(buf, 'breaka func Bar')
  call RunDbgCmd(buf, 'breaklis', ['  1  func Bar  line 1'])
  call RunDbgCmd(buf, 'breakadd func 3 Bazz')
  call RunDbgCmd(buf, 'breaklist', ['  1  func Bar  line 1',
	      \ '  2  func Bazz  line 3'])

  " Check whether the breakpoints are hit
  call RunDbgCmd(buf, 'cont', [
	      \ 'Breakpoint in "Bar" line 1',
	      \ 'function Foo[2]..Bar',
	      \ 'line 1: let var1 = 2 + a:var'])
  call RunDbgCmd(buf, 'cont', [
	      \ 'Breakpoint in "Bazz" line 3',
	      \ 'function Foo[2]..Bar[2]..Bazz',
	      \ 'line 3: let var3 = "another var"'])

  " Delete the breakpoints
  call RunDbgCmd(buf, 'breakd 1')
  call RunDbgCmd(buf, 'breakli', ['  2  func Bazz  line 3'])
  call RunDbgCmd(buf, 'breakdel func 3 Bazz')
  call RunDbgCmd(buf, 'breakl', ['No breakpoints defined'])

  call RunDbgCmd(buf, 'cont')

  " Make sure the breakpoints are removed
  call RunDbgCmd(buf, ':echo Foo()', ['19'])

  " Delete a non-existing breakpoint
  call RunDbgCmd(buf, ':breakdel 2', ['E161: Breakpoint not found: 2'])

  " Expression breakpoint
  call RunDbgCmd(buf, ':breakadd func 2 Bazz')
  call RunDbgCmd(buf, ':echo Bazz(1)', [
	      \ 'Entering Debug mode.  Type "cont" to continue.',
	      \ 'function Bazz',
	      \ 'line 2: let var1 = 3 + a:var'])
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'breaka expr var3')
  call RunDbgCmd(buf, 'breakl', ['  3  func Bazz  line 2',
	      \ '  4  expr var3'])
  call RunDbgCmd(buf, 'cont', ['Breakpoint in "Bazz" line 5',
	      \ 'Oldval = "''another var''"',
	      \ 'Newval = "''value2''"',
	      \ 'function Bazz',
	      \ 'line 5: catch'])

  call RunDbgCmd(buf, 'breakdel *')
  call RunDbgCmd(buf, 'breakl', ['No breakpoints defined'])

  " Check for error cases
  call RunDbgCmd(buf, 'breakadd abcd', [
	      \ 'Error detected while processing function Bazz:',
	      \ 'line    5:',
	      \ 'E475: Invalid argument: abcd'])
  call RunDbgCmd(buf, 'breakadd func', ['E475: Invalid argument: func'])
  call RunDbgCmd(buf, 'breakadd func 2', ['E475: Invalid argument: func 2'])
  call RunDbgCmd(buf, 'breaka func a()', ['E475: Invalid argument: func a()'])
  call RunDbgCmd(buf, 'breakd abcd', ['E475: Invalid argument: abcd'])
  call RunDbgCmd(buf, 'breakd func', ['E475: Invalid argument: func'])
  call RunDbgCmd(buf, 'breakd func a()', ['E475: Invalid argument: func a()'])
  call RunDbgCmd(buf, 'breakd func a', ['E161: Breakpoint not found: func a'])
  call RunDbgCmd(buf, 'breakd expr', ['E475: Invalid argument: expr'])
  call RunDbgCmd(buf, 'breakd expr x', ['E161: Breakpoint not found: expr x'])

  " finish the current function
  call RunDbgCmd(buf, 'finish', [
	      \ 'function Bazz',
	      \ 'line 8: End of function'])
  call RunDbgCmd(buf, 'cont')

  " Test for :next
  call RunDbgCmd(buf, ':debug echo Bar(1)')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'next')
  call RunDbgCmd(buf, '', [
	      \ 'function Bar',
	      \ 'line 3: return var2'])
  call RunDbgCmd(buf, 'c')

  " Test for :interrupt
  call RunDbgCmd(buf, ':debug echo Bazz(1)')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'interrupt', [
	      \ 'Exception thrown: Vim:Interrupt',
	      \ 'function Bazz',
	      \ 'line 5: catch'])
  call RunDbgCmd(buf, 'c')

  " Test showing local variable in :def function
  call RunDbgCmd(buf, ':breakadd func 2 Vim9Func')
  call RunDbgCmd(buf, ':call Vim9Func()', ['line 2:             for _ in [1, 2]'])
  call RunDbgCmd(buf, 'next', ['line 2: for _ in [1, 2]'])
  call RunDbgCmd(buf, 'echo cmd', ['confirm'])
  call RunDbgCmd(buf, 'breakdel *')
  call RunDbgCmd(buf, 'cont')

  " Test for :quit
  call RunDbgCmd(buf, ':debug echo Foo()')
  call RunDbgCmd(buf, 'breakdel *')
  call RunDbgCmd(buf, 'breakadd func 3 Foo')
  call RunDbgCmd(buf, 'breakadd func 3 Bazz')
  call RunDbgCmd(buf, 'cont', [
	      \ 'Breakpoint in "Bazz" line 3',
	      \ 'function Foo[2]..Bar[2]..Bazz',
	      \ 'line 3: let var3 = "another var"'])
  call RunDbgCmd(buf, 'quit', [
	      \ 'Breakpoint in "Foo" line 3',
	      \ 'function Foo',
	      \ 'line 3: return var2'])
  call RunDbgCmd(buf, 'breakdel *')
  call RunDbgCmd(buf, 'quit')
  call RunDbgCmd(buf, 'enew! | only!')

  call StopVimInTerminal(buf)
endfunc

func Test_Debugger_breakadd()
  " Tests for :breakadd file and :breakadd here
  " Breakpoints should be set before sourcing the file
  CheckRunVimInTerminal

  let lines =<< trim END
	let var1 = 10
	let var2 = 20
	let var3 = 30
	let var4 = 40
  END
  call writefile(lines, 'XdebugBreakadd.vim', 'D')

  " Start Vim in a terminal
  let buf = RunVimInTerminal('XdebugBreakadd.vim', {})
  call RunDbgCmd(buf, ':breakadd file 2 XdebugBreakadd.vim')
  call RunDbgCmd(buf, ':4 | breakadd here')
  call RunDbgCmd(buf, ':source XdebugBreakadd.vim', ['line 2: let var2 = 20'])
  call RunDbgCmd(buf, 'cont', ['line 4: let var4 = 40'])
  call RunDbgCmd(buf, 'cont')

  call StopVimInTerminal(buf)

  %bw!

  call assert_fails('breakadd here', 'E32:')
  call assert_fails('breakadd file Xtest.vim /\)/', 'E55:')
endfunc

" Test for expression breakpoint set using ":breakadd expr <expr>"
func Test_Debugger_breakadd_expr()
  CheckRunVimInTerminal
  CheckCWD

  let lines =<< trim END
    let g:Xtest_var += 1
  END
  call writefile(lines, 'XdebugBreakExpr.vim', 'D')

  " Start Vim in a terminal
  let buf = RunVimInTerminal('XdebugBreakExpr.vim', {})
  call RunDbgCmd(buf, ':let g:Xtest_var = 10')
  call RunDbgCmd(buf, ':breakadd expr g:Xtest_var')
  call RunDbgCmd(buf, ':source %')
  let expected =<< trim eval END
    Oldval = "10"
    Newval = "11"
    {fnamemodify('XdebugBreakExpr.vim', ':p')}
    line 1: let g:Xtest_var += 1
  END
  call RunDbgCmd(buf, ':source %', expected)
  call RunDbgCmd(buf, 'cont')
  let expected =<< trim eval END
    Oldval = "11"
    Newval = "12"
    {fnamemodify('XdebugBreakExpr.vim', ':p')}
    line 1: let g:Xtest_var += 1
  END
  call RunDbgCmd(buf, ':source %', expected)

  call StopVimInTerminal(buf)
endfunc

func Test_Backtrace_Through_Source()
  CheckRunVimInTerminal
  CheckCWD
  let file1 =<< trim END
    func SourceAnotherFile()
      source Xtest2.vim
    endfunc

    func CallAFunction()
      call SourceAnotherFile()
      call File2Function()
    endfunc

    func GlobalFunction()
      call CallAFunction()
    endfunc
  END
  call writefile(file1, 'Xtest1.vim', 'D')

  let file2 =<< trim END
    func DoAThing()
      echo "DoAThing"
    endfunc

    func File2Function()
      call DoAThing()
    endfunc

    call File2Function()
  END
  call writefile(file2, 'Xtest2.vim', 'D')

  let buf = RunVimInTerminal('-S Xtest1.vim', {})

  call RunDbgCmd(buf,
                \ ':debug call GlobalFunction()',
                \ ['cmd: call GlobalFunction()'])
  call RunDbgCmd(buf, 'step', ['line 1: call CallAFunction()'])

  call RunDbgCmd(buf, 'backtrace', ['>backtrace',
                                    \ '->0 function GlobalFunction',
                                    \ 'line 1: call CallAFunction()'])

  call RunDbgCmd(buf, 'step', ['line 1: call SourceAnotherFile()'])
  call RunDbgCmd(buf, 'step', ['line 1: source Xtest2.vim'])

  call RunDbgCmd(buf, 'backtrace', ['>backtrace',
                                    \ '  2 function GlobalFunction[1]',
                                    \ '  1 CallAFunction[1]',
                                    \ '->0 SourceAnotherFile',
                                    \ 'line 1: source Xtest2.vim'])

  " Step into the 'source' command. Note that we print the full trace all the
  " way though the source command.
  call RunDbgCmd(buf, 'step', ['line 1: func DoAThing()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '->0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()'])

  call RunDbgCmd( buf, 'up' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '->1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'up' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 function GlobalFunction[1]',
        \ '->2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'up' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '->3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'up', [ 'frame at highest level: 3' ] )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '->3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'down' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 function GlobalFunction[1]',
        \ '->2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'down' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '->1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'down' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '->0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'down', [ 'frame is zero' ] )

  " step until we have another meaningful trace
  call RunDbgCmd(buf, 'step', ['line 5: func File2Function()'])
  call RunDbgCmd(buf, 'step', ['line 9: call File2Function()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '->0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 9: call File2Function()'])

  call RunDbgCmd(buf, 'step', ['line 1: call DoAThing()'])
  call RunDbgCmd(buf, 'step', ['line 1: echo "DoAThing"'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  5 function GlobalFunction[1]',
        \ '  4 CallAFunction[1]',
        \ '  3 SourceAnotherFile[1]',
        \ '  2 script ' .. getcwd() .. '/Xtest2.vim[9]',
        \ '  1 function File2Function[1]',
        \ '->0 DoAThing',
        \ 'line 1: echo "DoAThing"'])

  " Now, step (back to Xfile1.vim), and call the function _in_ Xfile2.vim
  call RunDbgCmd(buf, 'step', ['line 1: End of function'])
  call RunDbgCmd(buf, 'step', ['line 1: End of function'])
  call RunDbgCmd(buf, 'step', ['line 10: End of sourced file'])
  call RunDbgCmd(buf, 'step', ['line 1: End of function'])
  call RunDbgCmd(buf, 'step', ['line 2: call File2Function()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  1 function GlobalFunction[1]',
        \ '->0 CallAFunction',
        \ 'line 2: call File2Function()'])

  call RunDbgCmd(buf, 'step', ['line 1: call DoAThing()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  2 function GlobalFunction[1]',
        \ '  1 CallAFunction[2]',
        \ '->0 File2Function',
        \ 'line 1: call DoAThing()'])

  call StopVimInTerminal(buf)
endfunc

func Test_Backtrace_Autocmd()
  CheckRunVimInTerminal
  CheckCWD
  let file1 =<< trim END
    func SourceAnotherFile()
      source Xtest2.vim
    endfunc

    func CallAFunction()
      call SourceAnotherFile()
      call File2Function()
    endfunc

    func GlobalFunction()
      call CallAFunction()
    endfunc

    au User TestGlobalFunction :call GlobalFunction() | echo "Done"
  END
  call writefile(file1, 'Xtest1.vim', 'D')

  let file2 =<< trim END
    func DoAThing()
      echo "DoAThing"
    endfunc

    func File2Function()
      call DoAThing()
    endfunc

    call File2Function()
  END
  call writefile(file2, 'Xtest2.vim', 'D')

  let buf = RunVimInTerminal('-S Xtest1.vim', {})

  call RunDbgCmd(buf,
                \ ':debug doautocmd User TestGlobalFunction',
                \ ['cmd: doautocmd User TestGlobalFunction'])
  call RunDbgCmd(buf, 'step', ['cmd: call GlobalFunction() | echo "Done"'])

  " At this point the only thing in the stack is the autocommand
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '->0 User Autocommands for "TestGlobalFunction"',
        \ 'cmd: call GlobalFunction() | echo "Done"'])

  " And now we're back into the call stack
  call RunDbgCmd(buf, 'step', ['line 1: call CallAFunction()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  1 User Autocommands for "TestGlobalFunction"',
        \ '->0 function GlobalFunction',
        \ 'line 1: call CallAFunction()'])

  call RunDbgCmd(buf, 'step', ['line 1: call SourceAnotherFile()'])
  call RunDbgCmd(buf, 'step', ['line 1: source Xtest2.vim'])

  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 User Autocommands for "TestGlobalFunction"',
        \ '  2 function GlobalFunction[1]',
        \ '  1 CallAFunction[1]',
        \ '->0 SourceAnotherFile',
        \ 'line 1: source Xtest2.vim'])

  " Step into the 'source' command. Note that we print the full trace all the
  " way though the source command.
  call RunDbgCmd(buf, 'step', ['line 1: func DoAThing()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '->0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()'])

  call RunDbgCmd( buf, 'up' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '->1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'up' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '->2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'up' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '->3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'up' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '->4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'up', [ 'frame at highest level: 4' ] )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '->4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'down' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '->3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )


  call RunDbgCmd( buf, 'down' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '->2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'down' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '->1 SourceAnotherFile[1]',
        \ '  0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'down' )
  call RunDbgCmd( buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '->0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 1: func DoAThing()' ] )

  call RunDbgCmd( buf, 'down', [ 'frame is zero' ] )

  " step until we have another meaningful trace
  call RunDbgCmd(buf, 'step', ['line 5: func File2Function()'])
  call RunDbgCmd(buf, 'step', ['line 9: call File2Function()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  4 User Autocommands for "TestGlobalFunction"',
        \ '  3 function GlobalFunction[1]',
        \ '  2 CallAFunction[1]',
        \ '  1 SourceAnotherFile[1]',
        \ '->0 script ' .. getcwd() .. '/Xtest2.vim',
        \ 'line 9: call File2Function()'])

  call RunDbgCmd(buf, 'step', ['line 1: call DoAThing()'])
  call RunDbgCmd(buf, 'step', ['line 1: echo "DoAThing"'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  6 User Autocommands for "TestGlobalFunction"',
        \ '  5 function GlobalFunction[1]',
        \ '  4 CallAFunction[1]',
        \ '  3 SourceAnotherFile[1]',
        \ '  2 script ' .. getcwd() .. '/Xtest2.vim[9]',
        \ '  1 function File2Function[1]',
        \ '->0 DoAThing',
        \ 'line 1: echo "DoAThing"'])

  " Now, step (back to Xfile1.vim), and call the function _in_ Xfile2.vim
  call RunDbgCmd(buf, 'step', ['line 1: End of function'])
  call RunDbgCmd(buf, 'step', ['line 1: End of function'])
  call RunDbgCmd(buf, 'step', ['line 10: End of sourced file'])
  call RunDbgCmd(buf, 'step', ['line 1: End of function'])
  call RunDbgCmd(buf, 'step', ['line 2: call File2Function()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  2 User Autocommands for "TestGlobalFunction"',
        \ '  1 function GlobalFunction[1]',
        \ '->0 CallAFunction',
        \ 'line 2: call File2Function()'])

  call RunDbgCmd(buf, 'step', ['line 1: call DoAThing()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 User Autocommands for "TestGlobalFunction"',
        \ '  2 function GlobalFunction[1]',
        \ '  1 CallAFunction[2]',
        \ '->0 File2Function',
        \ 'line 1: call DoAThing()'])


  " Now unwind so that we get back to the original autocommand (and the second
  " cmd echo "Done")
  call RunDbgCmd(buf, 'finish', ['line 1: End of function'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  3 User Autocommands for "TestGlobalFunction"',
        \ '  2 function GlobalFunction[1]',
        \ '  1 CallAFunction[2]',
        \ '->0 File2Function',
        \ 'line 1: End of function'])

  call RunDbgCmd(buf, 'finish', ['line 2: End of function'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  2 User Autocommands for "TestGlobalFunction"',
        \ '  1 function GlobalFunction[1]',
        \ '->0 CallAFunction',
        \ 'line 2: End of function'])

  call RunDbgCmd(buf, 'finish', ['line 1: End of function'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  1 User Autocommands for "TestGlobalFunction"',
        \ '->0 function GlobalFunction',
        \ 'line 1: End of function'])

  call RunDbgCmd(buf, 'step', ['cmd: echo "Done"'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '->0 User Autocommands for "TestGlobalFunction"',
        \ 'cmd: echo "Done"'])

  call StopVimInTerminal(buf)
endfunc

func Test_Backtrace_CmdLine()
  CheckRunVimInTerminal
  CheckCWD
  let file1 =<< trim END
    func SourceAnotherFile()
      source Xtest2.vim
    endfunc

    func CallAFunction()
      call SourceAnotherFile()
      call File2Function()
    endfunc

    func GlobalFunction()
      call CallAFunction()
    endfunc

    au User TestGlobalFunction :call GlobalFunction() | echo "Done"
  END
  call writefile(file1, 'Xtest1.vim', 'D')

  let file2 =<< trim END
    func DoAThing()
      echo "DoAThing"
    endfunc

    func File2Function()
      call DoAThing()
    endfunc

    call File2Function()
  END
  call writefile(file2, 'Xtest2.vim', 'D')

  let buf = RunVimInTerminal(
        \ '-S Xtest1.vim -c "debug call GlobalFunction()"',
        \ {'wait_for_ruler': 0})

  " Need to wait for the vim-in-terminal to be ready.
  " With valgrind this can take quite long.
  call CheckDbgOutput(buf, ['command line',
                            \ 'cmd: call GlobalFunction()'], #{msec: 5000})

  " At this point the only thing in the stack is the cmdline
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '->0 command line',
        \ 'cmd: call GlobalFunction()'])

  " And now we're back into the call stack
  call RunDbgCmd(buf, 'step', ['line 1: call CallAFunction()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '>backtrace',
        \ '  1 command line',
        \ '->0 function GlobalFunction',
        \ 'line 1: call CallAFunction()'])

  call StopVimInTerminal(buf)
endfunc

func Test_Backtrace_DefFunction()
  CheckRunVimInTerminal
  CheckCWD
  let file1 =<< trim END
    vim9script
    import './Xtest2.vim' as imp

    def SourceAnotherFile()
      source Xtest2.vim
    enddef

    def CallAFunction()
      SourceAnotherFile()
      imp.File2Function()
    enddef

    def g:GlobalFunction()
      var some = "some var"
      CallAFunction()
    enddef

    defcompile
  END
  call writefile(file1, 'Xtest1.vim', 'D')

  let file2 =<< trim END
    vim9script

    def DoAThing(): number
      var a = 100 * 2
      a += 3
      return a
    enddef

    export def File2Function()
      DoAThing()
    enddef

    defcompile
    File2Function()
  END
  call writefile(file2, 'Xtest2.vim', 'D')

  let buf = RunVimInTerminal('-S Xtest1.vim', {})

  call RunDbgCmd(buf,
                \ ':debug call GlobalFunction()',
                \ ['cmd: call GlobalFunction()'])

  call RunDbgCmd(buf, 'step', ['line 1: var some = "some var"'])
  call RunDbgCmd(buf, 'step', ['line 2: CallAFunction()'])
  call RunDbgCmd(buf, 'echo some', ['some var'])

  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V->0 function GlobalFunction',
        \ '\Vline 2: CallAFunction()',
        \ ],
        \ #{match: 'pattern'})

  call RunDbgCmd(buf, 'step', ['line 1: SourceAnotherFile()'])
  call RunDbgCmd(buf, 'step', ['line 1: source Xtest2.vim'])
  " Repeated line, because we fist are in the compiled function before the
  " EXEC and then in do_cmdline() before the :source command.
  call RunDbgCmd(buf, 'step', ['line 1: source Xtest2.vim'])
  call RunDbgCmd(buf, 'step', ['line 1: vim9script'])
  call RunDbgCmd(buf, 'step', ['line 3: def DoAThing(): number'])
  call RunDbgCmd(buf, 'step', ['line 9: export def File2Function()'])
  call RunDbgCmd(buf, 'step', ['line 9: def File2Function()'])
  call RunDbgCmd(buf, 'step', ['line 13: defcompile'])
  call RunDbgCmd(buf, 'step', ['line 14: File2Function()'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V  3 function GlobalFunction[2]',
        \ '\V  2 <SNR>\.\*_CallAFunction[1]',
        \ '\V  1 <SNR>\.\*_SourceAnotherFile[1]',
        \ '\V->0 script ' .. getcwd() .. '/Xtest2.vim',
        \ '\Vline 14: File2Function()'],
        \ #{match: 'pattern'})

  " Don't step into compiled functions...
  call RunDbgCmd(buf, 'next', ['line 15: End of sourced file'])
  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V  3 function GlobalFunction[2]',
        \ '\V  2 <SNR>\.\*_CallAFunction[1]',
        \ '\V  1 <SNR>\.\*_SourceAnotherFile[1]',
        \ '\V->0 script ' .. getcwd() .. '/Xtest2.vim',
        \ '\Vline 15: End of sourced file'],
        \ #{match: 'pattern'})

  call StopVimInTerminal(buf)
endfunc

func Test_DefFunction_expr()
  CheckRunVimInTerminal
  CheckCWD
  let file3 =<< trim END
      vim9script
      g:someVar = "foo"
      def g:ChangeVar()
        g:someVar = "bar"
        echo "changed"
      enddef
      defcompile
  END
  call writefile(file3, 'Xtest3.vim', 'D')
  let buf = RunVimInTerminal('-S Xtest3.vim', {})

  call RunDbgCmd(buf, ':breakadd expr g:someVar')
  call RunDbgCmd(buf, ':call g:ChangeVar()', ['Oldval = "''foo''"', 'Newval = "''bar''"', 'function ChangeVar', 'line 2: echo "changed"'])

  call StopVimInTerminal(buf)
endfunc

func Test_debug_def_and_legacy_function()
  CheckRunVimInTerminal
  CheckCWD
  let file =<< trim END
    vim9script
    def g:SomeFunc()
      echo "here"
      echo "and"
      echo "there"
      breakadd func 2 LocalFunc
      LocalFunc()
    enddef

    def LocalFunc()
      echo "first"
      echo "second"
      breakadd func LegacyFunc
      LegacyFunc()
    enddef

    func LegacyFunc()
      echo "legone"
      echo "legtwo"
    endfunc

    breakadd func 2 g:SomeFunc
  END
  call writefile(file, 'XtestDebug.vim', 'D')

  let buf = RunVimInTerminal('-S XtestDebug.vim', {})

  call RunDbgCmd(buf,':call SomeFunc()', ['line 2: echo "and"'])
  call RunDbgCmd(buf,'next', ['line 3: echo "there"'])
  call RunDbgCmd(buf,'next', ['line 4: breakadd func 2 LocalFunc'])

  " continue, next breakpoint is in LocalFunc()
  call RunDbgCmd(buf,'cont', ['line 2: echo "second"'])

  " continue, next breakpoint is in LegacyFunc()
  call RunDbgCmd(buf,'cont', ['line 1: echo "legone"'])

  call RunDbgCmd(buf, 'cont')

  call StopVimInTerminal(buf)
endfunc

func Test_debug_def_function()
  CheckRunVimInTerminal
  CheckCWD
  let file =<< trim END
    vim9script
    def g:Func()
      var n: number
      def Closure(): number
          return n + 3
      enddef
      n += Closure()
      echo 'result: ' .. n
    enddef

    def g:FuncWithArgs(text: string, nr: number, ...items: list<number>)
      echo text .. nr
      for it in items
        echo it
      endfor
      echo "done"
    enddef

    def g:FuncWithDict()
      var d = {
         a: 1,
         b: 2,
         }
         # comment
         def Inner()
           eval 1 + 2
         enddef
    enddef

    def g:FuncComment()
      # comment
      echo "first"
         .. "one"
      # comment
      echo "second"
    enddef

    def g:FuncForLoop()
      eval 1 + 2
      for i in [11, 22, 33]
        eval i + 2
      endfor
      echo "done"
    enddef

    def g:FuncWithSplitLine()
        eval 1 + 2
           | eval 2 + 3
    enddef
  END
  call writefile(file, 'Xtest.vim', 'D')

  let buf = RunVimInTerminal('-S Xtest.vim', {})

  call RunDbgCmd(buf,
                \ ':debug call Func()',
                \ ['cmd: call Func()'])
  call RunDbgCmd(buf, 'next', ['result: 3'])
  call term_sendkeys(buf, "\r")
  call RunDbgCmd(buf, 'cont')

  call RunDbgCmd(buf,
                \ ':debug call FuncWithArgs("asdf", 42, 1, 2, 3)',
                \ ['cmd: call FuncWithArgs("asdf", 42, 1, 2, 3)'])
  call RunDbgCmd(buf, 'step', ['line 1: echo text .. nr'])
  call RunDbgCmd(buf, 'echo text', ['asdf'])
  call RunDbgCmd(buf, 'echo nr', ['42'])
  call RunDbgCmd(buf, 'echo items', ['[1, 2, 3]'])
  call RunDbgCmd(buf, 'step', ['asdf42', 'function FuncWithArgs', 'line 2:   for it in items'])
  call RunDbgCmd(buf, 'step', ['function FuncWithArgs', 'line 2: for it in items'])
  call RunDbgCmd(buf, 'echo it', ['0'])
  call RunDbgCmd(buf, 'step', ['line 3: echo it'])
  call RunDbgCmd(buf, 'echo it', ['1'])
  call RunDbgCmd(buf, 'step', ['1', 'function FuncWithArgs', 'line 4: endfor'])
  call RunDbgCmd(buf, 'step', ['line 2: for it in items'])
  call RunDbgCmd(buf, 'echo it', ['1'])
  call RunDbgCmd(buf, 'step', ['line 3: echo it'])
  call RunDbgCmd(buf, 'step', ['2', 'function FuncWithArgs', 'line 4: endfor'])
  call RunDbgCmd(buf, 'step', ['line 2: for it in items'])
  call RunDbgCmd(buf, 'echo it', ['2'])
  call RunDbgCmd(buf, 'step', ['line 3: echo it'])
  call RunDbgCmd(buf, 'step', ['3', 'function FuncWithArgs', 'line 4: endfor'])
  call RunDbgCmd(buf, 'step', ['line 2: for it in items'])
  call RunDbgCmd(buf, 'step', ['line 5: echo "done"'])
  call RunDbgCmd(buf, 'cont')

  call RunDbgCmd(buf,
                \ ':debug call FuncWithDict()',
                \ ['cmd: call FuncWithDict()'])
  call RunDbgCmd(buf, 'step', ['line 1: var d = {  a: 1,  b: 2,  }'])
  call RunDbgCmd(buf, 'step', ['line 6: def Inner()'])
  call RunDbgCmd(buf, 'cont')

  call RunDbgCmd(buf, ':breakadd func 1 FuncComment')
  call RunDbgCmd(buf, ':call FuncComment()', ['function FuncComment', 'line 2: echo "first"  .. "one"'])
  call RunDbgCmd(buf, ':breakadd func 3 FuncComment')
  call RunDbgCmd(buf, 'cont', ['function FuncComment', 'line 5: echo "second"'])
  call RunDbgCmd(buf, 'cont')

  call RunDbgCmd(buf, ':breakadd func 2 FuncForLoop')
  call RunDbgCmd(buf, ':call FuncForLoop()', ['function FuncForLoop', 'line 2:   for i in [11, 22, 33]'])
  call RunDbgCmd(buf, 'step', ['line 2: for i in [11, 22, 33]'])
  call RunDbgCmd(buf, 'next', ['function FuncForLoop', 'line 3: eval i + 2'])
  call RunDbgCmd(buf, 'echo i', ['11'])
  call RunDbgCmd(buf, 'next', ['function FuncForLoop', 'line 4: endfor'])
  call RunDbgCmd(buf, 'next', ['function FuncForLoop', 'line 2: for i in [11, 22, 33]'])
  call RunDbgCmd(buf, 'next', ['line 3: eval i + 2'])
  call RunDbgCmd(buf, 'echo i', ['22'])

  call RunDbgCmd(buf, 'breakdel *')
  call RunDbgCmd(buf, 'cont')

  call RunDbgCmd(buf, ':breakadd func FuncWithSplitLine')
  call RunDbgCmd(buf, ':call FuncWithSplitLine()', ['function FuncWithSplitLine', 'line 1: eval 1 + 2 | eval 2 + 3'])

  call RunDbgCmd(buf, 'cont')
  call StopVimInTerminal(buf)
endfunc

func Test_debug_def_function_with_lambda()
  CheckRunVimInTerminal
  CheckCWD
  let lines =<< trim END
     vim9script
     def g:Func()
       var s = 'a'
       ['b']->map((_, v) => s)
       echo "done"
     enddef
     breakadd func 2 g:Func
  END
  call writefile(lines, 'XtestLambda.vim', 'D')

  let buf = RunVimInTerminal('-S XtestLambda.vim', {})

  call RunDbgCmd(buf,
                \ ':call g:Func()',
                \ ['function Func', 'line 2: [''b'']->map((_, v) => s)'])
  call RunDbgCmd(buf,
                \ 'next',
                \ ['function Func', 'line 3: echo "done"'])

  call RunDbgCmd(buf, 'cont')
  call StopVimInTerminal(buf)
endfunc

func Test_debug_backtrace_level()
  CheckRunVimInTerminal
  CheckCWD
  let lines =<< trim END
    let s:file1_var = 'file1'
    let g:global_var = 'global'

    func s:File1Func( arg )
      let s:file1_var .= a:arg
      let local_var = s:file1_var .. ' test1'
      let g:global_var .= local_var
      source Xtest2.vim
    endfunc

    call s:File1Func( 'arg1' )
  END
  call writefile(lines, 'Xtest1.vim', 'D')

  let lines =<< trim END
    let s:file2_var = 'file2'

    func s:File2Func( arg )
      let s:file2_var .= a:arg
      let local_var = s:file2_var .. ' test2'
      let g:global_var .= local_var
    endfunc

    call s:File2Func( 'arg2' )
  END
  call writefile(lines, 'Xtest2.vim', 'D')

  let file1 = getcwd() .. '/Xtest1.vim'
  let file2 = getcwd() .. '/Xtest2.vim'

  " set a breakpoint and source file1.vim
  let buf = RunVimInTerminal(
        \ '-c "breakadd file 1 Xtest1.vim" -S Xtest1.vim',
        \ #{wait_for_ruler: 0})

  call CheckDbgOutput(buf, [
        \ 'Breakpoint in "' .. file1 .. '" line 1',
        \ 'Entering Debug mode.  Type "cont" to continue.',
        \ 'command line..script ' .. file1,
        \ 'line 1: let s:file1_var = ''file1'''
        \ ], #{msec: 5000})

  " step through the initial declarations
  call RunDbgCmd(buf, 'step', [ 'line 2: let g:global_var = ''global''' ] )
  call RunDbgCmd(buf, 'step', [ 'line 4: func s:File1Func( arg )' ] )
  call RunDbgCmd(buf, 'echo s:file1_var', [ 'file1' ] )
  call RunDbgCmd(buf, 'echo g:global_var', [ 'global' ] )
  call RunDbgCmd(buf, 'echo global_var', [ 'global' ] )

  " step in to the first function
  call RunDbgCmd(buf, 'step', [ 'line 11: call s:File1Func( ''arg1'' )' ] )
  call RunDbgCmd(buf, 'step', [ 'line 1: let s:file1_var .= a:arg' ] )
  call RunDbgCmd(buf, 'echo a:arg', [ 'arg1' ] )
  call RunDbgCmd(buf, 'echo s:file1_var', [ 'file1' ] )
  call RunDbgCmd(buf, 'echo g:global_var', [ 'global' ] )
  call RunDbgCmd(buf,
                \'echo global_var',
                \[ 'E121: Undefined variable: global_var' ] )
  call RunDbgCmd(buf,
                \'echo local_var',
                \[ 'E121: Undefined variable: local_var' ] )
  call RunDbgCmd(buf,
                \'echo l:local_var',
                \[ 'E121: Undefined variable: l:local_var' ] )

  " backtrace up
  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V  2 command line',
        \ '\V  1 script ' .. file1 .. '[11]',
        \ '\V->0 function <SNR>\.\*_File1Func',
        \ '\Vline 1: let s:file1_var .= a:arg',
        \ ],
        \ #{ match: 'pattern' } )
  call RunDbgCmd(buf, 'up', [ '>up' ] )

  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V  2 command line',
        \ '\V->1 script ' .. file1 .. '[11]',
        \ '\V  0 function <SNR>\.\*_File1Func',
        \ '\Vline 1: let s:file1_var .= a:arg',
        \ ],
        \ #{ match: 'pattern' } )

  " Expression evaluation in the script frame (not the function frame)
  " FIXME: Unexpected in this scope (a: should not be visible)
  call RunDbgCmd(buf, 'echo a:arg', [ 'arg1' ] )
  call RunDbgCmd(buf, 'echo s:file1_var', [ 'file1' ] )
  call RunDbgCmd(buf, 'echo g:global_var', [ 'global' ] )
  " FIXME: Unexpected in this scope (global should be found)
  call RunDbgCmd(buf,
                \'echo global_var',
                \[ 'E121: Undefined variable: global_var' ] )
  call RunDbgCmd(buf,
                \'echo local_var',
                \[ 'E121: Undefined variable: local_var' ] )
  call RunDbgCmd(buf,
                \'echo l:local_var',
                \[ 'E121: Undefined variable: l:local_var' ] )


  " step while backtraced jumps to the latest frame
  call RunDbgCmd(buf, 'step', [
        \ 'line 2: let local_var = s:file1_var .. '' test1''' ] )
  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V  2 command line',
        \ '\V  1 script ' .. file1 .. '[11]',
        \ '\V->0 function <SNR>\.\*_File1Func',
        \ '\Vline 2: let local_var = s:file1_var .. '' test1''',
        \ ],
        \ #{ match: 'pattern' } )

  call RunDbgCmd(buf, 'step', [ 'line 3: let g:global_var .= local_var' ] )
  call RunDbgCmd(buf, 'echo local_var', [ 'file1arg1 test1' ] )
  call RunDbgCmd(buf, 'echo l:local_var', [ 'file1arg1 test1' ] )

  call RunDbgCmd(buf, 'step', [ 'line 4: source Xtest2.vim' ] )
  call RunDbgCmd(buf, 'step', [ 'line 1: let s:file2_var = ''file2''' ] )
  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V  3 command line',
        \ '\V  2 script ' .. file1 .. '[11]',
        \ '\V  1 function <SNR>\.\*_File1Func[4]',
        \ '\V->0 script ' .. file2,
        \ '\Vline 1: let s:file2_var = ''file2''',
        \ ],
        \ #{ match: 'pattern' } )

  " Expression evaluation in the script frame file2 (not the function frame)
  call RunDbgCmd(buf, 'echo a:arg', [ 'E121: Undefined variable: a:arg' ] )
  call RunDbgCmd(buf,
        \ 'echo s:file1_var',
        \ [ 'E121: Undefined variable: s:file1_var' ] )
  call RunDbgCmd(buf, 'echo g:global_var', [ 'globalfile1arg1 test1' ] )
  call RunDbgCmd(buf, 'echo global_var', [ 'globalfile1arg1 test1' ] )
  call RunDbgCmd(buf,
                \'echo local_var',
                \[ 'E121: Undefined variable: local_var' ] )
  call RunDbgCmd(buf,
                \'echo l:local_var',
                \[ 'E121: Undefined variable: l:local_var' ] )
  call RunDbgCmd(buf,
        \ 'echo s:file2_var',
        \ [ 'E121: Undefined variable: s:file2_var' ] )

  call RunDbgCmd(buf, 'step', [ 'line 3: func s:File2Func( arg )' ] )
  call RunDbgCmd(buf, 'echo s:file2_var', [ 'file2' ] )

  " Up the stack to the other script context
  call RunDbgCmd(buf, 'up')
  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V  3 command line',
        \ '\V  2 script ' .. file1 .. '[11]',
        \ '\V->1 function <SNR>\.\*_File1Func[4]',
        \ '\V  0 script ' .. file2,
        \ '\Vline 3: func s:File2Func( arg )',
        \ ],
        \ #{ match: 'pattern' } )
  " FIXME: Unexpected. Should see the a: and l: dicts from File1Func
  call RunDbgCmd(buf, 'echo a:arg', [ 'E121: Undefined variable: a:arg' ] )
  call RunDbgCmd(buf,
        \ 'echo l:local_var',
        \ [ 'E121: Undefined variable: l:local_var' ] )

  call RunDbgCmd(buf, 'up')
  call RunDbgCmd(buf, 'backtrace', [
        \ '\V>backtrace',
        \ '\V  3 command line',
        \ '\V->2 script ' .. file1 .. '[11]',
        \ '\V  1 function <SNR>\.\*_File1Func[4]',
        \ '\V  0 script ' .. file2,
        \ '\Vline 3: func s:File2Func( arg )',
        \ ],
        \ #{ match: 'pattern' } )

  " FIXME: Unexpected (wrong script vars are used)
  call RunDbgCmd(buf,
        \ 'echo s:file1_var',
        \ [ 'E121: Undefined variable: s:file1_var' ] )
  call RunDbgCmd(buf, 'echo s:file2_var', [ 'file2' ] )

  call RunDbgCmd(buf, 'cont')
  call StopVimInTerminal(buf)
endfunc

" Test for setting a breakpoint on a :endif where the :if condition is false
" and then quit the script. This should generate an interrupt.
func Test_breakpt_endif_intr()
  func F()
    let g:Xpath ..= 'a'
    if v:false
      let g:Xpath ..= 'b'
    endif
    invalid_command
  endfunc

  let g:Xpath = ''
  breakadd func 4 F
  try
    let caught_intr = 0
    debuggreedy
    call feedkeys(":call F()\<CR>quit\<CR>", "xt")
  catch /^Vim:Interrupt$/
    call assert_match('\.F, line 4', v:throwpoint)
    let caught_intr = 1
  endtry
  0debuggreedy
  call assert_equal(1, caught_intr)
  call assert_equal('a', g:Xpath)
  breakdel *
  delfunc F
endfunc

" Test for setting a breakpoint on a :else where the :if condition is false
" and then quit the script. This should generate an interrupt.
func Test_breakpt_else_intr()
  func F()
    let g:Xpath ..= 'a'
    if v:false
      let g:Xpath ..= 'b'
    else
      invalid_command
    endif
    invalid_command
  endfunc

  let g:Xpath = ''
  breakadd func 4 F
  try
    let caught_intr = 0
    debuggreedy
    call feedkeys(":call F()\<CR>quit\<CR>", "xt")
  catch /^Vim:Interrupt$/
    call assert_match('\.F, line 4', v:throwpoint)
    let caught_intr = 1
  endtry
  0debuggreedy
  call assert_equal(1, caught_intr)
  call assert_equal('a', g:Xpath)
  breakdel *
  delfunc F
endfunc

" Test for setting a breakpoint on a :endwhile where the :while condition is
" false and then quit the script. This should generate an interrupt.
func Test_breakpt_endwhile_intr()
  func F()
    let g:Xpath ..= 'a'
    while v:false
      let g:Xpath ..= 'b'
    endwhile
    invalid_command
  endfunc

  let g:Xpath = ''
  breakadd func 4 F
  try
    let caught_intr = 0
    debuggreedy
    call feedkeys(":call F()\<CR>quit\<CR>", "xt")
  catch /^Vim:Interrupt$/
    call assert_match('\.F, line 4', v:throwpoint)
    let caught_intr = 1
  endtry
  0debuggreedy
  call assert_equal(1, caught_intr)
  call assert_equal('a', g:Xpath)
  breakdel *
  delfunc F
endfunc

" Test for setting a breakpoint on a script local function
func Test_breakpt_scriptlocal_func()
  let g:Xpath = ''
  func s:G()
    let g:Xpath ..= 'a'
  endfunc

  let funcname = expand("<SID>") .. "G"
  exe "breakadd func 1 " .. funcname
  debuggreedy
  redir => output
  call feedkeys(":call " .. funcname .. "()\<CR>c\<CR>", "xt")
  redir END
  0debuggreedy
  call assert_match('Breakpoint in "' .. funcname .. '" line 1', output)
  call assert_equal('a', g:Xpath)
  breakdel *
  exe "delfunc " .. funcname
endfunc

" vim: shiftwidth=2 sts=2 expandtab
