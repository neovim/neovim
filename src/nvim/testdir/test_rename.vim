" Test rename()

func Test_rename_file_to_file()
  call writefile(['foo'], 'Xrename1')

  call assert_equal(0, rename('Xrename1', 'Xrename2'))

  call assert_equal('', glob('Xrename1'))
  call assert_equal(['foo'], readfile('Xrename2'))

  " When the destination file already exists, it should be overwritten.
  call writefile(['foo'], 'Xrename1')
  call writefile(['bar'], 'Xrename2')

  call assert_equal(0, rename('Xrename1', 'Xrename2'))
  call assert_equal('', glob('Xrename1'))
  call assert_equal(['foo'], readfile('Xrename2'))

  call delete('Xrename2')
endfunc

func Test_rename_file_ignore_case()
  " With 'fileignorecase', renaming file will go through a temp file
  " when the source and destination file only differ by case.
  set fileignorecase
  call writefile(['foo'], 'Xrename')

  call assert_equal(0, rename('Xrename', 'XRENAME'))

  call assert_equal(['foo'], readfile('XRENAME'))

  set fileignorecase&
  call delete('XRENAME')
endfunc

func Test_rename_same_file()
  call writefile(['foo'], 'Xrename')

  " When the source and destination are the same file, nothing
  " should be done. The source file should not be deleted.
  call assert_equal(0, rename('Xrename', 'Xrename'))
  call assert_equal(['foo'], readfile('Xrename'))

  call assert_equal(0, rename('./Xrename', 'Xrename'))
  call assert_equal(['foo'], readfile('Xrename'))

  call delete('Xrename')
endfunc

func Test_rename_dir_to_dir()
  call mkdir('Xrenamedir1')
  call writefile(['foo'], 'Xrenamedir1/Xrenamefile')

  call assert_equal(0, rename('Xrenamedir1', 'Xrenamedir2'))

  call assert_equal('', glob('Xrenamedir1'))
  call assert_equal(['foo'], readfile('Xrenamedir2/Xrenamefile'))

  call delete('Xrenamedir2/Xrenamefile')
  call delete('Xrenamedir2', 'd')
endfunc

func Test_rename_same_dir()
  call mkdir('Xrenamedir')
  call writefile(['foo'], 'Xrenamedir/Xrenamefile')

  call assert_equal(0, rename('Xrenamedir', 'Xrenamedir'))

  call assert_equal(['foo'], readfile('Xrenamedir/Xrenamefile'))

  call delete('Xrenamedir/Xrenamefile')
  call delete('Xrenamedir', 'd')
endfunc

func Test_rename_copy()
  " Check that when original file can't be deleted, rename()
  " still succeeds but copies the file.
  call mkdir('Xrenamedir')
  call writefile(['foo'], 'Xrenamedir/Xrenamefile')
  call setfperm('Xrenamedir', 'r-xr-xr-x')

  call assert_equal(0, rename('Xrenamedir/Xrenamefile', 'Xrenamefile'))

  if !has('win32')
    " On Windows, the source file is removed despite
    " its directory being made not writable.
    call assert_equal(['foo'], readfile('Xrenamedir/Xrenamefile'))
  endif
  call assert_equal(['foo'], readfile('Xrenamefile'))

  call setfperm('Xrenamedir', 'rwxrwxrwx')
  call delete('Xrenamedir/Xrenamefile')
  call delete('Xrenamedir', 'd')
  call delete('Xrenamefile')
endfunc

func Test_rename_fails()
  call writefile(['foo'], 'Xrenamefile')

  " Can't rename into a non-existing directory.
  call assert_notequal(0, rename('Xrenamefile', 'Xdoesnotexist/Xrenamefile'))

  " Can't rename a non-existing file.
  call assert_notequal(0, rename('Xdoesnotexist', 'Xrenamefile2'))
  call assert_equal('', glob('Xrenamefile2'))

  " When rename() fails, the destination file should not be deleted.
  call assert_notequal(0, rename('Xdoesnotexist', 'Xrenamefile'))
  call assert_equal(['foo'], readfile('Xrenamefile'))

  " Can't rename to en empty file name.
  call assert_notequal(0, rename('Xrenamefile', ''))

  call assert_fails('call rename("Xrenamefile", [])', 'E730')
  call assert_fails('call rename(0z, "Xrenamefile")', 'E976')

  call delete('Xrenamefile')
endfunc
