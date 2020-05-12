" Tests for stat functions and checktime

func CheckFileTime(doSleep)
  let fnames = ['Xtest1.tmp', 'Xtest2.tmp', 'Xtest3.tmp']
  let times = []
  let result = 0

  " Use three files istead of localtim(), with a network filesystem the file
  " times may differ at bit
  let fl = ['Hello World!']
  for fname in fnames
    call writefile(fl, fname)
    call add(times, getftime(fname))
    if a:doSleep
      sleep 1
    endif
  endfor

  let time_correct = (times[0] <= times[1] && times[1] <= times[2])
  if a:doSleep || time_correct
    call assert_true(time_correct, printf('Expected %s <= %s <= %s', times[0], times[1], times[2]))
    call assert_equal(strlen(fl[0] . "\n"), getfsize(fnames[0]))
    call assert_equal('file', getftype(fnames[0]))
    call assert_equal('rw-', getfperm(fnames[0])[0:2])
    let result = 1
  endif

  for fname in fnames
    call delete(fname)
  endfor
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
  call assert_equal(has('win32') ? 'rw-' : 'rwx', getfperm(dname)[0:2])
endfunc

func SleepForTimestamp()
  " FAT has a granularity of 2 seconds, otherwise it's usually 1 second
  if has('win32')
    sleep 2
  else
    sleep 2
  endif
endfunc

func Test_checktime()
  let fname = 'Xtest.tmp'

  let fl = ['Hello World!']
  call writefile(fl, fname)
  set autoread
  exec 'e' fname
  call SleepForTimestamp()
  let fl = readfile(fname)
  let fl[0] .= ' - checktime'
  call writefile(fl, fname)
  checktime
  call assert_equal(fl[0], getline(1))

  call delete(fname)
endfunc

func Test_autoread_file_deleted()
  new Xautoread
  set autoread
  call setline(1, 'original')
  w!

  call SleepForTimestamp()
  if has('win32')
    silent !echo changed > Xautoread
  else
    silent !echo 'changed' > Xautoread
  endif
  checktime
  call assert_equal('changed', trim(getline(1)))

  call SleepForTimestamp()
  messages clear
  if has('win32')
    silent !del Xautoread
  else
    silent !rm Xautoread
  endif
  checktime
  call assert_match('E211:', execute('messages'))
  call assert_equal('changed', trim(getline(1)))

  call SleepForTimestamp()
  if has('win32')
    silent !echo recreated > Xautoread
  else
    silent !echo 'recreated' > Xautoread
  endif
  checktime
  call assert_equal('recreated', trim(getline(1)))

  call delete('Xautoread')
  bwipe!
endfunc


func Test_nonexistent_file()
  let fname = 'Xtest.tmp'

  call delete(fname)
  call assert_equal(-1, getftime(fname))
  call assert_equal(-1, getfsize(fname))
  call assert_equal('', getftype(fname))
  call assert_equal('', getfperm(fname))
endfunc

func Test_getftype()
  call assert_equal('file', getftype(v:progpath))
  call assert_equal('dir',  getftype('.'))

  if !has('unix')
    return
  endif

  silent !ln -s Xfile Xlink
  call assert_equal('link', getftype('Xlink'))
  call delete('Xlink')

  if executable('mkfifo')
    silent !mkfifo Xfifo
    call assert_equal('fifo', getftype('Xfifo'))
    call delete('Xfifo')
  endif

  for cdevfile in systemlist('find /dev -type c -maxdepth 2 2>/dev/null')
    " On Mac /def/fd/2 is found but the type is "fifo"
    if cdevfile !~ '/dev/fd/'
      let type = getftype(cdevfile)
      " ignore empty result, can happen if the file disappeared
      if type != ''
	call assert_equal('cdev', type, 'for ' .. cdevfile)
      endif
    endif
  endfor

  for bdevfile in systemlist('find /dev -type b -maxdepth 2 2>/dev/null')
    let type = getftype(bdevfile)
    " ignore empty result, can happen if the file disappeared
    if type != ''
      call assert_equal('bdev', type, 'for ' .. bdevfile)
    endif
  endfor

  " The /run/ directory typically contains socket files.
  " If it does not, test won't fail but will not test socket files.
  for socketfile in systemlist('find /run -type s -maxdepth 2 2>/dev/null')
    let type = getftype(socketfile)
    " ignore empty result, can happen if the file disappeared
    if type != ''
      call assert_equal('socket', type, 'for ' .. socketfile)
    endif
  endfor

  " TODO: file type 'other' is not tested. How can we test it?
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
