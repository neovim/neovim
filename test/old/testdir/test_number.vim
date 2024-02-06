" Test for 'number' and 'relativenumber'

source check.vim
source view_util.vim

source screendump.vim

func s:screen_lines(start, end) abort
  return ScreenLines([a:start, a:end], 8)
endfunc

func s:compare_lines(expect, actual)
  call assert_equal(a:expect, a:actual)
endfunc

func s:test_windows(h, w) abort
  call NewWindow(a:h, a:w)
endfunc

func s:close_windows() abort
  call CloseWindow()
endfunc

func s:validate_cursor() abort
  " update skipcol.
  " wincol():
  "   f_wincol
  "     -> validate_cursor
  "          -> curs_columns
  call wincol()
endfunc

func Test_set_options()
  set nu rnu
  call assert_equal(1, &nu)
  call assert_equal(1, &rnu)

  call s:test_windows(10, 20)
  call assert_equal(1, &nu)
  call assert_equal(1, &rnu)
  call s:close_windows()

  set nu& rnu&
endfunc

func Test_set_global_and_local()
  " setlocal must NOT reset the other global value
  set nonu nornu
  setglobal nu
  setlocal rnu
  call assert_equal(1, &g:nu)

  set nonu nornu
  setglobal rnu
  setlocal nu
  call assert_equal(1, &g:rnu)

  " setglobal MUST reset the other global value
  set nonu nornu
  setglobal nu
  setglobal rnu
  call assert_equal(1, &g:nu)

  set nonu nornu
  setglobal rnu
  setglobal nu
  call assert_equal(1, &g:rnu)

  " set MUST reset the other global value
  set nonu nornu
  set nu
  set rnu
  call assert_equal(1, &g:nu)

  set nonu nornu
  set rnu
  set nu
  call assert_equal(1, &g:rnu)

  set nu& rnu&
endfunc

func Test_number()
  call s:test_windows(10, 20)
  call setline(1, ["abcdefghij", "klmnopqrst", "uvwxyzABCD", "EFGHIJKLMN", "OPQRSTUVWX", "YZ"])
  setl number
  let lines = s:screen_lines(1, 4)
  let expect = [
\ "  1 abcd",
\ "  2 klmn",
\ "  3 uvwx",
\ "  4 EFGH",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_relativenumber()
  call s:test_windows(10, 20)
  call setline(1, ["abcdefghij", "klmnopqrst", "uvwxyzABCD", "EFGHIJKLMN", "OPQRSTUVWX", "YZ"])
  3
  setl relativenumber
  let lines = s:screen_lines(1, 6)
  let expect = [
\ "  2 abcd",
\ "  1 klmn",
\ "  0 uvwx",
\ "  1 EFGH",
\ "  2 OPQR",
\ "  3 YZ  ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_number_with_relativenumber()
  call s:test_windows(10, 20)
  call setline(1, ["abcdefghij", "klmnopqrst", "uvwxyzABCD", "EFGHIJKLMN", "OPQRSTUVWX", "YZ"])
  4
  setl number relativenumber
  let lines = s:screen_lines(1, 6)
  let expect = [
\ "  3 abcd",
\ "  2 klmn",
\ "  1 uvwx",
\ "4   EFGH",
\ "  1 OPQR",
\ "  2 YZ  ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_number_with_linewrap1()
  call s:test_windows(3, 20)
  normal! 61ia
  setl number wrap
  call s:validate_cursor()
  let lines = s:screen_lines(1, 3)
  let expect = [
\ "<<< aaaa",
\ "    aaaa",
\ "    aaaa",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

" Pending: https://groups.google.com/forum/#!topic/vim_dev/tzNKP7EDWYI
func XTest_number_with_linewrap2()
  call s:test_windows(3, 20)
  normal! 61ia
  setl number wrap
  call s:validate_cursor()
  0
  call s:validate_cursor()
  let lines = s:screen_lines(1, 3)
  let expect = [
\ "  1 aaaa",
\ "    aaaa",
\ "    aaaa",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

" Pending: https://groups.google.com/forum/#!topic/vim_dev/tzNKP7EDWYI
func XTest_number_with_linewrap3()
  call s:test_windows(4, 20)
  normal! 81ia
  setl number wrap
  call s:validate_cursor()
  setl nonumber
  call s:validate_cursor()
  let lines = s:screen_lines(1, 4)
  let expect = [
\ "aaaaaaaa",
\ "aaaaaaaa",
\ "aaaaaaaa",
\ "a       ",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_numberwidth()
  call s:test_windows(10, 20)
  call setline(1, repeat(['aaaa'], 10))
  setl number numberwidth=6
  let lines = s:screen_lines(1, 3)
  let expect = [
\ "    1 aa",
\ "    2 aa",
\ "    3 aa",
\ ]
  call s:compare_lines(expect, lines)

  set relativenumber
  let lines = s:screen_lines(1, 3)
  let expect = [
\ "1     aa",
\ "    1 aa",
\ "    2 aa",
\ ]
  call s:compare_lines(expect, lines)

  set nonumber
  let lines = s:screen_lines(1, 3)
  let expect = [
\ "    0 aa",
\ "    1 aa",
\ "    2 aa",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

func Test_numberwidth_adjusted()
  call s:test_windows(10, 20)
  call setline(1, repeat(['aaaa'], 10000))
  setl number numberwidth=4
  let lines = s:screen_lines(1, 3)
  let expect = [
\ "    1 aa",
\ "    2 aa",
\ "    3 aa",
\ ]
  call s:compare_lines(expect, lines)

  $
  let lines = s:screen_lines(8, 10)
  let expect = [
\ " 9998 aa",
\ " 9999 aa",
\ "10000 aa",
\ ]
  call s:compare_lines(expect, lines)

  setl relativenumber
  let lines = s:screen_lines(8, 10)
  let expect = [
\ "    2 aa",
\ "    1 aa",
\ "10000 aa",
\ ]
  call s:compare_lines(expect, lines)

  setl nonumber
  let lines = s:screen_lines(8, 10)
  let expect = [
\ "  2 aaaa",
\ "  1 aaaa",
\ "  0 aaaa",
\ ]
  call s:compare_lines(expect, lines)
  call s:close_windows()
endfunc

" This was causing a memcheck error
func Test_relativenumber_uninitialised()
  new
  set rnu
  call setline(1, ["a", "b"])
  redraw
  call feedkeys("j", 'xt')
  redraw
  bwipe!
endfunc

func Test_relativenumber_colors()
  CheckScreendump

  let lines =<< trim [CODE]
    call setline(1, range(200))
    111
    set number relativenumber
    hi LineNr ctermfg=red
  [CODE]
  call writefile(lines, 'XTest_relnr', 'D')

  let buf = RunVimInTerminal('-S XTest_relnr', {'rows': 10, 'cols': 50})
  " Default colors
  call VerifyScreenDump(buf, 'Test_relnr_colors_1', {})

  call term_sendkeys(buf, ":hi LineNrAbove ctermfg=blue\<CR>:\<CR>")
  call VerifyScreenDump(buf, 'Test_relnr_colors_2', {})

  call term_sendkeys(buf, ":hi LineNrBelow ctermfg=green\<CR>:\<CR>")
  call VerifyScreenDump(buf, 'Test_relnr_colors_3', {})

  call term_sendkeys(buf, ":hi clear LineNrAbove\<CR>")
  call VerifyScreenDump(buf, 'Test_relnr_colors_4', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_relativenumber_colors_wrapped()
  CheckScreendump

  let lines =<< trim [CODE]
    set display=lastline scrolloff=0
    call setline(1, range(200)->map('v:val->string()->repeat(40)'))
    111
    set number relativenumber
    hi LineNr ctermbg=red ctermfg=black
    hi LineNrAbove ctermbg=blue ctermfg=black
    hi LineNrBelow ctermbg=green ctermfg=black
  [CODE]
  call writefile(lines, 'XTest_relnr_wrap', 'D')

  let buf = RunVimInTerminal('-S XTest_relnr_wrap', {'rows': 20, 'cols': 50})

  call VerifyScreenDump(buf, 'Test_relnr_colors_wrapped_1', {})
  call term_sendkeys(buf, "k")
  call VerifyScreenDump(buf, 'Test_relnr_colors_wrapped_2', {})
  call term_sendkeys(buf, "2j")
  call VerifyScreenDump(buf, 'Test_relnr_colors_wrapped_3', {})
  call term_sendkeys(buf, "2j")
  call VerifyScreenDump(buf, 'Test_relnr_colors_wrapped_4', {})
  call term_sendkeys(buf, "k")
  call VerifyScreenDump(buf, 'Test_relnr_colors_wrapped_5', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_relativenumber_callback()
  CheckScreendump
  CheckFeature timers

  let lines =<< trim END
      call setline(1, ['aaaaa', 'bbbbb', 'ccccc', 'ddddd'])
      set relativenumber
      call cursor(4, 1)

      func Func(timer)
        call cursor(1, 1)
      endfunc

      call timer_start(300, 'Func')
  END
  call writefile(lines, 'Xrnu_timer', 'D')

  let buf = RunVimInTerminal('-S Xrnu_timer', #{rows: 8})
  call TermWait(buf, 310)
  call VerifyScreenDump(buf, 'Test_relativenumber_callback_1', {})

  call StopVimInTerminal(buf)
endfunc

" Test for displaying line numbers with 'rightleft'
func Test_number_rightleft()
  CheckFeature rightleft
  new
  setlocal number
  setlocal rightleft
  call setline(1, range(1, 1000))
  normal! 9Gzt
  redraw!
  call assert_match('^\s\+9 9$', Screenline(1))
  normal! 10Gzt
  redraw!
  call assert_match('^\s\+01 10$', Screenline(1))
  normal! 100Gzt
  redraw!
  call assert_match('^\s\+001 100$', Screenline(1))
  normal! 1000Gzt
  redraw!
  call assert_match('^\s\+0001 1000$', Screenline(1))
  bw!
endfunc

" This used to cause a divide by zero
func Test_number_no_text_virtual_edit()
  vnew
  call setline(1, ['line one', 'line two'])
  set number virtualedit=all
  normal w
  4wincmd |
  normal j
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
