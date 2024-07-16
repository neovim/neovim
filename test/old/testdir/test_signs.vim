" Test for signs

source check.vim
CheckFeature signs

source screendump.vim

func Test_sign()
  new
  call setline(1, ['a', 'b', 'c', 'd'])

  " Define some signs.
  " We can specify icons even if not all versions of vim support icons as
  " icon is ignored when not supported.  "(not supported)" is shown after
  " the icon name when listing signs.
  sign define Sign1 text=x

  call Sign_command_ignore_error('sign define Sign2 text=xy texthl=Title linehl=Error culhl=Search numhl=Number icon=../../pixmaps/stock_vim_find_help.png')

  " Test listing signs.
  let a=execute('sign list')
  call assert_match('^\nsign Sign1 text=x \nsign Sign2 ' .
	      \ 'icon=../../pixmaps/stock_vim_find_help.png .*text=xy ' .
	      \ 'linehl=Error texthl=Title culhl=Search numhl=Number$', a)

  let a=execute('sign list Sign1')
  call assert_equal("\nsign Sign1 text=x ", a)

  " Split the window to the bottom to verify sign jump will stay in the
  " current window if the buffer is displayed there.
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
  call assert_fails("sign place 40 name=Sign1 buffer=" . bufnr('%'), 'E885:')

  " Check placed signs
  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\nSigns for [NULL]:\n" .
		\ "    line=3  id=41  name=Sign1  priority=10\n", a)

  " Unplace the sign and try jumping to it again should fail.
  sign unplace 41
  1
  call assert_fails("sign jump 41 buffer=" . bufnr('%'), 'E157:')
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

  " Place a sign without specifying the filename or buffer
  sign place 77 line=9 name=Sign2
  let a=execute('sign place')
  " Nvim: sign line clamped to buffer length
  call assert_equal("\n--- Signs ---\nSigns for [NULL]:\n" .
		\ "    line=4  id=77  name=Sign2  priority=10\n", a)
  sign unplace *

  " Check :jump with file=...
  edit foo
  call setline(1, ['A', 'B', 'C', 'D'])

  call Sign_command_ignore_error('sign define Sign3 text=y texthl=DoesNotExist linehl=DoesNotExist icon=doesnotexist.xpm')

  let fn = expand('%:p')
  exe 'sign place 43 line=2 name=Sign3 file=' . fn
  edit bar
  call assert_notequal(fn, expand('%:p'))
  exe 'sign jump 43 file=' . fn
  call assert_equal('B', getline('.'))

  " Check for jumping to a sign in a hidden buffer
  enew! | only!
  edit foo
  call setline(1, ['A', 'B', 'C', 'D'])
  let fn = expand('%:p')
  exe 'sign place 21 line=3 name=Sign3 file=' . fn
  hide edit bar
  exe 'sign jump 21 file=' . fn
  call assert_equal('C', getline('.'))

  " can't define a sign with a non-printable character as text
  call assert_fails("sign define Sign4 text=\e linehl=Comment", 'E239:')
  call assert_fails("sign define Sign4 text=a\e linehl=Comment", 'E239:')
  call assert_fails("sign define Sign4 text=\ea linehl=Comment", 'E239:')

  " Only 0, 1 or 2 character text is allowed
  call assert_fails("sign define Sign4 text=abc linehl=Comment", 'E239:')
  " call assert_fails("sign define Sign4 text= linehl=Comment", 'E239:')
  call assert_fails("sign define Sign4 text=\\ ab  linehl=Comment", 'E239:')

  " an empty highlight argument for an existing sign clears it
  sign define SignY texthl=TextHl culhl=CulHl linehl=LineHl numhl=NumHl
  let sl = sign_getdefined('SignY')[0]
  call assert_equal('TextHl', sl.texthl)
  call assert_equal('CulHl', sl.culhl)
  call assert_equal('LineHl', sl.linehl)
  call assert_equal('NumHl', sl.numhl)

  sign define SignY texthl= culhl=CulHl linehl=LineHl numhl=NumHl
  let sl = sign_getdefined('SignY')[0]
  call assert_false(has_key(sl, 'texthl'))
  call assert_equal('CulHl', sl.culhl)
  call assert_equal('LineHl', sl.linehl)
  call assert_equal('NumHl', sl.numhl)

  sign define SignY linehl=
  let sl = sign_getdefined('SignY')[0]
  call assert_false(has_key(sl, 'linehl'))
  call assert_equal('CulHl', sl.culhl)
  call assert_equal('NumHl', sl.numhl)

  sign define SignY culhl=
  let sl = sign_getdefined('SignY')[0]
  call assert_false(has_key(sl, 'culhl'))
  call assert_equal('NumHl', sl.numhl)

  sign define SignY numhl=
  let sl = sign_getdefined('SignY')[0]
  call assert_false(has_key(sl, 'numhl'))

  sign undefine SignY

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

  " define a sign with a leading 0 in the name
  sign unplace *
  sign define 004 text=#> linehl=Comment
  let a = execute('sign list 4')
  call assert_equal("\nsign 4 text=#> linehl=Comment", a)
  exe 'sign place 20 line=3 name=004 buffer=' . bufnr('')
  let a = execute('sign place')
  call assert_equal("\n--- Signs ---\nSigns for foo:\n" .
		\ "    line=3  id=20  name=4  priority=10\n", a)
  exe 'sign unplace 20 buffer=' . bufnr('')
  sign undefine 004
  call assert_fails('sign list 4', 'E155:')

  " After undefining the sign, we should no longer be able to place it.
  sign undefine Sign1
  sign undefine Sign2
  sign undefine Sign3
  call assert_fails("sign place 41 line=3 name=Sign1 buffer=" .
			  \ bufnr('%'), 'E155:')

  " Defining a sign without attributes is allowed.
  sign define Sign1
  call assert_equal([{'name': 'Sign1'}], sign_getdefined())
  sign undefine Sign1
endfunc

func Test_sign_many_bytes()
  new
  set signcolumn=number
  set number
  call setline(1, 'some text')
  " composing characters can use many bytes, check for overflow
  sign define manyBytes text=▶᷄᷅᷆◀᷄᷅᷆᷇
  sign place 17 line=1 name=manyBytes
  redraw

  bwipe!
  sign undefine manyBytes
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
  call assert_equal("\n--- Signs ---\nSigns for foobar:\n" .
		\ "    line=1  id=41  name=[Deleted]  priority=10\n", a)

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
  call assert_equal('"sign define Sign culhl= icon= linehl= numhl= priority= text= texthl=', @:)

  for hl in ['culhl', 'linehl', 'numhl', 'texthl']
    call feedkeys(":sign define Sign "..hl.."=Spell\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"sign define Sign '..hl..'=SpellBad SpellCap ' .
                \ 'SpellLocal SpellRare', @:)
  endfor

  call writefile(repeat(["Sun is shining"], 30), "XsignOne")
  call writefile(repeat(["Sky is blue"], 30), "XsignTwo")
  call feedkeys(":sign define Sign icon=Xsig\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign define Sign icon=XsignOne XsignTwo', @:)

  " Test for completion of arguments to ':sign undefine'
  call feedkeys(":sign undefine \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign undefine Sign1 Sign2', @:)

  call feedkeys(":sign place 1 \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place 1 buffer= file= group= line= name= priority=',
	      \ @:)

  call feedkeys(":sign place 1 name=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place 1 name=Sign1 Sign2', @:)

  edit XsignOne
  sign place 1 name=Sign1 line=5
  sign place 1 name=Sign1 group=g1 line=10
  edit XsignTwo
  sign place 1 name=Sign2 group=g2 line=15

  " Test for completion of group= and file= arguments to ':sign place'
  call feedkeys(":sign place 1 name=Sign1 file=Xsign\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place 1 name=Sign1 file=XsignOne XsignTwo', @:)
  call feedkeys(":sign place 1 name=Sign1 group=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place 1 name=Sign1 group=g1 g2', @:)

  " Test for completion of arguments to 'sign place' without sign identifier
  call feedkeys(":sign place \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place buffer= file= group=', @:)
  call feedkeys(":sign place file=Xsign\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place file=XsignOne XsignTwo', @:)
  call feedkeys(":sign place group=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place group=g1 g2', @:)
  call feedkeys(":sign place group=g1 file=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign place group=g1 file=XsignOne XsignTwo', @:)

  " Test for completion of arguments to ':sign unplace'
  call feedkeys(":sign unplace 1 \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign unplace 1 buffer= file= group=', @:)
  call feedkeys(":sign unplace 1 file=Xsign\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign unplace 1 file=XsignOne XsignTwo', @:)
  call feedkeys(":sign unplace 1 group=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign unplace 1 group=g1 g2', @:)
  call feedkeys(":sign unplace 1 group=g2 file=Xsign\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign unplace 1 group=g2 file=XsignOne XsignTwo', @:)

  " Test for completion of arguments to ':sign list'
  call feedkeys(":sign list \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign list Sign1 Sign2', @:)

  " Test for completion of arguments to ':sign jump'
  call feedkeys(":sign jump 1 \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign jump 1 buffer= file= group=', @:)
  call feedkeys(":sign jump 1 file=Xsign\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign jump 1 file=XsignOne XsignTwo', @:)
  call feedkeys(":sign jump 1 group=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign jump 1 group=g1 g2', @:)

  " Error cases
  call feedkeys(":sign here\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign here', @:)
  call feedkeys(":sign define Sign here=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"sign define Sign here=\<C-A>", @:)
  call feedkeys(":sign place 1 here=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"sign place 1 here=\<C-A>", @:)
  call feedkeys(":sign jump 1 here=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"sign jump 1 here=\<C-A>", @:)
  call feedkeys(":sign here there\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"sign here there\<C-A>", @:)
  call feedkeys(":sign here there=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"sign here there=\<C-A>", @:)

  sign unplace * group=*
  sign undefine Sign1
  sign undefine Sign2
  enew
  call delete('XsignOne')
  call delete('XsignTwo')
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
  call assert_fails('sign place 1 name=Sign1 buffer=999', 'E158:')
  call assert_fails('sign place buffer=999', 'E158:')
  call assert_fails('sign jump buffer=999', 'E158:')
  call assert_fails('sign jump 1 file=', 'E158:')
  call assert_fails('sign jump 1 group=', 'E474:')
  call assert_fails('sign jump 1 name=', 'E474:')
  call assert_fails('sign jump 1 name=Sign1', 'E474:')
  call assert_fails('sign jump 1 line=100', '474:')
  " call assert_fails('sign define Sign2 text=', 'E239:')
  " Non-numeric identifier for :sign place
  call assert_fails("sign place abc line=3 name=Sign1 buffer=" . bufnr(''),
								\ 'E474:')
  " Non-numeric identifier for :sign unplace
  call assert_fails("sign unplace abc name=Sign1 buffer=" . bufnr(''),
								\ 'E474:')
  " Number followed by an alphabet as sign identifier for :sign place
  call assert_fails("sign place 1abc line=3 name=Sign1 buffer=" . bufnr(''),
								\ 'E474:')
  " Number followed by an alphabet as sign identifier for :sign unplace
  call assert_fails("sign unplace 2abc name=Sign1 buffer=" . bufnr(''),
								\ 'E474:')
  " Sign identifier and '*' for :sign unplace
  call assert_fails("sign unplace 2 *", 'E474:')
  " Trailing characters after buffer number for :sign place
  call assert_fails("sign place 1 line=3 name=Sign1 buffer=" .
						\ bufnr('%') . 'xxx', 'E488:')
  " Trailing characters after buffer number for :sign unplace
  call assert_fails("sign unplace 1 buffer=" . bufnr('%') . 'xxx', 'E488:')
  call assert_fails("sign unplace * buffer=" . bufnr('%') . 'xxx', 'E488:')
  call assert_fails("sign unplace 1 xxx", 'E474:')
  call assert_fails("sign unplace * xxx", 'E474:')
  call assert_fails("sign unplace xxx", 'E474:')
  " Placing a sign without line number
  call assert_fails("sign place name=Sign1 buffer=" . bufnr('%'), 'E474:')
  " Placing a sign without sign name
  call assert_fails("sign place line=10 buffer=" . bufnr('%'), 'E474:')
  " Unplacing a sign with line number
  call assert_fails("sign unplace 2 line=10 buffer=" . bufnr('%'), 'E474:')
  " Unplacing a sign with sign name
  call assert_fails("sign unplace 2 name=Sign1 buffer=" . bufnr('%'), 'E474:')
  " Placing a sign without sign name
  call assert_fails("sign place 2 line=3 buffer=" . bufnr('%'), 'E474:')
  " Placing a sign with only sign identifier
  call assert_fails("sign place 2", 'E474:')
  " Placing a sign with only a name
  call assert_fails("sign place abc", 'E474:')
  " Placing a sign with only line number
  call assert_fails("sign place 5 line=3", 'E474:')
  " Placing a sign with only sign group
  call assert_fails("sign place 5 group=g1", 'E474:')
  call assert_fails("sign place 5 group=*", 'E474:')
  " Placing a sign with only sign priority
  call assert_fails("sign place 5 priority=10", 'E474:')

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

" Ignore error: E255: Couldn't read in sign data!
" This error can happen when running in the GUI.
" Some gui like Motif do not support the png icon format.
func Sign_command_ignore_error(cmd)
  try
    exe a:cmd
  catch /E255:/
  endtry
endfunc

" ignore error: E255: Couldn't read in sign data!
" This error can happen when running in gui.
func Sign_define_ignore_error(name, attr)
  try
    call sign_define(a:name, a:attr)
  catch /E255:/
  endtry
endfunc

" Test for Vim script functions for managing signs
func Test_sign_funcs()
  " Remove all the signs
  call sign_unplace('*')
  call sign_undefine()

  " Tests for sign_define()
  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Error',
              \ 'culhl': 'Visual', 'numhl': 'Number'}
  call assert_equal(0, "sign1"->sign_define(attr))
  call assert_equal([{'name' : 'sign1', 'texthl' : 'Error', 'linehl' : 'Search',
              \ 'culhl' : 'Visual', 'numhl': 'Number', 'text' : '=>'}],
              \ sign_getdefined())

  " Define a new sign without attributes and then update it
  call sign_define("sign2")
  let attr = {'text' : '!!', 'linehl' : 'DiffAdd', 'texthl' : 'DiffChange',
	      \ 'culhl': 'DiffDelete', 'numhl': 'Number', 'icon' : 'sign2.ico'}
  call Sign_define_ignore_error("sign2", attr)
  call assert_equal([{'name' : 'sign2', 'texthl' : 'DiffChange',
	      \ 'linehl' : 'DiffAdd', 'culhl' : 'DiffDelete', 'text' : '!!',
              \ 'numhl': 'Number', 'icon' : 'sign2.ico'}],
              \ "sign2"->sign_getdefined())

  " Test for a sign name with digits
  call assert_equal(0, sign_define(0002, {'linehl' : 'StatusLine'}))
  call assert_equal([{'name' : '2', 'linehl' : 'StatusLine'}],
	      \ sign_getdefined(0002))
  eval 0002->sign_undefine()

  " Tests for invalid arguments to sign_define()
  call assert_fails('call sign_define("sign4", {"text" : "===>"})', 'E239:')
  " call assert_fails('call sign_define("sign5", {"text" : ""})', 'E239:')
  call assert_fails('call sign_define({})', 'E731:')
  call assert_fails('call sign_define("sign6", [])', 'E1206:')

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
	      \ '%'->sign_getplaced({'lnum' : 20}))
  call assert_equal([{'bufnr' : bufnr(''), 'signs' :
	      \ [{'id' : 10, 'group' : '', 'lnum' : 20, 'name' : 'sign1',
	      \ 'priority' : 10}]}],
	      \ sign_getplaced('', {'id' : 10}))

  " Tests for invalid arguments to sign_place()
  call assert_fails('call sign_place([], "", "mySign", 1)', 'E745:')
  call assert_fails('call sign_place(5, "", "mySign", -1)', 'E158:')
  call assert_fails('call sign_place(-1, "", "sign1", "Xsign", [])', 'E1206:')
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
  call assert_fails('call sign_place(5, "", "sign1", "@", {"lnum" : 10})',
	      \ 'E158:')
  call assert_fails('call sign_place(5, "", "sign1", [], {"lnum" : 10})',
	      \ 'E730:')
  call assert_fails('call sign_place(21, "", "sign1", "Xsign",
	      \ {"lnum" : -1})', 'E474:')
  call assert_fails('call sign_place(22, "", "sign1", "Xsign",
	      \ {"lnum" : 0})', 'E474:')
  call assert_fails('call sign_place(22, "", "sign1", "Xsign",
	      \ {"lnum" : []})', 'E745:')
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
  call assert_fails('call sign_getplaced("&")', 'E158:')
  call assert_fails('call sign_getplaced(-1)', 'E158:')
  call assert_fails('call sign_getplaced("Xsign", [])', 'E1206:')
  call assert_equal([{'bufnr' : bufnr(''), 'signs' : []}],
	      \ sign_getplaced('Xsign', {'lnum' : 1000000}))
  call assert_fails("call sign_getplaced('Xsign', {'lnum' : []})",
	      \ 'E745:')
  call assert_equal([{'bufnr' : bufnr(''), 'signs' : []}],
	      \ sign_getplaced('Xsign', {'id' : 44}))
  call assert_fails("call sign_getplaced('Xsign', {'id' : []})",
	      \ 'E745:')

  " Tests for sign_unplace()
  eval 20->sign_place('', 'sign2', 'Xsign', {"lnum" : 30})
  call assert_equal(0, sign_unplace('',
	      \ {'id' : 20, 'buffer' : 'Xsign'}))
  call assert_equal(-1, ''->sign_unplace(
	      \ {'id' : 30, 'buffer' : 'Xsign'}))
  call sign_place(20, '', 'sign2', 'Xsign', {"lnum" : 30})
  call assert_fails("call sign_unplace('',
	      \ {'id' : 20, 'buffer' : 'buffer.c'})", 'E158:')
  call assert_fails("call sign_unplace('',
	      \ {'id' : 20, 'buffer' : '&'})", 'E158:')
  call assert_fails("call sign_unplace('g1',
	      \ {'id' : 20, 'buffer' : 200})", 'E158:')
  call assert_fails("call sign_unplace('g1', 'mySign')", 'E1206:')

  call sign_unplace('*')

  " Test for modifying a placed sign
  call assert_equal(15, sign_place(15, '', 'sign1', 'Xsign', {'lnum' : 20}))
  call assert_equal(15, sign_place(15, '', 'sign2', 'Xsign'))
  call assert_equal([{'bufnr' : bufnr(''), 'signs' :
	      \ [{'id' : 15, 'group' : '', 'lnum' : 20, 'name' : 'sign2',
	      \ 'priority' : 10}]}],
	      \ sign_getplaced())

  " Tests for sign_undefine()
  call assert_equal(0, sign_undefine("sign1"))
  call assert_equal([], sign_getdefined("sign1"))
  call assert_fails('call sign_undefine("none")', 'E155:')
  call assert_fails('call sign_undefine({})', 'E731:')

  " Test for using '.' as the line number for sign_place()
  call Sign_define_ignore_error("sign1", attr)
  call cursor(22, 1)
  call assert_equal(15, sign_place(15, '', 'sign1', 'Xsign',
	      \ {'lnum' : '.'}))
  call assert_equal([{'bufnr' : bufnr(''), 'signs' :
	      \ [{'id' : 15, 'group' : '', 'lnum' : 22, 'name' : 'sign1',
	      \ 'priority' : 10}]}],
	      \ sign_getplaced('%', {'lnum' : 22}))

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
  let s = sign_getplaced(bnum, {'group' : ''})
  call assert_equal([{'id' : 5, 'group' : '', 'name' : 'sign1', 'lnum' : 10,
	      \ 'priority' : 10}], s[0].signs)
  call assert_equal(1, len(s[0].signs))
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
  call assert_fails("call sign_unplace({})", 'E1174:')

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
  sign place 5 line=10 name=sign1 file=Xsign
  sign place 5 group=g1 line=10 name=sign1 file=Xsign
  sign place 5 group=g2 line=10 name=sign1 file=Xsign

  " Tests for the ':sign place' command

  " :sign place file={fname}
  let a = execute('sign place file=Xsign')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1  priority=10\n", a)

  " :sign place group={group} file={fname}
  let a = execute('sign place group=g2 file=Xsign')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  group=g2  name=sign1  priority=10\n", a)

  " :sign place group=* file={fname}
  let a = execute('sign place group=* file=Xsign')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  group=g2  name=sign1  priority=10\n" .
	      \ "    line=10  id=5  group=g1  name=sign1  priority=10\n" .
	      \ "    line=10  id=5  name=sign1  priority=10\n", a)

  " Error case: non-existing group
  let a = execute('sign place group=xyz file=Xsign')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n", a)

  call sign_unplace('*')
  let bnum = bufnr('Xsign')
  exe 'sign place 5 line=10 name=sign1 buffer=' . bnum
  exe 'sign place 5 group=g1 line=11 name=sign1 buffer=' . bnum
  exe 'sign place 5 group=g2 line=12 name=sign1 buffer=' . bnum

  " :sign place buffer={fname}
  let a = execute('sign place buffer=' . bnum)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1  priority=10\n", a)

  " :sign place group={group} buffer={fname}
  let a = execute('sign place group=g2 buffer=' . bnum)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=12  id=5  group=g2  name=sign1  priority=10\n", a)

  " :sign place group=* buffer={fname}
  let a = execute('sign place group=* buffer=' . bnum)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1  priority=10\n" .
	      \ "    line=11  id=5  group=g1  name=sign1  priority=10\n" .
	      \ "    line=12  id=5  group=g2  name=sign1  priority=10\n", a)

  " Error case: non-existing group
  let a = execute('sign place group=xyz buffer=' . bnum)
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n", a)

  " :sign place
  let a = execute('sign place')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1  priority=10\n", a)

  " Place signs in more than one buffer and list the signs
  split foo
  set buftype=nofile
  sign place 25 line=76 name=sign1 priority=99 file=foo
  let a = execute('sign place')
  " Nvim: sign line clamped to buffer length
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1  priority=10\n" .
	      \ "Signs for foo:\n" .
	      \ "    line=1  id=25  name=sign1  priority=99\n", a)
  close
  bwipe foo

  " :sign place group={group}
  let a = execute('sign place group=g1')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=11  id=5  group=g1  name=sign1  priority=10\n", a)

  " :sign place group=*
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1  priority=10\n" .
	      \ "    line=11  id=5  group=g1  name=sign1  priority=10\n" .
	      \ "    line=12  id=5  group=g2  name=sign1  priority=10\n", a)

  " Test for ':sign jump' command with groups
  sign jump 5 group=g1 file=Xsign
  call assert_equal(11, line('.'))
  call assert_equal('Xsign', bufname(''))
  sign jump 5 group=g2 file=Xsign
  call assert_equal(12, line('.'))

  " Test for :sign jump command without the filename or buffer
  sign jump 5
  call assert_equal(10, line('.'))
  sign jump 5 group=g1
  call assert_equal(11, line('.'))

  " Error cases
  call assert_fails("sign place 3 group= name=sign1 buffer=" . bnum, 'E474:')

  call delete("Xsign")
  call sign_unplace('*')
  call sign_undefine()
  enew | only
endfunc

" Place signs used for ":sign unplace" command test
func Place_signs_for_test()
  call sign_unplace('*')

  sign place 3 line=10 name=sign1 file=Xsign1
  sign place 3 group=g1 line=11 name=sign1 file=Xsign1
  sign place 3 group=g2 line=12 name=sign1 file=Xsign1
  sign place 4 line=15 name=sign1 file=Xsign1
  sign place 4 group=g1 line=16 name=sign1 file=Xsign1
  sign place 4 group=g2 line=17 name=sign1 file=Xsign1
  sign place 5 line=20 name=sign1 file=Xsign2
  sign place 5 group=g1 line=21 name=sign1 file=Xsign2
  sign place 5 group=g2 line=22 name=sign1 file=Xsign2
  sign place 6 line=25 name=sign1 file=Xsign2
  sign place 6 group=g1 line=26 name=sign1 file=Xsign2
  sign place 6 group=g2 line=27 name=sign1 file=Xsign2
endfunc

" Place multiple signs in a single line for test
func Place_signs_at_line_for_test()
  call sign_unplace('*')
  sign place 3 line=13 name=sign1 file=Xsign1
  sign place 3 group=g1 line=13 name=sign1 file=Xsign1
  sign place 3 group=g2 line=13 name=sign1 file=Xsign1
  sign place 4 line=13 name=sign1 file=Xsign1
  sign place 4 group=g1 line=13 name=sign1 file=Xsign1
  sign place 4 group=g2 line=13 name=sign1 file=Xsign1
endfunc

" Tests for the ':sign unplace' command
func Test_sign_unplace()
  enew | only
  " Remove all the signs
  call sign_unplace('*')
  call sign_undefine()

  " Create two files and define signs
  call writefile(repeat(["Sun is shining"], 30), "Xsign1")
  call writefile(repeat(["It is beautiful"], 30), "Xsign2")

  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Error'}
  call sign_define("sign1", attr)

  edit Xsign1
  let bnum1 = bufnr('%')
  split Xsign2
  let bnum2 = bufnr('%')

  let signs1 = [{'id' : 3, 'name' : 'sign1', 'lnum' : 10, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 3, 'name' : 'sign1', 'lnum' : 11, 'group' : 'g1',
	      \ 'priority' : 10},
	      \ {'id' : 3, 'name' : 'sign1', 'lnum' : 12, 'group' : 'g2',
	      \ 'priority' : 10},
	      \ {'id' : 4, 'name' : 'sign1', 'lnum' : 15, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 4, 'name' : 'sign1', 'lnum' : 16, 'group' : 'g1',
	      \ 'priority' : 10},
	      \ {'id' : 4, 'name' : 'sign1', 'lnum' : 17, 'group' : 'g2',
	      \ 'priority' : 10},]
  let signs2 = [{'id' : 5, 'name' : 'sign1', 'lnum' : 20, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 5, 'name' : 'sign1', 'lnum' : 21, 'group' : 'g1',
	      \ 'priority' : 10},
	      \ {'id' : 5, 'name' : 'sign1', 'lnum' : 22, 'group' : 'g2',
	      \ 'priority' : 10},
	      \ {'id' : 6, 'name' : 'sign1', 'lnum' : 25, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 6, 'name' : 'sign1', 'lnum' : 26, 'group' : 'g1',
	      \ 'priority' : 10},
	      \ {'id' : 6, 'name' : 'sign1', 'lnum' : 27, 'group' : 'g2',
	      \ 'priority' : 10},]

  " Test for :sign unplace {id} file={fname}
  call Place_signs_for_test()
  sign unplace 3 file=Xsign1
  sign unplace 6 file=Xsign2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 3 || val.group != ''}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 6 || val.group != ''}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace {id} group={group} file={fname}
  call Place_signs_for_test()
  sign unplace 4 group=g1 file=Xsign1
  sign unplace 5 group=g2 file=Xsign2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 4 || val.group != 'g1'}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 5 || val.group != 'g2'}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace {id} group=* file={fname}
  call Place_signs_for_test()
  sign unplace 3 group=* file=Xsign1
  sign unplace 6 group=* file=Xsign2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 3}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 6}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace * file={fname}
  call Place_signs_for_test()
  sign unplace * file=Xsign1
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.group != ''}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(signs2, sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace * group={group} file={fname}
  call Place_signs_for_test()
  sign unplace * group=g1 file=Xsign1
  sign unplace * group=g2 file=Xsign2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.group != 'g1'}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.group != 'g2'}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace * group=* file={fname}
  call Place_signs_for_test()
  sign unplace * group=* file=Xsign2
  call assert_equal(signs1, sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal([], sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace {id} buffer={nr}
  call Place_signs_for_test()
  exe 'sign unplace 3 buffer=' . bnum1
  exe 'sign unplace 6 buffer=' . bnum2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 3 || val.group != ''}),
	      \ sign_getplaced(bnum1, {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 6 || val.group != ''}),
	      \ sign_getplaced(bnum2, {'group' : '*'})[0].signs)

  " Test for :sign unplace {id} group={group} buffer={nr}
  call Place_signs_for_test()
  exe 'sign unplace 4 group=g1 buffer=' . bnum1
  exe 'sign unplace 5 group=g2 buffer=' . bnum2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 4 || val.group != 'g1'}),
	      \ sign_getplaced(bnum1, {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 5 || val.group != 'g2'}),
	      \ sign_getplaced(bnum2, {'group' : '*'})[0].signs)

  " Test for :sign unplace {id} group=* buffer={nr}
  call Place_signs_for_test()
  exe 'sign unplace 3 group=* buffer=' . bnum1
  exe 'sign unplace 6 group=* buffer=' . bnum2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 3}),
	      \ sign_getplaced(bnum1, {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 6}),
	      \ sign_getplaced(bnum2, {'group' : '*'})[0].signs)

  " Test for :sign unplace * buffer={nr}
  call Place_signs_for_test()
  exe 'sign unplace * buffer=' . bnum1
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.group != ''}),
	      \ sign_getplaced(bnum1, {'group' : '*'})[0].signs)
  call assert_equal(signs2, sign_getplaced(bnum2, {'group' : '*'})[0].signs)

  " Test for :sign unplace * group={group} buffer={nr}
  call Place_signs_for_test()
  exe 'sign unplace * group=g1 buffer=' . bnum1
  exe 'sign unplace * group=g2 buffer=' . bnum2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.group != 'g1'}),
	      \ sign_getplaced(bnum1, {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.group != 'g2'}),
	      \ sign_getplaced(bnum2, {'group' : '*'})[0].signs)

  " Test for :sign unplace * group=* buffer={nr}
  call Place_signs_for_test()
  exe 'sign unplace * group=* buffer=' . bnum2
  call assert_equal(signs1, sign_getplaced(bnum1, {'group' : '*'})[0].signs)
  call assert_equal([], sign_getplaced(bnum2, {'group' : '*'})[0].signs)

  " Test for :sign unplace {id}
  call Place_signs_for_test()
  sign unplace 4
  sign unplace 6
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 4 || val.group != ''}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 6 || val.group != ''}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace {id} group={group}
  call Place_signs_for_test()
  sign unplace 4 group=g1
  sign unplace 6 group=g2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 4 || val.group != 'g1'}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 6 || val.group != 'g2'}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace {id} group=*
  call Place_signs_for_test()
  sign unplace 3 group=*
  sign unplace 5 group=*
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 3}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.id != 5}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace *
  call Place_signs_for_test()
  sign unplace *
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.group != ''}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.group != ''}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace * group={group}
  call Place_signs_for_test()
  sign unplace * group=g1
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.group != 'g1'}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(
	      \ filter(copy(signs2),
	      \     {idx, val -> val.group != 'g1'}),
	      \ sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Test for :sign unplace * group=*
  call Place_signs_for_test()
  sign unplace * group=*
  call assert_equal([], sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal([], sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Negative test cases
  call Place_signs_for_test()
  sign unplace 3 group=xy file=Xsign1
  sign unplace * group=xy file=Xsign1
  silent! sign unplace * group=* file=FileNotPresent
  call assert_equal(signs1, sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  call assert_equal(signs2, sign_getplaced('Xsign2', {'group' : '*'})[0].signs)

  " Tests for removing sign at the current cursor position

  " Test for ':sign unplace'
  let signs1 = [{'id' : 4, 'name' : 'sign1', 'lnum' : 13, 'group' : 'g2',
	      \ 'priority' : 10},
	      \ {'id' : 4, 'name' : 'sign1', 'lnum' : 13, 'group' : 'g1',
	      \ 'priority' : 10},
	      \ {'id' : 4, 'name' : 'sign1', 'lnum' : 13, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 3, 'name' : 'sign1', 'lnum' : 13, 'group' : 'g2',
	      \ 'priority' : 10},
	      \ {'id' : 3, 'name' : 'sign1', 'lnum' : 13, 'group' : 'g1',
	      \ 'priority' : 10},
	      \ {'id' : 3, 'name' : 'sign1', 'lnum' : 13, 'group' : '',
	      \ 'priority' : 10},]
  exe bufwinnr('Xsign1') . 'wincmd w'
  call cursor(13, 1)

  " Should remove only one sign in the global group
  call Place_signs_at_line_for_test()
  sign unplace
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 4 || val.group != ''}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  " Should remove the second sign in the global group
  sign unplace
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.group != ''}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)

  " Test for ':sign unplace group={group}'
  call Place_signs_at_line_for_test()
  " Should remove only one sign in group g1
  sign unplace group=g1
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 4 || val.group != 'g1'}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  sign unplace group=g2
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 4 || val.group == ''}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)

  " Test for ':sign unplace group=*'
  call Place_signs_at_line_for_test()
  sign unplace group=*
  sign unplace group=*
  sign unplace group=*
  call assert_equal(
	      \ filter(copy(signs1),
	      \     {idx, val -> val.id != 4}),
	      \ sign_getplaced('Xsign1', {'group' : '*'})[0].signs)
  sign unplace group=*
  sign unplace group=*
  sign unplace group=*
  call assert_equal([], sign_getplaced('Xsign1', {'group' : '*'})[0].signs)

  call sign_unplace('*')
  call sign_undefine()
  enew | only
  call delete("Xsign1")
  call delete("Xsign2")
endfunc

" Tests for auto-generating the sign identifier.
func Test_aaa_sign_id_autogen()
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
  call assert_equal(4, sign_place(0, '', 'sign1', 'Xsign',
	      \ {'lnum' : 12}))

  call assert_equal(1, sign_place(0, 'g1', 'sign1', 'Xsign',
	      \ {'lnum' : 11}))
  " Check for the next generated sign id in this group
  call assert_equal(2, sign_place(0, 'g1', 'sign1', 'Xsign',
	      \ {'lnum' : 12}))
  call assert_equal(0, sign_unplace('g1', {'id' : 1}))
  call assert_equal(10,
	      \ sign_getplaced('Xsign', {'id' : 1})[0].signs[0].lnum)

  call delete("Xsign")
  call sign_unplace('*')
  call sign_undefine()
  enew | only
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
  let attr = {'text' : '=>', 'linehl' : 'Search', 'texthl' : 'Search', 'priority': 60}
  call sign_define("sign4", attr)

  " Test for :sign list
  let a = execute('sign list')
  call assert_equal("\nsign sign1 text==> linehl=Search texthl=Search\n" .
      \ "sign sign2 text==> linehl=Search texthl=Search\n" .
      \ "sign sign3 text==> linehl=Search texthl=Search\n" .
      \ "sign sign4 text==> priority=60 linehl=Search texthl=Search", a)

  " Test for sign_getdefined()
  let s = sign_getdefined()
  call assert_equal([
      \ {'name': 'sign1', 'texthl': 'Search', 'linehl': 'Search', 'text': '=>'},
      \ {'name': 'sign2', 'texthl': 'Search', 'linehl': 'Search', 'text': '=>'},
      \ {'name': 'sign3', 'texthl': 'Search', 'linehl': 'Search', 'text': '=>'},
      \ {'name': 'sign4', 'priority': 60, 'texthl': 'Search', 'linehl': 'Search',
      \ 'text': '=>'}],
      \ s)

  " Place three signs with different priority in the same line
  call writefile(repeat(["Sun is shining"], 30), "Xsign", 'D')
  edit Xsign

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

  call sign_unplace('*')

  " Three signs on different lines with changing priorities
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 11, 'priority' : 50})
  call sign_place(2, '', 'sign2', 'Xsign',
	      \ {'lnum' : 12, 'priority' : 60})
  call sign_place(3, '', 'sign3', 'Xsign',
	      \ {'lnum' : 13, 'priority' : 70})
  call sign_place(2, '', 'sign2', 'Xsign',
	      \ {'lnum' : 12, 'priority' : 40})
  call sign_place(3, '', 'sign3', 'Xsign',
	      \ {'lnum' : 13, 'priority' : 30})
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 11, 'priority' : 50})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 11, 'group' : '',
	      \ 'priority' : 50},
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 12, 'group' : '',
	      \ 'priority' : 40},
	      \ {'id' : 3, 'name' : 'sign3', 'lnum' : 13, 'group' : '',
	      \ 'priority' : 30}],
	      \ s[0].signs)

  call sign_unplace('*')

  " Two signs on the same line with changing priorities
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 20})
  call sign_place(2, '', 'sign2', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 30})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 30},
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20}],
	      \ s[0].signs)
  " Change the priority of the last sign to highest
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 40})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 40},
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 30}],
	      \ s[0].signs)
  " Change the priority of the first sign to lowest
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 25})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 30},
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 25}],
	      \ s[0].signs)
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 45})
  call sign_place(2, '', 'sign2', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 55})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 55},
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 45}],
	      \ s[0].signs)

  call sign_unplace('*')

  " Three signs on the same line with changing priorities
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 40})
  call sign_place(2, '', 'sign2', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 30})
  call sign_place(3, '', 'sign3', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 20})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 40},
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 30},
	      \ {'id' : 3, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20}],
	      \ s[0].signs)

  " Change the priority of the middle sign to the highest
  call sign_place(2, '', 'sign2', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 50})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 50},
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 40},
	      \ {'id' : 3, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20}],
	      \ s[0].signs)

  " Change the priority of the middle sign to the lowest
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 15})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 50},
	      \ {'id' : 3, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20},
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 15}],
	      \ s[0].signs)

  " Change the priority of the last sign to the highest
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 55})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 55},
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 50},
	      \ {'id' : 3, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20}],
	      \ s[0].signs)

  " Change the priority of the first sign to the lowest
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 15})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 50},
	      \ {'id' : 3, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20},
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 15}],
	      \ s[0].signs)

  call sign_unplace('*')

  " Three signs on the same line with changing priorities along with other
  " signs
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 2, 'priority' : 10})
  call sign_place(2, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 30})
  call sign_place(3, '', 'sign2', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 20})
  call sign_place(4, '', 'sign3', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 25})
  call sign_place(5, '', 'sign2', 'Xsign',
	      \ {'lnum' : 6, 'priority' : 80})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 2, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 2, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 30},
	      \ {'id' : 4, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 25},
	      \ {'id' : 3, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20},
	      \ {'id' : 5, 'name' : 'sign2', 'lnum' : 6, 'group' : '',
	      \ 'priority' : 80}],
	      \ s[0].signs)

  " Change the priority of the first sign to lowest
  call sign_place(2, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 15})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 2, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 4, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 25},
	      \ {'id' : 3, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20},
	      \ {'id' : 2, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 15},
	      \ {'id' : 5, 'name' : 'sign2', 'lnum' : 6, 'group' : '',
	      \ 'priority' : 80}],
	      \ s[0].signs)

  " Change the priority of the last sign to highest
  call sign_place(2, '', 'sign1', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 30})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 2, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 2, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 30},
	      \ {'id' : 4, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 25},
	      \ {'id' : 3, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20},
	      \ {'id' : 5, 'name' : 'sign2', 'lnum' : 6, 'group' : '',
	      \ 'priority' : 80}],
	      \ s[0].signs)

  " Change the priority of the middle sign to lowest
  call sign_place(4, '', 'sign3', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 15})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 2, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 2, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 30},
	      \ {'id' : 3, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 20},
	      \ {'id' : 4, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 15},
	      \ {'id' : 5, 'name' : 'sign2', 'lnum' : 6, 'group' : '',
	      \ 'priority' : 80}],
	      \ s[0].signs)

  " Change the priority of the middle sign to highest
  call sign_place(3, '', 'sign2', 'Xsign',
	      \ {'lnum' : 4, 'priority' : 35})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 2, 'group' : '',
	      \ 'priority' : 10},
	      \ {'id' : 3, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 35},
	      \ {'id' : 2, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 30},
	      \ {'id' : 4, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
	      \ 'priority' : 15},
	      \ {'id' : 5, 'name' : 'sign2', 'lnum' : 6, 'group' : '',
	      \ 'priority' : 80}],
	      \ s[0].signs)

  call sign_unplace('*')

  " Multiple signs with the same priority on the same line
  call sign_place(1, '', 'sign1', 'Xsign',
              \ {'lnum' : 4, 'priority' : 20})
  call sign_place(2, '', 'sign2', 'Xsign',
              \ {'lnum' : 4, 'priority' : 20})
  call sign_place(3, '', 'sign3', 'Xsign',
              \ {'lnum' : 4, 'priority' : 20})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  let se = [
              \ {'id' : 3, 'name' : 'sign3', 'lnum' : 4, 'group' : '',
              \ 'priority' : 20},
              \ {'id' : 2, 'name' : 'sign2', 'lnum' : 4, 'group' : '',
              \ 'priority' : 20},
              \ {'id' : 1, 'name' : 'sign1', 'lnum' : 4, 'group' : '',
              \ 'priority' : 20}]
  call assert_equal(se, s[0].signs)

  " Nvim: signs are always sorted lnum->priority->sign_id->last_modified
  " Last modified does not take precedence over sign_id here.

  " Place the last sign again with the same priority
  call sign_place(1, '', 'sign1', 'Xsign',
              \ {'lnum' : 4, 'priority' : 20})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal(se, s[0].signs)
  " Place the first sign again with the same priority
  call sign_place(1, '', 'sign1', 'Xsign',
              \ {'lnum' : 4, 'priority' : 20})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal(se, s[0].signs)
  " Place the middle sign again with the same priority
  call sign_place(3, '', 'sign3', 'Xsign',
              \ {'lnum' : 4, 'priority' : 20})
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal(se, s[0].signs)

  call sign_unplace('*')

  " Place multiple signs with same id on a line with different priority
  call sign_place(1, '', 'sign1', 'Xsign',
	      \ {'lnum' : 5, 'priority' : 20})
  call sign_place(1, '', 'sign2', 'Xsign',
	      \ {'lnum' : 5, 'priority' : 10})
  let s = sign_getplaced('Xsign', {'lnum' : 5})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign2', 'lnum' : 5, 'group' : '',
	      \ 'priority' : 10}],
	      \ s[0].signs)
  call sign_place(1, '', 'sign2', 'Xsign',
	      \ {'lnum' : 5, 'priority' : 5})
  let s = sign_getplaced('Xsign', {'lnum' : 5})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign2', 'lnum' : 5, 'group' : '',
	      \ 'priority' : 5}],
	      \ s[0].signs)

  " Error case
  call assert_fails("call sign_place(1, 'g1', 'sign1', 'Xsign', [])", 'E1206:')
  call assert_fails("call sign_place(1, 'g1', 'sign1', 'Xsign',
	      \ {'priority' : []})", 'E745:')
  call sign_unplace('*')

  " Tests for the :sign place command with priority
  sign place 5 line=10 name=sign1 priority=30 file=Xsign
  sign place 5 group=g1 line=10 name=sign1 priority=20 file=Xsign
  sign place 5 group=g2 line=10 name=sign1 priority=25 file=Xsign
  let a = execute('sign place group=*')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  name=sign1  priority=30\n" .
	      \ "    line=10  id=5  group=g2  name=sign1  priority=25\n" .
	      \ "    line=10  id=5  group=g1  name=sign1  priority=20\n", a)

  " Test for :sign place group={group}
  let a = execute('sign place group=g1')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=10  id=5  group=g1  name=sign1  priority=20\n", a)

  call sign_unplace('*')

  " Test for sign with default priority.
  call sign_place(1, 'g1', 'sign4', 'Xsign', {'lnum' : 3})
  sign place 2 line=5 name=sign4 group=g1 file=Xsign

  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 1, 'name' : 'sign4', 'lnum' : 3, 'group' : 'g1',
	      \ 'priority' : 60},
	      \ {'id' : 2, 'name' : 'sign4', 'lnum' : 5, 'group' : 'g1',
	      \ 'priority' : 60}],
	      \ s[0].signs)

  let a = execute('sign place group=g1')
  call assert_equal("\n--- Signs ---\nSigns for Xsign:\n" .
	      \ "    line=3  id=1  group=g1  name=sign4  priority=60\n" .
	      \ "    line=5  id=2  group=g1  name=sign4  priority=60\n", a)

  call sign_unplace('*')
  call sign_undefine()
  enew | only
endfunc

" Tests for memory allocation failures in sign functions
func Test_sign_memfailures()
  CheckFunction test_alloc_fail
  call writefile(repeat(["Sun is shining"], 30), "Xsign", 'D')
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
  enew | only
endfunc

" Test for auto-adjusting the line number of a placed sign.
func Test_sign_lnum_adjust()
  enew! | only!

  sign define sign1 text=#> linehl=Comment
  call setline(1, ['A', 'B', 'C', 'D', 'E'])
  exe 'sign place 5 line=3 name=sign1 buffer=' . bufnr('')
  let l = sign_getplaced(bufnr(''))
  call assert_equal(3, l[0].signs[0].lnum)

  " Add some lines before the sign and check the sign line number
  call append(2, ['BA', 'BB', 'BC'])
  let l = sign_getplaced(bufnr(''))
  call assert_equal(6, l[0].signs[0].lnum)

  " Delete some lines before the sign and check the sign line number
  call deletebufline('%', 1, 2)
  let l = sign_getplaced(bufnr(''))
  call assert_equal(4, l[0].signs[0].lnum)

  " Insert some lines after the sign and check the sign line number
  call append(5, ['DA', 'DB'])
  let l = sign_getplaced(bufnr(''))
  call assert_equal(4, l[0].signs[0].lnum)

  " Delete some lines after the sign and check the sign line number
  call deletebufline('', 6, 7)
  let l = sign_getplaced(bufnr(''))
  call assert_equal(4, l[0].signs[0].lnum)

  " Break the undo. Otherwise the undo operation below will undo all the
  " changes made by this function.
  let &g:undolevels=&g:undolevels

  " Nvim: deleting a line removes the signs along with it.

  " " Delete the line with the sign
  " call deletebufline('', 4)
  " let l = sign_getplaced(bufnr(''))
  " call assert_equal(4, l[0].signs[0].lnum)

  " " Undo the delete operation
  " undo
  " let l = sign_getplaced(bufnr(''))
  " call assert_equal(5, l[0].signs[0].lnum)

  " " Break the undo
  " let &g:undolevels=&g:undolevels

  " " Delete few lines at the end of the buffer including the line with the sign
  " " Sign line number should not change (as it is placed outside of the buffer)
  " call deletebufline('', 3, 6)
  " let l = sign_getplaced(bufnr(''))
  " call assert_equal(5, l[0].signs[0].lnum)

  " " Undo the delete operation. Sign should be restored to the previous line
  " undo
  " let l = sign_getplaced(bufnr(''))
  " call assert_equal(5, l[0].signs[0].lnum)

  " set signcolumn&

  sign unplace * group=*
  sign undefine sign1
  enew!
endfunc

" Test for changing the type of a placed sign
func Test_sign_change_type()
  enew! | only!

  sign define sign1 text=#> linehl=Comment
  sign define sign2 text=@@ linehl=Comment

  call setline(1, ['A', 'B', 'C', 'D'])
  exe 'sign place 4 line=3 name=sign1 buffer=' . bufnr('')
  let l = sign_getplaced(bufnr(''))
  call assert_equal('sign1', l[0].signs[0].name)
  exe 'sign place 4 name=sign2 buffer=' . bufnr('')
  let l = sign_getplaced(bufnr(''))
  call assert_equal('sign2', l[0].signs[0].name)
  call sign_place(4, '', 'sign1', '')
  let l = sign_getplaced(bufnr(''))
  call assert_equal('sign1', l[0].signs[0].name)

  exe 'sign place 4 group=g1 line=4 name=sign1 buffer=' . bufnr('')
  let l = sign_getplaced(bufnr(''), {'group' : 'g1'})
  call assert_equal('sign1', l[0].signs[0].name)
  exe 'sign place 4 group=g1 name=sign2 buffer=' . bufnr('')
  let l = sign_getplaced(bufnr(''), {'group' : 'g1'})
  call assert_equal('sign2', l[0].signs[0].name)
  call sign_place(4, 'g1', 'sign1', '')
  let l = sign_getplaced(bufnr(''), {'group' : 'g1'})
  call assert_equal('sign1', l[0].signs[0].name)

  sign unplace * group=*
  sign undefine sign1
  sign undefine sign2
  enew!
endfunc

" Test for the sign_jump() function
func Test_sign_jump_func()
  enew! | only!

  sign define sign1 text=#> linehl=Comment

  edit foo
  set buftype=nofile
  call setline(1, ['A', 'B', 'C', 'D', 'E'])
  call sign_place(5, '', 'sign1', '', {'lnum' : 2})
  call sign_place(5, 'g1', 'sign1', '', {'lnum' : 3})
  call sign_place(6, '', 'sign1', '', {'lnum' : 4})
  call sign_place(6, 'g1', 'sign1', '', {'lnum' : 5})
  split bar
  set buftype=nofile
  call setline(1, ['P', 'Q', 'R', 'S', 'T'])
  call sign_place(5, '', 'sign1', '', {'lnum' : 2})
  call sign_place(5, 'g1', 'sign1', '', {'lnum' : 3})
  call sign_place(6, '', 'sign1', '', {'lnum' : 4})
  call sign_place(6, 'g1', 'sign1', '', {'lnum' : 5})

  let r = sign_jump(5, '', 'foo')
  call assert_equal(2, r)
  call assert_equal(2, line('.'))
  let r = 6->sign_jump('g1', 'foo')
  call assert_equal(5, r)
  call assert_equal(5, line('.'))
  let r = sign_jump(5, '', 'bar')
  call assert_equal(2, r)
  call assert_equal(2, line('.'))

  " Error cases
  call assert_fails("call sign_jump(99, '', 'bar')", 'E157:')
  call assert_fails("call sign_jump(0, '', 'foo')", 'E474:')
  call assert_fails("call sign_jump(5, 'g5', 'foo')", 'E157:')
  call assert_fails('call sign_jump([], "", "foo")', 'E745:')
  call assert_fails('call sign_jump(2, [], "foo")', 'E730:')
  call assert_fails('call sign_jump(2, "", {})', 'E731:')
  call assert_fails('call sign_jump(2, "", "baz")', 'E158:')

  sign unplace * group=*
  sign undefine sign1
  enew! | only!
endfunc

" Test for correct cursor position after the sign column appears or disappears.
func Test_sign_cursor_position()
  CheckRunVimInTerminal

  let lines =<< trim END
	call setline(1, [repeat('x', 75), 'mmmm', 'yyyy'])
	call cursor(2,1)
   	sign define s1 texthl=Search text==>
	redraw
   	sign place 10 line=2 name=s1
  END
  call writefile(lines, 'XtestSigncolumn')
  let buf = RunVimInTerminal('-S XtestSigncolumn', {'rows': 6})
  call VerifyScreenDump(buf, 'Test_sign_cursor_1', {})

  " Change the sign text
  call term_sendkeys(buf, ":sign define s1 text=-)\<CR>")
  call VerifyScreenDump(buf, 'Test_sign_cursor_2', {})

  " update cursor position calculation
  call term_sendkeys(buf, "lh")
  call term_sendkeys(buf, ":sign unplace 10\<CR>")
  call VerifyScreenDump(buf, 'Test_sign_cursor_3', {})


  " clean up
  call StopVimInTerminal(buf)
  call delete('XtestSigncolumn')
endfunc

" Return the 'len' characters in screen starting from (row,col)
func s:ScreenLine(row, col, len)
  let s = ''
  for i in range(a:len)
    let s .= nr2char(screenchar(a:row, a:col + i))
  endfor
  return s
endfunc

" Test for 'signcolumn' set to 'number'.
func Test_sign_numcol()
  new
  call append(0, "01234")
  " With 'signcolumn' set to 'number', make sure sign is displayed in the
  " number column and line number is not displayed.
  set numberwidth=2
  set number
  set signcolumn=number
  sign define sign1 text==>
  sign define sign2 text=Ｖ
  sign place 10 line=1 name=sign1
  redraw!
  call assert_equal("=> 01234", s:ScreenLine(1, 1, 8))

  " With 'signcolumn' set to 'number', when there is no sign, make sure line
  " number is displayed in the number column
  sign unplace 10
  redraw!
  call assert_equal("1 01234", s:ScreenLine(1, 1, 7))

  " Disable number column. Check whether sign is displayed in the sign column
  set numberwidth=4
  set nonumber
  sign place 10 line=1 name=sign1
  redraw!
  call assert_equal("=>01234", s:ScreenLine(1, 1, 7))

  " Enable number column. Check whether sign is displayed in the number column
  set number
  redraw!
  call assert_equal(" => 01234", s:ScreenLine(1, 1, 9))

  " Disable sign column. Make sure line number is displayed
  set signcolumn=no
  redraw!
  call assert_equal("  1 01234", s:ScreenLine(1, 1, 9))

  " Enable auto sign column. Make sure both sign and line number are displayed
  set signcolumn=auto
  redraw!
  call assert_equal("=>  1 01234", s:ScreenLine(1, 1, 11))

  " Test displaying signs in the number column with width 1
  call sign_unplace('*')
  call append(1, "abcde")
  call append(2, "01234")
  " Enable number column with width 1
  set number numberwidth=1 signcolumn=auto
  redraw!
  call assert_equal("3 01234", s:ScreenLine(3, 1, 7))
  " Place a sign and make sure number column width remains the same
  sign place 20 line=2 name=sign1
  redraw!
  call assert_equal("=>2 abcde", s:ScreenLine(2, 1, 9))
  call assert_equal("  3 01234", s:ScreenLine(3, 1, 9))
  " Set 'signcolumn' to 'number', make sure the number column width increases
  set signcolumn=number
  redraw!
  call assert_equal("=> abcde", s:ScreenLine(2, 1, 8))
  call assert_equal(" 3 01234", s:ScreenLine(3, 1, 8))
  " Set 'signcolumn' to 'auto', make sure the number column width is 1.
  set signcolumn=auto
  redraw!
  call assert_equal("=>2 abcde", s:ScreenLine(2, 1, 9))
  call assert_equal("  3 01234", s:ScreenLine(3, 1, 9))
  " Set 'signcolumn' to 'number', make sure the number column width is 2.
  set signcolumn=number
  redraw!
  call assert_equal("=> abcde", s:ScreenLine(2, 1, 8))
  call assert_equal(" 3 01234", s:ScreenLine(3, 1, 8))
  " Disable 'number' column
  set nonumber
  redraw!
  call assert_equal("=>abcde", s:ScreenLine(2, 1, 7))
  call assert_equal("  01234", s:ScreenLine(3, 1, 7))
  " Enable 'number' column
  set number
  redraw!
  call assert_equal("=> abcde", s:ScreenLine(2, 1, 8))
  call assert_equal(" 3 01234", s:ScreenLine(3, 1, 8))
  " Remove the sign and make sure the width of the number column is 1.
  call sign_unplace('', {'id' : 20})
  redraw!
  call assert_equal("3 01234", s:ScreenLine(3, 1, 7))
  " When the first sign is placed with 'signcolumn' set to number, verify that
  " the number column width increases
  sign place 30 line=1 name=sign1
  redraw!
  call assert_equal("=> 01234", s:ScreenLine(1, 1, 8))
  call assert_equal(" 2 abcde", s:ScreenLine(2, 1, 8))
  " Add sign with multi-byte text
  set numberwidth=4
  sign place 40 line=2 name=sign2
  redraw!
  call assert_equal(" => 01234", s:ScreenLine(1, 1, 9))
  call assert_equal(" Ｖ abcde", s:ScreenLine(2, 1, 9))

  sign unplace * group=*
  sign undefine sign1
  set signcolumn&
  set number&
  enew!  | close
endfunc

" Test for managing multiple signs using the sign functions
func Test_sign_funcs_multi()
  call writefile(repeat(["Sun is shining"], 30), "Xsign")
  edit Xsign
  let bnum = bufnr('')

  " Define multiple signs at once
  call assert_equal([0, 0, 0, 0], sign_define([
	      \ {'name' : 'sign1', 'text' : '=>', 'linehl' : 'Search',
	      \ 'texthl' : 'Search'},
	      \ {'name' : 'sign2', 'text' : '=>', 'linehl' : 'Search',
	      \ 'texthl' : 'Search'},
	      \ {'name' : 'sign3', 'text' : '=>', 'linehl' : 'Search',
	      \ 'texthl' : 'Search'},
	      \ {'name' : 'sign4', 'text' : '=>', 'linehl' : 'Search',
	      \ 'texthl' : 'Search'}]))

  " Negative cases for sign_define()
  call assert_equal([], sign_define([]))
  call assert_equal([-1], sign_define([{}]))
  call assert_fails('call sign_define([6])', 'E715:')
  call assert_fails('call sign_define(["abc"])', 'E715:')
  call assert_fails('call sign_define([[]])', 'E715:')

  " Place multiple signs at once with specific sign identifier
  let l = sign_placelist([{'id' : 1, 'group' : 'g1', 'name' : 'sign1',
	      \ 'buffer' : 'Xsign', 'lnum' : 11, 'priority' : 50},
	      \ {'id' : 2, 'group' : 'g2', 'name' : 'sign2',
	      \ 'buffer' : 'Xsign', 'lnum' : 11, 'priority' : 100},
	      \ {'id' : 3, 'group' : '', 'name' : 'sign3',
	      \ 'buffer' : 'Xsign', 'lnum' : 11}])
  call assert_equal([1, 2, 3], l)
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 2, 'name' : 'sign2', 'lnum' : 11,
	      \ 'group' : 'g2', 'priority' : 100},
	      \ {'id' : 1, 'name' : 'sign1', 'lnum' : 11,
	      \ 'group' : 'g1', 'priority' : 50},
	      \ {'id' : 3, 'name' : 'sign3', 'lnum' : 11,
	      \ 'group' : '', 'priority' : 10}], s[0].signs)

  call sign_unplace('*')

  " Place multiple signs at once with auto-generated sign identifier
  " Nvim: next sign id is not reset and is always incremented
  call assert_equal([2, 3, 4], sign_placelist([
	      \ {'group' : 'g1', 'name' : 'sign1',
	      \ 'buffer' : 'Xsign', 'lnum' : 11},
	      \ {'group' : 'g2', 'name' : 'sign2',
	      \ 'buffer' : 'Xsign', 'lnum' : 11},
	      \ {'group' : '', 'name' : 'sign3',
	      \ 'buffer' : 'Xsign', 'lnum' : 11}]))
  let s = sign_getplaced('Xsign', {'group' : '*'})
  call assert_equal([
	      \ {'id' : 4, 'name' : 'sign3', 'lnum' : 11,
	      \ 'group' : '', 'priority' : 10},
	      \ {'id' : 3, 'name' : 'sign2', 'lnum' : 11,
	      \ 'group' : 'g2', 'priority' : 10},
	      \ {'id' : 2, 'name' : 'sign1', 'lnum' : 11,
	      \ 'group' : 'g1', 'priority' : 10}], s[0].signs)

  " Change an existing sign without specifying the group
  call assert_equal([4], [{'id' : 4, 'name' : 'sign1', 'buffer' : 'Xsign'}]->sign_placelist())
  let s = sign_getplaced('Xsign', {'id' : 4, 'group' : ''})
  call assert_equal([{'id' : 4, 'name' : 'sign1', 'lnum' : 11,
	      \ 'group' : '', 'priority' : 10}], s[0].signs)

  " Place a sign using '.' as the line number
  call cursor(23, 1)
  call assert_equal([7], sign_placelist([
	      \ {'id' : 7, 'name' : 'sign1', 'buffer' : '%', 'lnum' : '.'}]))
  let s = sign_getplaced('%', {'lnum' : '.'})
  call assert_equal([{'id' : 7, 'name' : 'sign1', 'lnum' : 23,
	      \ 'group' : '', 'priority' : 10}], s[0].signs)

  " Place sign without a sign name
  call assert_equal([-1], sign_placelist([{'id' : 10, 'buffer' : 'Xsign',
	      \ 'lnum' : 12, 'group' : ''}]))

  " Place sign without a buffer
  call assert_equal([-1], sign_placelist([{'id' : 10, 'name' : 'sign1',
	      \ 'lnum' : 12, 'group' : ''}]))

  " Invalid arguments
  call assert_equal([], sign_placelist([]))
  call assert_fails('call sign_placelist({})', "E714:")
  call assert_fails('call sign_placelist([[]])', "E715:")
  call assert_fails('call sign_placelist(["abc"])', "E715:")
  call assert_fails('call sign_placelist([100])', "E715:")

  " Unplace multiple signs
  call assert_equal([0, 0, 0], sign_unplacelist([{'id' : 4},
	      \ {'id' : 2, 'group' : 'g1'}, {'id' : 3, 'group' : 'g2'}]))

  " Invalid arguments
  call assert_equal([], []->sign_unplacelist())
  call assert_fails('call sign_unplacelist({})', "E714:")
  call assert_fails('call sign_unplacelist([[]])', "E715:")
  call assert_fails('call sign_unplacelist(["abc"])', "E715:")
  call assert_fails('call sign_unplacelist([100])', "E715:")
  call assert_fails("call sign_unplacelist([{'id' : -1}])", 'E474')

  call assert_equal([0, 0, 0, 0],
	      \ sign_undefine(['sign1', 'sign2', 'sign3', 'sign4']))
  call assert_equal([], sign_getdefined())

  " Invalid arguments
  call assert_equal([], sign_undefine([]))
  call assert_fails('call sign_undefine([[]])', 'E730:')
  call assert_fails('call sign_undefine([{}])', 'E731:')
  call assert_fails('call sign_undefine(["1abc2"])', 'E155:')

  call sign_unplace('*')
  call sign_undefine()
  enew!
  call delete("Xsign")
endfunc

func Test_sign_null_list()
  eval v:_null_list->sign_define()
  eval v:_null_list->sign_placelist()
  eval v:_null_list->sign_undefine()
  eval v:_null_list->sign_unplacelist()
endfunc

" vim: shiftwidth=2 sts=2 expandtab
