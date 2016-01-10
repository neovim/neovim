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

" Without the +eval feature we can't run these tests, bail out.
so small.vim

" Check that the screen size is at least 24 x 80 characters.
if &lines < 24 || &columns < 80 
  let error = 'Screen size too small! Tests require at least 24 lines with 80 characters'
  echoerr error
  split test.log
  $put =error
  w
  cquit
endif

" Source the test script.  First grab the file name, in case the script
" navigates away.
let testname = expand('%')
let done = 0
let fail = 0
let errors = []
try
  source %
catch
  let fail += 1
  call add(errors, 'Caught exception: ' . v:exception . ' @ ' . v:throwpoint)
endtry

" Locate Test_ functions and execute them.
redir @q
function /^Test_
redir END
let tests = split(substitute(@q, 'function \(\k*()\)', '\1', 'g'))

for test in tests
  if exists("*SetUp")
    call SetUp()
  endif

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

echo 'Executed ' . done . (done > 1 ? ' tests': ' test')
if fail > 0
  echo fail . ' FAILED'
endif

qall!
