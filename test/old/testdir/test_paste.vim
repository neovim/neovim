
" Test for restoring option values when 'paste' is disabled
func Test_paste_opt_restore()
  set autoindent expandtab ruler showmatch
  if has('rightleft')
    " set hkmap
    set revins
  endif
  set smarttab softtabstop=3 textwidth=27 wrapmargin=12
  if has('vartabs')
    set varsofttabstop=10,20
  endif

  " enabling 'paste' should reset the above options
  set paste
  call assert_false(&autoindent)
  call assert_false(&expandtab)
  if has('rightleft')
    call assert_false(&revins)
    " call assert_false(&hkmap)
  endif
  call assert_false(&ruler)
  call assert_false(&showmatch)
  call assert_false(&smarttab)
  call assert_equal(0, &softtabstop)
  call assert_equal(0, &textwidth)
  call assert_equal(0, &wrapmargin)
  if has('vartabs')
    call assert_equal('', &varsofttabstop)
  endif

  " disabling 'paste' should restore the option values
  set nopaste
  call assert_true(&autoindent)
  call assert_true(&expandtab)
  if has('rightleft')
    call assert_true(&revins)
    " call assert_true(&hkmap)
  endif
  call assert_true(&ruler)
  call assert_true(&showmatch)
  call assert_true(&smarttab)
  call assert_equal(3, &softtabstop)
  call assert_equal(27, &textwidth)
  call assert_equal(12, &wrapmargin)
  if has('vartabs')
    call assert_equal('10,20', &varsofttabstop)
  endif

  set autoindent& expandtab& ruler& showmatch&
  if has('rightleft')
    set revins& hkmap&
  endif
  set smarttab& softtabstop& textwidth& wrapmargin&
  if has('vartabs')
    set varsofttabstop&
  endif
endfunc

" vim: shiftwidth=2 sts=2 expandtab
