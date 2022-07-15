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
  setlocal noautoindent smartindent indentexpr=
  exe "normal! Gotwo\<Esc>"
  call assert_equal("\ttwo", getline("$"))

  set indentexpr=MyIndent
  exe "normal! Gothree\<Esc>"
  call assert_equal("three", getline("$"))

  delfunction! MyIndent
  bwipe!
endfunc

" Test for inserting '{' and '} with smartindent
func Test_smartindent_braces()
  new
  setlocal smartindent shiftwidth=4
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
  close!
endfunc

" Test for adding a new line before and after comments with smartindent
func Test_si_add_line_around_comment()
  new
  setlocal smartindent shiftwidth=4
  call setline(1, ['    A', '# comment1', '# comment2'])
  exe "normal GoC\<Esc>2GOB"
  call assert_equal(['    A', '    B', '# comment1', '# comment2', '    C'],
        \ getline(1, '$'))
  close!
endfunc

" After a C style comment, indent for a following line should line up with the
" line containing the start of the comment.
func Test_si_indent_after_c_comment()
  new
  setlocal smartindent shiftwidth=4 fo+=ro
  exe "normal i\<C-t>/*\ncomment\n/\n#define FOOBAR\n75\<Esc>ggOabc"
  normal 3jOcont
  call assert_equal(['    abc', '    /*', '     * comment', '     * cont',
        \ '     */', '#define FOOBAR', '    75'], getline(1, '$'))
  close!
endfunc

" Test for indenting a statement after a if condition split across lines
func Test_si_if_cond_split_across_lines()
  new
  setlocal smartindent shiftwidth=4
  exe "normal i\<C-t>if (cond1 &&\n\<C-t>cond2) {\ni = 10;\n}"
  call assert_equal(['    if (cond1 &&', "\t    cond2) {", "\ti = 10;",
        \ '    }'], getline(1, '$'))
  close!
endfunc

" Test for inserting lines before and after a one line comment
func Test_si_one_line_comment()
  new
  setlocal smartindent shiftwidth=4
  exe "normal i\<C-t>abc;\n\<C-t>/* comment */"
  normal oi = 10;
  normal kOj = 1;
  call assert_equal(['    abc;', "\tj = 1;", "\t/* comment */", "\ti = 10;"],
        \ getline(1, '$'))
  close!
endfunc

" Test for smartindent with a comment continued across multiple lines
func Test_si_comment_line_continuation()
  new
  setlocal smartindent shiftwidth=4
  call setline(1, ['# com1', '# com2 \', '    contd', '# com3', '  xyz'])
  normal ggOabc
  call assert_equal(['  abc', '# com1', '# com2 \', '    contd', '# com3',
        \ '  xyz'], getline(1, '$'))
  close!
endfunc

func Test_si_after_completion()
  new
  setlocal ai smartindent indentexpr=
  call setline(1, 'foo foot')
  call feedkeys("o  f\<C-X>\<C-N>#", 'tx')
  call assert_equal('  foo#', getline(2))

  call setline(2, '')
  call feedkeys("1Go  f\<C-X>\<C-N>}", 'tx')
  call assert_equal('  foo}', getline(2))

  bwipe!
endfunc

func Test_no_si_after_completion()
  new
  call setline(1, 'foo foot')
  call feedkeys("o  f\<C-X>\<C-N>#", 'tx')
  call assert_equal('  foo#', getline(2))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
