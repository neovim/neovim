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

func Test_blockinsert_delete()
  new
  let _bs = &bs
  set bs=2
  call setline(1, ['case Arg is ', '        when Name_Async,', '        when Name_Num_Gangs,', 'end if;'])
  exe "norm! ggjVj\<c-v>$o$A\<bs>\<esc>"
  "call feedkeys("Vj\<c-v>$o$A\<bs>\<esc>", 'ti')
  call assert_equal(["case Arg is ", "        when Name_Async", "        when Name_Num_Gangs,", "end if;"],
        \ getline(1,'$'))
  " reset to sane state
  let &bs = _bs
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
