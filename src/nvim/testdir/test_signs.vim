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
    sign define Sign2 text=xy texthl=Title linehl=Error icon=../../pixmaps/stock_vim_find_help.png
  catch /E255:/
    " ignore error: E255: Couldn't read in sign data!
    " This error can happen when running in gui.
    " Some gui like Motif do not support the png icon format.
  endtry

  " Test listing signs.
  let a=execute('sign list')
  call assert_match("^\nsign Sign1 text=x \nsign Sign2 icon=../../pixmaps/stock_vim_find_help.png .*text=xy linehl=Error texthl=Title$", a)

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
  call assert_equal("\n--- Signs ---\nSigns for [NULL]:\n    line=3  id=41  name=Sign1\n", a)

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
  call assert_equal("\n--- Signs ---\nSigns for foobar:\n    line=1  id=41  name=[Deleted]\n", a)

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
  call assert_equal('"sign define Sign icon= linehl= text= texthl=', @:)

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
  call assert_fails('sign', 'E471:')
  call assert_fails('sign jump', 'E471:')
  call assert_fails('sign xxx', 'E160:')
  call assert_fails('sign define', 'E156:')
  call assert_fails('sign define Sign1 xxx', 'E475:')
  call assert_fails('sign undefine', 'E156:')
  call assert_fails('sign list xxx', 'E155:')
  call assert_fails('sign place 1 buffer=', 'E158:')
  call assert_fails('sign define Sign2 text=', 'E239:')
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
