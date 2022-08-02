" Test for Select-mode

source shared.vim

" Test for selecting a register with CTRL-R
func Test_selectmode_register()
  new

  " Default behavior: use unnamed register
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>a"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('f', getreg('"'))
  call assert_equal('baz', getreg('a'))

  " Use the black hole register
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>\<c-r>_a"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('bar', getreg('"'))
  call assert_equal('baz', getreg('a'))

  " Invalid register: use unnamed register
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>\<c-r>?a"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('f', getreg('"'))
  call assert_equal('baz', getreg('a'))

  " Use unnamed register
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>\<c-r>\"a"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('f', getreg('"'))
  call assert_equal('baz', getreg('a'))

  " use specicifed register, unnamed register is also written
  call setline(1, 'foo')
  call setreg('"', 'bar')
  call setreg('a', 'baz')
  exe ":norm! v\<c-g>\<c-r>aa"
  call assert_equal(getline('.'), 'aoo')
  call assert_equal('f', getreg('"'))
  call assert_equal('f', getreg('a'))

  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
