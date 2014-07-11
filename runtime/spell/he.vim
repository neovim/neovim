" For Hebrew capitals should not be checked.  But only change the
" 'spellcapcheck' option when it is not at its default value.
let s:spc = &l:spc
setlocal spc&
if s:spc == &l:spc
  setlocal spc=
else
  let &l:spc = s:spc
endif
unlet s:spc
