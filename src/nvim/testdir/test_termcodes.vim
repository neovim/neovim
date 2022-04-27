
func Test_simplify_ctrl_at()
  " feeding unsimplified CTRL-@ should still trigger i_CTRL-@
  call feedkeys("ifoo\<Esc>A\<*C-@>", 'xt')
  call assert_equal('foofoo', getline(1))
endfunc


" vim: shiftwidth=2 sts=2 expandtab
