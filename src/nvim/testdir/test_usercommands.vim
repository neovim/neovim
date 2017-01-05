" Tests for user defined commands

" Test for <mods> in user defined commands
function Test_cmdmods()
  let g:mods = ''

  command! -nargs=* MyCmd let g:mods .= '<mods> '

  MyCmd
  aboveleft MyCmd
  abo MyCmd
  belowright MyCmd
  bel MyCmd
  botright MyCmd
  bo MyCmd
  browse MyCmd
  bro MyCmd
  confirm MyCmd
  conf MyCmd
  hide MyCmd
  hid MyCmd
  keepalt MyCmd
  keepa MyCmd
  keepjumps MyCmd
  keepj MyCmd
  keepmarks MyCmd
  kee MyCmd
  keeppatterns MyCmd
  keepp MyCmd
  leftabove MyCmd  " results in :aboveleft
  lefta MyCmd
  lockmarks MyCmd
  loc MyCmd
  " noautocmd MyCmd
  noswapfile MyCmd
  nos MyCmd
  rightbelow MyCmd " results in :belowright
  rightb MyCmd
  " sandbox MyCmd
  silent MyCmd
  sil MyCmd
  tab MyCmd
  topleft MyCmd
  to MyCmd
  " unsilent MyCmd
  verbose MyCmd
  verb MyCmd
  vertical MyCmd
  vert MyCmd

  aboveleft belowright botright browse confirm hide keepalt keepjumps
        \ keepmarks keeppatterns lockmarks noswapfile silent tab
        \ topleft verbose vertical MyCmd

  call assert_equal(' aboveleft aboveleft belowright belowright botright ' .
        \ 'botright browse browse confirm confirm hide hide ' .
        \ 'keepalt keepalt keepjumps keepjumps keepmarks keepmarks ' .
        \ 'keeppatterns keeppatterns aboveleft aboveleft lockmarks lockmarks noswapfile ' .
        \ 'noswapfile belowright belowright silent silent tab topleft topleft verbose verbose ' .
        \ 'vertical vertical ' .
        \ 'aboveleft belowright botright browse confirm hide keepalt keepjumps ' .
        \ 'keepmarks keeppatterns lockmarks noswapfile silent tab topleft ' .
        \ 'verbose vertical ', g:mods)

  let g:mods = ''
  command! -nargs=* MyQCmd let g:mods .= '<q-mods> '

  vertical MyQCmd
  call assert_equal('"vertical" ', g:mods)

  delcommand MyCmd
  delcommand MyQCmd
  unlet g:mods
endfunction
