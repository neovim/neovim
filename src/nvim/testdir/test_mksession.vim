" Tests for sessions

" Verify that arglist is stored correctly to the session file.
func Test_mksession_arglist()
  argdel *
  next file1 file2 file3 file4
  mksession! Xtest_mks.out
  source Xtest_mks.out
  call assert_equal(['file1', 'file2', 'file3', 'file4'], argv())

  call delete('Xtest_mks.out')
  argdel *
endfunc

" vim: shiftwidth=2 sts=2 expandtab
