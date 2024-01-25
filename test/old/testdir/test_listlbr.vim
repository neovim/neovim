" Test for linebreak and list option (non-utf8)

scriptencoding latin1

source check.vim
CheckOption linebreak
CheckFeature conceal

source view_util.vim
source screendump.vim

function s:screen_lines(lnum, width) abort
  return ScreenLines(a:lnum, a:width)
endfunction

func s:compare_lines(expect, actual)
  call assert_equal(a:expect, a:actual)
endfunc

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
  throw 'skipped: Nvim does not support enc=latin1'
  set listchars=
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
  set listchars&vim
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

func Test_linebreak_with_list_and_number()
  call s:test_windows('setl list listchars+=tab:>-')
  call setline(1, ["abcdefg\thijklmnopqrstu", "v"])
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect_nonumber = [
\ "abcdefg>------------",
\ "hijklmnopqrstu$     ",
\ "v$                  ",
\ "~                   ",
\ ]
  call s:compare_lines(expect_nonumber, lines)

  setl number
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect_number = [
\ "  1 abcdefg>--------",
\ "    hijklmnopqrstu$ ",
\ "  2 v$              ",
\ "~                   ",
\ ]
  call s:compare_lines(expect_number, lines)
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

func Test_linebreak_with_visual_operations()
  call s:test_windows()
  let line = '1234567890 2234567890 3234567890'
  call setline(1, line)

  " yank
  exec "norm! ^w\<C-V>ey"
  call assert_equal('2234567890', @@)
  exec "norm! w\<C-V>ey"
  call assert_equal('3234567890', @@)

  " increment / decrement
  exec "norm! ^w\<C-V>\<C-A>w\<C-V>\<C-X>"
  call assert_equal('1234567890 3234567890 2234567890', getline(1))

  " replace
  exec "norm! ^w\<C-V>3lraw\<C-V>3lrb"
  call assert_equal('1234567890 aaaa567890 bbbb567890', getline(1))

  " tilde
  exec "norm! ^w\<C-V>2l~w\<C-V>2l~"
  call assert_equal('1234567890 AAAa567890 BBBb567890', getline(1))

  " delete and insert
  exec "norm! ^w\<C-V>3lc2345\<Esc>w\<C-V>3lc3456\<Esc>"
  call assert_equal('1234567890 2345567890 3456567890', getline(1))
  call assert_equal('BBBb', @@)

  call s:close_windows()
endfunc

" Test that cursor is drawn at correct position after an operator when
" 'linebreak' is enabled.
func Test_linebreak_reset_restore()
  CheckScreendump

  " f_wincol() calls validate_cursor()
  let lines =<< trim END
    set linebreak showcmd noshowmode formatexpr=wincol()-wincol()
    call setline(1, repeat('a', &columns - 10) .. ' bbbbbbbbbb c')
  END
  call writefile(lines, 'XlbrResetRestore', 'D')
  let buf = RunVimInTerminal('-S XlbrResetRestore', {'rows': 8})

  call term_sendkeys(buf, '$v$')
  call WaitForAssert({-> assert_equal(13, term_getcursor(buf)[1])})
  call term_sendkeys(buf, 'zo')
  call WaitForAssert({-> assert_equal(12, term_getcursor(buf)[1])})

  call term_sendkeys(buf, '$v$')
  call WaitForAssert({-> assert_equal(13, term_getcursor(buf)[1])})
  call term_sendkeys(buf, 'gq')
  call WaitForAssert({-> assert_equal(12, term_getcursor(buf)[1])})

  call term_sendkeys(buf, "$\<C-V>$")
  call WaitForAssert({-> assert_equal(13, term_getcursor(buf)[1])})
  call term_sendkeys(buf, 'I')
  call WaitForAssert({-> assert_equal(12, term_getcursor(buf)[1])})

  call term_sendkeys(buf, "\<Esc>$v$")
  call WaitForAssert({-> assert_equal(13, term_getcursor(buf)[1])})
  call term_sendkeys(buf, 's')
  call WaitForAssert({-> assert_equal(12, term_getcursor(buf)[1])})
  call VerifyScreenDump(buf, 'Test_linebreak_reset_restore_1', {})

  " clean up
  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
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
\ "<<<bar foobar       ",
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
  throw 'skipped: Nvim does not support enc=latin1'
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
endfunc

func Test_ctrl_char_on_wrap_column()
  call s:test_windows("setl nolbr wrap sbr=")
  call setline(1, 'aaa' .. repeat("\<C-A>", 150) .. 'bbb')
  call cursor(1,1)
  norm! $
  redraw!
  let expect=[
\ '<<<^A^A^A^A^A^A^A^A^',
\ 'A^A^A^A^A^A^A^A^A^A^',
\ 'A^A^A^A^A^A^A^A^A^A^',
\ 'A^A^A^A^A^A^A^A^A^A^',
\ 'A^A^A^A^A^A^A^A^A^A^',
\ 'A^A^A^A^A^A^A^A^A^A^',
\ 'A^A^A^A^A^A^A^A^A^A^',
\ 'A^A^A^A^A^A^A^A^A^A^',
\ 'A^A^A^A^A^A^A^A^A^A^',
\ 'A^Abbb              ']
  let lines = s:screen_lines([1, 10], winwidth(0))
  call s:compare_lines(expect, lines)
  call assert_equal(len(expect), winline())
  call assert_equal(strwidth(trim(expect[-1], ' ', 2)), wincol())
  setl sbr=!!
  redraw!
  let expect=[
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^A^A^A^',
\ '!!A^A^A^A^A^A^Abbb  ']
  let lines = s:screen_lines([1, 10], winwidth(0))
  call s:compare_lines(expect, lines)
  call assert_equal(len(expect), winline())
  call assert_equal(strwidth(trim(expect[-1], ' ', 2)), wincol())
  call s:close_windows()
endfunc

func Test_linebreak_no_break_after_whitespace_only()
  call s:test_windows('setl ts=4 linebreak wrap')
  call setline(1, "\t  abcdefghijklmnopqrstuvwxyz" ..
        \ "abcdefghijklmnopqrstuvwxyz")
  let lines = s:screen_lines([1, 4], winwidth(0))
  let expect = [
\ "      abcdefghijklmn",
\ "opqrstuvwxyzabcdefgh",
\ "ijklmnopqrstuvwxyz  ",
\ "~                   ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

" vim: shiftwidth=2 sts=2 expandtab
