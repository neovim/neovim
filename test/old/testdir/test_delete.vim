" Test for delete().

source check.vim
source term_util.vim
source screendump.vim

func Test_file_delete()
  split Xfdelfile
  call setline(1, ['a', 'b'])
  wq
  call assert_equal(['a', 'b'], readfile('Xfdelfile'))
  call assert_equal(0, delete('Xfdelfile'))
  call assert_fails('call readfile("Xfdelfile")', 'E484:')
  call assert_equal(-1, delete('Xfdelfile'))
  bwipe Xfdelfile
endfunc

func Test_dir_delete()
  call mkdir('Xdirdel')
  call assert_true(isdirectory('Xdirdel'))
  call assert_equal(0, delete('Xdirdel', 'd'))
  call assert_false(isdirectory('Xdirdel'))
  call assert_equal(-1, delete('Xdirdel', 'd'))
endfunc

func Test_recursive_delete()
  call mkdir('Xrecdel')
  call mkdir('Xrecdel/subdir')
  call mkdir('Xrecdel/empty')
  split Xrecdel/Xfile
  call setline(1, ['a', 'b'])
  w
  w Xrecdel/subdir/Xfile
  close
  call assert_true(isdirectory('Xrecdel'))
  call assert_equal(['a', 'b'], readfile('Xrecdel/Xfile'))
  call assert_true(isdirectory('Xrecdel/subdir'))
  call assert_equal(['a', 'b'], readfile('Xrecdel/subdir/Xfile'))
  call assert_true('Xrecdel/empty'->isdirectory())
  call assert_equal(0, delete('Xrecdel', 'rf'))
  call assert_false(isdirectory('Xrecdel'))
  call assert_equal(-1, delete('Xrecdel', 'd'))
  bwipe Xrecdel/Xfile
  bwipe Xrecdel/subdir/Xfile
endfunc

func Test_symlink_delete()
  CheckUnix
  split Xslfile
  call setline(1, ['a', 'b'])
  wq
  silent !ln -s Xslfile Xdellink
  " Delete the link, not the file
  call assert_equal(0, delete('Xdellink'))
  call assert_equal(-1, delete('Xdellink'))
  call assert_equal(0, delete('Xslfile'))
  bwipe Xslfile
endfunc

func Test_symlink_dir_delete()
  CheckUnix
  call mkdir('Xsymdir')
  silent !ln -s Xsymdir Xdirlink
  call assert_true(isdirectory('Xsymdir'))
  call assert_true(isdirectory('Xdirlink'))
  " Delete the link, not the directory
  call assert_equal(0, delete('Xdirlink'))
  call assert_equal(-1, delete('Xdirlink'))
  call assert_equal(0, delete('Xsymdir', 'd'))
endfunc

func Test_symlink_recursive_delete()
  CheckUnix
  call mkdir('Xrecdir3')
  call mkdir('Xrecdir3/subdir')
  call mkdir('Xrecdir4')
  split Xrecdir3/Xfile
  call setline(1, ['a', 'b'])
  w
  w Xrecdir3/subdir/Xfile
  w Xrecdir4/Xfile
  close
  silent !ln -s ../Xrecdir4 Xrecdir3/Xreclink

  call assert_true(isdirectory('Xrecdir3'))
  call assert_equal(['a', 'b'], readfile('Xrecdir3/Xfile'))
  call assert_true(isdirectory('Xrecdir3/subdir'))
  call assert_equal(['a', 'b'], readfile('Xrecdir3/subdir/Xfile'))
  call assert_true(isdirectory('Xrecdir4'))
  call assert_true(isdirectory('Xrecdir3/Xreclink'))
  call assert_equal(['a', 'b'], readfile('Xrecdir4/Xfile'))

  call assert_equal(0, delete('Xrecdir3', 'rf'))
  call assert_false(isdirectory('Xrecdir3'))
  call assert_equal(-1, delete('Xrecdir3', 'd'))
  " symlink is deleted, not the directory it points to
  call assert_true(isdirectory('Xrecdir4'))
  call assert_equal(['a', 'b'], readfile('Xrecdir4/Xfile'))
  call assert_equal(0, delete('Xrecdir4/Xfile'))
  call assert_equal(0, delete('Xrecdir4', 'd'))

  bwipe Xrecdir3/Xfile
  bwipe Xrecdir3/subdir/Xfile
  bwipe Xrecdir4/Xfile
endfunc

func Test_delete_errors()
  call assert_fails('call delete('''')', 'E474:')
  call assert_fails('call delete(''foo'', 0)', 'E15:')
endfunc

" This should no longer trigger ml_get errors
func Test_delete_ml_get_errors()
  CheckRunVimInTerminal
  let lines =<< trim END
    set noshowcmd noruler scrolloff=0
    source samples/matchparen.vim
  END
  call writefile(lines, 'XDelete_ml_get_error', 'D')
  let buf = RunVimInTerminal('-S XDelete_ml_get_error samples/box.txt', #{rows: 10, wait_for_ruler: 0})
  call TermWait(buf)
  call term_sendkeys(buf, "249GV\<C-End>d")
  call TermWait(buf)
  " The following used to trigger ml_get errors
  call term_sendkeys(buf, "\<PageUp>")
  call TermWait(buf)
  call term_sendkeys(buf, ":mess\<cr>")
  call VerifyScreenDump(buf, 'Test_delete_ml_get_errors_1', {})
  call term_sendkeys(buf, ":q!\<cr>")
  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
