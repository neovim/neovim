
" Test for translation of special key codes (<xF1>, <xF2>, etc.)
func Test_Keycode_Translation()
  let keycodes = [
        \ ["<xUp>", "<Up>"],
        \ ["<xDown>", "<Down>"],
        \ ["<xLeft>", "<Left>"],
        \ ["<xRight>", "<Right>"],
        \ ["<xHome>", "<Home>"],
        \ ["<xEnd>", "<End>"],
        \ ["<zHome>", "<Home>"],
        \ ["<zEnd>", "<End>"],
        \ ["<xF1>", "<F1>"],
        \ ["<xF2>", "<F2>"],
        \ ["<xF3>", "<F3>"],
        \ ["<xF4>", "<F4>"],
        \ ["<S-xF1>", "<S-F1>"],
        \ ["<S-xF2>", "<S-F2>"],
        \ ["<S-xF3>", "<S-F3>"],
        \ ["<S-xF4>", "<S-F4>"]]
  for [k1, k2] in keycodes
    exe "nnoremap " .. k1 .. " 2wx"
    call assert_true(maparg(k1, 'n', 0, 1).lhs == k2)
    exe "nunmap " .. k1
  endfor
endfunc

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


" vim: shiftwidth=2 sts=2 expandtab
