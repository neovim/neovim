" Test for matchadd() and conceal feature
if !has('conceal')
  finish
endif

source shared.vim

function! Test_simple_matchadd()
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
endfunction

function! Test_simple_matchadd_and_conceal()
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
endfunction

function! Test_matchadd_and_conceallevel_3()
  new

  setlocal conceallevel=3
  " set filetype and :syntax on to change screenattr()
  setlocal filetype=conf
  syntax on

  1put='# This is a Test'
  "             1234567890123456
  let expect = '#ThisisaTest'

  call cursor(1, 1)
  call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'X'})
  redraw!
  let lnum = 2
  call assert_equal(expect, Screenline(lnum))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 16))

  " more matchadd()
  "             1234567890123456
  let expect = '#Thisisa Test'

  call matchadd('ErrorMsg', '\%2l Test', 20, -1, {'conceal': 'X'})
  redraw!
  call assert_equal(expect, Screenline(lnum))
  call assert_equal(screenattr(lnum, 1) , screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2) , screenattr(lnum, 7))
  call assert_notequal(screenattr(lnum, 1) , screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 10), screenattr(lnum, 12))
  call assert_notequal(screenattr(lnum, 1) , screenattr(lnum, 16))
  call assert_notequal(screenattr(lnum, 10), screenattr(lnum, 16))

  syntax off
  quit!
endfunction

function! Test_default_conceal_char()
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
endfunction

function! Test_syn_and_match_conceal()
  new
  setlocal concealcursor=n conceallevel=1

  1put='# This is a Test'
  "             1234567890123456
  let expect = '#ZThisZisZaZTest'

  call cursor(1, 1)
  call matchadd('Conceal', '\%2l ', 10, -1, {'conceal': 'Z'})
  syntax match MyConceal /\%2l / conceal containedin=ALL cchar=*
  redraw!
  let lnum = 2
  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  "             1234567890123456
  let expect = '#*This*is*a*Test'
  call clearmatches()
  redraw!

  call assert_equal(expect, Screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  syntax off
  quit!
endfunction

function! Test_clearmatches()
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
endfunction

function! Test_using_matchaddpos()
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
endfunction

function! Test_matchadd_repeat_conceal_with_syntax_off()
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
endfunction

function! Test_matchadd_and_syn_conceal()
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
endfunction
