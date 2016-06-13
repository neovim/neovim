" This script is sourced while editing the .vim file with the tests.
" When the script is successful the .res file will be created.
" Errors are appended to the test.log file.
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

" Check that the screen size is at least 24 x 80 characters.
if &lines < 24 || &columns < 80 
  let error = 'Screen size too small! Tests require at least 24 lines with 80 characters'
  echoerr error
  split test.log
  $put =error
  w
  cquit
endif

" This also enables use of line continuation.
set viminfo+=nviminfo

" Avoid stopping at the "hit enter" prompt
set nomore

" Output all messages in English.
lang mess C

" Source the test script.  First grab the file name, in case the script
" navigates away.
let testname = expand('%')
let done = 0
let fail = 0
let errors = []
let messages = []
if expand('%') =~ 'test_viml.vim'
  " this test has intentional errors, don't use try/catch.
  source %
else
  try
    source %
  catch
    let fail += 1
    call add(errors, 'Caught exception: ' . v:exception . ' @ ' . v:throwpoint)
  endtry
endif

" Locate Test_ functions and execute them.
set nomore
redir @q
silent function /^Test_
redir END
let tests = split(substitute(@q, 'function \(\k*()\)', '\1', 'g'))

" Execute the tests in alphabetical order.
for test in sort(tests)
  echo 'Executing ' . test
  if exists("*SetUp")
    call SetUp()
  endif

  call add(messages, 'Executing ' . test)
  let done += 1
  try
    exe 'call ' . test
  catch
    let fail += 1
    call add(v:errors, 'Caught exception in ' . test . ': ' . v:exception . ' @ ' . v:throwpoint)
  endtry

  if len(v:errors) > 0
    let fail += 1
    call add(errors, 'Found errors in ' . test . ':')
    call extend(errors, v:errors)
    let v:errors = []
  endif

  if exists("*TearDown")
    call TearDown()
  endif
endfor

if fail == 0
  " Success, create the .res file so that make knows it's done.
  exe 'split ' . fnamemodify(testname, ':r') . '.res'
  write
endif

if len(errors) > 0
  " Append errors to test.log
  split test.log
  call append(line('$'), '')
  call append(line('$'), 'From ' . testname . ':')
  call append(line('$'), errors)
  write
endif

let message = 'Executed ' . done . (done > 1 ? ' tests': ' test')
echo message
call add(messages, message)
if fail > 0
  let message = fail . ' FAILED'
  echo message
  call add(messages, message)
endif

" Append messages to "messages"
split messages
call append(line('$'), '')
call append(line('$'), 'From ' . testname . ':')
call append(line('$'), messages)
write

qall!
