" Test :setfiletype

func Test_detection()
  filetype on
  augroup filetypedetect
    au BufNewFile,BufRead *	call assert_equal(1, did_filetype())
  augroup END
  new something.vim
  call assert_equal('vim', &filetype)

  bwipe!
  filetype off
endfunc

func Test_conf_type()
  filetype on
  call writefile(['# some comment', 'must be conf'], 'Xfile')
  augroup filetypedetect
    au BufNewFile,BufRead *	call assert_equal(0, did_filetype())
  augroup END
  split Xfile
  call assert_equal('conf', &filetype)

  bwipe!
  call delete('Xfile')
  filetype off
endfunc

func Test_other_type()
  filetype on
  augroup filetypedetect
    au BufNewFile,BufRead *	call assert_equal(0, did_filetype())
    au BufNewFile,BufRead Xfile	setf testfile
    au BufNewFile,BufRead *	call assert_equal(1, did_filetype())
  augroup END
  call writefile(['# some comment', 'must be conf'], 'Xfile')
  split Xfile
  call assert_equal('testfile', &filetype)

  bwipe!
  call delete('Xfile')
  filetype off
endfunc
