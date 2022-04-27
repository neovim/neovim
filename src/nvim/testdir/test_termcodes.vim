
func Test_simplify_ctrl_at()
  " feeding unsimplified CTRL-@ should still trigger i_CTRL-@
  call feedkeys("ifoo\<Esc>A\<*C-@>x", 'xt')
  call assert_equal('foofo', getline(1))
  bw!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
