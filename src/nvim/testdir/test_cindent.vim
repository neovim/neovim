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

  let without_ind =<< trim [CODE]
    #ifdef __cplusplus
    extern "C" {
    #endif
    int func_a(void);
    #ifdef __cplusplus
    }
    #endif
  [CODE]

  let with_ind =<< trim [CODE]
    #ifdef __cplusplus
    extern "C" {
    #endif
    	int func_a(void);
    #ifdef __cplusplus
    }
    #endif
  [CODE]
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

func Test_cindent_rawstring()
  new
  setl cindent
  call feedkeys("i" .
          \ "int main() {\<CR>" .
          \ "R\"(\<CR>" .
          \ ")\";\<CR>" .
          \ "statement;\<Esc>", "x")
  call assert_equal("\tstatement;", getline(line('.')))
  bw!
endfunc

func Test_cindent_expr()
  new
  func! MyIndentFunction()
    return v:lnum == 1 ? shiftwidth() : 0
  endfunc
  setl expandtab sw=8 indentkeys+=; indentexpr=MyIndentFunction()
  let testinput =<< trim [CODE]
    var_a = something()
    b = something()
  [CODE]
  call setline(1, testinput)
  call cursor(1, 1)
  call feedkeys("^\<c-v>j$A;\<esc>", 'tnix')
  let expected =<< [CODE]
        var_a = something();
b = something();
[CODE]
  call assert_equal(expected, getline(1, '$'))

  %d
  let testinput =<< [CODE]
                var_a = something()
                b = something()
[CODE]
  call setline(1, testinput)
  call cursor(1, 1)
  call feedkeys("^\<c-v>j$A;\<esc>", 'tnix')
  let expected =<< [CODE]
        var_a = something();
                b = something()
[CODE]
  call assert_equal(expected, getline(1, '$'))
  bw!
endfunc

func Test_cindent_func()
  new
  setlocal cindent
  call setline(1, ['int main(void)', '{', 'return 0;', '}'])
  call assert_equal(-1, cindent(0))
  call assert_equal(&sw, 3->cindent())
  call assert_equal(-1, cindent(line('$')+1))
  bwipe!
endfunc

" this was going beyond the end of the line.
func Test_cindent_case()
  new
  call setline(1, "case x: // x")
  set cindent
  norm! f:a:
  bwipe!
endfunc

func Test_cindent_pragma()
  new
  setl cindent ts=4 sw=4
  setl cino=Ps

  let code =<< trim [CODE]
  {
  #pragma omp parallel
  {
  #pragma omp task
  foo();
  # pragma omp taskwait
  }
  }
  [CODE]

  call append(0, code)
  normal gg
  normal =G

  let expected =<< trim [CODE]
  {
	#pragma omp parallel
	{
		#pragma omp task
		foo();
		# pragma omp taskwait
	}
  }

  [CODE]

  call assert_equal(expected, getline(1, '$'))
  enew! | close
endfunc

" vim: shiftwidth=2 sts=2 expandtab
