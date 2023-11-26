" Tests for using Ctrl-A/Ctrl-X using DBCS.
" neovim needs an iconv to handle cp932. Please do not remove the following
" conditions.
if !has('iconv')
  finish
endif
scriptencoding cp932

func SetUp()
  new
  set nrformats&
endfunc

func TearDown()
  bwipe!
endfunc

func Test_increment_dbcs_1()
  set nrformats+=alpha
  call setline(1, ["ŽR1"])
  exec "norm! 0\<C-A>"
  call assert_equal(["ŽR2"], getline(1, '$'))
  call assert_equal([0, 1, 4, 0], getpos('.'))

  call setline(1, ["‚`‚a‚b0xDE‚e"])
  exec "norm! 0\<C-X>"
  call assert_equal(["‚`‚a‚b0xDD‚e"], getline(1, '$'))
  call assert_equal([0, 1, 13, 0], getpos('.'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
