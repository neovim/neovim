" This script is sourced while editing the .vim file with the tests.
" When the script is successful the .res file will be created.
" Errors are appended to the test.log file.
"
" To execute only specific test functions, add a second argument.  It will be
" matched against the names of the Test_ function.  E.g.:
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
" 	call add(v:errors, "this happened")


" Check that the screen size is at least 24 x 80 characters.
if &lines < 24 || &columns < 80 
  let error = 'Screen size too small! Tests require at least 24 lines with 80 characters'
  echoerr error
  split test.log
  $put =error
  w
  cquit
endif

" Common with all tests on all systems.
source setup.vim

" For consistency run all tests with 'nocompatible' set.
" This also enables use of line continuation.
set nocp viminfo+=nviminfo

" Use utf-8 or latin1 by default, instead of whatever the system default
" happens to be.  Individual tests can overrule this at the top of the file.
if has('multi_byte')
  set encoding=utf-8
else
  set encoding=latin1
endif

" Avoid stopping at the "hit enter" prompt
set nomore

" Output all messages in English.
lang mess C

" Always use forward slashes.
" set shellslash

" Prepare for calling test_garbagecollect_now().
let v:testing = 1

" Support function: get the alloc ID by name.
function GetAllocId(name)
  exe 'split ' . s:srcdir . '/alloc.h'
  let top = search('typedef enum')
  if top == 0
    call add(v:errors, 'typedef not found in alloc.h')
  endif
  let lnum = search('aid_' . a:name . ',')
  if lnum == 0
    call add(v:errors, 'Alloc ID ' . a:name . ' not defined')
  endif
  close
  return lnum - top - 1
endfunc

func RunTheTest(test)
  echo 'Executing ' . a:test

  " Avoid stopping at the "hit enter" prompt
  set nomore

  " Avoid a three second wait when a message is about to be overwritten by the
  " mode message.
  set noshowmode

  " Some tests wipe out buffers.  To be consistent, always wipe out all
  " buffers.
  %bwipe!

  " The test may change the current directory. Save and restore the
  " directory after executing the test.
  let save_cwd = getcwd()

  if exists("*SetUp")
    try
      call SetUp()
    catch
      call add(v:errors, 'Caught exception in SetUp() before ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
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
      exe 'call ' . a:test
    catch /^\cskipped/
      call add(s:messages, '    Skipped')
      call add(s:skipped, 'SKIPPED ' . a:test . ': ' . substitute(v:exception, '^\S*\s\+', '',  ''))
    catch
      call add(v:errors, 'Caught exception in ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
    endtry
  endif

  if exists("*TearDown")
    try
      call TearDown()
    catch
      call add(v:errors, 'Caught exception in TearDown() after ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
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
    call add(s:errors, 'Found errors in ' . s:test . ':')
    call extend(s:errors, v:errors)
    let v:errors = []
  endif
endfunc

" This function can be called by a test if it wants to abort testing.
func FinishTesting()
  call AfterTheTest()

  " Don't write viminfo on exit.
  set viminfo=

  " Clean up files created by setup.vim
  call delete('XfakeHOME', 'rf')

  if s:fail == 0
    " Success, create the .res file so that make knows it's done.
    exe 'split ' . fnamemodify(g:testname, ':r') . '.res'
    write
  endif

  if len(s:errors) > 0
    " Append errors to test.log
    split test.log
    call append(line('$'), '')
    call append(line('$'), 'From ' . g:testname . ':')
    call append(line('$'), s:errors)
    write
  endif

  let message = 'Executed ' . s:done . (s:done > 1 ? ' tests' : ' test')
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
  call append(line('$'), 'From ' . g:testname . ':')
  call append(line('$'), s:messages)
  write

  qall!
endfunc

" Source the test script.  First grab the file name, in case the script
" navigates away.  g:testname can be used by the tests.
let g:testname = expand('%')
let s:done = 0
let s:fail = 0
let s:errors = []
let s:messages = []
let s:skipped = []
if expand('%') =~ 'test_vimscript.vim'
  " this test has intentional s:errors, don't use try/catch.
  source %
else
  try
    source %
  catch
    let s:fail += 1
    call add(s:errors, 'Caught exception: ' . v:exception . ' @ ' . v:throwpoint)
  endtry
endif

" Names of flaky tests.
let s:flaky = [
      \ 'Test_exit_callback_interval()',
      \ 'Test_oneshot()',
      \ 'Test_out_cb()',
      \ 'Test_paused()',
      \ 'Test_quoteplus()',
      \ 'Test_quotestar()',
      \ 'Test_reltime()',
      \ 'Test_terminal_composing_unicode()',
      \ 'Test_terminal_redir_file()',
      \ 'Test_terminal_tmap()',
      \ 'Test_with_partial_callback()',
      \ 'Test_lambda_with_timer()',
      \ ]

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

  if len(v:errors) > 0 && index(s:flaky, s:test) >= 0
    call add(s:messages, 'Found errors in ' . s:test . ':')
    call extend(s:messages, v:errors)
    call add(s:messages, 'Flaky test failed, running it again')
    let first_run = v:errors

    " Flakiness is often caused by the system being very busy.  Sleep a couple
    " of seconds to have a higher chance of succeeding the second time.
    sleep 2

    let v:errors = []
    call RunTheTest(s:test)
    if len(v:errors) > 0
      let second_run = v:errors
      let v:errors = ['First run:']
      call extend(v:errors, first_run)
      call add(v:errors, 'Second run:')
      call extend(v:errors, second_run)
    endif
  endif

  call AfterTheTest()
endfor

call FinishTesting()

" vim: shiftwidth=2 sts=2 expandtab
