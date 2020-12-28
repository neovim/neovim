" Tests for smartindent

" Tests for not doing smart indenting when it isn't set.
func Test_nosmartindent()
  new
  call append(0, ["		some test text",
	\ "		test text",
	\ "test text",
	\ "		test text"])
  set nocindent nosmartindent autoindent
  exe "normal! gg/some\<CR>"
  exe "normal! 2cc#test\<Esc>"
  call assert_equal("		#test", getline(1))
  enew! | close
endfunc

func MyIndent()
endfunc

" When 'indentexpr' is set, setting 'si' has no effect.
func Test_smartindent_has_no_effect()
  new
  exe "normal! i\<Tab>one\<Esc>"
  set noautoindent
  set smartindent
  set indentexpr=
  exe "normal! Gotwo\<Esc>"
  call assert_equal("\ttwo", getline("$"))

  set indentexpr=MyIndent
  exe "normal! Gothree\<Esc>"
  call assert_equal("three", getline("$"))

  delfunction! MyIndent
  set autoindent&
  set smartindent&
  set indentexpr&
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
