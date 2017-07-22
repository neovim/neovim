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
