" Test for cinoptions and cindent
"
" TODO: rewrite test3.in into this new style test

func Test_cino_hash()
  " Test that curbuf->b_ind_hash_comment is correctly reset
  new
  setlocal cindent cinoptions=#1
  setlocal cinoptions=
  call setline(1, ["#include <iostream>"])
  call cursor(1, 1)
  norm! o#include
  "call feedkeys("o#include\<esc>", 't')
  call assert_equal(["#include <iostream>", "#include"], getline(1,2))
  bwipe!
endfunc

func Test_cino_extern_c()
  " Test for cino-E

  let without_ind = [
        \ '#ifdef __cplusplus',
        \ 'extern "C" {',
        \ '#endif',
        \ 'int func_a(void);',
        \ '#ifdef __cplusplus',
        \ '}',
        \ '#endif'
        \ ]

  let with_ind = [
        \ '#ifdef __cplusplus',
        \ 'extern "C" {',
        \ '#endif',
        \ "\tint func_a(void);",
        \ '#ifdef __cplusplus',
        \ '}',
        \ '#endif'
        \ ]
  new
  setlocal cindent cinoptions=E0
  call setline(1, without_ind)
  call feedkeys("gg=G", 'tx')
  call assert_equal(with_ind, getline(1, '$'))

  setlocal cinoptions=E-s
  call setline(1, with_ind)
  call feedkeys("gg=G", 'tx')
  call assert_equal(without_ind, getline(1, '$'))

  setlocal cinoptions=Es
  let tests = [
        \ ['recognized', ['extern "C" {'], "\t\t;"],
        \ ['recognized', ['extern "C++" {'], "\t\t;"],
        \ ['recognized', ['extern /* com */ "C"{'], "\t\t;"],
        \ ['recognized', ['extern"C"{'], "\t\t;"],
        \ ['recognized', ['extern "C"', '{'], "\t\t;"],
        \ ['not recognized', ['extern {'], "\t;"],
        \ ['not recognized', ['extern /*"C"*/{'], "\t;"],
        \ ['not recognized', ['extern "C" //{'], ";"],
        \ ['not recognized', ['extern "C" /*{*/'], ";"],
        \ ]

  for pair in tests
    let lines = pair[1]
    call setline(1, lines)
    call feedkeys(len(lines) . "Go;", 'tx')
    call assert_equal(pair[2], getline(len(lines) + 1), 'Failed for "' . string(lines) . '"')
  endfor



  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
