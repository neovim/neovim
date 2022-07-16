
" Test for terminal keycodes that doesn't have termcap entries
func Test_special_term_keycodes()
  new
  " Test for <xHome>, <S-xHome> and <C-xHome>
  " send <K_SPECIAL> <KS_EXTRA> keycode
  call feedkeys("i\<C-K>\x80\xfd\x3f\n", 'xt')
  " send <K_SPECIAL> <KS_MODIFIER> bitmap <K_SPECIAL> <KS_EXTRA> keycode
  call feedkeys("i\<C-K>\x80\xfc\x2\x80\xfd\x3f\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x4\x80\xfd\x3f\n", 'xt')
  " Test for <xEnd>, <S-xEnd> and <C-xEnd>
  call feedkeys("i\<C-K>\x80\xfd\x3d\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x2\x80\xfd\x3d\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x4\x80\xfd\x3d\n", 'xt')
  " Test for <zHome>, <S-zHome> and <C-zHome>
  call feedkeys("i\<C-K>\x80\xfd\x40\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x2\x80\xfd\x40\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x4\x80\xfd\x40\n", 'xt')
  " Test for <zEnd>, <S-zEnd> and <C-zEnd>
  call feedkeys("i\<C-K>\x80\xfd\x3e\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x2\x80\xfd\x3e\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfc\x4\x80\xfd\x3e\n", 'xt')
  " Test for <xUp>, <xDown>, <xLeft> and <xRight>
  call feedkeys("i\<C-K>\x80\xfd\x41\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfd\x42\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfd\x43\n", 'xt')
  call feedkeys("i\<C-K>\x80\xfd\x44\n", 'xt')
  call assert_equal(['<Home>', '<S-Home>', '<C-Home>',
        \ '<End>', '<S-End>', '<C-End>',
        \ '<Home>', '<S-Home>', '<C-Home>',
        \ '<End>', '<S-End>', '<C-End>',
        \ '<Up>', '<Down>', '<Left>', '<Right>', ''], getline(1, '$'))
  bw!
endfunc

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
