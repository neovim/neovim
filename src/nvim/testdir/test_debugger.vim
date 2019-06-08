" Tests for the Vim script debug commands

source shared.vim
" source screendump.vim

" Run a Vim debugger command
" If the expected output argument is supplied, then check for it.
func RunDbgCmd(buf, cmd, ...)
  call term_sendkeys(a:buf, a:cmd . "\r")
  call term_wait(a:buf)

  if a:0 != 0
    " Verify the expected output
    let lnum = 20 - len(a:1)
    for l in a:1
      call WaitForAssert({-> assert_equal(l, term_getline(a:buf, lnum))})
      let lnum += 1
    endfor
  endif
endfunc

" Debugger tests
func Test_Debugger()
  if !CanRunVimInTerminal()
    return
  endif

  " Create a Vim script with some functions
  call writefile([
	      \ 'func Foo()',
	      \ '  let var1 = 1',
	      \ '  let var2 = Bar(var1) + 9',
	      \ '  return var2',
	      \ 'endfunc',
	      \ 'func Bar(var)',
	      \ '  let var1 = 2 + a:var',
	      \ '  let var2 = Bazz(var1) + 4',
	      \ '  return var2',
	      \ 'endfunc',
	      \ 'func Bazz(var)',
	      \ '  try',
	      \ '    let var1 = 3 + a:var',
	      \ '    let var3 = "another var"',
	      \ '    let var3 = "value2"',
	      \ '  catch',
	      \ '    let var4 = "exception"',
	      \ '  endtry',
	      \ '  return var1',
	      \ 'endfunc'], 'Xtest.vim')

  " Start Vim in a terminal
  let buf = RunVimInTerminal('-S Xtest.vim', {})

  " Start the Vim debugger
  call RunDbgCmd(buf, ':debug echo Foo()')

  " Create a few stack frames by stepping through functions
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'step')
  call RunDbgCmd(buf, 'step')

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
  call RunDbgCmd(buf, ':debug echo Foo()')

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
  call RunDbgCmd(buf, 'breakd expr x', [
	      \ 'E121: Undefined variable: x',
	      \ 'E161: Breakpoint not found: expr x'])

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

  " Tests for :breakadd file and :breakadd here
  " Breakpoints should be set before sourcing the file

  call writefile([
	      \ 'let var1 = 10',
	      \ 'let var2 = 20',
	      \ 'let var3 = 30',
	      \ 'let var4 = 40'], 'Xtest.vim')

  " Start Vim in a terminal
  let buf = RunVimInTerminal('Xtest.vim', {})
  call RunDbgCmd(buf, ':breakadd file 2 Xtest.vim')
  call RunDbgCmd(buf, ':4 | breakadd here')
  call RunDbgCmd(buf, ':source Xtest.vim', ['line 2: let var2 = 20'])
  call RunDbgCmd(buf, 'cont', ['line 4: let var4 = 40'])
  call RunDbgCmd(buf, 'cont')

  call StopVimInTerminal(buf)

  call delete('Xtest.vim')
endfunc
