" Test "nvim -es -u foo.vim" with a Vimscript error.

func! TestFail() abort
  if 1
    throw 'failed in TestFail'
  endif
endfunc

call TestFail()
