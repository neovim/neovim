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
  let lines =<< trim [CODE]
    int x;

    int func(void)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gD', lines, 1, 5)
endfunc

func Test_gD_too()
  let lines =<< trim [CODE]
    Filename x;

    int Filename
    int func() {
      Filename x;
      return x;
  [CODE]

  call XTest_goto_decl('gD', lines, 1, 10)
endfunc

func Test_gD_comment()
  let lines =<< trim [CODE]
    /* int x; */
    int x;

    int func(void)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gD', lines, 2, 5)
endfunc

func Test_gD_inline_comment()
  let lines =<< trim [CODE]
    int y /* , x */;
    int x;

    int func(void)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gD', lines, 2, 5)
endfunc

func Test_gD_string()
  let lines =<< trim [CODE]
    char *s[] = "x";
    int x = 1;

    int func(void)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gD', lines, 2, 5)
endfunc

func Test_gD_string_same_line()
  let lines =<< trim [CODE]
    char *s[] = "x", int x = 1;

    int func(void)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gD', lines, 1, 22)
endfunc

func Test_gD_char()
  let lines =<< trim [CODE]
    char c = 'x';
    int x = 1;

    int func(void)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gD', lines, 2, 5)
endfunc

func Test_gd()
  let lines =<< trim [CODE]
    int x;

    int func(int x)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 3, 14)
endfunc

" Using gd to jump to a declaration in a fold
func Test_gd_with_fold()
  new
  let lines =<< trim END
    #define ONE 1
    #define TWO 2
    #define THREE 3

    TWO
  END
  call setline(1, lines)
  1,3fold
  call feedkeys('Ggd', 'xt')
  call assert_equal(2, line('.'))
  call assert_equal(-1, foldclosedend(2))
  bw!
endfunc

func Test_gd_not_local()
  let lines =<< trim [CODE]
    int func1(void)
    {
      return x;
    }

    int func2(int x)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 3, 10)
endfunc

func Test_gd_kr_style()
  let lines =<< trim [CODE]
    int func(x)
      int x;
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 2, 7)
endfunc

func Test_gd_missing_braces()
  let lines =<< trim [CODE]
    def func1(a)
      a + 1
    end

    a = 1

    def func2()
      return a
    end
  [CODE]

  call XTest_goto_decl('gd', lines, 1, 11)
endfunc

func Test_gd_comment()
  let lines =<< trim [CODE]
    int func(void)
    {
      /* int x; */
      int x;
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 4, 7)
endfunc

func Test_gd_comment_in_string()
  let lines =<< trim [CODE]
    int func(void)
    {
      char *s ="//"; int x;
      int x;
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 3, 22)
endfunc

func Test_gd_string_in_comment()
  set comments=
  let lines =<< trim [CODE]
    int func(void)
    {
      /* " */ int x;
      int x;
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 3, 15)
  set comments&
endfunc

func Test_gd_inline_comment()
  let lines =<< trim [CODE]
    int func(/* x is an int */ int x)
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 1, 32)
endfunc

func Test_gd_inline_comment_only()
  let lines =<< trim [CODE]
    int func(void) /* one lonely x */
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 3, 10)
endfunc

func Test_gd_inline_comment_body()
  let lines =<< trim [CODE]
    int func(void)
    {
      int y /* , x */;

      for (/* int x = 0 */; y < 2; y++);

      int x = 0;

      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 7, 7)
endfunc

func Test_gd_trailing_multiline_comment()
  let lines =<< trim [CODE]
    int func(int x) /* x is an int */
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 1, 14)
endfunc

func Test_gd_trailing_comment()
  let lines =<< trim [CODE]
    int func(int x) // x is an int
    {
      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 1, 14)
endfunc

func Test_gd_string()
  let lines =<< trim [CODE]
    int func(void)
    {
      char *s = "x";
      int x = 1;

      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 4, 7)
endfunc

func Test_gd_string_only()
  let lines =<< trim [CODE]
    int func(void)
    {
      char *s = "x";

      return x;
    }
  [CODE]

  call XTest_goto_decl('gd', lines, 5, 10)
endfunc

" Check that setting some options does not change curswant
func Test_set_options_keep_col()
  new
  call setline(1, ['long long long line', 'short line'])
  normal ggfi
  let pos = getcurpos()
  normal j
  set invhlsearch spell spelllang=en,cjk spelloptions=camel textwidth=80
  set cursorline cursorcolumn cursorlineopt=line colorcolumn=+1 winfixbuf
  set comments=:# commentstring=#%s define=function
  set background=dark
  set background=light
  normal k
  call assert_equal(pos, getcurpos())
  bwipe!
  set hlsearch& spell& spelllang& spelloptions& textwidth&
  set cursorline& cursorcolumn& cursorlineopt& colorcolumn& winfixbuf&
  set comments& commentstring& define&
  set background&
endfunc

func Test_gd_local_block()
  let lines =<< trim [CODE]
    int main()
    {
      char *a = "NOT NULL";
      if(a)
      {
        char *b = a;
        printf("%s\n", b);
      }
      else
      {
        char *b = "NULL";
        return b;
      }

      return 0;
    }
  [CODE]

  call XTest_goto_decl('1gd', lines, 11, 11)
endfunc

func Test_motion_if_elif_else_endif()
  new
  let lines =<< trim END
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

    #define FOO 1
  END
  call setline(1, lines)
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

  " Test for [# and ]# command
  call cursor(5, 1)
  normal [#
  call assert_equal([4, 1], getpos('.')[1:2])
  call cursor(5, 1)
  normal ]#
  call assert_equal([9, 1], getpos('.')[1:2])
  call cursor(10, 1)
  normal [#
  call assert_equal([9, 1], getpos('.')[1:2])
  call cursor(10, 1)
  normal ]#
  call assert_equal([11, 1], getpos('.')[1:2])

  " Finding a match before the first line or after the last line should fail
  normal gg
  call assert_beeps('normal [#')
  normal G
  call assert_beeps('normal ]#')

  " Finding a match for a macro definition (#define) should fail
  normal G
  call assert_beeps('normal %')

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

" vim: shiftwidth=2 sts=2 expandtab
