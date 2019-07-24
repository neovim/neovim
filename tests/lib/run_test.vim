" This script is sourced while editing the .vim file with the tests.
" When the script is successful the .res file will be created.
" Errors are appended to the test.log file.
"
" To execute only specific test functions, add a second argument.  It will be
" matched against the names of the Test_ funtion.  E.g.:
"	../vim -u NONE -S runtest.vim test_channel.vim open_delay
" The output can be found in the "messages" file.
"
" The test script may contain anything, only functions that start with
" "Test_" are special.  These will be invoked and should contain assert
" functions.  See test_assert.vim for an example.
"
" It is possible to source other files that contain "Test_" functions.  This
" can speed up testing, since Vim does not need to restart.  But be careful
" that the tests do not interfere with each other.
"
" If an error cannot be detected properly with an assert function add the
" error to the v:errors list:
"   call add(v:errors, 'test foo failed: Cannot find xyz')
"
" If preparation for each Test_ function is needed, define a SetUp function.
" It will be called before each Test_ function.
"
" If cleanup after each Test_ function is needed, define a TearDown function.
" It will be called after each Test_ function.
"
" When debugging a test it can be useful to add messages to v:errors:
"	call add(v:errors, "this happened")

set rtp=$PWD/lib,$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after
if has('packages')
  let &packpath = &rtp
endif

call ch_logfile( 'debuglog', 'w' )

" For consistency run all tests with 'nocompatible' set.
" This also enables use of line continuation.
set nocp viminfo+=nviminfo

" Use utf-8 by default, instead of whatever the system default happens to be.
" Individual tests can overrule this at the top of the file.
set encoding=utf-8

" Avoid stopping at the "hit enter" prompt
set nomore

" Output all messages in English.
lang mess C

" Always use forward slashes.
set shellslash

func RunTheTest(test)
  echo 'Executing ' . a:test

  " Avoid stopping at the "hit enter" prompt
  set nomore

  " Avoid a three second wait when a message is about to be overwritten by the
  " mode message.
  set noshowmode

  " Clear any overrides.
  call test_override('ALL', 0)

  " Some tests wipe out buffers.  To be consistent, always wipe out all
  " buffers.
  %bwipe!

  " The test may change the current directory. Save and restore the
  " directory after executing the test.
  let save_cwd = getcwd()

  if exists("*SetUp_" . a:test)
    try
      exe 'call SetUp_' . a:test
    catch
      call add(v:errors,
            \ 'Caught exception in SetUp_' . a:test . ' before '
            \ . a:test
            \ . ': '
            \ . v:exception
            \ . ' @ '
            \ . g:testpath
            \ . ':'
            \ . v:throwpoint)
    endtry
  endif

  if exists("*SetUp")
    try
      call SetUp()
    catch
      call add(v:errors,
            \ 'Caught exception in SetUp() before '
            \ . a:test
            \ . ': '
            \ . v:exception
            \ . ' @ '
            \ . g:testpath
            \ . ':'
            \ . v:throwpoint)
    endtry
  endif

  call add(s:messages, 'Executing ' . a:test)
  let s:done += 1

  if a:test =~ 'Test_nocatch_'
    " Function handles errors itself.  This avoids skipping commands after the
    " error.
    exe 'call ' . a:test
  else
    try
      let s:test = a:test
      let s:testid = g:testpath . ':' . a:test
      let test_filesafe = substitute( a:test, ')', '_', 'g' )
      let test_filesafe = substitute( test_filesafe, '(', '_', 'g' )
      let test_filesafe = substitute( test_filesafe, ',', '_', 'g' )
      let test_filesafe = substitute( test_filesafe, ':', '_', 'g' )
      let s:testid_filesafe = g:testpath . '_' . test_filesafe
      au VimLeavePre * call EarlyExit(s:test)
      exe 'call ' . a:test
      au! VimLeavePre
    catch /^\cskipped/
      call add(s:messages, '    Skipped')
      call add(s:skipped,
            \ 'SKIPPED ' . a:test
            \ . ': '
            \ . substitute(v:exception, '^\S*\s\+', '',  ''))
    catch
      call add(v:errors,
            \ 'Caught exception in ' . a:test
            \ . ': '
            \ . v:exception
            \ . ' @ '
            \ . g:testpath
            \ . ':'
            \ . v:throwpoint)
    endtry
  endif

  " In case 'insertmode' was set and something went wrong, make sure it is
  " reset to avoid trouble with anything else.
  set noinsertmode

  if exists("*TearDown")
    try
      call TearDown()
    catch
      call add(v:errors,
            \ 'Caught exception in TearDown() after ' . a:test
            \ . ': '
            \ . v:exception
            \ . ' @ '
            \ . g:testpath
            \ . ':'
            \ . v:throwpoint)
    endtry
  endif

  if exists("*TearDown_" . a:test)
    try
      exe 'call TearDown_' . a:test
    catch
      call add(v:errors,
            \ 'Caught exception in TearDown_' . a:test . ' after ' . a:test
            \ . ': '
            \ . v:exception
            \ . ' @ '
            \ . g:testpath
            \ . ':'
            \ . v:throwpoint)
    endtry
  endif

  " Clear any autocommands
  au!

  " Close any extra tab pages and windows and make the current one not modified.
  while tabpagenr('$') > 1
    quit!
  endwhile

  while 1
    let wincount = winnr('$')
    if wincount == 1
      break
    endif
    bwipe!
    if wincount == winnr('$')
      " Did not manage to close a window.
      only!
      break
    endif
  endwhile

  exe 'cd ' . save_cwd
endfunc

func AfterTheTest()
  if len(v:errors) > 0
    let s:fail += 1
    call add(s:errors, 'Found errors in ' . s:testid . ':')
    call extend(s:errors, v:errors)
    let v:errors = []

    let log = readfile( expand( '~/.vimspector.log' ) )
    let logfile = s:testid_filesafe . '.vimspector.log'
    call writefile( log, logfile, 's' )
    call add( s:messages, 'Wrote log for failed test: ' . logfile )
    call extend( s:messages, log )
  endif
endfunc

func EarlyExit(test)
  " It's OK for the test we use to test the quit detection.
  if a:test != 'Test_zz_quit_detected()'
    call add(v:errors, 'Test caused Vim to exit: ' . a:test)
  endif

  call FinishTesting()
endfunc

" This function can be called by a test if it wants to abort testing.
func FinishTesting()
  call AfterTheTest()

  " Don't write viminfo on exit.
  set viminfo=

  if s:fail == 0
    " Success, create the .res file so that make knows it's done.
    exe 'split ' . fnamemodify(g:testname, ':r') . '.res'
    write
  endif

  if len(s:errors) > 0
    " Append errors to test.log
    split test.log
    call append(line('$'), '')
    call append(line('$'), 'From ' . g:testpath . ':')
    call append(line('$'), s:errors)
    write
  endif

  if s:done == 0
    let message = 'NO tests executed'
  else
    let message = 'Executed ' . s:done . (s:done > 1 ? ' tests' : ' test')
  endif
  echo message
  call add(s:messages, message)
  if s:fail > 0
    let message = s:fail . ' FAILED:'
    echo message
    call add(s:messages, message)
    call extend(s:messages, s:errors)
  endif

  " Add SKIPPED messages
  call extend(s:messages, s:skipped)

  " Append messages to the file "messages"
  split messages
  call append(line('$'), '')
  call append(line('$'), 'From ' . g:testpath . ':')
  call append(line('$'), s:messages)
  write

  if s:fail > 0
    cquit!
  else
    qall!
  endif
endfunc

" Source the test script.  First grab the file name, in case the script
" navigates away.  g:testname can be used by the tests.
let g:testname = expand('%')
let g:testpath = expand('%:p')
let s:done = 0
let s:fail = 0
let s:errors = []
let s:messages = []
let s:skipped = []
try
  source %
catch
  let s:fail += 1
  call add(s:errors,
        \ 'Caught exception: ' .
        \ v:exception .
        \ ' @ ' . v:throwpoint)
endtry

" Names of flaky tests.
let s:flaky_tests = []

" Pattern indicating a common flaky test failure.
let s:flaky_errors_re = '__does_not_match__'

" Locate Test_ functions and execute them.
redir @q
silent function /^Test_
redir END
let s:tests = split(substitute(@q, 'function \(\k*()\)', '\1', 'g'))

" If there is an extra argument filter the function names against it.
if argc() > 1
  let s:tests = filter(s:tests, 'v:val =~ argv(1)')
endif

" Execute the tests in alphabetical order.
for s:test in sort(s:tests)
  " Silence, please!
  set belloff=all
  call RunTheTest(s:test)
  call AfterTheTest()
endfor

call FinishTesting()

" vim: shiftwidth=2 sts=2 expandtab
