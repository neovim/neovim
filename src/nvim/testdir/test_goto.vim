" Test commands that jump somewhere.

" Create a new buffer using "lines" and place the cursor on the word after the
" first occurrence of return and invoke "cmd". The cursor should now be
" positioned at the given line and col.
func XTest_goto_decl(cmd, lines, line, col)
  new
  call setline(1, a:lines)
  /return/
  normal! W
  execute 'norm! ' . a:cmd
  call assert_equal(a:line, line('.'))
  call assert_equal(a:col, col('.'))
  quit!
endfunc

func Test_gD()
  let lines = [
	\ 'int x;',
	\ '',
	\ 'int func(void)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gD', lines, 1, 5)
endfunc

func Test_gD_too()
  let lines = [
	\ 'Filename x;',
	\ '',
	\ 'int Filename',
	\ 'int func() {',
	\ '  Filename x;',
	\ '  return x;',
	\ ]
  call XTest_goto_decl('gD', lines, 1, 10)
endfunc

func Test_gD_comment()
  let lines = [
	\ '/* int x; */',
	\ 'int x;',
	\ '',
	\ 'int func(void)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gD', lines, 2, 5)
endfunc

func Test_gD_inline_comment()
  let lines = [
	\ 'int y /* , x */;',
	\ 'int x;',
	\ '',
	\ 'int func(void)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gD', lines, 2, 5)
endfunc

func Test_gD_string()
  let lines = [
	\ 'char *s[] = "x";',
	\ 'int x = 1;',
	\ '',
	\ 'int func(void)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gD', lines, 2, 5)
endfunc

func Test_gD_string_same_line()
  let lines = [
	\ 'char *s[] = "x", int x = 1;',
	\ '',
	\ 'int func(void)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gD', lines, 1, 22)
endfunc

func Test_gD_char()
  let lines = [
	\ "char c = 'x';",
	\ 'int x = 1;',
	\ '',
	\ 'int func(void)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gD', lines, 2, 5)
endfunc

func Test_gd()
  let lines = [
	\ 'int x;',
	\ '',
	\ 'int func(int x)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 3, 14)
endfunc

func Test_gd_not_local()
  let lines = [
	\ 'int func1(void)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ '',
	\ 'int func2(int x)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 3, 10)
endfunc

func Test_gd_kr_style()
  let lines = [
	\ 'int func(x)',
	\ '  int x;',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 2, 7)
endfunc

func Test_gd_missing_braces()
  let lines = [
	\ 'def func1(a)',
	\ '  a + 1',
	\ 'end',
	\ '',
	\ 'a = 1',
	\ '',
	\ 'def func2()',
	\ '  return a',
	\ 'end',
	\ ]
  call XTest_goto_decl('gd', lines, 1, 11)
endfunc

func Test_gd_comment()
  let lines = [
	\ 'int func(void)',
	\ '{',
	\ '  /* int x; */',
	\ '  int x;',
	\ '  return x;',
	\ '}',
	\]
  call XTest_goto_decl('gd', lines, 4, 7)
endfunc

func Test_gd_comment_in_string()
  let lines = [
	\ 'int func(void)',
	\ '{',
	\ '  char *s ="//"; int x;',
	\ '  int x;',
	\ '  return x;',
	\ '}',
	\]
  call XTest_goto_decl('gd', lines, 3, 22)
endfunc

func Test_gd_string_in_comment()
  set comments=
  let lines = [
	\ 'int func(void)',
	\ '{',
	\ '  /* " */ int x;',
	\ '  int x;',
	\ '  return x;',
	\ '}',
	\]
  call XTest_goto_decl('gd', lines, 3, 15)
  set comments&
endfunc

func Test_gd_inline_comment()
  let lines = [
	\ 'int func(/* x is an int */ int x)',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 1, 32)
endfunc

func Test_gd_inline_comment_only()
  let lines = [
	\ 'int func(void) /* one lonely x */',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 3, 10)
endfunc

func Test_gd_inline_comment_body()
  let lines = [
	\ 'int func(void)',
	\ '{',
	\ '  int y /* , x */;',
	\ '',
	\ '  for (/* int x = 0 */; y < 2; y++);',
	\ '',
	\ '  int x = 0;',
	\ '',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 7, 7)
endfunc

func Test_gd_trailing_multiline_comment()
  let lines = [
	\ 'int func(int x) /* x is an int */',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 1, 14)
endfunc

func Test_gd_trailing_comment()
  let lines = [
	\ 'int func(int x) // x is an int',
	\ '{',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 1, 14)
endfunc

func Test_gd_string()
  let lines = [
	\ 'int func(void)',
	\ '{',
	\ '  char *s = "x";',
	\ '  int x = 1;',
	\ '',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 4, 7)
endfunc

func Test_gd_string_only()
  let lines = [
	\ 'int func(void)',
	\ '{',
	\ '  char *s = "x";',
	\ '',
	\ '  return x;',
	\ '}',
	\ ]
  call XTest_goto_decl('gd', lines, 5, 10)
endfunc

" Check that setting 'cursorline' does not change curswant
func Test_cursorline_keep_col()
  new
  call setline(1, ['long long long line', 'short line'])
  normal ggfi
  let pos = getcurpos()
  normal j
  set cursorline
  normal k
  call assert_equal(pos, getcurpos())
  bwipe!
  set nocursorline
endfunc

func Test_gd_local_block()
  let lines = [
	\ '  int main()',
	\ '{',
	\ '  char *a = "NOT NULL";',
	\ '  if(a)',
	\ '  {',
	\ '    char *b = a;',
	\ '    printf("%s\n", b);',
	\ '  }',
	\ '  else',
	\ '  {',
	\ '    char *b = "NULL";',
	\ '    return b;',
	\ '  }',
	\ '',
	\ '  return 0;',
	\ '}',
  \ ]
  call XTest_goto_decl('1gd', lines, 11, 11)
endfunc

func Test_motion_if_elif_else_endif()
  new
  a
/* Test pressing % on #if, #else #elsif and #endif,
 * with nested #if
 */
#if FOO
/* ... */
#  if BAR
/* ... */
#  endif
#elif BAR
/* ... */
#else
/* ... */
#endif
.
  /#if FOO
  norm %
  call assert_equal([9, 1], getpos('.')[1:2])
  norm %
  call assert_equal([11, 1], getpos('.')[1:2])
  norm %
  call assert_equal([13, 1], getpos('.')[1:2])
  norm %
  call assert_equal([4, 1], getpos('.')[1:2])
  /#  if BAR
  norm $%
  call assert_equal([8, 1], getpos('.')[1:2])
  norm $%
  call assert_equal([6, 1], getpos('.')[1:2])

  bw!
endfunc

func Test_motion_c_comment()
  new
  a
/*
 * Test pressing % on beginning/end
 * of C comments.
 */
/* Another comment */
.
  norm gg0%
  call assert_equal([4, 3], getpos('.')[1:2])
  norm %
  call assert_equal([1, 1], getpos('.')[1:2])
  norm gg0l%
  call assert_equal([4, 3], getpos('.')[1:2])
  norm h%
  call assert_equal([1, 1], getpos('.')[1:2])

  norm G^
  norm %
  call assert_equal([5, 21], getpos('.')[1:2])
  norm %
  call assert_equal([5, 1], getpos('.')[1:2])

  bw!
endfunc
