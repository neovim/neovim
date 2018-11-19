" Tests for the swap feature

" Tests for 'directory' option.
func Test_swap_directory()
  if !has("unix")
    return
  endif
  let content = ['start of testfile',
	      \ 'line 2 Abcdefghij',
	      \ 'line 3 Abcdefghij',
	      \ 'end of testfile']
  call writefile(content, 'Xtest1')

  "  '.', swap file in the same directory as file
  set dir=.,~

  " Verify that the swap file doesn't exist in the current directory
  call assert_equal([], glob(".Xtest1*.swp", 1, 1, 1))
  edit Xtest1
  let swfname = split(execute("swapname"))[0]
  call assert_equal([swfname], glob(swfname, 1, 1, 1))

  " './dir', swap file in a directory relative to the file
  set dir=./Xtest2,.,~

  call mkdir("Xtest2")
  edit Xtest1
  call assert_equal([], glob(swfname, 1, 1, 1))
  let swfname = "Xtest2/Xtest1.swp"
  call assert_equal(swfname, split(execute("swapname"))[0])
  call assert_equal([swfname], glob("Xtest2/*", 1, 1, 1))

  " 'dir', swap file in directory relative to the current dir
  set dir=Xtest.je,~

  call mkdir("Xtest.je")
  call writefile(content, 'Xtest2/Xtest3')
  edit Xtest2/Xtest3
  call assert_equal(["Xtest2/Xtest3"], glob("Xtest2/*", 1, 1, 1))
  let swfname = "Xtest.je/Xtest3.swp"
  call assert_equal(swfname, split(execute("swapname"))[0])
  call assert_equal([swfname], glob("Xtest.je/*", 1, 1, 1))

  set dir&
  call delete("Xtest1")
  call delete("Xtest2", "rf")
  call delete("Xtest.je", "rf")
endfunc

func Test_missing_dir()
  call mkdir('Xswapdir')
  exe 'set directory=' . getcwd() . '/Xswapdir'

  call assert_equal('', glob('foo'))
  call assert_equal('', glob('bar'))
  edit foo/x.txt
  " This should not give a warning for an existing swap file.
  split bar/x.txt
  only

  set directory&
  call delete('Xswapdir', 'rf')
endfunc
