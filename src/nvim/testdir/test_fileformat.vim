
" Test behavior of fileformat after bwipeout of last buffer
func Test_fileformat_after_bw()
  bwipeout
  set fileformat&
  if &fileformat == 'dos'
    let test_fileformats = 'unix'
  elseif &fileformat == 'unix'
    let test_fileformats = 'mac'
  else  " must be mac
    let test_fileformats = 'dos'
  endif
  exec 'set fileformats='.test_fileformats
  bwipeout!
  call assert_equal(test_fileformats, &fileformat)
  set fileformats&
endfunc

func Test_fileformat_autocommand()
  let filecnt = ["", "foobar\<CR>", "eins\<CR>", "\<CR>", "zwei\<CR>", "drei", "vier", "fünf", ""]
  let ffs = &ffs
  call writefile(filecnt, 'Xfile', 'b')
  au BufReadPre Xfile set ffs=dos ff=dos
  new Xfile
  call assert_equal('dos', &l:ff)
  call assert_equal('dos', &ffs)

  " cleanup
  call delete('Xfile')
  let &ffs = ffs
  au! BufReadPre Xfile
  bw!
endfunc

" Convert the contents of a file into a literal string
func s:file2str(fname)
  let b = readfile(a:fname, 'B')
  let s = ''
  for c in b
    let s .= nr2char(c)
  endfor
  return s
endfunc

" Concatenate the contents of files 'f1' and 'f2' and create 'destfile'
func s:concat_files(f1, f2, destfile)
  let b1 = readfile(a:f1, 'B')
  let b2 = readfile(a:f2, 'B')
  let b3 = b1 + b2
  call writefile(b3, a:destfile, 'B')
endfun

" Test for a lot of variations of the 'fileformats' option
func Test_fileformats()
  " create three test files, one in each format
  call writefile(['unix', 'unix'], 'XXUnix')
  call writefile(["dos\r", "dos\r"], 'XXDos')
  call writefile(["mac\rmac\r"], 'XXMac', 'b')
  " create a file with no End Of Line
  call writefile(["noeol"], 'XXEol', 'b')
  " create mixed format files
  call s:concat_files('XXUnix', 'XXDos', 'XXUxDs')
  call s:concat_files('XXUnix', 'XXMac', 'XXUxMac')
  call s:concat_files('XXDos', 'XXMac', 'XXDosMac')
  call s:concat_files('XXMac', 'XXEol', 'XXMacEol')
  call s:concat_files('XXUxDs', 'XXMac', 'XXUxDsMc')

  new

  " Test 1: try reading and writing with 'fileformats' empty
  set fileformats=

  " try with 'fileformat' set to 'unix'
  set fileformat=unix
  e! XXUnix
  w! Xtest
  call assert_equal("unix\nunix\n", s:file2str('Xtest'))
  e! XXDos
  w! Xtest
  call assert_equal("dos\r\ndos\r\n", s:file2str('Xtest'))
  e! XXMac
  w! Xtest
  call assert_equal("mac\rmac\r\n", s:file2str('Xtest'))
  bwipe XXUnix XXDos XXMac

  " try with 'fileformat' set to 'dos'
  set fileformat=dos
  e! XXUnix
  w! Xtest
  call assert_equal("unix\r\nunix\r\n", s:file2str('Xtest'))
  e! XXDos
  w! Xtest
  call assert_equal("dos\r\ndos\r\n", s:file2str('Xtest'))
  e! XXMac
  w! Xtest
  call assert_equal("mac\rmac\r\r\n", s:file2str('Xtest'))
  bwipe XXUnix XXDos XXMac

  " try with 'fileformat' set to 'mac'
  set fileformat=mac
  e! XXUnix
  w! Xtest
  call assert_equal("unix\nunix\n\r", s:file2str('Xtest'))
  e! XXDos
  w! Xtest
  call assert_equal("dos\r\ndos\r\n\r", s:file2str('Xtest'))
  e! XXMac
  w! Xtest
  call assert_equal("mac\rmac\r", s:file2str('Xtest'))
  bwipe XXUnix XXDos XXMac

  " Test 2: try reading and writing with 'fileformats' set to one format

  " try with 'fileformats' set to 'unix'
  set fileformats=unix
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r\n",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  " try with 'fileformats' set to 'dos'
  set fileformats=dos
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\r\nunix\r\ndos\r\ndos\r\nmac\rmac\r\r\n",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  " try with 'fileformats' set to 'mac'
  set fileformats=mac
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  " Test 3: try reading and writing with 'fileformats' set to two formats

  " try with 'fileformats' set to 'unix,dos'
  set fileformats=unix,dos
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r\n",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  e! XXUxMac
  w! Xtest
  call assert_equal("unix\nunix\nmac\rmac\r\n", s:file2str('Xtest'))
  bwipe XXUxMac

  e! XXDosMac
  w! Xtest
  call assert_equal("dos\r\ndos\r\nmac\rmac\r\r\n", s:file2str('Xtest'))
  bwipe XXDosMac

  " try with 'fileformats' set to 'unix,mac'
  set fileformats=unix,mac
  e! XXUxDs
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\n", s:file2str('Xtest'))
  bwipe XXUxDs

  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r\n",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  e! XXDosMac
  w! Xtest
  call assert_equal("dos\r\ndos\r\nmac\rmac\r", s:file2str('Xtest'))
  bwipe XXDosMac

  e! XXEol
  exe "normal ggO\<C-R>=&ffs\<CR>:\<C-R>=&ff\<CR>"
  w! Xtest
  call assert_equal("unix,mac:unix\nnoeol\n", s:file2str('Xtest'))
  bwipe! XXEol

  " try with 'fileformats' set to 'dos,mac'
  set fileformats=dos,mac
  e! XXUxDs
  w! Xtest
  call assert_equal("unix\r\nunix\r\ndos\r\ndos\r\n", s:file2str('Xtest'))
  bwipe XXUxDs

  e! XXUxMac
  exe "normal ggO\<C-R>=&ffs\<CR>:\<C-R>=&ff\<CR>"
  w! Xtest
  call assert_equal("dos,mac:dos\r\nunix\r\nunix\r\nmac\rmac\r\r\n",
	      \ s:file2str('Xtest'))
  bwipe! XXUxMac

  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\r\nunix\r\ndos\r\ndos\r\nmac\rmac\r\r\n",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  e! XXMacEol
  exe "normal ggO\<C-R>=&ffs\<CR>:\<C-R>=&ff\<CR>"
  w! Xtest
  call assert_equal("dos,mac:mac\rmac\rmac\rnoeol\r", s:file2str('Xtest'))
  bwipe! XXMacEol

  " Test 4: try reading and writing with 'fileformats' set to three formats
  set fileformats=unix,dos,mac
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r\n",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  e! XXEol
  exe "normal ggO\<C-R>=&ffs\<CR>:\<C-R>=&ff\<CR>"
  w! Xtest
  call assert_equal("unix,dos,mac:unix\nnoeol\n", s:file2str('Xtest'))
  bwipe! XXEol

  set fileformats=mac,dos,unix
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r\n",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  e! XXEol
  exe "normal ggO\<C-R>=&ffs\<CR>:\<C-R>=&ff\<CR>"
  w! Xtest
  call assert_equal("mac,dos,unix:mac\rnoeol\r", s:file2str('Xtest'))
  bwipe! XXEol

  " Test 5: try with 'binary' set
  set fileformats=mac,unix,dos
  set binary
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  set fileformats=mac
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  set fileformats=dos
  e! XXUxDsMc
  w! Xtest
  call assert_equal("unix\nunix\ndos\r\ndos\r\nmac\rmac\r",
	      \ s:file2str('Xtest'))
  bwipe XXUxDsMc

  e! XXUnix
  w! Xtest
  call assert_equal("unix\nunix\n", s:file2str('Xtest'))
  bwipe! XXUnix

  set nobinary ff& ffs&

  " cleanup
  only
  %bwipe!
  call delete('XXUnix')
  call delete('XXDos')
  call delete('XXMac')
  call delete('XXEol')
  call delete('XXUxDs')
  call delete('XXUxMac')
  call delete('XXDosMac')
  call delete('XXMacEol')
  call delete('XXUxDsMc')
  call delete('Xtest')
endfunc
