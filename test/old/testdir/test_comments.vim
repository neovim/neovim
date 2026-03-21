" Tests for the various flags in the 'comments' option

" Test for the 'n' flag in 'comments'
func Test_comment_nested()
  new
  setlocal comments=n:> fo+=ro
  exe "normal i> B\nD\<C-C>ggOA\<C-C>joC\<C-C>Go\<BS>>>> F\nH"
  exe "normal 5GOE\<C-C>6GoG"
  let expected =<< trim END
    > A
    > B
    > C
    > D
    >>>> E
    >>>> F
    >>>> G
    >>>> H
  END
  call assert_equal(expected, getline(1, '$'))
  bw!
endfunc

" Test for the 'b' flag in 'comments'
func Test_comment_blank()
  new
  setlocal comments=b:* fo+=ro
  exe "normal i* E\nF\n\<BS>G\nH\<C-C>ggOC\<C-C>O\<BS>B\<C-C>OA\<C-C>2joD"
  let expected =<< trim END
    A
    *B
    * C
    * D
    * E
    * F
    *G
    H
  END
  call assert_equal(expected, getline(1, '$'))
  bw!
endfunc

" Test for the 'f' flag in 'comments' (only the first line has a comment
" string)
func Test_comment_firstline()
  new
  setlocal comments=f:- fo+=ro
  exe "normal i- B\nD\<C-C>ggoC\<C-C>ggOA\<C-C>"
  call assert_equal(['A', '- B', '  C', '  D'], getline(1, '$'))
  %d
  setlocal comments=:-
  exe "normal i- B\nD\<C-C>ggoC\<C-C>ggOA\<C-C>"
  call assert_equal(['- A', '- B', '- C', '- D'], getline(1, '$'))
  bw!
endfunc

" Test for the 's', 'm' and 'e' flags in 'comments'
" Test for automatically adding comment leaders in insert mode
func Test_comment_threepiece()
  new
  setlocal expandtab
  call setline(1, ["\t/*"])
  setlocal formatoptions=croql
  call cursor(1, 3)
  call feedkeys("A\<cr>\<cr>/", 'tnix')
  call assert_equal(["\t/*", " *", " */"], getline(1, '$'))

  " If a comment ends in a single line, then don't add it in the next line
  %d
  call setline(1, '/* line1 */')
  call feedkeys("A\<CR>next line", 'xt')
  call assert_equal(['/* line1 */', 'next line'], getline(1, '$'))

  %d
  " Copy the trailing indentation from the leader comment to a new line
  setlocal autoindent noexpandtab
  call feedkeys("a\t/*\tone\ntwo\n/", 'xt')
  call assert_equal(["\t/*\tone", "\t *\ttwo", "\t */"], getline(1, '$'))
  bw!
endfunc

" Test for the 'r' flag in 'comments' (right align comment)
func Test_comment_rightalign()
  new
  setlocal comments=sr:/***,m:**,ex-2:******/ fo+=ro
  exe "normal i=\<C-C>o\t  /***\nD\n/"
  exe "normal 2GOA\<C-C>joB\<C-C>jOC\<C-C>joE\<C-C>GOF\<C-C>joG"
  let expected =<< trim END
    =
    A
    	  /***
    	    ** B
    	    ** C
    	    ** D
    	    ** E
    	    **     F
    	    ******/
    G
  END
  call assert_equal(expected, getline(1, '$'))
  bw!
endfunc

" Test for the 'O' flag in 'comments'
func Test_comment_O()
  new
  setlocal comments=Ob:* fo+=ro
  exe "normal i* B\nD\<C-C>kOA\<C-C>joC"
  let expected =<< trim END
    A
    * B
    * C
    * D
  END
  call assert_equal(expected, getline(1, '$'))
  bw!
endfunc

" Test for using a multibyte character as a comment leader
func Test_comment_multibyte_leader()
  new
  let t =<< trim END
    {
    Ｘ
    Ｘa
    ＸaＹ
    ＸＹ
    ＸＹＺ
    Ｘ Ｙ
    Ｘ ＹＺ
    ＸＸ
    ＸＸa
    ＸＸＹ
    }
  END
  call setline(1, t)
  call cursor(2, 1)

  set tw=2 fo=cqm comments=n:Ｘ
  exe "normal gqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgq"
  let t =<< trim END
    Ｘ
    Ｘa
    ＸaＹ
    ＸＹ
    ＸＹＺ
    Ｘ Ｙ
    Ｘ ＹＺ
    ＸＸ
    ＸＸa
    ＸＸＹ
  END
  exe "normal o\n" . join(t, "\n")

  let expected =<< trim END
    {
    Ｘ
    Ｘa
    Ｘa
    ＸＹ
    ＸＹ
    ＸＹ
    ＸＺ
    Ｘ Ｙ
    Ｘ Ｙ
    Ｘ Ｚ
    ＸＸ
    ＸＸa
    ＸＸＹ

    Ｘ
    Ｘa
    Ｘa
    ＸＹ
    ＸＹ
    ＸＹ
    ＸＺ
    Ｘ Ｙ
    Ｘ Ｙ
    Ｘ Ｚ
    ＸＸ
    ＸＸa
    ＸＸＹ
    }
  END
  call assert_equal(expected, getline(1, '$'))

  set tw& fo& comments&
  bw!
endfunc

" Test for a space character in 'comments' setting
func Test_comment_space()
  new
  setlocal comments=b:\ > fo+=ro
  exe "normal i> B\nD\<C-C>ggOA\<C-C>joC"
  exe "normal Go > F\nH\<C-C>kOE\<C-C>joG"
  let expected =<< trim END
    A
    > B
    C
    D
     > E
     > F
     > G
     > H
  END
  call assert_equal(expected, getline(1, '$'))
  bw!
endfunc

" Test for formatting lines with and without comments
func Test_comment_format_lines()
  new
  call setline(1, ['one', '/* two */', 'three'])
  normal gggqG
  call assert_equal(['one', '/* two */', 'three'], getline(1, '$'))
  bw!
endfunc

" Test for using 'a' in 'formatoptions' with comments
func Test_comment_autoformat()
  new
  setlocal formatoptions+=a
  call feedkeys("a- one\n- two\n", 'xt')
  call assert_equal(['- one', '- two', ''], getline(1, '$'))

  %d
  call feedkeys("a\none\n", 'xt')
  call assert_equal(['', 'one', ''], getline(1, '$'))

  setlocal formatoptions+=aw
  %d
  call feedkeys("aone \ntwo\n", 'xt')
  call assert_equal(['one two', ''], getline(1, '$'))

  %d
  call feedkeys("aone\ntwo\n", 'xt')
  call assert_equal(['one', 'two', ''], getline(1, '$'))

  set backspace=indent,eol,start
  %d
  call feedkeys("aone \n\<BS>", 'xt')
  call assert_equal(['one'], getline(1, '$'))
  set backspace&

  bw!
endfunc

" Test for joining lines with comments ('j' flag in 'formatoptions')
func Test_comment_join_lines_fo_j()
  new
  setlocal fo+=j comments=://
  call setline(1, ['i++; // comment1', '           // comment2'])
  normal J
  call assert_equal('i++; // comment1 comment2', getline(1))
  setlocal fo-=j
  call setline(1, ['i++; // comment1', '           // comment2'])
  normal J
  call assert_equal('i++; // comment1 // comment2', getline(1))
  " Test with nested comments
  setlocal fo+=j comments=n:>,n:)
  call setline(1, ['i++; > ) > ) comment1', '           > ) comment2'])
  normal J
  call assert_equal('i++; > ) > ) comment1 comment2', getline(1))
  bw!
endfunc

" Test for formatting lines where only the first line has a comment.
func Test_comment_format_firstline_comment()
  new
  setlocal formatoptions=tcq
  call setline(1, ['- one two', 'three'])
  normal gggqG
  call assert_equal(['- one two three'], getline(1, '$'))

  %d
  call setline(1, ['- one', '- two'])
  normal gggqG
  call assert_equal(['- one', '- two'], getline(1, '$'))
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
