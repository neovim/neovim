" Test for options

" opt_test.vim is generated from src/optiondefs.h and runtime/doc/options.txt
" using gen_opt_test.vim
if filereadable('opt_test.vim')
  source opt_test.vim
else
  func Test_set_values()
    throw 'Skipped: opt_test.vim does not exist'
  endfunc
endif

" vim: shiftwidth=2 sts=2 expandtab
