" Tests for user defined commands

" Test for <mods> in user defined commands
function Test_cmdmods()
  let g:mods = ''

  command! -nargs=* MyCmd let g:mods .= '<mods> '

  MyCmd
  aboveleft MyCmd
  belowright MyCmd
  botright MyCmd
  browse MyCmd
  confirm MyCmd
  hide MyCmd
  keepalt MyCmd
  keepjumps MyCmd
  keepmarks MyCmd
  keeppatterns MyCmd
  lockmarks MyCmd
  noswapfile MyCmd
  silent MyCmd
  tab MyCmd
  topleft MyCmd
  verbose MyCmd
  vertical MyCmd

  aboveleft belowright botright browse confirm hide keepalt keepjumps
        \ keepmarks keeppatterns lockmarks noswapfile silent tab
        \ topleft verbose vertical MyCmd

  call assert_equal(' aboveleft belowright botright browse confirm ' .
        \ 'hide keepalt keepjumps keepmarks keeppatterns lockmarks ' .
        \ 'noswapfile silent tab topleft verbose vertical aboveleft ' .
        \ 'belowright botright browse confirm hide keepalt keepjumps ' .
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
