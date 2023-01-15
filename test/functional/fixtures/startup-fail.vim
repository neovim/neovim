func! TestFail() abort
  if 1
    throw 'failed in TestFail'
  endif
endfunc

call TestFail()
