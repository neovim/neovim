" Test for block inserting
"
" TODO: rewrite test39.in into this new style test

func Test_blockinsert_indent()
  new
  filetype plugin indent on
  setlocal sw=2 et ft=vim
  call setline(1, ['let a=[', '  ''eins'',', '  ''zwei'',', '  ''drei'']'])
  call cursor(2, 3)
  exe "norm! \<c-v>2jI\\ \<esc>"
  call assert_equal(['let a=[', '      \ ''eins'',', '      \ ''zwei'',', '      \ ''drei'']'],
        \ getline(1,'$'))
  " reset to sane state
  filetype off
  bwipe!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
