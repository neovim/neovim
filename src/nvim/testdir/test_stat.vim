" Tests for stat functions and checktime

func Test_existent_file()
  let fname='Xtest.tmp'

  let ts=localtime()
  sleep 1
  let fl=['Hello World!']
  call writefile(fl, fname)
  let tf=getftime(fname)
  sleep 1
  let te=localtime()

  call assert_true(ts <= tf && tf <= te)
  call assert_equal(strlen(fl[0] . "\n"), getfsize(fname))
  call assert_equal('file', getftype(fname))
  call assert_equal('rw-', getfperm(fname)[0:2])
endfunc

func Test_existent_directory()
  let dname='.'

  call assert_equal(0, getfsize(dname))
  call assert_equal('dir', getftype(dname))
  call assert_equal('rwx', getfperm(dname)[0:2])
endfunc

func Test_checktime()
  let fname='Xtest.tmp'

  let fl=['Hello World!']
  call writefile(fl, fname)
  set autoread
  exec 'e' fname
  sleep 2
  let fl=readfile(fname)
  let fl[0] .= ' - checktime'
  call writefile(fl, fname)
  checktime
  call assert_equal(fl[0], getline(1))
endfunc

func Test_nonexistent_file()
  let fname='Xtest.tmp'

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
    let res=system('dir C:\Users /a')
    if match(res, '\C<SYMLINKD> *All Users') >= 0
      " Get the filetype of the symlink.
      call assert_equal('dir', getftype('C:\Users\All Users'))
    endif
  endif
endfunc
