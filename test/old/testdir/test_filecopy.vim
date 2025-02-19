" Test filecopy()

source check.vim
source shared.vim

func Test_copy_file_to_file()
  call writefile(['foo'], 'Xcopy1')

  call assert_true(filecopy('Xcopy1', 'Xcopy2'))

  call assert_equal(['foo'], readfile('Xcopy2'))

  " When the destination file already exists, it should not be overwritten.
  call writefile(['foo'], 'Xcopy1')
  call writefile(['bar'], 'Xcopy2', 'D')
  call assert_false(filecopy('Xcopy1', 'Xcopy2'))
  call assert_equal(['bar'], readfile('Xcopy2'))

  call delete('Xcopy2')
  call delete('Xcopy1')
endfunc

func Test_copy_symbolic_link()
  CheckUnix

  call writefile(['text'], 'Xtestfile', 'D')
  silent !ln -s -f Xtestfile Xtestlink

  call assert_true(filecopy('Xtestlink', 'Xtestlink2'))
  call assert_equal('link', getftype('Xtestlink2'))
  call assert_equal(['text'], readfile('Xtestlink2'))

  " When the destination file already exists, it should not be overwritten.
  call assert_false(filecopy('Xtestlink', 'Xtestlink2'))

  call delete('Xtestlink2')
  call delete('Xtestlink')
  call delete('Xtestfile')
endfunc

func Test_copy_dir_to_dir()
  call mkdir('Xcopydir1')
  call writefile(['foo'], 'Xcopydir1/Xfilecopy')
  call mkdir('Xcopydir2')

  " Directory copy is not supported
  call assert_false(filecopy('Xcopydir1', 'Xcopydir2'))

  call delete('Xcopydir2', 'rf')
  call delete('Xcopydir1', 'rf')
endfunc

func Test_copy_fails()
  CheckUnix

  call writefile(['foo'], 'Xfilecopy', 'D')

  " Can't copy into a non-existing directory.
  call assert_false(filecopy('Xfilecopy', 'Xdoesnotexist/Xfilecopy'))

  " Can't copy a non-existing file.
  call assert_false(filecopy('Xdoesnotexist', 'Xfilecopy2'))
  call assert_equal('', glob('Xfilecopy2'))

  " Can't copy to en empty file name.
  call assert_false(filecopy('Xfilecopy', ''))

  call assert_fails('call filecopy("Xfilecopy", [])', 'E1174:')
  call assert_fails('call filecopy(0z, "Xfilecopy")', 'E1174:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
