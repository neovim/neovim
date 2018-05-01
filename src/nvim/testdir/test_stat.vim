" Tests for stat functions and checktime

func CheckFileTime(doSleep)
  let fname = 'Xtest.tmp'
  let result = 0

  let ts = localtime()
  if a:doSleep
    sleep 1
  endif
  let fl = ['Hello World!']
  call writefile(fl, fname)
  let tf = getftime(fname)
  if a:doSleep
    sleep 1
  endif
  let te = localtime()

  let time_correct = (ts <= tf && tf <= te)
  if a:doSleep || time_correct
    call assert_true(time_correct)
    call assert_equal(strlen(fl[0] . "\n"), getfsize(fname))
    call assert_equal('file', getftype(fname))
    call assert_equal('rw-', getfperm(fname)[0:2])
    let result = 1
  endif

  call delete(fname)
  return result
endfunc

func Test_existent_file()
  " On some systems the file timestamp is rounded to a multiple of 2 seconds.
  " We need to sleep to handle that, but that makes the test slow.  First try
  " without the sleep, and if it fails try again with the sleep.
  if CheckFileTime(0) == 0
    call CheckFileTime(1)
  endif
endfunc

func Test_existent_directory()
  let dname = '.'

  call assert_equal(0, getfsize(dname))
  call assert_equal('dir', getftype(dname))
  call assert_equal('rwx', getfperm(dname)[0:2])
endfunc

func Test_checktime()
  let fname = 'Xtest.tmp'

  let fl = ['Hello World!']
  call writefile(fl, fname)
  set autoread
  exec 'e' fname
  " FAT has a granularity of 2 seconds, otherwise it's usually 1 second
  if has('win32')
    sleep 2
  else
    sleep 2
  endif
  let fl = readfile(fname)
  let fl[0] .= ' - checktime'
  call writefile(fl, fname)
  checktime
  call assert_equal(fl[0], getline(1))

  call delete(fname)
endfunc

func Test_nonexistent_file()
  let fname = 'Xtest.tmp'

  call delete(fname)
  call assert_equal(-1, getftime(fname))
  call assert_equal(-1, getfsize(fname))
  call assert_equal('', getftype(fname))
  call assert_equal('', getfperm(fname))
endfunc

func Test_win32_symlink_dir()
  " On Windows, non-admin users cannot create symlinks.
  " So we use an existing symlink for this test.
  if has('win32')
    " Check if 'C:\Users\All Users' is a symlink to a directory.
    let res = system('dir C:\Users /a')
    if match(res, '\C<SYMLINKD> *All Users') >= 0
      " Get the filetype of the symlink.
      call assert_equal('link', getftype('C:\Users\All Users'))
    endif
  endif
endfunc
