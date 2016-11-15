" Test for signs

if !has('signs')
  finish
endif

func Test_sign()
  new
  call setline(1, ['a', 'b', 'c', 'd'])

  sign define Sign1 text=x
  sign define Sign2 text=y

  " Test listing signs.
  let a=execute('sign list')
  call assert_equal("\nsign Sign1 text=x \nsign Sign2 text=y ", a)

  let a=execute('sign list Sign1')
  call assert_equal("\nsign Sign1 text=x ", a)

  " Place the sign at line 3,then check that we can jump to it.
  exe 'sign place 42 line=3 name=Sign1 buffer=' . bufnr('')
  1
  exe 'sign jump 42 buffer=' . bufnr('')
  call assert_equal('c', getline('.'))

  " Can't change sign.
  call assert_fails("exe 'sign place 43 name=Sign1 buffer=' . bufnr('')", 'E885:')

  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\nSigns for [NULL]:\n    line=3  id=42  name=Sign1\n", a)

  " Unplace the sign and try jumping to it again should now fail.
  sign unplace 42
  1
  call assert_fails("exe 'sign jump 42 buffer=' . bufnr('')", 'E157:')
  call assert_equal('a', getline('.'))

  " Unplace sign on current line.
  exe 'sign place 43 line=4 name=Sign2 buffer=' . bufnr('')
  4
  sign unplace
  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\n", a)
  
  " Try again to unplace sign on current line, it should fail this time.
  call assert_fails('sign unplace', 'E159:')

  " Unplace all signs.
  exe 'sign place 42 line=3 name=Sign1 buffer=' . bufnr('')
  sign unplace *
  let a=execute('sign place')
  call assert_equal("\n--- Signs ---\n", a)

  " After undefining the sign, we should no longer be able to place it.
  sign undefine Sign1
  sign undefine Sign2
  call assert_fails("exe 'sign place 42 line=3 name=Sign1 buffer=' . bufnr('')", 'E155:')

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
  call assert_fails('sign xxx', 'E160:')
  call assert_fails('sign define', 'E156:')
  call assert_fails('sign undefine', 'E156:')
  call assert_fails('sign list xxx', 'E155:')
  call assert_fails('sign place 1 buffer=', 'E158:')
  call assert_fails('sign define Sign2 text=', 'E239:')
endfunc
