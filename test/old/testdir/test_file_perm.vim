" Test getting and setting file permissions.

func Test_file_perm()
  call assert_equal('', getfperm('XtestPerm'))
  call assert_equal(0, 'XtestPerm'->setfperm('r--------'))

  call writefile(['one'], 'XtestPerm', 'D')
  call assert_true(len('XtestPerm'->getfperm()) == 9)

  call assert_equal(1, setfperm('XtestPerm', 'rwx------'))
  if has('win32')
    call assert_equal('rw-rw-rw-', getfperm('XtestPerm'))
  else
    call assert_equal('rwx------', getfperm('XtestPerm'))
  endif

  call assert_equal(1, setfperm('XtestPerm', 'r--r--r--'))
  call assert_equal('r--r--r--', getfperm('XtestPerm'))

  call assert_fails("call setfperm('XtestPerm', '---')", 'E475: Invalid argument: ---')

  call assert_equal(1, setfperm('XtestPerm', 'rwx------'))

  call assert_fails("call setfperm(['Xpermfile'], 'rw-rw-rw-')", 'E730:')
  call assert_fails("call setfperm('Xpermfile', [])", 'E730:')
  call assert_fails("call setfperm('Xpermfile', 'rwxrwxrwxrw')", 'E475:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
