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

func Test_format_c_comment()
  new
  setl ai cindent tw=40 et fo=croql
  let text =<< trim END
      var = 2345;  // asdf asdf asdf asdf asdf asdf asdf asdf asdf asdf
  END
  call setline(1, text)
  normal gql
  let expected =<< trim END
      var = 2345;  // asdf asdf asdf asdf asdf
                   // asdf asdf asdf asdf asdf
  END
  call assert_equal(expected, getline(1, '$'))

  %del
  let text =<< trim END
      var = 2345;  // asdf asdf asdf asdf asdf asdf asdf asdf asdf asdf asdf asdf
  END
  call setline(1, text)
  normal gql
  let expected =<< trim END
      var = 2345;  // asdf asdf asdf asdf asdf
                   // asdf asdf asdf asdf asdf
                   // asdf asdf
  END
  call assert_equal(expected, getline(1, '$'))

  %del
  let text =<< trim END
      #if 0           // This is another long end of
                      // line comment that
                      // wraps.
  END
  call setline(1, text)
  normal gq2j
  let expected =<< trim END
      #if 0           // This is another long
                      // end of line comment
                      // that wraps.
  END
  call assert_equal(expected, getline(1, '$'))

  " Using either "o" or "O" repeats a line comment occupying a whole line.
  %del
  let text =<< trim END
      nop;
      // This is a comment
      val = val;
  END
  call setline(1, text)
  normal 2Go
  let expected =<< trim END
      nop;
      // This is a comment
      //
      val = val;
  END
  call assert_equal(expected, getline(1, '$'))
  normal 2GO
  let expected =<< trim END
      nop;
      //
      // This is a comment
      //
      val = val;
  END
  call assert_equal(expected, getline(1, '$'))

  " Using "o" repeats a line comment after a statement, "O" does not.
  %del
  let text =<< trim END
      nop;
      val = val;      // This is a comment
  END
  call setline(1, text)
  normal 2Go
  let expected =<< trim END
      nop;
      val = val;      // This is a comment
                      //
  END
  call assert_equal(expected, getline(1, '$'))
  3delete

  " No comment repeated with a slash in 'formatoptions'
  set fo+=/
  normal 2Gox
  let expected =<< trim END
      nop;
      val = val;      // This is a comment
      x
  END
  call assert_equal(expected, getline(1, '$'))

  " Comment is formatted when it wraps
  normal 2GA with some more text added
  let expected =<< trim END
      nop;
      val = val;      // This is a comment
                      // with some more text
                      // added
      x
  END
  call assert_equal(expected, getline(1, '$'))

  set fo-=/

  " using 'indentexpr' instead of 'cindent' does not repeat a comment
  setl nocindent indentexpr=2
  %del
  let text =<< trim END
      nop;
      val = val;      // This is a comment
  END
  call setline(1, text)
  normal 2Gox
  let expected =<< trim END
      nop;
      val = val;      // This is a comment
        x
  END
  call assert_equal(expected, getline(1, '$'))
  setl cindent indentexpr=
  3delete

  normal 2GO
  let expected =<< trim END
      nop;

      val = val;      // This is a comment
  END
  call assert_equal(expected, getline(1, '$'))

  " Using "o" does not repeat a comment in a string
  %del
  let text =<< trim END
      nop;
      val = " // This is not a comment";
  END
  call setline(1, text)
  normal 2Gox
  let expected =<< trim END
      nop;
      val = " // This is not a comment";
      x
  END
  call assert_equal(expected, getline(1, '$'))

  " Using CTRL-U after "o" fixes the indent
  %del
  let text =<< trim END
      {
         val = val;      // This is a comment
  END
  call setline(1, text)
  exe "normal! 2Go\<C-U>x\<Esc>"
  let expected =<< trim END
      {
         val = val;      // This is a comment
         x
  END
  call assert_equal(expected, getline(1, '$'))

  " typing comment text auto-wraps
  %del
  call setline(1, text)
  exe "normal! 2GA blah more text blah.\<Esc>"
  let expected =<< trim END
      {
         val = val;      // This is a comment
                         // blah more text
                         // blah.
  END
  call assert_equal(expected, getline(1, '$'))

  bwipe!
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

  " align text with 'rightleft'
  if has('rightleft')
    new
    call setline(1, 'Vim')
    setlocal rightleft
    left 20
    setlocal norightleft
    call assert_equal("\t\t Vim", getline(1))
    setlocal rightleft
    right
    setlocal norightleft
    call assert_equal("Vim", getline(1))
    close!
  endif

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
func Test_mps_multibyte()
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

" Test for 'matchpairs' in latin1 encoding
func Test_mps_latin1()
  new
  let save_enc = &encoding
  " set encoding=latin1
  call setline(1, 'abc(def)ghi')
  normal %
  call assert_equal(8, col('.'))
  normal %
  call assert_equal(4, col('.'))
  call cursor(1, 6)
  normal [(
  call assert_equal(4, col('.'))
  normal %
  call assert_equal(8, col('.'))
  call cursor(1, 6)
  normal ])
  call assert_equal(8, col('.'))
  normal %
  call assert_equal(4, col('.'))
  let &encoding = save_enc
  close!
endfunc

func Test_empty_matchpairs()
  split
  set matchpairs= showmatch
  call assert_nobeep('call feedkeys("ax\tx\t\<Esc>", "xt")')
  set matchpairs& noshowmatch
  bwipe!
endfunc

func Test_mps_error()
  let encoding_save = &encoding

  " for e in ['utf-8', 'latin1']
  for e in ['utf-8']
    exe 'set encoding=' .. e

    call assert_fails('set mps=<:', 'E474:', e)
    call assert_fails('set mps=:>', 'E474:', e)
    call assert_fails('set mps=<>', 'E474:', e)
    call assert_fails('set mps=<:>_', 'E474:', e)
  endfor

  let &encoding = encoding_save
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

" Test for 'a' and 'w' flags in 'formatoptions'
func Test_fo_a_w()
  new
  setlocal fo+=aw tw=10
  call feedkeys("iabc abc a abc\<Esc>k0weade", 'xt')
  call assert_equal(['abc abcde ', 'a abc'], getline(1, '$'))

  " when a line ends with space, it is not broken up.
  %d
  call feedkeys("ione two to    ", 'xt')
  call assert_equal('one two to    ', getline(1))

  " when a line ends with spaces and backspace is used in the next line, the
  " last space in the previous line should be removed.
  %d
  set backspace=indent,eol,start
  call setline(1, ['one    ', 'two'])
  exe "normal 2Gi\<BS>"
  call assert_equal(['one   two'], getline(1, '$'))
  set backspace&

  " Test for 'a', 'w' and '1' options.
  setlocal textwidth=0
  setlocal fo=1aw
  %d
  call setline(1, '. foo')
  normal 72ig
  call feedkeys('a uu uu uu', 'xt')
  call assert_equal('g uu uu ', getline(1)[-8:])
  call assert_equal(['uu. foo'], getline(2, '$'))

  " using backspace or "x" triggers reformat
  call setline(1, ['1 2 3 4 5 ', '6 7 8 9'])
  set tw=10
  set fo=taw
  set bs=indent,eol,start
  exe "normal 1G4la\<BS>\<BS>\<Esc>"
  call assert_equal(['1 2 4 5 6 ', '7 8 9'], getline(1, 2))
  exe "normal f4xx"
  call assert_equal(['1 2 5 6 7 ', '8 9'], getline(1, 2))

  " using "cw" leaves cursor in right spot
  call setline(1, ['Now we g whether that nation, or',
      \ 'any nation so conceived and,'])
  set fo=tcqa tw=35
  exe "normal 2G0cwx\<Esc>"
  call assert_equal(['Now we g whether that nation, or x', 'nation so conceived and,'], getline(1, 2))

  set tw=0
  set fo&
  %bw!
endfunc

" Test for formatting lines using gq in visual mode
func Test_visual_gq_format()
  new
  call setline(1, ['one two three four', 'five six', 'one two'])
  setl textwidth=10
  call feedkeys('ggv$jj', 'xt')
  redraw!
  normal gq
  %d
  call setline(1, ['one two three four', 'five six', 'one two'])
  normal G$
  call feedkeys('v0kk', 'xt')
  redraw!
  normal gq
  setl textwidth&
  close!
endfunc

" Test for 'n' flag in 'formatoptions' to format numbered lists
func Test_fo_n()
  new
  setlocal autoindent
  setlocal textwidth=12
  setlocal fo=n
  call setline(1, ['  1) one two three four', '  2) two'])
  normal gggqG
  call assert_equal(['  1) one two', '     three', '     four', '  2) two'],
        \ getline(1, '$'))
  close!
endfunc

" Test for 'formatlistpat' option
func Test_formatlistpat()
  new
  setlocal autoindent
  setlocal textwidth=10
  setlocal fo=n
  setlocal formatlistpat=^\\s*-\\s*
  call setline(1, ['  - one two three', '  - two'])
  normal gggqG
  call assert_equal(['  - one', '    two', '    three', '  - two'],
        \ getline(1, '$'))
  close!
endfunc

" Test for the 'b' and 'v' flags in 'formatoptions'
" Text should wrap only if a space character is inserted at or before
" 'textwidth'
func Test_fo_b()
  new
  setlocal textwidth=20

  setlocal formatoptions=t
  call setline(1, 'one two three four')
  call feedkeys('Amore', 'xt')
  call assert_equal(['one two three', 'fourmore'], getline(1, '$'))

  setlocal formatoptions=bt
  %d
  call setline(1, 'one two three four')
  call feedkeys('Amore five', 'xt')
  call assert_equal(['one two three fourmore five'], getline(1, '$'))

  setlocal formatoptions=bt
  %d
  call setline(1, 'one two three four')
  call feedkeys('A five', 'xt')
  call assert_equal(['one two three four', 'five'], getline(1, '$'))

  setlocal formatoptions=vt
  %d
  call setline(1, 'one two three four')
  call feedkeys('Amore five', 'xt')
  call assert_equal(['one two three fourmore', 'five'], getline(1, '$'))

  close!
endfunc

" Test for the '1' flag in 'formatoptions'. Don't wrap text after a one letter
" word.
func Test_fo_1()
  new
  setlocal textwidth=20

  setlocal formatoptions=t
  call setline(1, 'one two three four')
  call feedkeys('A a bird', 'xt')
  call assert_equal(['one two three four a', 'bird'], getline(1, '$'))

  %d
  setlocal formatoptions=t1
  call setline(1, 'one two three four')
  call feedkeys('A a bird', 'xt')
  call assert_equal(['one two three four', 'a bird'], getline(1, '$'))

  close!
endfunc

" Test for 'l' flag in 'formatoptions'. When starting insert mode, if a line
" is longer than 'textwidth', then it is not broken.
func Test_fo_l()
  new
  setlocal textwidth=20

  setlocal formatoptions=t
  call setline(1, 'one two three four five')
  call feedkeys('A six', 'xt')
  call assert_equal(['one two three four', 'five six'], getline(1, '$'))

  %d
  setlocal formatoptions=tl
  call setline(1, 'one two three four five')
  call feedkeys('A six', 'xt')
  call assert_equal(['one two three four five six'], getline(1, '$'))

  close!
endfunc

" Test for the '2' flag in 'formatoptions'
func Test_fo_2()
  new
  setlocal autoindent
  setlocal formatoptions=t2
  setlocal textwidth=30
  call setline(1, ["\tfirst line of a paragraph.",
        \ "second line of the same paragraph.",
        \ "third line."])
  normal gggqG
  call assert_equal(["\tfirst line of a",
        \ "paragraph.  second line of the",
        \ "same paragraph.  third line."], getline(1, '$'))
  close!
endfunc

" This was leaving the cursor after the end of a line.  Complicated way to
" have the problem show up with valgrind.
func Test_correct_cursor_position()
  " set encoding=iso8859
  new
  norm a0000
  sil! norm gggg0i0gw0gg

  bwipe!
  set encoding=utf8
endfunc

" vim: shiftwidth=2 sts=2 expandtab
