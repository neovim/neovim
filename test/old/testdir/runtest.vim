" This script is sourced while editing the .vim file with the tests.
" When the script is successful the .res file will be created.
" Errors are appended to the test.log file.
"
" To execute only specific test functions, add a second argument.  It will be
" matched against the names of the Test_ function.  E.g.:
"	../vim -u NONE -S runtest.vim test_channel.vim open_delay
" The output can be found in the "messages" file.
"
" If the environment variable $TEST_FILTER is set then only test functions
" matching this pattern are executed.  E.g. for sh/bash:
"     export TEST_FILTER=Test_channel
" For csh:
"     setenv TEST_FILTER Test_channel
"
" If the environment variable $TEST_SKIP_PAT is set then test functions
" matching this pattern will be skipped.  It's the opposite of $TEST_FILTER.
"
" While working on a test you can make $TEST_NO_RETRY non-empty to not retry:
"     export TEST_NO_RETRY=yes
"
" To ignore failure for tests that are known to fail in a certain environment,
" set $TEST_MAY_FAIL to a comma separated list of function names.  E.g. for
" sh/bash:
"     export TEST_MAY_FAIL=Test_channel_one,Test_channel_other
" The failure report will then not be included in the test.log file and
" "make test" will not fail.
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


" Without the +eval feature we can't run these tests, bail out.
silent! while 0
  qa!
silent! endwhile

" In the GUI we can always change the screen size.
if has('gui_running')
  set columns=80 lines=25
endif

" Check that the screen size is at least 24 x 80 characters.
if &lines < 24 || &columns < 80
  let error = 'Screen size too small! Tests require at least 24 lines with 80 characters, got ' .. &lines .. ' lines with ' .. &columns .. ' characters'
  echoerr error
  split test.log
  $put =error
  write
  split messages
  call append(line('$'), '')
  call append(line('$'), 'From ' . expand('%') . ':')
  call append(line('$'), error)
  write
  qa!
endif

if has('reltime')
  let s:run_start_time = reltime()

  if !filereadable('starttime')
    " first test, store the overall test starting time
    let s:test_start_time = localtime()
    call writefile([string(s:test_start_time)], 'starttime')
  else
    " second or later test, read the overall test starting time
    let s:test_start_time = readfile('starttime')[0]->str2nr()
  endif
endif

" Always use forward slashes.
set shellslash

" Common with all tests on all systems.
source setup.vim

" For consistency run all tests with 'nocompatible' set.
" This also enables use of line continuation.
set nocp viminfo+=nviminfo

" Use utf-8 by default, instead of whatever the system default happens to be.
" Individual tests can overrule this at the top of the file and use
" g:orig_encoding if needed.
let g:orig_encoding = &encoding
set encoding=utf-8

" REDIR_TEST_TO_NULL has a very permissive SwapExists autocommand which is for
" the test_name.vim file itself. Replace it here with a more restrictive one,
" so we still catch mistakes.
if has("win32")
  " replace any '/' directory separators by '\\'
  let s:test_script_fname = substitute(expand('%'), '/', '\\', 'g')
else
  let s:test_script_fname = expand('%')
endif
au! SwapExists * call HandleSwapExists()
func HandleSwapExists()
  if exists('g:ignoreSwapExists')
    if type(g:ignoreSwapExists) == v:t_string
      let v:swapchoice = g:ignoreSwapExists
    endif
    return
  endif
  " Ignore finding a swap file for the test script (the user might be
  " editing it and do ":make test_name") and the output file.
  " Report finding another swap file and chose 'q' to avoid getting stuck.
  if expand('<afile>') == 'messages' || expand('<afile>') =~ s:test_script_fname
    let v:swapchoice = 'e'
  else
    call assert_report('Unexpected swap file: ' .. v:swapname)
    let v:swapchoice = 'q'
  endif
endfunc

" Avoid stopping at the "hit enter" prompt
set nomore

" Output all messages in English.
lang mess C

" Nvim: append runtime from build dir, which contains the generated doc/tags.
let &runtimepath ..= ',' .. expand($BUILD_DIR) .. '/runtime/'
" Nvim: append libdir from build dir, which contains the bundled TS parsers.
let &runtimepath ..= ',' .. expand($BUILD_DIR) .. '/lib/nvim/'

let s:t_bold = &t_md
let s:t_normal = &t_me
if has('win32')
  " avoid prompt that is long or contains a line break
  let $PROMPT = '$P$G'
endif

if has('mac')
  " In macOS, when starting a shell in a terminal, a bash deprecation warning
  " message is displayed. This breaks the terminal test. Disable the warning
  " message.
  let $BASH_SILENCE_DEPRECATION_WARNING = 1
endif


" Prepare for calling test_garbagecollect_now().
let v:testing = 1

" Support function: get the alloc ID by name.
func GetAllocId(name)
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

" Get the list of swap files in the current directory.
func s:GetSwapFileList()
  let save_dir = &directory
  let &directory = '.'
  let files = swapfilelist()
  let &directory = save_dir

  " remove a match with runtest.vim
  let idx = indexof(files, 'v:val =~ "runtest.vim."')
  if idx >= 0
    call remove(files, idx)
  endif

  return files
endfunc

" A previous (failed) test run may have left swap files behind.  Delete them
" before running tests again, they might interfere.
for name in s:GetSwapFileList()
  call delete(name)
endfor
unlet! name


" Invoked when a test takes too much time.
func TestTimeout(id)
  split test.log
  call append(line('$'), '')
  call append(line('$'), 'Test timed out: ' .. g:testfunc)
  write
  call add(v:errors, 'Test timed out: ' . g:testfunc)

  cquit! 42
endfunc

func RunTheTest(test)
  let prefix = ''
  if has('reltime')
    let prefix = strftime('%M:%S', localtime() - s:test_start_time) .. ' '
    let g:func_start = reltime()
  endif
  echo prefix .. 'Executing ' .. a:test

  if has('timers')
    " No test should take longer than 30 seconds.  If it takes longer we
    " assume we are stuck and need to break out.
    let test_timeout_timer = timer_start(30000, 'TestTimeout')
  endif

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

  " Align Nvim defaults to Vim.
  source setup.vim

  if exists("*SetUp")
    try
      call SetUp()
    catch
      call add(v:errors, 'Caught exception in SetUp() before ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
    endtry
  endif

  let skipped = v:false

  au VimLeavePre * call EarlyExit(g:testfunc)
  if a:test =~ 'Test_nocatch_'
    " Function handles errors itself.  This avoids skipping commands after the
    " error.
    let g:skipped_reason = ''
    exe 'call ' . a:test
    if g:skipped_reason != ''
      call add(s:messages, '    Skipped')
      call add(s:skipped, 'SKIPPED ' . a:test . ': ' . g:skipped_reason)
      let skipped = v:true
    endif
  else
    try
      exe 'call ' . a:test
    catch /^\cskipped/
      call add(s:messages, '    Skipped')
      call add(s:skipped, 'SKIPPED ' . a:test . ': ' . substitute(v:exception, '^\S*\s\+', '',  ''))
      let skipped = v:true
    catch
      call add(v:errors, 'Caught exception in ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
    endtry
  endif
  au! VimLeavePre

  if a:test =~ '_terminal_'
    " Terminal tests sometimes hang, give extra information
    echoconsole 'After executing ' .. a:test
  endif

  " In case 'insertmode' was set and something went wrong, make sure it is
  " reset to avoid trouble with anything else.
  set noinsertmode

  if exists("*TearDown")
    try
      call TearDown()
    catch
      call add(v:errors, 'Caught exception in TearDown() after ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
    endtry
  endif

  if has('timers')
    call timer_stop(test_timeout_timer)
  endif

  " Clear any autocommands and put back the catch-all for SwapExists.
  au!
  au SwapExists * call HandleSwapExists()

  " Close any extra tab pages and windows and make the current one not modified.
  while tabpagenr('$') > 1
    let winid = win_getid()
    quit!
    if winid == win_getid()
      echoerr 'Could not quit window'
      break
    endif
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

  if a:test =~ '_terminal_'
    " Terminal tests sometimes hang, give extra information
    echoconsole 'Finished ' . a:test
  endif

  let message = 'Executed ' . a:test
  if has('reltime')
    let message ..= repeat(' ', 50 - len(message))
    let time = reltime(g:func_start)
    if reltimefloat(time) > 0.1
      let message = s:t_bold .. message
    endif
    let message ..= ' in ' .. reltimestr(time) .. ' seconds'
    if reltimefloat(time) > 0.1
      let message ..= s:t_normal
    endif
  endif
  call add(s:messages, message)
  let s:done += 1

  " close any split windows
  while winnr('$') > 1
    bwipe!
  endwhile

  " May be editing some buffer, wipe it out.  Then we may end up in another
  " buffer, continue until we end up in an empty no-name buffer without a swap
  " file.
  while bufname() != '' || execute('swapname') !~ 'No swap file'
    let bn = bufnr()

    noswapfile bwipe!

    if bn == bufnr()
      " avoid getting stuck in the same buffer
      break
    endif
  endwhile

  if !skipped
    " Check if the test has left any swap files behind.  Delete them before
    " running tests again, they might interfere.
    let swapfiles = s:GetSwapFileList()
    if len(swapfiles) > 0
      call add(s:messages, "Found swap files: " .. string(swapfiles))
      for name in swapfiles
        call delete(name)
      endfor
    endif
  endif
endfunc

function Delete_Xtest_Files()
  for file in glob('X*', v:false, v:true)
    if file ==? 'XfakeHOME'
      " Clean up files created by setup.vim
      call delete('XfakeHOME', 'rf')
      continue
    endif
    " call add(v:errors, file .. " exists when it shouldn't, trying to delete it!")
    call delete(file)
    if !empty(glob(file, v:false, v:true))
      " call add(v:errors, file .. " still exists after trying to delete it!")
      if has('unix')
        call system('rm -rf  ' .. file)
      endif
    endif
  endfor
endfunc

func AfterTheTest(func_name)
  if len(v:errors) > 0
    if match(s:may_fail_list, '^' .. a:func_name) >= 0
      let s:fail_expected += 1
      call add(s:errors_expected, 'Found errors in ' . g:testfunc . ':')
      call extend(s:errors_expected, v:errors)
    else
      let s:fail += 1
      call add(s:errors, 'Found errors in ' . g:testfunc . ':')
      call extend(s:errors, v:errors)
    endif
    let v:errors = []
  endif
endfunc

func EarlyExit(test)
  " It's OK for the test we use to test the quit detection.
  if a:test != 'Test_zz_quit_detected()'
    call add(v:errors, v:errmsg)
    call add(v:errors, 'Test caused Vim to exit: ' . a:test)
  endif

  call FinishTesting()
endfunc

" This function can be called by a test if it wants to abort testing.
func FinishTesting()
  call AfterTheTest('')
  call Delete_Xtest_Files()

  " Don't write viminfo on exit.
  set viminfo=

  if s:fail == 0 && s:fail_expected == 0
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

  if s:done == 0
    if s:filtered > 0
      if $TEST_FILTER != ''
        let message = "NO tests match $TEST_FILTER: '" .. $TEST_FILTER .. "'"
      else
        let message = "ALL tests match $TEST_SKIP_PAT: '" .. $TEST_SKIP_PAT .. "'"
      endif
    else
      let message = 'NO tests executed'
    endif
  else
    if s:filtered > 0
      call add(s:messages, "Filtered " .. s:filtered .. " tests with $TEST_FILTER and $TEST_SKIP_PAT")
    endif
    let message = 'Executed ' . s:done . (s:done > 1 ? ' tests' : ' test')
  endif
  if s:done > 0 && has('reltime')
    let message = s:t_bold .. message .. repeat(' ', 40 - len(message))
    let message ..= ' in ' .. reltimestr(reltime(s:run_start_time)) .. ' seconds'
    let message ..= s:t_normal
  endif
  echo message
  call add(s:messages, message)
  if s:fail > 0
    let message = s:fail . ' FAILED:'
    echo message
    call add(s:messages, message)
    call extend(s:messages, s:errors)
  endif
  if s:fail_expected > 0
    let message = s:fail_expected . ' FAILED (matching $TEST_MAY_FAIL):'
    echo message
    call add(s:messages, message)
    call extend(s:messages, s:errors_expected)
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
let s:fail_expected = 0
let s:errors = []
let s:errors_expected = []
let s:messages = []
let s:skipped = []
if expand('%') =~ 'test_vimscript.vim'
  " this test has intentional errors, don't use try/catch.
  source %
else
  try
    source %
  catch /^\cskipped/
    call add(s:messages, '    Skipped')
    call add(s:skipped, 'SKIPPED ' . expand('%') . ': ' . substitute(v:exception, '^\S*\s\+', '',  ''))
  catch
    let s:fail += 1
    call add(s:errors, 'Caught exception: ' . v:exception . ' @ ' . v:throwpoint)
  endtry
endif

" Delete the .res file, it may change behavior for completion
call delete(fnamemodify(g:testname, ':r') .. '.res')

" Locate Test_ functions and execute them.
redir @q
silent function /^Test_
redir END
let s:tests = split(substitute(@q, 'function \(\k*()\)', '\1', 'g'))

" If there is an extra argument filter the function names against it.
if argc() > 1
  let s:tests = filter(s:tests, 'v:val =~ argv(1)')
endif

" If the environment variable $TEST_FILTER is set then filter the function
" names against it.
let s:filtered = 0
if $TEST_FILTER != ''
  let s:filtered = len(s:tests)
  let s:tests = filter(s:tests, 'v:val =~ $TEST_FILTER')
  let s:filtered -= len(s:tests)
endif

let s:may_fail_list = []
if $TEST_MAY_FAIL != ''
  " Split the list at commas and add () to make it match g:testfunc.
  let s:may_fail_list = split($TEST_MAY_FAIL, ',')->map({i, v -> v .. '()'})
endif

" Execute the tests in alphabetical order.
for g:testfunc in sort(s:tests)
  if $TEST_SKIP_PAT != '' && g:testfunc =~ $TEST_SKIP_PAT
    call add(s:messages, g:testfunc .. ' matches $TEST_SKIP_PAT')
    let s:filtered += 1
    continue
  endif

  " Silence, please!
  set belloff=all
  let prev_error = ''
  let total_errors = []
  let g:run_nr = 1

  " A test can set g:test_is_flaky to retry running the test.
  let g:test_is_flaky = 0

  " A test can set g:max_run_nr to change the max retry count.
  let g:max_run_nr = 5
  if has('mac')
    let g:max_run_nr = 10
  endif

  " By default, give up if the same error occurs.  A test can set
  " g:giveup_same_error to 0 to not give up on the same error and keep trying.
  let g:giveup_same_error = 1

  let starttime = strftime("%H:%M:%S")
  call RunTheTest(g:testfunc)

  " Repeat a flaky test.  Give up when:
  " - $TEST_NO_RETRY is not empty
  " - it fails again with the same message
  " - it fails five times (with a different message)
  if len(v:errors) > 0
        \ && $TEST_NO_RETRY == ''
        \ && g:test_is_flaky
    while 1
      call add(s:messages, 'Found errors in ' .. g:testfunc .. ':')
      call extend(s:messages, v:errors)

      let endtime = strftime("%H:%M:%S")
      if has('reltime')
        let suffix = $' in{reltimestr(reltime(g:func_start))} seconds'
      else
        let suffix = ''
      endif
      call add(total_errors, $'Run {g:run_nr}, {starttime} - {endtime}{suffix}:')
      call extend(total_errors, v:errors)

      if g:run_nr >= g:max_run_nr || g:giveup_same_error && prev_error == v:errors[0]
        call add(total_errors, 'Flaky test failed too often, giving up')
        let v:errors = total_errors
        break
      endif

      call add(s:messages, 'Flaky test failed, running it again')

      " Flakiness is often caused by the system being very busy.  Sleep a
      " couple of seconds to have a higher chance of succeeding the second
      " time.
      let delay = g:run_nr * 2
      exe 'sleep' delay

      let prev_error = v:errors[0]
      let v:errors = []
      let g:run_nr += 1

      let starttime = strftime("%H:%M:%S")
      call RunTheTest(g:testfunc)

      if len(v:errors) == 0
        " Test passed on rerun.
        break
      endif
    endwhile
  endif

  call AfterTheTest(g:testfunc)
endfor

call FinishTesting()

" vim: shiftwidth=2 sts=2 expandtab
