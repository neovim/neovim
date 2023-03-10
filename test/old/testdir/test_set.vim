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


" :set, :setlocal, :setglobal without arguments show values of options.
func Test_set_no_arg()
  set textwidth=79
  let a = execute('set')
  call assert_match("^\n--- Options ---\n.*textwidth=79\\>", a)
  set textwidth&

  setlocal textwidth=78
  let a = execute('setlocal')
  call assert_match("^\n--- Local option values ---\n.*textwidth=78\\>", a)
  setlocal textwidth&

  setglobal textwidth=77
  let a = execute('setglobal')
  call assert_match("^\n--- Global option values ---\n.*textwidth=77\\>", a)
  setglobal textwidth&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
