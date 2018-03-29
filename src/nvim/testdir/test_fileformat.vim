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
