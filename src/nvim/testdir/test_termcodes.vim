
func Test_simplify_ctrl_at()
  " feeding unsimplified CTRL-@ should still trigger i_CTRL-@
  call feedkeys("ifoo\<Esc>A\<*C-@>x", 'xt')
  call assert_equal('foofo', getline(1))
  bw!
endfunc

func Test_simplify_noremap()
  call feedkeys("i\<*C-M>", 'nx')
  call assert_equal('', getline(1))
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  bw!
endfunc

func Test_simplify_timedout()
  inoremap <C-M>a b
  call feedkeys("i\<*C-M>", 'xt')
  call assert_equal('', getline(1))
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  iunmap <C-M>a
  bw!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
