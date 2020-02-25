" Test for "rvim" or "vim -Z"

source shared.vim

func Test_restricted()
  let cmd = GetVimCommand('Xrestricted')
  if cmd == ''
    return
  endif

  call writefile([
	\ "silent !ls",
	\ "call writefile([v:errmsg], 'Xrestrout')",
	\ "qa!",
	\ ], 'Xrestricted')
  call system(cmd . ' -Z')
  call assert_match('E145:', join(readfile('Xrestrout')))

  call delete('Xrestricted')
  call delete('Xrestrout')
endfunc

func Run_restricted_test(ex_cmd, error)
  let cmd = GetVimCommand('Xrestricted')
  if cmd == ''
    return
  endif

  call writefile([
	\ a:ex_cmd,
	\ "call writefile([v:errmsg], 'Xrestrout')",
	\ "qa!",
	\ ], 'Xrestricted')
  call system(cmd . ' -Z')
  call assert_match(a:error, join(readfile('Xrestrout')))

  call delete('Xrestricted')
  call delete('Xrestrout')
endfunc

func Test_restricted_lua()
  if !has('lua')
    throw 'Skipped: Lua is not supported'
  endif
  call Run_restricted_test('lua print("Hello, Vim!")', 'E981:')
  call Run_restricted_test('luado return "hello"', 'E981:')
  call Run_restricted_test('luafile somefile', 'E981:')
  call Run_restricted_test('call luaeval("expression")', 'E145:')
endfunc

func Test_restricted_mzscheme()
  if !has('mzscheme')
    throw 'Skipped: MzScheme is not supported'
  endif
  call Run_restricted_test('mzscheme statement', 'E981:')
  call Run_restricted_test('mzfile somefile', 'E981:')
  call Run_restricted_test('call mzeval("expression")', 'E145:')
endfunc

func Test_restricted_perl()
  if !has('perl')
    throw 'Skipped: Perl is not supported'
  endif
  " TODO: how to make Safe mode fail?
  " call Run_restricted_test('perl system("ls")', 'E981:')
  " call Run_restricted_test('perldo system("hello")', 'E981:')
  " call Run_restricted_test('perlfile somefile', 'E981:')
  " call Run_restricted_test('call perleval("system(\"ls\")")', 'E145:')
endfunc

func Test_restricted_python()
  if !has('python')
    throw 'Skipped: Python is not supported'
  endif
  call Run_restricted_test('python print "hello"', 'E981:')
  call Run_restricted_test('pydo return "hello"', 'E981:')
  call Run_restricted_test('pyfile somefile', 'E981:')
  call Run_restricted_test('call pyeval("expression")', 'E145:')
endfunc

func Test_restricted_python3()
  if !has('python3')
    throw 'Skipped: Python3 is not supported'
  endif
  call Run_restricted_test('py3 print "hello"', 'E981:')
  call Run_restricted_test('py3do return "hello"', 'E981:')
  call Run_restricted_test('py3file somefile', 'E981:')
  call Run_restricted_test('call py3eval("expression")', 'E145:')
endfunc

func Test_restricted_ruby()
  if !has('ruby')
    throw 'Skipped: Ruby is not supported'
  endif
  call Run_restricted_test('ruby print "Hello"', 'E981:')
  call Run_restricted_test('rubydo print "Hello"', 'E981:')
  call Run_restricted_test('rubyfile somefile', 'E981:')
endfunc

func Test_restricted_tcl()
  if !has('tcl')
    throw 'Skipped: Tcl is not supported'
  endif
  call Run_restricted_test('tcl puts "Hello"', 'E981:')
  call Run_restricted_test('tcldo puts "Hello"', 'E981:')
  call Run_restricted_test('tclfile somefile', 'E981:')
endfunc
