" Test spell checking
" TODO: move test58 tests here

if !has('spell')
  finish
endif

func Test_wrap_search()
  new
  call setline(1, ['The', '', 'A plong line with two zpelling mistakes', '', 'End'])
  set spell wrapscan
  normal ]s
  call assert_equal('plong', expand('<cword>'))
  normal ]s
  call assert_equal('zpelling', expand('<cword>'))
  normal ]s
  call assert_equal('plong', expand('<cword>'))
  bwipe!
  set nospell
endfunc
