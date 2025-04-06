" Test that groups and patterns are tested correctly when calling exists() for
" autocommands.

function Test_AutoCommands()
  let results=[]
  augroup auexists
  augroup END
  call assert_true(exists("##BufEnter"))
  call assert_false(exists("#BufEnter"))
  au BufEnter * let g:entered=1
  call assert_true(exists("#BufEnter"))
  call assert_false(exists("#auexists#BufEnter"))
  augroup auexists
  au BufEnter * let g:entered=1
  augroup END
  call assert_true(exists("#auexists#BufEnter"))
  call assert_false(exists("#BufEnter#*.test"))
  au BufEnter *.test let g:entered=1
  call assert_true(exists("#BufEnter#*.test"))
  edit testfile.test
  call assert_false(exists("#BufEnter#<buffer>"))
  au BufEnter <buffer> let g:entered=1
  call assert_true(exists("#BufEnter#<buffer>"))
  edit testfile2.test
  call assert_false(exists("#BufEnter#<buffer>"))
endfunction
