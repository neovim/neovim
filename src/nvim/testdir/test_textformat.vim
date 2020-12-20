" Tests for the various 'formatoptions' settings

source check.vim

func Test_text_format()
  enew!

  setl noai tw=2 fo=t
  call append('$', [
	      \ '{',
	      \ '    ',
	      \ '',
	      \ '}'])
  exe "normal /^{/+1\n0"
  normal gRa b
  let lnum = line('.')
  call assert_equal([
	      \ 'a',
	      \ 'b'], getline(lnum - 1, lnum))

  normal ggdG
  setl ai tw=2 fo=tw
  call append('$', [
	      \ '{',
	      \ 'a  b  ',
	      \ '',
	      \ 'a    ',
	      \ '}'])
  exe "normal /^{/+1\n0"
  normal gqgqjjllab
  let lnum = line('.')
  call assert_equal([
	      \ 'a  ',
	      \ 'b  ',
	      \ '',
	      \ 'a  ',
	      \ 'b'], getline(lnum - 4, lnum))

  normal ggdG
  setl tw=3 fo=t
  call append('$', [
	      \ '{',
	      \ "a \<C-A>",
	      \ '}'])
  exe "normal /^{/+1\n0"
  exe "normal gqgqo\na \<C-V>\<C-A>"
  let lnum = line('.')
  call assert_equal([
	      \ 'a',
	      \ "\<C-A>",
	      \ '',
	      \ 'a',
	      \ "\<C-A>"], getline(lnum - 4, lnum))

  normal ggdG
  setl tw=2 fo=tcq1 comments=:#
  call append('$', [
	      \ '{',
	      \ 'a b',
	      \ '#a b',
	      \ '}'])
  exe "normal /^{/+1\n0"
  exe "normal gqgqjgqgqo\na b\n#a b"
  let lnum = line('.')
  call assert_equal([
	      \ 'a b',
	      \ '#a b',
	      \ '',
	      \ 'a b',
	      \ '#a b'], getline(lnum - 4, lnum))

  normal ggdG
  setl tw=5 fo=tcn comments=:#
  call append('$', [
	      \ '{',
	      \ '  1 a',
	      \ '# 1 a',
	      \ '}'])
  exe "normal /^{/+1\n0"
  exe "normal A b\<Esc>jA b"
  let lnum = line('.')
  call assert_equal([
	      \ '  1 a',
	      \ '    b',
	      \ '# 1 a',
	      \ '#   b'], getline(lnum - 3, lnum))

  normal ggdG
  setl tw=5 fo=t2a si
  call append('$', [
	      \ '{',
	      \ '',
	      \ '  x a',
	      \ '  b',
	      \ ' c',
	      \ '',
	      \ '}'])
  exe "normal /^{/+3\n0"
  exe "normal i  \<Esc>A_"
  let lnum = line('.')
  call assert_equal([
	      \ '',
	      \ '  x a',
	      \ '    b_',
	      \ '    c',
	      \ ''], getline(lnum - 2, lnum + 2))

  normal ggdG
  setl tw=5 fo=qn comments=:#
  call append('$', [
	      \ '{',
	      \ '# 1 a b',
	      \ '}'])
  exe "normal /^{/+1\n5|"
  normal gwap
  call assert_equal(5, col('.'))
  let lnum = line('.')
  call assert_equal([
	      \ '# 1 a',
	      \ '#   b'], getline(lnum, lnum + 1))

  normal ggdG
  setl tw=5 fo=q2 comments=:#
  call append('$', [
	      \ '{',
	      \ '# x',
	      \ '#   a b',
	      \ '}'])
  exe "normal /^{/+1\n0"
  normal gwap
  let lnum = line('.')
  call assert_equal([
	      \ '# x a',
	      \ '#   b'], getline(lnum, lnum + 1))

  normal ggdG
  setl tw& fo=a
  call append('$', [
	      \ '{',
	      \ '   1aa',
	      \ '   2bb',
	      \ '}'])
  exe "normal /^{/+2\n0"
  normal I^^
  call assert_equal('{ 1aa ^^2bb }', getline('.'))

  normal ggdG
  setl tw=20 fo=an12wcq comments=s1:/*,mb:*,ex:*/
  call append('$', [
	      \ '/* abc def ghi jkl ',
	      \ ' *    mno pqr stu',
	      \ ' */'])
  exe "normal /mno pqr/\n"
  normal A vwx yz
  let lnum = line('.')
  call assert_equal([
	      \ ' *    mno pqr stu ',
	      \ ' *    vwx yz',
	      \ ' */'], getline(lnum - 1, lnum + 1))

  normal ggdG
  setl tw=12 fo=tqnc comments=:#
  call setline('.', '# 1 xxxxx')
  normal A foobar
  call assert_equal([
	      \ '# 1 xxxxx',
	      \ '#   foobar'], getline(1, 2))

  " Test the 'p' flag for 'formatoptions'
  " First test without the flag: that it will break "Mr. Feynman" at the space
  normal ggdG
  setl tw=28 fo=tcq
  call setline('.', 'Surely you''re joking, Mr. Feynman!')
  normal gqq
  call assert_equal([
              \ 'Surely you''re joking, Mr.',
              \ 'Feynman!'], getline(1, 2))
  " Now test with the flag: that it will push the name with the title onto the
  " next line
  normal ggdG
  setl fo+=p
  call setline('.', 'Surely you''re joking, Mr. Feynman!')
  normal gqq
  call assert_equal([
              \ 'Surely you''re joking,',
              \ 'Mr. Feynman!'], getline(1, 2))
  " Ensure that it will still break if two spaces are entered
  normal ggdG
  call setline('.', 'Surely you''re joking, Mr.  Feynman!')
  normal gqq
  call assert_equal([
              \ 'Surely you''re joking, Mr.',
              \ 'Feynman!'], getline(1, 2))

  setl ai& tw& fo& si& comments&
  enew!
endfunc

" Tests for :right, :center and :left on text with embedded TAB.
func Test_format_align()
  enew!
  set tw=65

  " :left alignment
  call append(0, [
	      \ "	test for :left",
	      \ "	  a		a",
	      \ "	    fa		a",
	      \ "	  dfa		a",
	      \ "	        sdfa		a",
	      \ "	  asdfa		a",
	      \ "	        xasdfa		a",
	      \ "asxxdfa		a",
	      \ ])
  %left
  call assert_equal([
	      \ "test for :left",
	      \ "a		a",
	      \ "fa		a",
	      \ "dfa		a",
	      \ "sdfa		a",
	      \ "asdfa		a",
	      \ "xasdfa		a",
	      \ "asxxdfa		a",
	      \ ""
	      \ ], getline(1, '$'))
  enew!

  " :center alignment
  call append(0, [
	      \ "	test for :center",
	      \ "	  a		a",
	      \ "	    fa		afd asdf",
	      \ "	  dfa		a",
	      \ "	        sdfa		afd asdf",
	      \ "	  asdfa		a",
	      \ "	        xasdfa		asdfasdfasdfasdfasdf",
	      \ "asxxdfa		a"
	      \ ])
  %center
  call assert_equal([
	      \ "			test for :center",
	      \ "			 a		a",
	      \ "		      fa		afd asdf",
	      \ "			 dfa		a",
	      \ "		    sdfa		afd asdf",
	      \ "			 asdfa		a",
	      \ "	      xasdfa		asdfasdfasdfasdfasdf",
	      \ "			asxxdfa		a",
	      \ ""
	      \ ], getline(1, '$'))
  enew!

  " :right alignment
  call append(0, [
	      \ "	test for :right",
	      \ "	a		a",
	      \ "	fa		a",
	      \ "	dfa		a",
	      \ "	sdfa		a",
	      \ "	asdfa		a",
	      \ "	xasdfa		a",
	      \ "	asxxdfa		a",
	      \ "	asxa;ofa		a",
	      \ "	asdfaqwer		a",
	      \ "	a		ax",
	      \ "	fa		ax",
	      \ "	dfa		ax",
	      \ "	sdfa		ax",
	      \ "	asdfa		ax",
	      \ "	xasdfa		ax",
	      \ "	asxxdfa		ax",
	      \ "	asxa;ofa		ax",
	      \ "	asdfaqwer		ax",
	      \ "	a		axx",
	      \ "	fa		axx",
	      \ "	dfa		axx",
	      \ "	sdfa		axx",
	      \ "	asdfa		axx",
	      \ "	xasdfa		axx",
	      \ "	asxxdfa		axx",
	      \ "	asxa;ofa		axx",
	      \ "	asdfaqwer		axx",
	      \ "	a		axxx",
	      \ "	fa		axxx",
	      \ "	dfa		axxx",
	      \ "	sdfa		axxx",
	      \ "	asdfa		axxx",
	      \ "	xasdfa		axxx",
	      \ "	asxxdfa		axxx",
	      \ "	asxa;ofa		axxx",
	      \ "	asdfaqwer		axxx",
	      \ "	a		axxxo",
	      \ "	fa		axxxo",
	      \ "	dfa		axxxo",
	      \ "	sdfa		axxxo",
	      \ "	asdfa		axxxo",
	      \ "	xasdfa		axxxo",
	      \ "	asxxdfa		axxxo",
	      \ "	asxa;ofa		axxxo",
	      \ "	asdfaqwer		axxxo",
	      \ "	a		axxxoi",
	      \ "	fa		axxxoi",
	      \ "	dfa		axxxoi",
	      \ "	sdfa		axxxoi",
	      \ "	asdfa		axxxoi",
	      \ "	xasdfa		axxxoi",
	      \ "	asxxdfa		axxxoi",
	      \ "	asxa;ofa		axxxoi",
	      \ "	asdfaqwer		axxxoi",
	      \ "	a		axxxoik",
	      \ "	fa		axxxoik",
	      \ "	dfa		axxxoik",
	      \ "	sdfa		axxxoik",
	      \ "	asdfa		axxxoik",
	      \ "	xasdfa		axxxoik",
	      \ "	asxxdfa		axxxoik",
	      \ "	asxa;ofa		axxxoik",
	      \ "	asdfaqwer		axxxoik",
	      \ "	a		axxxoike",
	      \ "	fa		axxxoike",
	      \ "	dfa		axxxoike",
	      \ "	sdfa		axxxoike",
	      \ "	asdfa		axxxoike",
	      \ "	xasdfa		axxxoike",
	      \ "	asxxdfa		axxxoike",
	      \ "	asxa;ofa		axxxoike",
	      \ "	asdfaqwer		axxxoike",
	      \ "	a		axxxoikey",
	      \ "	fa		axxxoikey",
	      \ "	dfa		axxxoikey",
	      \ "	sdfa		axxxoikey",
	      \ "	asdfa		axxxoikey",
	      \ "	xasdfa		axxxoikey",
	      \ "	asxxdfa		axxxoikey",
	      \ "	asxa;ofa		axxxoikey",
	      \ "	asdfaqwer		axxxoikey",
	      \ ])
  %right
  call assert_equal([
	      \ "\t\t\t\t		  test for :right",
	      \ "\t\t\t\t		      a		a",
	      \ "\t\t\t\t		     fa		a",
	      \ "\t\t\t\t		    dfa		a",
	      \ "\t\t\t\t		   sdfa		a",
	      \ "\t\t\t\t		  asdfa		a",
	      \ "\t\t\t\t		 xasdfa		a",
	      \ "\t\t\t\t		asxxdfa		a",
	      \ "\t\t\t\t	       asxa;ofa		a",
	      \ "\t\t\t\t	      asdfaqwer		a",
	      \ "\t\t\t\t	      a		ax",
	      \ "\t\t\t\t	     fa		ax",
	      \ "\t\t\t\t	    dfa		ax",
	      \ "\t\t\t\t	   sdfa		ax",
	      \ "\t\t\t\t	  asdfa		ax",
	      \ "\t\t\t\t	 xasdfa		ax",
	      \ "\t\t\t\t	asxxdfa		ax",
	      \ "\t\t\t\t       asxa;ofa		ax",
	      \ "\t\t\t\t      asdfaqwer		ax",
	      \ "\t\t\t\t	      a		axx",
	      \ "\t\t\t\t	     fa		axx",
	      \ "\t\t\t\t	    dfa		axx",
	      \ "\t\t\t\t	   sdfa		axx",
	      \ "\t\t\t\t	  asdfa		axx",
	      \ "\t\t\t\t	 xasdfa		axx",
	      \ "\t\t\t\t	asxxdfa		axx",
	      \ "\t\t\t\t       asxa;ofa		axx",
	      \ "\t\t\t\t      asdfaqwer		axx",
	      \ "\t\t\t\t	      a		axxx",
	      \ "\t\t\t\t	     fa		axxx",
	      \ "\t\t\t\t	    dfa		axxx",
	      \ "\t\t\t\t	   sdfa		axxx",
	      \ "\t\t\t\t	  asdfa		axxx",
	      \ "\t\t\t\t	 xasdfa		axxx",
	      \ "\t\t\t\t	asxxdfa		axxx",
	      \ "\t\t\t\t       asxa;ofa		axxx",
	      \ "\t\t\t\t      asdfaqwer		axxx",
	      \ "\t\t\t\t	      a		axxxo",
	      \ "\t\t\t\t	     fa		axxxo",
	      \ "\t\t\t\t	    dfa		axxxo",
	      \ "\t\t\t\t	   sdfa		axxxo",
	      \ "\t\t\t\t	  asdfa		axxxo",
	      \ "\t\t\t\t	 xasdfa		axxxo",
	      \ "\t\t\t\t	asxxdfa		axxxo",
	      \ "\t\t\t\t       asxa;ofa		axxxo",
	      \ "\t\t\t\t      asdfaqwer		axxxo",
	      \ "\t\t\t\t	      a		axxxoi",
	      \ "\t\t\t\t	     fa		axxxoi",
	      \ "\t\t\t\t	    dfa		axxxoi",
	      \ "\t\t\t\t	   sdfa		axxxoi",
	      \ "\t\t\t\t	  asdfa		axxxoi",
	      \ "\t\t\t\t	 xasdfa		axxxoi",
	      \ "\t\t\t\t	asxxdfa		axxxoi",
	      \ "\t\t\t\t       asxa;ofa		axxxoi",
	      \ "\t\t\t\t      asdfaqwer		axxxoi",
	      \ "\t\t\t\t	      a		axxxoik",
	      \ "\t\t\t\t	     fa		axxxoik",
	      \ "\t\t\t\t	    dfa		axxxoik",
	      \ "\t\t\t\t	   sdfa		axxxoik",
	      \ "\t\t\t\t	  asdfa		axxxoik",
	      \ "\t\t\t\t	 xasdfa		axxxoik",
	      \ "\t\t\t\t	asxxdfa		axxxoik",
	      \ "\t\t\t\t       asxa;ofa		axxxoik",
	      \ "\t\t\t\t      asdfaqwer		axxxoik",
	      \ "\t\t\t\t	      a		axxxoike",
	      \ "\t\t\t\t	     fa		axxxoike",
	      \ "\t\t\t\t	    dfa		axxxoike",
	      \ "\t\t\t\t	   sdfa		axxxoike",
	      \ "\t\t\t\t	  asdfa		axxxoike",
	      \ "\t\t\t\t	 xasdfa		axxxoike",
	      \ "\t\t\t\t	asxxdfa		axxxoike",
	      \ "\t\t\t\t       asxa;ofa		axxxoike",
	      \ "\t\t\t\t      asdfaqwer		axxxoike",
	      \ "\t\t\t\t	      a		axxxoikey",
	      \ "\t\t\t\t	     fa		axxxoikey",
	      \ "\t\t\t\t	    dfa		axxxoikey",
	      \ "\t\t\t\t	   sdfa		axxxoikey",
	      \ "\t\t\t\t	  asdfa		axxxoikey",
	      \ "\t\t\t\t	 xasdfa		axxxoikey",
	      \ "\t\t\t\t	asxxdfa		axxxoikey",
	      \ "\t\t\t\t       asxa;ofa		axxxoikey",
	      \ "\t\t\t\t      asdfaqwer		axxxoikey",
	      \ ""
	      \ ], getline(1, '$'))
  enew!

  " align text with 'wrapmargin'
  50vnew
  call setline(1, ['Vim'])
  setl textwidth=0
  setl wrapmargin=30
  right
  call assert_equal("\t\t Vim", getline(1))
  q!

  set tw&
endfunc

" Test formatting a paragraph.
func Test_format_para()
  enew!
  set fo+=tcroql tw=72

  call append(0, [
	\ "xxxxx xx xxxxxx ",
	\ "xxxxxxx xxxxxxxxx xxx xxxx xxxxx xxxxx xxx xx",
	\ "xxxxxxxxxxxxxxxxxx xxxxx xxxx, xxxx xxxx xxxx xxxx xxx xx xx",
	\ "xx xxxxxxx. xxxx xxxx.",
	\ "",
	\ "> xx xx, xxxx xxxx xxx xxxx xxx xxxxx xxx xxx xxxxxxx xxx xxxxx",
	\ "> xxxxxx xxxxxxx: xxxx xxxxxxx, xx xxxxxx xxxx xxxxxxxxxx"
	\ ])
  exe "normal /xxxxxxxx$\<CR>"
  normal 0gq6kk
  call assert_equal([
	\ "xxxxx xx xxxxxx xxxxxxx xxxxxxxxx xxx xxxx xxxxx xxxxx xxx xx",
	\ "xxxxxxxxxxxxxxxxxx xxxxx xxxx, xxxx xxxx xxxx xxxx xxx xx xx xx xxxxxxx.",
	\ "xxxx xxxx.",
	\ "",
	\ "> xx xx, xxxx xxxx xxx xxxx xxx xxxxx xxx xxx xxxxxxx xxx xxxxx xxxxxx",
	\ "> xxxxxxx: xxxx xxxxxxx, xx xxxxxx xxxx xxxxxxxxxx",
	\ ""
	\ ], getline(1, '$'))

  set fo& tw&
  enew!
endfunc

" Test undo after ":%s" and formatting.
func Test_format_undo()
  enew!
  map gg :.,.+2s/^/x/<CR>kk:set tw=3<CR>gqq

  call append(0, [
	      \ "aa aa aa aa",
	      \ "bb bb bb bb",
	      \ "cc cc cc cc"
	      \ ])
  " undo/redo here to make the next undo only work on the following changes
  exe "normal i\<C-G>u"
  call cursor(1,1)
  normal ggu
  call assert_equal([
	      \ "aa aa aa aa",
	      \ "bb bb bb bb",
	      \ "cc cc cc cc",
	      \ ""
	      \ ], getline(1, '$'))

  unmap gg
  set tw&
  enew!
endfunc

func Test_format_list_auto()
  new
  call setline(1, ['1. abc', '2. def', '3.  ghi'])
  set fo=tan ai bs=2
  call feedkeys("3G0lli\<BS>\<BS>x\<Esc>", 'tx')
  call assert_equal('2. defx ghi', getline(2))
  bwipe!
  set fo& ai& bs&
endfunc

func Test_crash_github_issue_5095()
  CheckFeature autocmd

  " This used to segfault, see https://github.com/vim/vim/issues/5095
  augroup testing
    au BufNew x center
  augroup END

  next! x

  bw
  augroup testing
    au!
  augroup END
  augroup! testing
endfunc

" Test for formatting multi-byte text with 'fo=t'
func Test_tw_2_fo_t()
  new
  let t =<< trim END
    {
    ＸＹＺ
    abc ＸＹＺ
    }
  END
  call setline(1, t)
  call cursor(2, 1)

  set tw=2 fo=t
  let t =<< trim END
    ＸＹＺ
    abc ＸＹＺ
  END
  exe "normal gqgqjgqgq"
  exe "normal o\n" . join(t, "\n")

  let expected =<< trim END
    {
    ＸＹＺ
    abc
    ＸＹＺ

    ＸＹＺ
    abc
    ＸＹＺ
    }
  END
  call assert_equal(expected, getline(1, '$'))

  set tw& fo&
  bwipe!
endfunc

" Test for formatting multi-byte text with 'fo=tm' and 'tw=1'
func Test_tw_1_fo_tm()
  new
  let t =<< trim END
    {
    Ｘ
    Ｘa
    Ｘ a
    ＸＹ
    Ｘ Ｙ
    }
  END
  call setline(1, t)
  call cursor(2, 1)

  set tw=1 fo=tm
  let t =<< trim END
    Ｘ
    Ｘa
    Ｘ a
    ＸＹ
    Ｘ Ｙ
  END
  exe "normal gqgqjgqgqjgqgqjgqgqjgqgq"
  exe "normal o\n" . join(t, "\n")

  let expected =<< trim END
    {
    Ｘ
    Ｘ
    a
    Ｘ
    a
    Ｘ
    Ｙ
    Ｘ
    Ｙ

    Ｘ
    Ｘ
    a
    Ｘ
    a
    Ｘ
    Ｙ
    Ｘ
    Ｙ
    }
  END
  call assert_equal(expected, getline(1, '$'))

  set tw& fo&
  bwipe!
endfunc

" Test for formatting multi-byte text with 'fo=tm' and 'tw=2'
func Test_tw_2_fo_tm()
  new
  let t =<< trim END
    {
    Ｘ
    Ｘa
    Ｘ a
    ＸＹ
    Ｘ Ｙ
    aＸ
    abＸ
    abcＸ
    abＸ c
    abＸＹ
    }
  END
  call setline(1, t)
  call cursor(2, 1)

  set tw=2 fo=tm
  let t =<< trim END
    Ｘ
    Ｘa
    Ｘ a
    ＸＹ
    Ｘ Ｙ
    aＸ
    abＸ
    abcＸ
    abＸ c
    abＸＹ
  END
  exe "normal gqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgqjgqgq"
  exe "normal o\n" . join(t, "\n")

  let expected =<< trim END
    {
    Ｘ
    Ｘ
    a
    Ｘ
    a
    Ｘ
    Ｙ
    Ｘ
    Ｙ
    a
    Ｘ
    ab
    Ｘ
    abc
    Ｘ
    ab
    Ｘ
    c
    ab
    Ｘ
    Ｙ

    Ｘ
    Ｘ
    a
    Ｘ
    a
    Ｘ
    Ｙ
    Ｘ
    Ｙ
    a
    Ｘ
    ab
    Ｘ
    abc
    Ｘ
    ab
    Ｘ
    c
    ab
    Ｘ
    Ｙ
    }
  END
  call assert_equal(expected, getline(1, '$'))

  set tw& fo&
  bwipe!
endfunc

" Test for formatting multi-byte text with 'fo=tm', 'tw=2' and 'autoindent'.
func Test_tw_2_fo_tm_ai()
  new
  let t =<< trim END
    {
      Ｘ
      Ｘa
    }
  END
  call setline(1, t)
  call cursor(2, 1)

  set ai tw=2 fo=tm
  let t =<< trim END
    Ｘ
    Ｘa
  END
  exe "normal gqgqjgqgq"
  exe "normal o\n" . join(t, "\n")

  let expected =<< trim END
    {
      Ｘ
      Ｘ
      a

      Ｘ
      Ｘ
      a
    }
  END
  call assert_equal(expected, getline(1, '$'))

  set tw& fo& ai&
  bwipe!
endfunc

" Test for formatting multi-byte text with 'fo=tm', 'tw=2' and 'noai'.
func Test_tw_2_fo_tm_noai()
  new
  let t =<< trim END
    {
      Ｘ
      Ｘa
    }
  END
  call setline(1, t)
  call cursor(2, 1)

  set noai tw=2 fo=tm
  exe "normal gqgqjgqgqo\n  Ｘ\n  Ｘa"

  let expected =<< trim END
    {
      Ｘ
      Ｘ
    a

      Ｘ
      Ｘ
    a
    }
  END
  call assert_equal(expected, getline(1, '$'))

  set tw& fo& ai&
  bwipe!
endfunc

func Test_tw_2_fo_cqm_com()
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
  bwipe!
endfunc

func Test_tw_2_fo_tm_replace()
  new
  let t =<< trim END
    {

    }
  END
  call setline(1, t)
  call cursor(2, 1)

  set tw=2 fo=tm
  exe "normal RＸa"

  let expected =<< trim END
    {
    Ｘ
    a
    }
  END
  call assert_equal(expected, getline(1, '$'))

  set tw& fo&
  bwipe!
endfunc

" Test for 'matchpairs' with multibyte chars
func Test_mps()
  new
  let t =<< trim END
    {
    ‘ two three ’ four
    }
  END
  call setline(1, t)
  call cursor(2, 1)

  exe "set mps+=\u2018:\u2019"
  normal d%

  let expected =<< trim END
    {
     four
    }
  END
  call assert_equal(expected, getline(1, '$'))

  set mps&
  bwipe!
endfunc

" Test for ra on multi-byte characters
func Test_ra_multibyte()
  new
  let t =<< trim END
    ra test
    ａbbａ
    ａａb
  END
  call setline(1, t)
  call cursor(1, 1)

  normal jVjra

  let expected =<< trim END
    ra test
    aaaa
    aaa
  END
  call assert_equal(expected, getline(1, '$'))

  bwipe!
endfunc

" Test for 'whichwrap' with multi-byte character
func Test_whichwrap_multi_byte()
  new
  let t =<< trim END
    á
    x
  END
  call setline(1, t)
  call cursor(2, 1)

  set whichwrap+=h
  normal dh
  set whichwrap&

  let expected =<< trim END
    áx
  END
  call assert_equal(expected, getline(1, '$'))

  bwipe!
endfunc

func Test_substitute()
  call assert_equal('a１a２a３a', substitute('１２３', '\zs', 'a', 'g'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
