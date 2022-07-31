" Test syntax highlighting functions.

func Test_missing_attr()
  throw 'Skipped: use test/functional/legacy/syn_attr_spec.lua'

  hi Mine term=bold cterm=italic
  call assert_equal('Mine', synIDattr(hlID("Mine"), "name"))
  call assert_equal('', synIDattr("Mine"->hlID(), "bg", 'term'))
  call assert_equal('', synIDattr("Mine"->hlID(), "fg", 'term'))
  call assert_equal('', synIDattr("Mine"->hlID(), "sp", 'term'))
  call assert_equal('1', synIDattr(hlID("Mine"), "bold", 'term'))
  call assert_equal('1', synIDattr(hlID("Mine"), "italic", 'cterm'))
  hi Mine term=reverse cterm=inverse
  call assert_equal('1', synIDattr(hlID("Mine"), "reverse", 'term'))
  call assert_equal('1', synIDattr(hlID("Mine"), "inverse", 'cterm'))

  hi Mine term=underline cterm=standout gui=undercurl
  call assert_equal('1', synIDattr(hlID("Mine"), "underline", 'term'))
  call assert_equal('1', synIDattr(hlID("Mine"), "standout", 'cterm'))
  call assert_equal('1', synIDattr("Mine"->hlID(), "undercurl", 'gui'))

  hi Mine term=underdouble cterm=underdotted gui=underdashed
  call assert_equal('1', synIDattr(hlID("Mine"), "underdouble", 'term'))
  call assert_equal('1', synIDattr(hlID("Mine"), "underdotted", 'cterm'))
  call assert_equal('1', synIDattr("Mine"->hlID(), "underdashed", 'gui'))

  hi Mine term=nocombine gui=strikethrough
  call assert_equal('1', synIDattr(hlID("Mine"), "strikethrough", 'gui'))
  call assert_equal('1', synIDattr(hlID("Mine"), "nocombine", 'term'))
  call assert_equal('', synIDattr(hlID("Mine"), "nocombine", 'gui'))
  hi Mine term=NONE cterm=NONE gui=NONE
  call assert_equal('', synIDattr(hlID("Mine"), "bold", 'term'))
  call assert_equal('', synIDattr(hlID("Mine"), "italic", 'cterm'))
  call assert_equal('', synIDattr(hlID("Mine"), "reverse", 'term'))
  call assert_equal('', synIDattr(hlID("Mine"), "inverse", 'cterm'))
  call assert_equal('', synIDattr(hlID("Mine"), "underline", 'term'))
  call assert_equal('', synIDattr(hlID("Mine"), "standout", 'cterm'))
  call assert_equal('', synIDattr(hlID("Mine"), "undercurl", 'gui'))
  call assert_equal('', synIDattr(hlID("Mine"), "strikethrough", 'gui'))

  if has('gui')
    let fontname = getfontname()
    if fontname == ''
      let fontname = 'something'
    endif
    exe "hi Mine guifg=blue guibg=red font='" . fontname . "'"
    call assert_equal('blue', synIDattr(hlID("Mine"), "fg", 'gui'))
    call assert_equal('red', synIDattr(hlID("Mine"), "bg", 'gui'))
    call assert_equal(fontname, synIDattr(hlID("Mine"), "font", 'gui'))
  endif
endfunc
