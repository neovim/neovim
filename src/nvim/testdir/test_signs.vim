" Test for signs

if !has('signs')
  finish
endif

func Test_sign()
  new
  call setline(1, ['a', 'b', 'c', 'd'])

  " Define some signs.
  " We can specify icons even if not all versions of vim support icons as
  " icon is ignored when not supported.  "(not supported)" is shown after
  " the icon name when listing signs.
  sign define Sign1 text=x
  try
    sign define Sign2 text=xy texthl=Title linehl=Error numhl=Number icon=../../pixmaps/stock_vim_find_help.png
  catch /E255:/
    " Ignore error: E255: Couldn't read in sign data!
    " This error can happen when running in the GUI.
    " Some gui like Motif do not support the png icon format.
  endtry

  " Test listing signs.
  let a=execute('sign list')
  call assert_match("^\nsign Sign1 text=x \nsign Sign2 icon=../../pixmaps/stock_vim_find_help.png .*text=xy linehl=Error texthl=Title numhl=Number$", a)

  let a=execute('sign list Sign1')
  call assert_equal("\nsign Sign1 text=x ", a)

  " Split the window to the bottom to verify sign jump will stay in the current window
  " if the buffer is displayed there.
  let bn = bufnr('%')
  let wn = winnr()
  exe 'sign place 41 line=3 name=Sign1 buffer=' . bn 
  1
  bot split
  exe 'sign jump 41 buffer=' . bufnr('%')
  call assert_equal('c', getline('.'))
  call assert_equal(3, winnr())
  call assert_equal(bn, bufnr('%'))
  call assert_notequal(wn, winnr())

  " Create a new buffer and check that ":sign jump" switches to the old buffer.
  1
  new foo
  call assert_notequal(bn, bufnr('%'))
  exe 'sign jump 41 buffer=' . bn
  call assert_equal(bn, bufnr('%'))
  call assert_equal('c', getline('.'))

  " Redraw to make sure that screen redraw with sign gets exercised,
  " with and without 'rightleft'.
  if has('rightleft')
    set rightleft
    redraw
    set norightleft
  endif
  redraw

  " Check that we can't change sign.
  call assert_fails("exe 'sign place 40 name=Sign1 buffer=' . bufnr('%')", 'E885:')

  " Check placed signs
  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\nSigns for [NULL]:\n    line=3  id=41  name=Sign1 priority=10\n", a)

  " Unplace the sign and try jumping to it again should fail.
  sign unplace 41
  1
  call assert_fails("exe 'sign jump 41 buffer=' . bufnr('%')", 'E157:')
  call assert_equal('a', getline('.'))

  " Unplace sign on current line.
  exe 'sign place 42 line=4 name=Sign2 buffer=' . bufnr('%')
  4
  sign unplace
  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\n", a)
  
  " Try again to unplace sign on current line, it should fail this time.
  call assert_fails('sign unplace', 'E159:')

  " Unplace all signs.
  exe 'sign place 41 line=3 name=Sign1 buffer=' . bufnr('%')
  sign unplace *
  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\n", a)

  " Check :jump with file=...
  edit foo
  call setline(1, ['A', 'B', 'C', 'D'])

  try
    sign define Sign3 text=y texthl=DoesNotExist linehl=DoesNotExist icon=doesnotexist.xpm
  catch /E255:/
    " ignore error: E255: it can happens for guis.
  endtry

  let fn = expand('%:p')
  exe 'sign place 43 line=2 name=Sign3 file=' . fn
  edit bar
  call assert_notequal(fn, expand('%:p'))
  exe 'sign jump 43 file=' . fn
  call assert_equal('B', getline('.'))

  " can't define a sign with a non-printable character as text
  call assert_fails("sign define Sign4 text=\e linehl=Comment", 'E239:')
  call assert_fails("sign define Sign4 text=a\e linehl=Comment", 'E239:')
  call assert_fails("sign define Sign4 text=\ea linehl=Comment", 'E239:')

  " Only 1 or 2 character text is allowed
  call assert_fails("sign define Sign4 text=abc linehl=Comment", 'E239:')
  call assert_fails("sign define Sign4 text= linehl=Comment", 'E239:')
  call assert_fails("sign define Sign4 text=\\ ab  linehl=Comment", 'E239:')

  " define sign with whitespace
  sign define Sign4 text=\ X linehl=Comment
  sign undefine Sign4
  sign define Sign4 linehl=Comment text=\ X
  sign undefine Sign4

  sign define Sign5 text=X\  linehl=Comment
  sign undefine Sign5
  sign define Sign5 linehl=Comment text=X\ 
  sign undefine Sign5

  " define sign with backslash
  sign define Sign4 text=\\\\ linehl=Comment
  sign undefine Sign4
  sign define Sign4 text=\\ linehl=Comment
  sign undefine Sign4

  " Error cases
  call assert_fails("exe 'sign place abc line=3 name=Sign1 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("exe 'sign unplace abc name=Sign1 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("exe 'sign place 1abc line=3 name=Sign1 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("exe 'sign unplace 2abc name=Sign1 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("sign unplace 2 *", 'E474:')
  call assert_fails("exe 'sign place 1 line=3 name=Sign1 buffer=' . bufnr('%') a", 'E488:')
  call assert_fails("exe 'sign place name=Sign1 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("exe 'sign place line=10 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("exe 'sign unplace 2 line=10 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("exe 'sign unplace 2 name=Sign1 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("exe 'sign place 2 line=3 buffer=' . bufnr('%')", 'E474:')
  call assert_fails("sign place 2", 'E474:')
  call assert_fails("sign place abc", 'E474:')
  call assert_fails("sign place 5 line=3", 'E474:')
  call assert_fails("sign place 5 name=Sign1", 'E474:')
  call assert_fails("sign place 5 group=g1", 'E474:')
  call assert_fails("sign place 5 group=*", 'E474:')
  call assert_fails("sign place 5 priority=10", 'E474:')
  call assert_fails("sign place 5 line=3 name=Sign1", 'E474:')
  call assert_fails("sign place 5 group=g1 line=3 name=Sign1", 'E474:')

  " After undefining the sign, we should no longer be able to place it.
  sign undefine Sign1
  sign undefine Sign2
  sign undefine Sign3
  call assert_fails("exe 'sign place 41 line=3 name=Sign1 buffer=' . bufnr('%')", 'E155:')
endfunc

" Undefining placed sign is not recommended.
" Quoting :help sign
"
" :sign undefine {name}
"                Deletes a previously defined sign.  If signs with this {name}
"                are still placed this will cause trouble.
func Test_sign_undefine_still_placed()
  new foobar
  sign define Sign text=x
  exe 'sign place 41 line=1 name=Sign buffer=' . bufnr('%')
  sign undefine Sign

  " Listing placed sign should show that sign is deleted.
  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\nSigns for foobar:\n    line=1  id=41  name=[Deleted] priority=10\n", a)

  sign unplace 41
  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\n", a)
endfunc

func Test_sign_completion()
  sign define Sign1 text=x
  sign define Sign2 text=y

  call feedkeys(":sign \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign define jump list place undefine unplace', @:)

  call feedkeys(":sign define Sign \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign define Sign icon= linehl= numhl= text= texthl=', @:)

  call feedkeys(":sign define Sign linehl=Spell\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign define Sign linehl=SpellBad SpellCap SpellLocal SpellRare', @:)

  call writefile(['foo'], 'XsignOne')
  call writefile(['bar'], 'XsignTwo')
  call feedkeys(":sign define Sign icon=Xsig\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign define Sign icon=XsignOne XsignTwo', @:)
  call delete('XsignOne')
  call delete('XsignTwo')

  call feedkeys(":sign undefine \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign undefine Sign1 Sign2', @:)

  call feedkeys(":sign place 1 \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place 1 buffer= file= line= name=', @:)

  call feedkeys(":sign place 1 name=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place 1 name=Sign1 Sign2', @:)

  call feedkeys(":sign unplace 1 \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign unplace 1 buffer= file=', @:)

  call feedkeys(":sign list \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign list Sign1 Sign2', @:)

  call feedkeys(":sign jump 1 \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign jump 1 buffer= file=', @:)

  sign undefine Sign1
  sign undefine Sign2
endfunc

func Test_sign_invalid_commands()
  sign define Sign1 text=x

  call assert_fails('sign', 'E471:')
  call assert_fails('sign jump', 'E471:')
  call assert_fails('sign xxx', 'E160:')
  call assert_fails('sign define', 'E156:')
  call assert_fails('sign define Sign1 xxx', 'E475:')
  call assert_fails('sign undefine', 'E156:')
  call assert_fails('sign list xxx', 'E155:')
  call assert_fails('sign place 1 buffer=999', 'E158:')
  call assert_fails('sign define Sign2 text=', 'E239:')
  " Non-numeric identifier for :sign place
  call assert_fails("exe 'sign place abc line=3 name=Sign1 buffer=' . bufnr('%')", 'E474:')
  " Non-numeric identifier for :sign unplace
  call assert_fails("exe 'sign unplace abc name=Sign1 buffer=' . bufnr('%')", 'E474:')
  " Number followed by an alphabet as sign identifier for :sign place
  call assert_fails("exe 'sign place 1abc line=3 name=Sign1 buffer=' . bufnr('%')", 'E474:')
  " Number followed by an alphabet as sign identifier for :sign unplace
  call assert_fails("exe 'sign unplace 2abc name=Sign1 buffer=' . bufnr('%')", 'E474:')
  " Sign identifier and '*' for :sign unplace
  call assert_fails("sign unplace 2 *", 'E474:')
  " Trailing characters after buffer number for :sign place
  call assert_fails("exe 'sign place 1 line=3 name=Sign1 buffer=' . bufnr('%') . 'xxx'", 'E488:')
  " Trailing characters after buffer number for :sign unplace
  call assert_fails("exe 'sign unplace 1 buffer=' . bufnr('%') . 'xxx'", 'E488:')
  call assert_fails("exe 'sign unplace * buffer=' . bufnr('%') . 'xxx'", 'E488:')
  call assert_fails("sign unplace 1 xxx", 'E474:')
  call assert_fails("sign unplace * xxx", 'E474:')
  call assert_fails("sign unplace xxx", 'E474:')
  " Placing a sign without line number
  call assert_fails("exe 'sign place name=Sign1 buffer=' . bufnr('%')", 'E474:')
  " Placing a sign without sign name
  call assert_fails("exe 'sign place line=10 buffer=' . bufnr('%')", 'E474:')
  " Unplacing a sign with line number
  call assert_fails("exe 'sign unplace 2 line=10 buffer=' . bufnr('%')", 'E474:')
  " Unplacing a sign with sign name
  call assert_fails("exe 'sign unplace 2 name=Sign1 buffer=' . bufnr('%')", 'E474:')
  " Placing a sign without sign name
  call assert_fails("exe 'sign place 2 line=3 buffer=' . bufnr('%')", 'E474:')
  " Placing a sign with only sign identifier
  call assert_fails("sign place 2", 'E474:')
  " Placing a sign with only a name
  call assert_fails("sign place abc", 'E474:')
  " Placing a sign with only line number
  call assert_fails("sign place 5 line=3", 'E474:')
  " Placing a sign with only sign name
  call assert_fails("sign place 5 name=Sign1", 'E474:')
  " Placing a sign with only sign group
  call assert_fails("sign place 5 group=g1", 'E474:')
  call assert_fails("sign place 5 group=*", 'E474:')
  " Placing a sign with only sign priority
  call assert_fails("sign place 5 priority=10", 'E474:')
  " Placing a sign without buffer number or file name
  call assert_fails("sign place 5 line=3 name=Sign1", 'E474:')
  call assert_fails("sign place 5 group=g1 line=3 name=Sign1", 'E474:')

  sign undefine Sign1
endfunc

func Test_sign_delete_buffer()
  new
  sign define Sign text=x
  let bufnr = bufnr('%')
  new
  exe 'bd ' . bufnr
  exe 'sign place 61 line=3 name=Sign buffer=' . bufnr
  call assert_fails('sign jump 61 buffer=' . bufnr, 'E934:')
  sign unplace 61
  sign undefine Sign
endfunc

" Test for VimL functions for managing signs
func Test_sign_funcs()
  " Remove all the signs
  call sign_unplace('*')
  call sign_undefine()

  " Tests for sign_define()
  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Error'}
  call assert_equal(0, sign_define("sign1", attr))
  call assert_equal([{'name' : 'sign1', 'texthl' : 'Error',
	      \ 'linehl' : 'Search', 'text' : '=>'}], sign_getdefined())

  " Define a new sign without attributes and then update it
  call sign_define("sign2")
  let attr = {'text' : '!!', 'linehl' : 'DiffAdd', 'texthl' : 'DiffChange',
	      \ 'icon' : 'sign2.ico'}
  try
    call sign_define("sign2", attr)
  catch /E255:/
    " ignore error: E255: Couldn't read in sign data!
    " This error can happen when running in gui.
  endtry
  call assert_equal([{'name' : 'sign2', 'texthl' : 'DiffChange',
	      \ 'linehl' : 'DiffAdd', 'text' : '!!', 'icon' : 'sign2.ico'}],
	      \ sign_getdefined("sign2"))

  " Test for a sign name with digits
  call assert_equal(0, sign_define(0002, {'linehl' : 'StatusLine'}))
  call assert_equal([{'name' : '2', 'linehl' : 'StatusLine'}],
	      \ sign_getdefined(0002))
  call sign_undefine(0002)

  " Tests for invalid arguments to sign_define()
  call assert_fails('call sign_define("sign4", {"text" : "===>"})', 'E239:')
  call assert_fails('call sign_define("sign5", {"text" : ""})', 'E239:')
  call assert_fails('call sign_define([])', 'E730:')
  call assert_fails('call sign_define("sign6", [])', 'E715:')

  " Tests for sign_getdefined()
  call assert_equal([], sign_getdefined("none"))
  call assert_fails('call sign_getdefined({})', 'E731:')

  " Tests for sign_place()
  call writefile(repeat(["Sun is shining"], 30), "Xsign")
  edit Xsign

  call assert_equal(10, sign_place(10, '', 'sign1', 'Xsign',
	      \ {'lnum' : 20}))
  call assert_equal([{'bufnr' : bufnr(''), 'signs' :
	      \ [{'id' : 10, 'group' : '', 'lnum' : 20, 'name' : 'sign1',
	      \ 'priority' : 10}]}], sign_getplaced('Xsign'))
  call assert_equal([{'bufnr' : bufnr(''), 'signs' :
	      \ [{'id' : 10, 'group' : '', 'lnum' : 20, 'name' : 'sign1',
	      \ 'priority' : 10}]}],
	      \ sign_getplaced('Xsign', {'lnum' : 20}))
  call assert_equal([{'bufnr' : bufnr(''), 'signs' :
	      \ [{'id' : 10, 'group' : '', 'lnum' : 20, 'name' : 'sign1',
	      \ 'priority' : 10}]}],
	      \ sign_getplaced('Xsign', {'id' : 10}))

  " Tests for invalid arguments to sign_place()
  call assert_fails('call sign_place([], "", "mySign", 1)', 'E745:')
  call assert_fails('call sign_place(5, "", "mySign", -1)', 'E158:')
  call assert_fails('call sign_place(-1, "", "sign1", "Xsign", [])',
	      \ 'E474:')
  call assert_fails('call sign_place(-1, "", "sign1", "Xsign",
	      \ {"lnum" : 30})', 'E474:')
  call assert_fails('call sign_place(10, "", "xsign1x", "Xsign",
	      \ {"lnum" : 30})', 'E155:')
  call assert_fails('call sign_place(10, "", "", "Xsign",
	      \ {"lnum" : 30})', 'E155:')
  call assert_fails('call sign_place(10, "", [], "Xsign",
	      \ {"lnum" : 30})', 'E730:')
  call assert_fails('call sign_place(5, "", "sign1", "abcxyz.xxx",
	      \ {"lnum" : 10})', 'E158:')
  call assert_fails('call sign_place(5, "", "sign1", "", {"lnum" : 10})',
	      \ 'E158:')
  call assert_fails('call sign_place(5, "", "sign1", [], {"lnum" : 10})',
	      \ 'E158:')
  call assert_fails('call sign_place(21, "", "sign1", "Xsign",
	      \ {"lnum" : -1})', 'E885:')
  call assert_fails('call sign_place(22, "", "sign1", "Xsign",
	      \ {"lnum" : 0})', 'E885:')
  call assert_equal(-1, sign_place(1, "*", "sign1", "Xsign", {"lnum" : 10}))

  " Tests for sign_getplaced()
  call assert_equal([{'bufnr' : bufnr(''), 'signs' :
	      \ [{'id' : 10, 'group' : '', 'lnum' : 20, 'name' : 'sign1',
	      \ 'priority' : 10}]}],
	      \ sign_getplaced(bufnr('Xsign')))
  call assert_equal([{'bufnr' : bufnr(''), 'signs' :
	      \ [{'id' : 10, 'group' : '', 'lnum' : 20, 'name' : 'sign1',
	      \ 'priority' : 10}]}],
	      \ sign_getplaced())
  call assert_fails("call sign_getplaced('dummy.sign')", 'E158:')
  call assert_fails('call sign_getplaced("")', 'E158:')
  call assert_fails('call sign_getplaced(-1)', 'E158:')
  call assert_fails('call sign_getplaced("Xsign", [])', 'E715:')
  call assert_equal([{'bufnr' : bufnr(''), 'signs' : []}],
	      \ sign_getplaced('Xsign', {'lnum' : 1000000}))
  call assert_fails("call sign_getplaced('Xsign', {'lnum' : []})",
	      \ 'E745:')
  call assert_equal([{'bufnr' : bufnr(''), 'signs' : []}],
	      \ sign_getplaced('Xsign', {'id' : 44}))
  call assert_fails("call sign_getplaced('Xsign', {'id' : []})",
	      \ 'E745:')

  " Tests for sign_unplace()
  call sign_place(20, '', 'sign2', 'Xsign', {"lnum" : 30})
  call assert_equal(0, sign_unplace('',
	      \ {'id' : 20, 'buffer' : 'Xsign'}))
  call assert_equal(-1, sign_unplace('',
	      \ {'id' : 30, 'buffer' : 'Xsign'}))
  call sign_place(20, '', 'sign2', 'Xsign', {"lnum" : 30})
  call assert_fails("call sign_unplace('',
	      \ {'id' : 20, 'buffer' : 'buffer.c'})", 'E158:')
  call assert_fails("call sign_unplace('',
	      \ {'id' : 20, 'buffer' : ''})", 'E158:')
  call assert_fails("call sign_unplace('',
	      \ {'id' : 20, 'buffer' : 200})", 'E158:')
  call assert_fails("call sign_unplace('', 'mySign')", 'E715:')

  " Tests for sign_undefine()
  call assert_equal(0, sign_undefine("sign1"))
  call assert_equal([], sign_getdefined("sign1"))
  call assert_fails('call sign_undefine("none")', 'E155:')
  call assert_fails('call sign_undefine([])', 'E730:')

  call delete("Xsign")
  call sign_unplace('*')
  call sign_undefine()
  enew | only
endfunc

" Tests for sign groups
func Test_sign_group()
  enew | only
  " Remove all the signs
  call sign_unplace('*')
  call sign_undefine()

  call writefile(repeat(["Sun is shining"], 30), "Xsign")

  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Error'}
  call assert_equal(0, sign_define("sign1", attr))

  edit Xsign
  let bnum = bufnr('%')
  let fname = fnamemodify('Xsign', ':p')

  " Error case
  call assert_fails("call sign_place(5, [], 'sign1', 'Xsign',
	      \ {'lnum' : 30})", 'E730:')

  " place three signs with the same identifier. One in the global group and
  " others in the named groups
  call assert_equal(5, sign_place(5, '', 'sign1', 'Xsign',
	      \ {'lnum' : 10}))
  call assert_equal(5, sign_place(5, 'g1', 'sign1', bnum, {'lnum' : 20}))
  call assert_equal(5, sign_place(5, 'g2', 'sign1', bnum, {'lnum' : 30}))

  " Test for sign_getplaced() with group
  let s = sign_getplaced('Xsign')
  call assert_equal(1, len(s[0].signs))
  call assert_equal(s[0].signs[0].group, '')
  let s = sign_getplaced(bnum, {'group' : 'g2'})
  call assert_equal('g2', s[0].signs[0].group)
  let s = sign_getplaced(bnum, {'group' : 'g3'})
  call assert_equal([], s[0].signs)
  let s = sign_getplaced(bnum, {'group' : '*'})
  call assert_equal([{'id' : 5, 'group' : '', 'name' : 'sign1', 'lnum' : 10,
	      \ 'priority' : 10},
	      \ {'id' : 5, 'group' : 'g1', 'name' : 'sign1', 'lnum' : 20,
	      \  'priority' : 10},
	      \ {'id' : 5, 'group' : 'g2', 'name' : 'sign1', 'lnum' : 30,
	      \  'priority' : 10}],
	      \ s[0].signs)

  " Test for sign_getplaced() with id
  let s = sign_getplaced(bnum, {'id' : 5})
  call assert_equal([{'id' : 5, 'group' : '', 'name' : 'sign1', 'lnum' : 10,
	      \ 'priority' : 10}],
	      \ s[0].signs)
  let s = sign_getplaced(bnum, {'id' : 5, 'group' : 'g2'})
  call assert_equal(
	      \ [{'id' : 5, 'name' : 'sign1', 'lnum' : 30, 'group' : 'g2',
	      \ 'priority' : 10}],
	      \ s[0].signs)
  let s = sign_getplaced(bnum, {'id' : 5, 'group' : '*'})
  call assert_equal([{'id' : 5, 'group' : '', 'name' : 'sign1', 'lnum' : 10,
	      \ 'priority' : 10},
	      \ {'id' : 5, 'group' : 'g1', 'name' : 'sign1', 'lnum' : 20,
	      \ 'priority' : 10},
	      \ {'id' : 5, 'group' : 'g2', 'name' : 'sign1', 'lnum' : 30,
	      \ 'priority' : 10}],
	      \ s[0].signs)
  let s = sign_getplaced(bnum, {'id' : 5, 'group' : 'g3'})
  call assert_equal([], s[0].signs)

  " Test for sign_getplaced() with lnum
  let s = sign_getplaced(bnum, {'lnum' : 20})
  call assert_equal([], s[0].signs)
  let s = sign_getplaced(bnum, {'lnum' : 20, 'group' : 'g1'})
  call assert_equal(
	      \ [{'id' : 5, 'name' : 'sign1', 'lnum' : 20, 'group' : 'g1',
	      \ 'priority' : 10}],
	      \ s[0].signs)
  let s = sign_getplaced(bnum, {'lnum' : 30, 'group' : '*'})
  call assert_equal(
	      \ [{'id' : 5, 'name' : 'sign1', 'lnum' : 30, 'group' : 'g2',
	      \ 'priority' : 10}],
	      \ s[0].signs)
  let s = sign_getplaced(bnum, {'lnum' : 40, 'group' : '*'})
  call assert_equal([], s[0].signs)

  " Error case
  call assert_fails("call sign_getplaced(bnum, {'group' : []})",
	      \ 'E730:')

  " Clear the sign in global group
  call sign_unplace('', {'id' : 5, 'buffer' : bnum})
  let s = sign_getplaced(bnum, {'group' : '*'})
  call assert_equal([
	      \ {'id' : 5, 'name' : 'sign1', 'lnum' : 20, 'group' : 'g1',
	      \ 'priority' : 10},
	      \ {'id' : 5, 'name' : 'sign1', 'lnum' : 30, 'group' : 'g2',
	      \ 'priority' : 10}],
	      \ s[0].signs)

  " Clear the sign in one of the groups
  call sign_unplace('g1', {'buffer' : 'Xsign'})
  let s = sign_getplaced(bnum, {'group' : '*'})
  call assert_equal([
	      \ {'id' : 5, 'name' : 'sign1', 'lnum' : 30, 'group' : 'g2',
	      \ 'priority' : 10}],
	      \ s[0].signs)

  " Clear all the signs from the buffer
  call sign_unplace('*', {'buffer' : bnum})
  call assert_equal([], sign_getplaced(bnum, {'group' : '*'})[0].signs)

  " Clear sign across groups using an identifier
  call sign_place(25, '', 'sign1', bnum, {'lnum' : 10})
  call sign_place(25, 'g1', 'sign1', bnum, {'lnum' : 11})
  call sign_place(25, 'g2', 'sign1', bnum, {'lnum' : 12})
  call assert_equal(0, sign_unplace('*', {'id' : 25}))
  call assert_equal([], sign_getplaced(bnum, {'group' : '*'})[0].signs)

  " Error case
  call assert_fails("call sign_unplace([])", 'E474:')

  " Place a sign in the global group and try to delete it using a group
  call assert_equal(5, sign_place(5, '', 'sign1', bnum, {'lnum' : 10}))
  call assert_equal(-1, sign_unplace('g1', {'id' : 5}))

  " Place signs in multiple groups and delete all the signs in one of the
  " group
  call assert_equal(5, sign_place(5, '', 'sign1', bnum, {'lnum' : 10}))
  call assert_equal(6, sign_place(6, '', 'sign1', bnum, {'lnum' : 11}))
  call assert_equal(5, sign_place(5, 'g1', 'sign1', bnum, {'lnum' : 10}))
  call assert_equal(5, sign_place(5, 'g2', 'sign1', bnum, {'lnum' : 10}))
  call assert_equal(6, sign_place(6, 'g1', 'sign1', bnum, {'lnum' : 11}))
  call assert_equal(6, sign_place(6, 'g2', 'sign1', bnum, {'lnum' : 11}))
  call assert_equal(0, sign_unplace('g1'))
  let s = sign_getplaced(bnum, {'group' : 'g1'})
  call assert_equal([], s[0].signs)
  let s = sign_getplaced(bnum)
  call assert_equal(2, len(s[0].signs))
  let s = sign_getplaced(bnum, {'group' : 'g2'})
  call assert_equal('g2', s[0].signs[0].group)
  call assert_equal(0, sign_unplace('', {'id' : 5}))
  call assert_equal(0, sign_unplace('', {'id' : 6}))
  let s = sign_getplaced(bnum, {'group' : 'g2'})
  call assert_equal('g2', s[0].signs[0].group)
  call assert_equal(0, sign_unplace('', {'buffer' : bnum}))

  call sign_unplace('*')

  " Test for :sign command and groups
  exe 'sign place 5 line=10 name=sign1 file=' . fname
  exe 'sign place 5 group=g1 line=10 name=sign1 file=' . fname
  exe 'sign place 5 group=g2 line=10 name=sign1 file=' . fname

  " Test for :sign place group={group} file={fname}
  let a = execute('sign place file=' . fname)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n    line=10  id=5  name=sign1 priority=10\n", a)

  let a = execute('sign place group=g2 file=' . fname)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n    line=10  id=5  group=g2  name=sign1 priority=10\n", a)

  let a = execute('sign place group=* file=' . fname)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  group=g2  name=sign1 priority=10\n" .
	      \ "    line=10  id=5  group=g1  name=sign1 priority=10\n" .
	      \ "    line=10  id=5  name=sign1 priority=10\n", a)

  let a = execute('sign place group=xyz file=' . fname)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n", a)

  call sign_unplace('*')

  " Test for :sign place group={group} buffer={nr}
  let bnum = bufnr('Xsign')
  exe 'sign place 5 line=10 name=sign1 buffer=' . bnum
  exe 'sign place 5 group=g1 line=11 name=sign1 buffer=' . bnum
  exe 'sign place 5 group=g2 line=12 name=sign1 buffer=' . bnum

  let a = execute('sign place buffer=' . bnum)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n    line=10  id=5  name=sign1 priority=10\n", a)

  let a = execute('sign place group=g2 buffer=' . bnum)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n    line=12  id=5  group=g2  name=sign1 priority=10\n", a)

  let a = execute('sign place group=* buffer=' . bnum)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1 priority=10\n" .
	      \ "    line=11  id=5  group=g1  name=sign1 priority=10\n" .
	      \ "    line=12  id=5  group=g2  name=sign1 priority=10\n", a)

  let a = execute('sign place group=xyz buffer=' . bnum)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n", a)

  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1 priority=10\n" .
	      \ "    line=11  id=5  group=g1  name=sign1 priority=10\n" .
	      \ "    line=12  id=5  group=g2  name=sign1 priority=10\n", a)

  " Test for :sign unplace
  exe 'sign unplace 5 group=g2 file=' . fname
  call assert_equal([], sign_getplaced(bnum, {'group' : 'g2'})[0].signs)

  exe 'sign unplace 5 group=g1 buffer=' . bnum
  call assert_equal([], sign_getplaced(bnum, {'group' : 'g1'})[0].signs)

  exe 'sign unplace 5 group=xy file=' . fname
  call assert_equal(1, len(sign_getplaced(bnum, {'group' : '*'})[0].signs))

  " Test for removing all the signs. Place the signs again for this test
  exe 'sign place 5 group=g1 line=11 name=sign1 file=' . fname
  exe 'sign place 5 group=g2 line=12 name=sign1 file=' . fname
  exe 'sign place 6 line=20 name=sign1 file=' . fname
  exe 'sign place 6 group=g1 line=21 name=sign1 file=' . fname
  exe 'sign place 6 group=g2 line=22 name=sign1 file=' . fname
  exe 'sign unplace 5 group=* file=' . fname
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=20  id=6  name=sign1 priority=10\n" .
	      \ "    line=21  id=6  group=g1  name=sign1 priority=10\n" .
	      \ "    line=22  id=6  group=g2  name=sign1 priority=10\n", a)

  " Remove all the signs from the global group
  exe 'sign unplace * file=' . fname
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=21  id=6  group=g1  name=sign1 priority=10\n" .
	      \ "    line=22  id=6  group=g2  name=sign1 priority=10\n", a)

  " Remove all the signs from a particular group
  exe 'sign place 5 line=10 name=sign1 file=' . fname
  exe 'sign place 5 group=g1 line=11 name=sign1 file=' . fname
  exe 'sign place 5 group=g2 line=12 name=sign1 file=' . fname
  exe 'sign unplace * group=g1 file=' . fname
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1 priority=10\n" .
	      \ "    line=12  id=5  group=g2  name=sign1 priority=10\n" .
	      \ "    line=22  id=6  group=g2  name=sign1 priority=10\n", a)

  " Remove all the signs from all the groups in a file
  exe 'sign place 5 group=g1 line=11 name=sign1 file=' . fname
  exe 'sign place 6 line=20 name=sign1 file=' . fname
  exe 'sign place 6 group=g1 line=21 name=sign1 file=' . fname
  exe 'sign unplace * group=* file=' . fname
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\n", a)

  " Remove a particular sign id in a group from all the files
  exe 'sign place 5 group=g1 line=11 name=sign1 file=' . fname
  sign unplace 5 group=g1
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\n", a)

  " Remove a particular sign id in all the groups from all the files
  exe 'sign place 5 line=10 name=sign1 file=' . fname
  exe 'sign place 5 group=g1 line=11 name=sign1 file=' . fname
  exe 'sign place 5 group=g2 line=12 name=sign1 file=' . fname
  exe 'sign place 6 line=20 name=sign1 file=' . fname
  exe 'sign place 6 group=g1 line=21 name=sign1 file=' . fname
  exe 'sign place 6 group=g2 line=22 name=sign1 file=' . fname
  sign unplace 5 group=*
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=20  id=6  name=sign1 priority=10\n" .
	      \ "    line=21  id=6  group=g1  name=sign1 priority=10\n" .
	      \ "    line=22  id=6  group=g2  name=sign1 priority=10\n", a)

  " Remove all the signs from all the groups in all the files
  exe 'sign place 5 line=10 name=sign1 file=' . fname
  exe 'sign place 5 group=g1 line=11 name=sign1 file=' . fname
  sign unplace * group=*
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\n", a)

  " Error cases
  call assert_fails("exe 'sign place 3 group= name=sign1 buffer=' . bnum", 'E474:')

  call delete("Xsign")
  call sign_unplace('*')
  call sign_undefine()
  enew  | only
endfunc

" Tests for auto-generating the sign identifier
func Test_sign_id_autogen()
  enew | only
  call sign_unplace('*')
  call sign_undefine()

  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Error'}
  call assert_equal(0, sign_define("sign1", attr))

  call writefile(repeat(["Sun is shining"], 30), "Xsign")
  edit Xsign

  call assert_equal(1, sign_place(0, '', 'sign1', 'Xsign',
	      \ {'lnum' : 10}))
  call assert_equal(2, sign_place(2, '', 'sign1', 'Xsign',
	      \ {'lnum' : 12}))
  call assert_equal(3, sign_place(0, '', 'sign1', 'Xsign',
	      \ {'lnum' : 14}))
  call sign_unplace('', {'buffer' : 'Xsign', 'id' : 2})
  call assert_equal(2, sign_place(0, '', 'sign1', 'Xsign',
	      \ {'lnum' : 12}))

  call assert_equal(1, sign_place(0, 'g1', 'sign1', 'Xsign',
	      \ {'lnum' : 11}))
  call assert_equal(0, sign_unplace('g1', {'id' : 1}))
  call assert_equal(10,
	      \ sign_getplaced('Xsign', {'id' : 1})[0].signs[0].lnum)

  call delete("Xsign")
  call sign_unplace('*')
  call sign_undefine()
  enew  | only
endfunc

" Test for sign priority
func Test_sign_priority()
  enew | only
  call sign_unplace('*')
  call sign_undefine()

  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Search'}
  call sign_define("sign1", attr)
  call sign_define("sign2", attr)
  call sign_define("sign3", attr)

  " Place three signs with different priority in the same line
  call writefile(repeat(["Sun is shining"], 30), "Xsign")
  edit Xsign
  let fname = fnamemodify('Xsign', ':p')

  call sign_place(1, 'g1', 'sign1', 'Xsign',
	      \ {'lnum' : 11, 'priority' : 50})
  call sign_place(2, 'g2', 'sign2', 'Xsign',
	      \ {'lnum' : 11, 'priority' : 100})
  call sign_place(3, '', 'sign3', 'Xsign', {'lnum' : 11})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 11, 'group' : 'g2',
	      \ 'priority' : 100},
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 11, 'group' : 'g1',
	      \ 'priority' : 50},
	      \ {'id' : 3, 'name' : 'sign3', 'lnum' : 11, 'group' : '',
	      \ 'priority' : 10}],
	      \ s[0].signs)

  " Error case
  call assert_fails("call sign_place(1, 'g1', 'sign1', 'Xsign',
	      \ [])", 'E715:')
  call sign_unplace('*')

  " Tests for the :sign place command with priority
  sign place 5 line=10 name=sign1 priority=30 file=Xsign
  sign place 5 group=g1 line=10 name=sign1 priority=20 file=Xsign
  sign place 5 group=g2 line=10 name=sign1 priority=25 file=Xsign
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1 priority=30\n" .
	      \ "    line=10  id=5  group=g2  name=sign1 priority=25\n" .
	      \ "    line=10  id=5  group=g1  name=sign1 priority=20\n", a)

  " Test for :sign place group={group}
  let a = execute('sign place group=g1')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  group=g1  name=sign1 priority=20\n", a)

  call sign_unplace('*')
  call sign_undefine()
  enew  | only
  call delete("Xsign")
endfunc

" Tests for memory allocation failures in sign functions
func Test_sign_memfailures()
  call writefile(repeat(["Sun is shining"], 30), "Xsign")
  edit Xsign

  call test_alloc_fail(GetAllocId('sign_getdefined'), 0, 0)
  call assert_fails('call sign_getdefined("sign1")', 'E342:')
  call test_alloc_fail(GetAllocId('sign_getplaced'), 0, 0)
  call assert_fails('call sign_getplaced("Xsign")', 'E342:')
  call test_alloc_fail(GetAllocId('sign_define_by_name'), 0, 0)
  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Error'}
  call assert_fails('call sign_define("sign1", attr)', 'E342:')

  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Error'}
  call sign_define("sign1", attr)
  call test_alloc_fail(GetAllocId('sign_getlist'), 0, 0)
  call assert_fails('call sign_getdefined("sign1")', 'E342:')

  call sign_place(3, 'g1', 'sign1', 'Xsign', {'lnum' : 10})
  call test_alloc_fail(GetAllocId('sign_getplaced_dict'), 0, 0)
  call assert_fails('call sign_getplaced("Xsign")', 'E342:')
  call test_alloc_fail(GetAllocId('sign_getplaced_list'), 0, 0)
  call assert_fails('call sign_getplaced("Xsign")', 'E342:')

  call test_alloc_fail(GetAllocId('insert_sign'), 0, 0)
  call assert_fails('call sign_place(4, "g1", "sign1", "Xsign", {"lnum" : 11})',
								\ 'E342:')

  call test_alloc_fail(GetAllocId('sign_getinfo'), 0, 0)
  call assert_fails('call getbufinfo()', 'E342:')
  call sign_place(4, 'g1', 'sign1', 'Xsign', {'lnum' : 11})
  call test_alloc_fail(GetAllocId('sign_getinfo'), 0, 0)
  call assert_fails('let binfo=getbufinfo("Xsign")', 'E342:')
  call assert_equal([{'lnum': 11, 'id': 4, 'name': 'sign1',
	      \ 'priority': 10, 'group': 'g1'}], binfo[0].signs)

  call sign_unplace('*')
  call sign_undefine()
  enew  | only
  call delete("Xsign")
endfunc
