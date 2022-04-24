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

" Test for inserting '{' and '} with smartindent
func Test_smartindent_braces()
  new
  set smartindent shiftwidth=4
  call setline(1, ['    if (a)', "\tif (b)", "\t    return 1"])
  normal 2ggO{
  normal 3ggA {
  normal 4ggo}
  normal o}
  normal 4ggO#define FOO 1
  call assert_equal([
        \ '    if (a)',
        \ '    {',
        \ "\tif (b) {",
        \ '#define FOO 1',
        \ "\t    return 1",
        \ "\t}",
        \ '    }'
        \ ], getline(1, '$'))
  set si& sw& ai&
  close!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
