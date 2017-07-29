" Test for linebreak and list option (non-utf8)

set encoding=latin1
scriptencoding latin1

if !exists("+linebreak") || !has("conceal")
  finish
endif

source view_util.vim

function s:screen_lines(lnum, width) abort
  return ScreenLines(a:lnum, a:width)
endfunction

function! s:compare_lines(expect, actual)
  call assert_equal(join(a:expect, "\n"), join(a:actual, "\n"))
endfunction

function s:test_windows(...)
  call NewWindow(10, 20)
  setl ts=8 sw=4 sts=4 linebreak sbr= wrap
  exe get(a:000, 0, '')
endfunction

function s:close_windows(...)
  call CloseWindow()
  exe get(a:000, 0, '')
endfunction

func Test_set_linebreak()
  call s:test_windows('setl ts=4 sbr=+')
  call setline(1, "\tabcdef hijklmn\tpqrstuvwxyz_1060ABCDEFGHIJKLMNOP ")
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "    abcdef          ",
\ "+hijklmn            ",
\ "+pqrstuvwxyz_1060ABC",
\ "+DEFGHIJKLMNOP      ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_linebreak_with_list()
  call s:test_windows('setl ts=4 sbr=+ list listchars=')
  call setline(1, "\tabcdef hijklmn\tpqrstuvwxyz_1060ABCDEFGHIJKLMNOP ")
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "^Iabcdef hijklmn^I  ",
\ "+pqrstuvwxyz_1060ABC",
\ "+DEFGHIJKLMNOP      ",
\ "~                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_linebreak_with_nolist()
  call s:test_windows('setl ts=4 sbr=+ nolist')
  call setline(1, "\tabcdef hijklmn\tpqrstuvwxyz_1060ABCDEFGHIJKLMNOP ")
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "    abcdef          ",
\ "+hijklmn            ",
\ "+pqrstuvwxyz_1060ABC",
\ "+DEFGHIJKLMNOP      ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_should_break()
  call s:test_windows('setl sbr=+ nolist')
  call setline(1, "1\t" . repeat('a', winwidth(0)-2))
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "1                   ",
\ "+aaaaaaaaaaaaaaaaaa ",
\ "~                   ",
\ "~                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_linebreak_with_conceal()
  call s:test_windows('setl cpo&vim sbr=+ list conceallevel=2 concealcursor=nv listchars=tab:ab')
  call setline(1, "_S_\t bla")
  syn match ConcealVar contained /_/ conceal
  syn match All /.*/ contains=ConcealVar
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "Sabbbbbb bla        ",
\ "~                   ",
\ "~                   ",
\ "~                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_virtual_block()
  call s:test_windows('setl sbr=+')
  call setline(1, [
\ "REMOVE: this not",
\ "REMOVE: aaaaaaaaaaaaa",
\ ])
  exe "norm! 1/^REMOVE:"
  exe "norm! 0\<C-V>jf x"
  $put
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "this not            ",
\ "aaaaaaaaaaaaa       ",
\ "REMOVE:             ",
\ "REMOVE:             ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_virtual_block_and_vbA()
  call s:test_windows()
  call setline(1, "long line: " . repeat("foobar ", 40) . "TARGET at end")
  exe "norm! $3B\<C-v>eAx\<Esc>"
  let lines = s:screen_lines([1, 10], winwidth(0))
  let expect = [
\ "foobar foobar       ",
\ "foobar foobar       ",
\ "foobar foobar       ",
\ "foobar foobar       ",
\ "foobar foobar       ",
\ "foobar foobar       ",
\ "foobar foobar       ",
\ "foobar foobar       ",
\ "foobar foobar       ",
\ "foobar TARGETx at   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_virtual_char_and_block()
  call s:test_windows()
  call setline(1, "1111-1111-1111-11-1111-1111-1111")
  exe "norm! 0f-lv3lc2222\<Esc>bgj."
  let lines = s:screen_lines([1, 2], winwidth(0))
  let expect = [
\ "1111-2222-1111-11-  ",
\ "1111-2222-1111      ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_undo_after_block_visual()
  call s:test_windows()
  call setline(1, ["aaa", "aaa", "a"])
  exe "norm! gg\<C-V>2j~e."
  let lines = s:screen_lines([1, 3], winwidth(0))
  let expect = [
\ "AaA                 ",
\ "AaA                 ",
\ "A                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_norm_after_block_visual()
  call s:test_windows()
  call setline(1, ["abcd{ef", "ghijklm", "no}pgrs"])
  exe "norm! ggf{\<C-V>\<C-V>c%"
  let lines = s:screen_lines([1, 3], winwidth(0))
  let expect = [
\ "abcdpgrs            ",
\ "~                   ",
\ "~                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_block_replace_after_wrapping()
  call s:test_windows()
  call setline(1, repeat("a", 150))
  exe "norm! 0yypk147|\<C-V>jr0"
  call assert_equal(repeat("a", 146) . "0aaa", getline(1))
  call assert_equal(repeat("a", 146) . "0aaa", getline(2))
  let lines = s:screen_lines([1, 10], winwidth(0))
  let expect = [
\ "aaaaaaaaaaaaaaaaaaaa",
\ "aaaaaaaaaaaaaaaaaaaa",
\ "aaaaaaaaaaaaaaaaaaaa",
\ "aaaaaaaaaaaaaaaaaaaa",
\ "aaaaaaaaaaaaaaaaaaaa",
\ "aaaaaaaaaaaaaaaaaaaa",
\ "aaaaaaaaaaaaaaaaaaaa",
\ "aaaaaa0aaa          ",
\ "@                   ",
\ "@                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_list_with_listchars()
  call s:test_windows('setl list listchars=space:_,trail:-,tab:>-,eol:$')
  call setline(1, "a aaaaaaaaaaaaaaaaaaaaaa\ta ")
  let lines = s:screen_lines([1, 3], winwidth(0))
  let expect = [
\ "a_                  ",
\ "aaaaaaaaaaaaaaaaaaaa",
\ "aa>-----a-$         ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_list_with_tab_and_skipping_first_chars()
  call s:test_windows('setl list listchars=tab:>- ts=70 nowrap')
  call setline(1, ["iiiiiiiiiiiiiiii\taaaaaaaaaaaaaaaaaa", "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii\taaaaaaaaaaaaaaaaaa", "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii\taaaaaaaaaaaaaaaaaa", "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii\taaaaaaaaaaaaaaaaaa"])
  call cursor(4,64)
  norm! 2zl
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "---------------aaaaa",
\ "---------------aaaaa",
\ "---------------aaaaa",
\ "iiiiiiiii>-----aaaaa",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfu
