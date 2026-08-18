" Tests for the matchit plugin

func SetUp()
  filetype plugin on
  packadd matchit
  call assert_equal('<Plug>(MatchitNormalForward)', maparg('%', 'n', 0))
endfunc

func TearDown()
  filetype plugin off
endfunc

func s:Setup(lines, ft)
  new
  call setline(1, a:lines)
  exe "setl ft=".. a:ft
  call assert_true(exists('b:match_words'))
  call assert_true(!empty(b:match_words))
endfunc

func s:PercentTo(arg)
  call call('cursor', a:arg)
  normal %
  return line('.')
endfunc

func Test_html_matchit_simple_tag()
  call s:Setup(['<b>', '<big>some text</big>', '</b>'], 'html')
  call assert_equal(3, s:PercentTo([1, 2]))
  call assert_equal(1, s:PercentTo([3, 3]))
  call assert_equal(2, s:PercentTo([2, 2]))
  normal %
  call assert_equal(2, line('.'))
  bwipe!
endfunc

func Test_html_matchit_tag_with_attribute()
  call s:Setup(['<b id="123">', '<big>some text</big>', '</b>'], 'html')
  call assert_equal(3, s:PercentTo([1, 2]))
  call assert_equal(1, s:PercentTo([3, 3]))
  call assert_equal(2, s:PercentTo([2, 2]))
  normal %
  call assert_equal(2, line('.'))
  bwipe!
endfunc

func Test_html_matchit_tag_multiline_attributes()
  call s:Setup(['<b', '  id="123"', '  name="abc"', '>',
        \ '<big>some text</big>', '</b>'], 'html')
  call assert_equal(6, s:PercentTo([1, 2]))
  call assert_equal(1, s:PercentTo([6, 3]))
  call assert_equal(5, s:PercentTo([5, 2]))
  normal %
  call assert_equal(5, line('.'))
  bwipe!
endfunc

func Test_shaderslang_matchit_switch_break()
  call s:Setup(['void main() {', '  switch (x) {', '    case 1:',
        \ '      break;', '  }', '}'], 'shaderslang')
  call assert_equal(5, s:PercentTo([2, 14]))
  call assert_equal(2, s:PercentTo([5, 3]))
  bwipe!
endfunc

func Test_shaderslang_matchit_loop_break()
  call s:Setup(['void f() {', '  for (int i = 0; i < 4; ++i) {',
        \ '    if (i == 2)', '      break;', '    total += i;', '  }',
        \ '  int after = 1;', '}'], 'shaderslang')
  call assert_equal(8, s:PercentTo([1, 10]))
  call assert_equal(6, s:PercentTo([2, 31]))
  call assert_equal(2, s:PercentTo([6, 3]))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
