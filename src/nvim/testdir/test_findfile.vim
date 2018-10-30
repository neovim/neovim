" Test for findfile()
"
func Test_findfile()
  new
  let cwd=getcwd()
  cd $ROOT
  set shellslash

  call assert_equal('src/nvim/testdir/test_findfile.vim', findfile('test_findfile.vim','src/nvim/test*'))
  cd $ROOT/src/nvim
  call assert_equal('testdir/test_findfile.vim', findfile('test_findfile.vim','test*'))
  call assert_equal('testdir/test_findfile.vim', findfile('test_findfile.vim','testdir'))

  execute 'cd' fnameescape(cwd)
  q!
endfunc
