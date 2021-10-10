" Tests for expand()

source shared.vim

let s:sfile = expand('<sfile>')
let s:slnum = str2nr(expand('<slnum>'))
let s:sflnum = str2nr(expand('<sflnum>'))

func s:expand_sfile()
  return expand('<sfile>')  
endfunc

func s:expand_slnum()
  return str2nr(expand('<slnum>'))  
endfunc

func s:expand_sflnum()
  return str2nr(expand('<sflnum>'))  
endfunc

" This test depends on the location in the test file, put it first.
func Test_expand_sflnum()
  call assert_equal(7, s:sflnum)
  call assert_equal(24, str2nr(expand('<sflnum>')))

  " Line-continuation
  call assert_equal(
        \ 27,
        \ str2nr(expand('<sflnum>')))

  " Call in script-local function
  call assert_equal(18, s:expand_sflnum())

  " Call in command
  command Flnum echo expand('<sflnum>')
  call assert_equal(36, str2nr(trim(execute('Flnum'))))
  delcommand Flnum
endfunc

func Test_expand()
  new
  call assert_equal("",  expand('%:S'))
  call assert_equal('3', '<slnum>'->expand())
  call assert_equal(['4'], expand('<slnum>', v:false, v:true))
  " Don't add any line above this, otherwise <slnum> will change.
  quit
endfunc

func Test_expand_sfile()
  call assert_match('test_expand_func\.vim$', s:sfile)
  call assert_match('^function .*\.\.Test_expand_sfile$', expand('<sfile>'))

  " Call in script-local function
  call assert_match('^function .*\.\.Test_expand_sfile\[5\]\.\.<SNR>\d\+_expand_sfile$', s:expand_sfile())

  " Call in command
  command Sfile echo expand('<sfile>')
  call assert_match('^function .*\.\.Test_expand_sfile$', trim(execute('Sfile')))
  delcommand Sfile
endfunc

func Test_expand_slnum()
  call assert_equal(6, s:slnum)
  call assert_equal(2, str2nr(expand('<slnum>')))

  " Line-continuation
  call assert_equal(
        \ 5,
        \ str2nr(expand('<slnum>')))

  " Call in script-local function
  call assert_equal(1, s:expand_slnum())

  " Call in command
  command Slnum echo expand('<slnum>')
  call assert_equal(14, str2nr(trim(execute('Slnum'))))
  delcommand Slnum
endfunc

func s:sid_test()
  return 'works'
endfunc

func Test_expand_SID()
  let sid = expand('<SID>')
  execute 'let g:sid_result = ' .. sid .. 'sid_test()'
  call assert_equal('works', g:sid_result)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
