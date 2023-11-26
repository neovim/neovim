source shared.vim
source term_util.vim

command -nargs=1 MissingFeature throw 'Skipped: ' .. <args> .. ' feature missing'

" Command to check for the presence of a feature.
command -nargs=1 CheckFeature call CheckFeature(<f-args>)
func CheckFeature(name)
  " if !has(a:name, 1)
  "   throw 'Checking for non-existent feature ' .. a:name
  " endif
  if !has(a:name)
    MissingFeature a:name
  endif
endfunc

" Command to check for the absence of a feature.
command -nargs=1 CheckNotFeature call CheckNotFeature(<f-args>)
func CheckNotFeature(name)
  " if !has(a:name, 1)
  "   throw 'Checking for non-existent feature ' .. a:name
  " endif
  if has(a:name)
    throw 'Skipped: ' .. a:name .. ' feature present'
  endif
endfunc

" Command to check for the presence of a working option.
command -nargs=1 CheckOption call CheckOption(<f-args>)
func CheckOption(name)
  if !exists('&' .. a:name)
    throw 'Checking for non-existent option ' .. a:name
  endif
  if !exists('+' .. a:name)
    throw 'Skipped: ' .. a:name .. ' option not supported'
  endif
endfunc

" Command to check for the presence of a function.
command -nargs=1 CheckFunction call CheckFunction(<f-args>)
func CheckFunction(name)
  if !exists('*' .. a:name)
    throw 'Skipped: ' .. a:name .. ' function missing'
  endif
endfunc

" Command to check for the presence of an Ex command
command -nargs=1 CheckCommand call CheckCommand(<f-args>)
func CheckCommand(name)
  if !exists(':' .. a:name)
    throw 'Skipped: ' .. a:name .. ' command not supported'
  endif
endfunc

" Command to check for the presence of a shell command
command -nargs=1 CheckExecutable call CheckExecutable(<f-args>)
func CheckExecutable(name)
  if !executable(a:name)
    throw 'Skipped: ' .. a:name .. ' program not executable'
  endif
endfunc

" Command to check for the presence of python.  Argument should have been
" obtained with PythonProg()
func CheckPython(name)
  if a:name == ''
    throw 'Skipped: python command not available'
  endif
endfunc

" Command to check for running on MS-Windows
command CheckMSWindows call CheckMSWindows()
func CheckMSWindows()
  if !has('win32')
    throw 'Skipped: only works on MS-Windows'
  endif
endfunc

" Command to check for NOT running on MS-Windows
command CheckNotMSWindows call CheckNotMSWindows()
func CheckNotMSWindows()
  if has('win32')
    throw 'Skipped: does not work on MS-Windows'
  endif
endfunc

" Command to check for running on Unix
command CheckUnix call CheckUnix()
func CheckUnix()
  if !has('unix')
    throw 'Skipped: only works on Unix'
  endif
endfunc

" Command to check for running on Linux
command CheckLinux call CheckLinux()
func CheckLinux()
  if !has('linux')
    throw 'Skipped: only works on Linux'
  endif
endfunc

" Command to check for not running on a BSD system.
command CheckNotBSD call CheckNotBSD()
func CheckNotBSD()
  if has('bsd')
    throw 'Skipped: does not work on BSD'
  endif
endfunc

" Command to check for not running on a MacOS
command CheckNotMac call CheckNotMac()
func CheckNotMac()
  if has('mac')
    throw 'Skipped: does not work on MacOS'
  endif
endfunc

" Command to check for not running on a MacOS M1 system.
command CheckNotMacM1 call CheckNotMacM1()
func CheckNotMacM1()
  if has('mac') && system('uname -a') =~ '\<arm64\>'
    throw 'Skipped: does not work on MacOS M1'
  endif
endfunc

" Command to check that making screendumps is supported.
" Caller must source screendump.vim
command CheckScreendump call CheckScreendump()
func CheckScreendump()
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif
endfunc

" Command to check that we can Run Vim in a terminal window
command CheckRunVimInTerminal call CheckRunVimInTerminal()
func CheckRunVimInTerminal()
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot run Vim in a terminal window'
  endif
endfunc

" Command to check that we can run the GUI
command CheckCanRunGui call CheckCanRunGui()
func CheckCanRunGui()
  if !has('gui') || ($DISPLAY == "" && !has('gui_running'))
    throw 'Skipped: cannot start the GUI'
  endif
endfunc

" Command to Check for an environment variable
command -nargs=1 CheckEnv call CheckEnv(<f-args>)
func CheckEnv(name)
  if empty(eval('$' .. a:name))
    throw 'Skipped: Environment variable ' .. a:name .. ' is not set'
  endif
endfunc

" Command to check that we are using the GUI
command CheckGui call CheckGui()
func CheckGui()
  if !has('gui_running')
    throw 'Skipped: only works in the GUI'
  endif
endfunc

" Command to check that not currently using the GUI
command CheckNotGui call CheckNotGui()
func CheckNotGui()
  if has('gui_running')
    throw 'Skipped: only works in the terminal'
  endif
endfunc

" Command to check that test is not running as root
command CheckNotRoot call CheckNotRoot()
func CheckNotRoot()
  if IsRoot()
    throw 'Skipped: cannot run test as root'
  endif
endfunc

" Command to check that the current language is English
command CheckEnglish call CheckEnglish()
func CheckEnglish()
  if v:lang != "C" && v:lang !~ '^[Ee]n'
      throw 'Skipped: only works in English language environment'
  endif
endfunc

" Command to check for not running under ASAN
command CheckNotAsan call CheckNotAsan()
func CheckNotAsan()
  if execute('verbose version') =~# '-fsanitize=[a-z,]*\<address\>'
    throw 'Skipped: does not work with ASAN'
  endif
endfunc

" Command to check for not running under valgrind
command CheckNotValgrind call CheckNotValgrind()
func CheckNotValgrind()
  if RunningWithValgrind()
    throw 'Skipped: does not work well with valgrind'
  endif
endfunc

" Command to check for X11 based GUI
command CheckX11BasedGui call CheckX11BasedGui()
func CheckX11BasedGui()
  if !g:x11_based_gui
    throw 'Skipped: requires X11 based GUI'
  endif
endfunc

" Command to check for satisfying any of the conditions.
" e.g. CheckAnyOf Feature:bsd Feature:sun Linux
command -nargs=+ CheckAnyOf call CheckAnyOf(<f-args>)
func CheckAnyOf(...)
  let excp = []
  for arg in a:000
    try
      exe 'Check' .. substitute(arg, ':', ' ', '')
      return
    catch /^Skipped:/
      let excp += [substitute(v:exception, '^Skipped:\s*', '', '')]
    endtry
  endfor
  throw 'Skipped: ' .. join(excp, '; ')
endfunc

" Command to check for satisfying all of the conditions.
" e.g. CheckAllOf Unix Gui Option:ballooneval
command -nargs=+ CheckAllOf call CheckAllOf(<f-args>)
func CheckAllOf(...)
  for arg in a:000
    exe 'Check' .. substitute(arg, ':', ' ', '')
  endfor
endfunc

" vim: shiftwidth=2 sts=2 expandtab
