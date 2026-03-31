" Test for matchadd() and conceal feature

source check.vim
CheckFeature conceal

source shared.vim
source term_util.vim
source view_util.vim

func Test_simple_matchadd()
  new

  1put='# This is a Test'
  "             1234567890123456
  let expect = '# This is a Test'

  call cursor(1, 1)
  call matchadd('Conceal', '\%2l ')
  redraw!
  let lnum = 2
  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  quit!
endfunc

func Test_simple_matchadd_and_conceal()
  new
  setlocal concealcursor=n conceallevel=1

  1put='# This is a Test'
  "             1234567890123456
  let expect = '#XThisXisXaXTest'

  call cursor(1, 1)
  call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'X'})
  redraw!
  let lnum = 2
  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  quit!
endfunc

func Test_matchadd_and_conceallevel_3()
  new

  setlocal conceallevel=3
  " set filetype and :syntax on to change screenattr()
  setlocal filetype=conf
  syntax on

  1put='# This is a Test  $'
  "             1234567890123
  let expect = '#ThisisaTest$'

  call cursor(1, 1)
  call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'X'})
  redraw!
  let lnum = 2
  call assert_equal(expect, Screenline(lnum))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 13))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 14))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 16))

  " more matchadd()
  "             12345678901234
  let expect = '#Thisisa Test$'

  call matchadd('ErrorMsg', '\%2l Test', 20, -1, {'conceal': 'X'})
  redraw!
  call assert_equal(expect, Screenline(lnum))
  call assert_equal(screenattr(lnum, 1) , screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 1) , screenattr(lnum, 7))
  call assert_notequal(screenattr(lnum, 1) , screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 10), screenattr(lnum, 13))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 14))
  call assert_notequal(screenattr(lnum, 1) , screenattr(lnum, 16))
  call assert_notequal(screenattr(lnum, 10), screenattr(lnum, 16))

  syntax off
  quit!
endfunc

func Test_default_conceal_char()
  new
  setlocal concealcursor=n conceallevel=1

  1put='# This is a Test'
  "             1234567890123456
  let expect = '# This is a Test'

  call cursor(1, 1)
  call matchadd('Conceal', '\%2l ', 10, -1, {})
  redraw!
  let lnum = 2
  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  "             1234567890123456
  let expect = '#+This+is+a+Test'
  let listchars_save = &listchars
  set listchars=conceal:+
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  let &listchars = listchars_save
  quit!
endfunc

func Test_syn_and_match_conceal()
  new
  setlocal concealcursor=n conceallevel=1

  1put='# This is a Test  '

  let lnum = 2
  call cursor(1, 1)

  "             123456789012345678
  let expect = '#ZThisZisZaZTestZZ'
  call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'Z'})
  syntax match MyConceal /\%2l / conceal containedin=ALL
  hi MyConceal ctermbg=4 ctermfg=2
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  syntax clear MyConceal
  syntax match MyConceal /\%2l / conceal containedin=ALL cchar=*
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  "             123456789012345678
  let expect = '#*This*is*a*Test**'
  call clearmatches()
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  "             123456789012345678
  let expect = '#*ThisXis*a*Test**'
  call matchadd('Conceal', '\%2l\%7c ', 10, -1, {'conceal': 'X'})
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  "             123456789012345678
  let expect = '#*ThisXis*a*Test**'
  call matchadd('ErrorMsg', '\%2l Test', 20, -1)
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_notequal(screenattr(lnum, 12), screenattr(lnum, 13))
  call assert_equal(screenattr(lnum, 13), screenattr(lnum, 16))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 17))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 18))
  call assert_notequal(screenattr(lnum, 18), screenattr(lnum, 19))

  5new | setlocal conceallevel=2 concealcursor=n
  redraw!
  call assert_equal(expect, Screenline(6 + lnum))

  " Syntax conceal shouldn't interfere with matchadd() in another buffer.
  call setline(1, 'foo bar baz')
  call matchadd('Conceal', 'bar')
  redraw!
  call assert_equal('foo  baz', Screenline(1))
  call assert_equal(expect, Screenline(6 + lnum))

  " Syntax conceal shouldn't interfere with matchadd() in the same buffer.
  syntax match MyOtherConceal /foo/ conceal cchar=!
  redraw!
  call assert_equal('!  baz', Screenline(1))
  call assert_equal(expect, Screenline(6 + lnum))

  syntax clear
  redraw!
  call assert_equal('foo  baz', Screenline(1))
  call assert_equal(expect, Screenline(6 + lnum))
  bwipe!

  "             123456789012345678
  let expect = '# ThisXis a Test'
  syntax clear MyConceal
  syntax match MyConceal /\%2l / conceal containedin=ALL
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 12))
  call assert_notequal(screenattr(lnum, 12), screenattr(lnum, 13))
  call assert_equal(screenattr(lnum, 13), screenattr(lnum, 16))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 17))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 18))
  call assert_notequal(screenattr(lnum, 18), screenattr(lnum, 19))

  syntax off
  quit!
endfunc

func Test_clearmatches()
  new
  setlocal concealcursor=n conceallevel=1

  1put='# This is a Test'
  "             1234567890123456
  let expect = '# This is a Test'

  call cursor(1, 1)
  call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'Z'})
  let a = getmatches()
  call clearmatches()
  redraw!

  let lnum = 2
  call assert_equal(expect, Screenline(lnum))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  " reset match using setmatches()
  "             1234567890123456
  let expect = '#ZThisZisZaZTest'
  call setmatches(a)
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))
  call assert_equal({'group': 'Conceal', 'pattern': '\%2l ', 'priority': 10, 'id': a[0].id, 'conceal': 'Z'}, a[0])

  quit!
endfunc

func Test_using_matchaddpos()
  new
  setlocal concealcursor=n conceallevel=1
  " set filetype and :syntax on to change screenattr()
  setlocal filetype=conf
  syntax on

  1put='# This is a Test'
  "             1234567890123456
  let expect = '#Pis a Test'

  call cursor(1, 1)
  call matchaddpos('Conceal', [[2,2,6]], 10, -1, {'conceal': 'P'})
  let a = getmatches()
  redraw!

  let lnum = 2
  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1) , screenattr(lnum, 2))
  call assert_notequal(screenattr(lnum, 2) , screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 1) , screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 1) , screenattr(lnum, 10))
  call assert_notequal(screenattr(lnum, 1) , screenattr(lnum, 12))
  call assert_notequal(screenattr(lnum, 1) , screenattr(lnum, 16))
  call assert_equal(screenattr(lnum, 12), screenattr(lnum, 16))
  call assert_equal({'group': 'Conceal', 'id': a[0].id, 'priority': 10, 'pos1': [2, 2, 6], 'conceal': 'P'}, a[0])

  syntax off
  quit!
endfunc

func Test_matchadd_repeat_conceal_with_syntax_off()
  new

  " To test targets in the same line string is replaced with conceal char
  " correctly, repeat 'TARGET'
  1put ='TARGET_TARGETTARGET'
  call cursor(1, 1)
  redraw
  call assert_equal('TARGET_TARGETTARGET', Screenline(2))

  setlocal conceallevel=2
  call matchadd('Conceal', 'TARGET', 10, -1, {'conceal': 't'})

  redraw
  call assert_equal('t_tt', Screenline(2))

  quit!
endfunc

func Test_matchadd_and_syn_conceal()
  new
  let cnt='Inductive bool : Type := | true : bool | false : bool.'
  let expect = 'Inductive - : Type := | true : - | false : -.'
  0put =cnt
  " set filetype and :syntax on to change screenattr()
  set cole=1 cocu=nv
  hi link CheckedByCoq WarningMsg
  syntax on
  syntax keyword coqKwd bool conceal cchar=-
  redraw!
  call assert_equal(expect, Screenline(1))
  call assert_notequal(screenattr(1, 10) , screenattr(1, 11))
  call assert_notequal(screenattr(1, 11) , screenattr(1, 12))
  call assert_equal(screenattr(1, 11) , screenattr(1, 32))
  call matchadd('CheckedByCoq', '\%<2l\%>9c\%<16c')
  redraw!
  call assert_equal(expect, Screenline(1))
  call assert_notequal(screenattr(1, 10) , screenattr(1, 11))
  call assert_notequal(screenattr(1, 11) , screenattr(1, 12))
  call assert_equal(screenattr(1, 11) , screenattr(1, 32))
endfunc

func Test_interaction_matchadd_syntax()
  new
  " Test for issue #7268 fix.
  " When redrawing the second column, win_line() was comparing the sequence
  " number of the syntax-concealed region with a bogus zero value that was
  " returned for the matchadd-concealed region. Before 8.0.0672 the sequence
  " number was never reset, thus masking the problem.
  call setline(1, 'aaa|bbb|ccc')
  call matchadd('Conceal', '^..', 10, -1, #{conceal: 'X'})
  syn match foobar '^.'
  setl concealcursor=n conceallevel=1
  redraw!

  call assert_equal('Xa|bbb|ccc', Screenline(1))
  call assert_notequal(screenattr(1, 1), screenattr(1, 2))

  bwipe!
endfunc

func Test_cursor_column_in_concealed_line_after_window_scroll()
  CheckRunVimInTerminal

  " Test for issue #5012 fix.
  " For a concealed line with cursor, there should be no window's cursor
  " position invalidation during win_update() after scrolling attempt that is
  " not successful and no real topline change happens. The invalidation would
  " cause a window's cursor position recalc outside of win_line() where it's
  " not possible to take conceal into account.
  let lines =<< trim END
    3split
    let m = matchadd('Conceal', '=')
    setl conceallevel=2 concealcursor=nc
    normal gg
    "==expr==
  END
  call writefile(lines, 'Xcolesearch')
  let buf = RunVimInTerminal('Xcolesearch', {})
  call TermWait(buf, 50)

  " Jump to something that is beyond the bottom of the window,
  " so there's a scroll down.
  call term_sendkeys(buf, ":so %\<CR>")
  call TermWait(buf, 50)
  call term_sendkeys(buf, "/expr\<CR>")
  call TermWait(buf, 50)

  " Are the concealed parts of the current line really hidden?
  let cursor_row = term_scrape(buf, '.')->map({_, e -> e.chars})->join('')
  call assert_equal('"expr', cursor_row)

  " BugFix check: Is the window's cursor column properly updated for hidden
  " parts of the current line?
  call assert_equal(2, term_getcursor(buf)[1])

  call StopVimInTerminal(buf)
  call delete('Xcolesearch')
endfunc

func Test_cursor_column_in_concealed_line_after_leftcol_change()
  CheckRunVimInTerminal

  " Test for issue #5214 fix.
  let lines =<< trim END
    0put = 'ab' .. repeat('-', &columns) .. 'c'
    call matchadd('Conceal', '-')
    set nowrap ss=0 cole=3 cocu=n
  END
  call writefile(lines, 'Xcurs-columns')
  let buf = RunVimInTerminal('-S Xcurs-columns', {})

  " Go to the end of the line (3 columns beyond the end of the screen).
  " Horizontal scroll would center the cursor in the screen line, but conceal
  " makes it go to screen column 1.
  call term_sendkeys(buf, "$")
  call TermWait(buf)

  " Are the concealed parts of the current line really hidden?
  call WaitForAssert({-> assert_equal('c', term_getline(buf, '.'))})

  " BugFix check: Is the window's cursor column properly updated for conceal?
  call assert_equal(1, term_getcursor(buf)[1])

  call StopVimInTerminal(buf)
  call delete('Xcurs-columns')
endfunc
