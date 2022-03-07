" Tests for the :set command

function Test_set_backslash()
  let isk_save = &isk

  set isk=a,b,c
  set isk+=d
  call assert_equal('a,b,c,d', &isk)
  set isk+=\\,e
  call assert_equal('a,b,c,d,\,e', &isk)
  set isk-=e
  call assert_equal('a,b,c,d,\', &isk)
  set isk-=\\
  call assert_equal('a,b,c,d', &isk)

  let &isk = isk_save
endfunction

function Test_set_add()
  let wig_save = &wig

  set wildignore=*.png,
  set wildignore+=*.jpg
  call assert_equal('*.png,*.jpg', &wig)

  let &wig = wig_save
endfunction

" vim: shiftwidth=2 sts=2 expandtab
