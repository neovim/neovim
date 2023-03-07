" Test getting and setting file permissions.

func Test_file_perm()
  call assert_equal('', getfperm('Xtest'))
  call assert_equal(0, 'Xtest'->setfperm('r--------'))

  call writefile(['one'], 'Xtest')
  call assert_true(len('Xtest'->getfperm()) == 9)

  call assert_equal(1, setfperm('Xtest', 'rwx------'))
  if has('win32')
    call assert_equal('rw-rw-rw-', getfperm('Xtest'))
  else
    call assert_equal('rwx------', getfperm('Xtest'))
  endif

  call assert_equal(1, setfperm('Xtest', 'r--r--r--'))
  call assert_equal('r--r--r--', getfperm('Xtest'))

  call assert_fails("setfperm('Xtest', '---')")

  call assert_equal(1, setfperm('Xtest', 'rwx------'))
  call delete('Xtest')

  call assert_fails("call setfperm(['Xfile'], 'rw-rw-rw-')", 'E730:')
  call assert_fails("call setfperm('Xfile', [])", 'E730:')
  call assert_fails("call setfperm('Xfile', 'rwxrwxrwxrw')", 'E475:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
