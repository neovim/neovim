" Test for findfile()
"
func Test_findfile()
  new
  let cwd=getcwd()
  cd ..

  " Tests may be run from a shadow directory, so an extra cd needs to be done to
  " get above src/
  if fnamemodify(getcwd(), ':t') != 'src'
    cd ../.. 
  else 
    cd .. 
  endif
  set ssl

  call assert_equal('src/nvim/testdir/test_findfile.vim', findfile('test_findfile.vim','src/nvim/test*'))
  exe "cd" cwd
  cd ..
  call assert_equal('testdir/test_findfile.vim', findfile('test_findfile.vim','test*'))
  call assert_equal('testdir/test_findfile.vim', findfile('test_findfile.vim','testdir'))

  exe "cd" cwd
  q!
endfunc
