" Test for 'scroll', 'scrolloff', 'smoothscroll', etc.

source check.vim
source screendump.vim
source mouse.vim

func Test_reset_scroll()
  let scr = &l:scroll

  setlocal scroll=1
  setlocal scroll&
  call assert_equal(scr, &l:scroll)

  setlocal scroll=1
  setlocal scroll=0
  call assert_equal(scr, &l:scroll)

  try
    execute 'setlocal scroll=' . (winheight(0) + 1)
    " not reached
    call assert_false(1)
  catch
    call assert_exception('E49:')
  endtry

  split

  let scr = &l:scroll

  setlocal scroll=1
  setlocal scroll&
  call assert_equal(scr, &l:scroll)

  setlocal scroll=1
  setlocal scroll=0
  call assert_equal(scr, &l:scroll)

  quit!
endfunc

func Test_scolloff_even_line_count()
  new
  resize 6
  setlocal scrolloff=3
  call setline(1, range(20))
  normal 2j
  call assert_equal(1, getwininfo(win_getid())[0].topline)
  normal j
  call assert_equal(1, getwininfo(win_getid())[0].topline)
  normal j
  call assert_equal(2, getwininfo(win_getid())[0].topline)
  normal j
  call assert_equal(3, getwininfo(win_getid())[0].topline)

  bwipe!
endfunc

func Test_mouse_scroll_inactive_with_cursorbind()
  for scb in [0, 1]
    for so in [0, 1, 2]
      let msg = $'scb={scb} so={so}'

      new | only
      let w1 = win_getid()
      setlocal cursorbind
      let &l:scb = scb
      let &l:so = so
      call setline(1, range(101, 109))
      rightbelow vnew
      let w2 = win_getid()
      setlocal cursorbind
      let &l:scb = scb
      let &l:so = so
      call setline(1, range(101, 109))

      normal! $
      call assert_equal(3, col('.', w1), msg)
      call assert_equal(3, col('.', w2), msg)
      call Ntest_setmouse(1, 1)
      call feedkeys("\<ScrollWheelDown>", 'xt')
      call assert_equal(4, line('w0', w1), msg)
      call assert_equal(4 + so, line('.', w1), msg)
      call assert_equal(1, line('w0', w2), msg)
      call assert_equal(1, line('.', w2), msg)
      call feedkeys("\<ScrollWheelDown>", 'xt')
      call assert_equal(7, line('w0', w1), msg)
      call assert_equal(7 + so, line('.', w1), msg)
      call assert_equal(1, line('w0', w2), msg)
      call assert_equal(1, line('.', w2), msg)
      call feedkeys("\<ScrollWheelUp>", 'xt')
      call assert_equal(4, line('w0', w1), msg)
      call assert_equal(7 + so, line('.', w1), msg)
      call assert_equal(1, line('w0', w2), msg)
      call assert_equal(1, line('.', w2), msg)
      call feedkeys("\<ScrollWheelUp>", 'xt')
      call assert_equal(1, line('w0', w1), msg)
      call assert_equal(7 + so, line('.', w1), msg)
      call assert_equal(1, line('w0', w2), msg)
      call assert_equal(1, line('.', w2), msg)
      normal! 0
      call assert_equal(1, line('.', w1), msg)
      call assert_equal(1, col('.', w1), msg)
      call assert_equal(1, line('.', w2), msg)
      call assert_equal(1, col('.', w2), msg)

      bwipe!
      bwipe!
    endfor
  endfor
endfunc

func Test_CtrlE_CtrlY_stop_at_end()
  enew
  call setline(1, ['one', 'two'])
  set number
  exe "normal \<C-Y>"
  call assert_equal(["  1 one   "], ScreenLines(1, 10))
  exe "normal \<C-E>\<C-E>\<C-E>"
  call assert_equal(["  2 two   "], ScreenLines(1, 10))

  bwipe!
  set nonumber
endfunc

func Test_smoothscroll_CtrlE_CtrlY()
  CheckScreendump

  let lines =<< trim END
      vim9script
      setline(1, [
        'line one',
        'word '->repeat(20),
        'line three',
        'long word '->repeat(7),
        'line',
        'line',
        'line',
      ])
      set smoothscroll
      :5
  END
  call writefile(lines, 'XSmoothScroll', 'D')
  let buf = RunVimInTerminal('-S XSmoothScroll', #{rows: 12, cols: 40})

  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_1', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_2', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_3', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_4', {})

  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_5', {})
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_6', {})
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_7', {})
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_8', {})

  if has('folding')
    call term_sendkeys(buf, ":set foldmethod=indent\<CR>")
    " move the cursor so we can reuse the same dumps
    call term_sendkeys(buf, "5G")
    call term_sendkeys(buf, "\<C-E>")
    call VerifyScreenDump(buf, 'Test_smoothscroll_1', {})
    call term_sendkeys(buf, "\<C-E>")
    call VerifyScreenDump(buf, 'Test_smoothscroll_2', {})
    call term_sendkeys(buf, "7G")
    call term_sendkeys(buf, "\<C-Y>")
    call VerifyScreenDump(buf, 'Test_smoothscroll_7', {})
    call term_sendkeys(buf, "\<C-Y>")
    call VerifyScreenDump(buf, 'Test_smoothscroll_8', {})
  endif

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_multibyte()
  CheckScreendump

  let lines =<< trim END
      set scrolloff=0 smoothscroll
      call setline(1, [repeat('ϛ', 45), repeat('2', 36)])
      exe "normal G35l\<C-E>k"
  END
  call writefile(lines, 'XSmoothMultibyte', 'D')
  let buf = RunVimInTerminal('-S XSmoothMultibyte', #{rows: 6, cols: 40})
  call VerifyScreenDump(buf, 'Test_smoothscroll_multi_1', {})

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_number()
  CheckScreendump

  let lines =<< trim END
      vim9script
      setline(1, [
        'one ' .. 'word '->repeat(20),
        'two ' .. 'long word '->repeat(7),
        'line',
        'line',
        'line',
      ])
      set smoothscroll
      set splitkeep=topline
      set number cpo+=n
      :3

      def g:DoRel()
        set number relativenumber scrolloff=0
        :%del
        setline(1, [
          'one',
          'very long text '->repeat(12),
          'three',
        ])
        exe "normal 2Gzt\<C-E>"
      enddef
  END
  call writefile(lines, 'XSmoothNumber', 'D')
  let buf = RunVimInTerminal('-S XSmoothNumber', #{rows: 12, cols: 40})

  call VerifyScreenDump(buf, 'Test_smooth_number_1', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_number_2', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_number_3', {})

  call term_sendkeys(buf, ":set cpo-=n\<CR>")
  call VerifyScreenDump(buf, 'Test_smooth_number_4', {})
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smooth_number_5', {})
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smooth_number_6', {})

  call term_sendkeys(buf, ":botright split\<CR>gg")
  call VerifyScreenDump(buf, 'Test_smooth_number_7', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_number_8', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_number_9', {})
  call term_sendkeys(buf, ":close\<CR>")

  call term_sendkeys(buf, ":call DoRel()\<CR>")
  call VerifyScreenDump(buf, 'Test_smooth_number_10', {})

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_list()
  CheckScreendump

  let lines =<< trim END
      vim9script
      set smoothscroll scrolloff=0
      set list
      setline(1, [
        'one',
        'very long text '->repeat(12),
        'three',
      ])
      exe "normal 2Gzt\<C-E>"
  END
  call writefile(lines, 'XSmoothList', 'D')
  let buf = RunVimInTerminal('-S XSmoothList', #{rows: 8, cols: 40})

  call VerifyScreenDump(buf, 'Test_smooth_list_1', {})

  call term_sendkeys(buf, ":set listchars+=precedes:#\<CR>")
  call VerifyScreenDump(buf, 'Test_smooth_list_2', {})

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_diff_mode()
  CheckScreendump

  let lines =<< trim END
      vim9script
      var text = 'just some text here'
      setline(1, text)
      set smoothscroll
      diffthis
      new
      setline(1, text)
      set smoothscroll
      diffthis
  END
  call writefile(lines, 'XSmoothDiff', 'D')
  let buf = RunVimInTerminal('-S XSmoothDiff', #{rows: 8})

  call VerifyScreenDump(buf, 'Test_smooth_diff_1', {})
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smooth_diff_1', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_diff_1', {})

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_wrap_scrolloff_zero()
  CheckScreendump

  let lines =<< trim END
      vim9script
      setline(1, ['Line' .. (' with some text'->repeat(7))]->repeat(7))
      set smoothscroll scrolloff=0
      :3
  END
  call writefile(lines, 'XSmoothWrap', 'D')
  let buf = RunVimInTerminal('-S XSmoothWrap', #{rows: 8, cols: 40})

  call VerifyScreenDump(buf, 'Test_smooth_wrap_1', {})

  " moving cursor down - whole bottom line shows
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_smooth_wrap_2', {})

  call term_sendkeys(buf, "\<C-E>j")
  call VerifyScreenDump(buf, 'Test_smooth_wrap_3', {})

  call term_sendkeys(buf, "G")
  call VerifyScreenDump(buf, 'Test_smooth_wrap_4', {})

  call term_sendkeys(buf, "4\<C-Y>G")
  call VerifyScreenDump(buf, 'Test_smooth_wrap_4', {})

  " moving cursor up right after the <<< marker - no need to show whole line
  call term_sendkeys(buf, "2gj3l2k")
  call VerifyScreenDump(buf, 'Test_smooth_wrap_5', {})

  " moving cursor up where the <<< marker is - whole top line shows
  call term_sendkeys(buf, "2j02k")
  call VerifyScreenDump(buf, 'Test_smooth_wrap_6', {})

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_wrap_long_line()
  CheckScreendump

  let lines =<< trim END
      vim9script
      setline(1, ['one', 'two', 'Line' .. (' with lots of text'->repeat(30)) .. ' end', 'four'])
      set smoothscroll scrolloff=0
      normal 3G10|zt
  END
  call writefile(lines, 'XSmoothWrap', 'D')
  let buf = RunVimInTerminal('-S XSmoothWrap', #{rows: 6, cols: 40})
  call VerifyScreenDump(buf, 'Test_smooth_long_1', {})

  " scrolling up, cursor moves screen line down
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_long_2', {})
  call term_sendkeys(buf, "5\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_long_3', {})

  " scrolling down, cursor moves screen line up
  call term_sendkeys(buf, "5\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smooth_long_4', {})
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smooth_long_5', {})

  " 'scrolloff' set to 1, scrolling up, cursor moves screen line down
  call term_sendkeys(buf, ":set scrolloff=1\<CR>")
  call term_sendkeys(buf, "10|\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_long_6', {})
  
  " 'scrolloff' set to 1, scrolling down, cursor moves screen line up
  call term_sendkeys(buf, "\<C-E>")
  call term_sendkeys(buf, "gjgj")
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smooth_long_7', {})
  
  " 'scrolloff' set to 2, scrolling up, cursor moves screen line down
  call term_sendkeys(buf, ":set scrolloff=2\<CR>")
  call term_sendkeys(buf, "10|\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_long_8', {})
  
  " 'scrolloff' set to 2, scrolling down, cursor moves screen line up
  call term_sendkeys(buf, "\<C-E>")
  call term_sendkeys(buf, "gj")
  call term_sendkeys(buf, "\<C-Y>")
  call VerifyScreenDump(buf, 'Test_smooth_long_9', {})

  " 'scrolloff' set to 0, move cursor down one line.
  " Cursor should move properly, and since this is a really long line, it will
  " be put on top of the screen.
  call term_sendkeys(buf, ":set scrolloff=0\<CR>")
  call term_sendkeys(buf, "0j")
  call VerifyScreenDump(buf, 'Test_smooth_long_10', {})

  " Test zt/zz/zb that they work properly when a long line is above it
  call term_sendkeys(buf, "zt")
  call VerifyScreenDump(buf, 'Test_smooth_long_11', {})
  call term_sendkeys(buf, "zz")
  call VerifyScreenDump(buf, 'Test_smooth_long_12', {})
  call term_sendkeys(buf, "zb")
  call VerifyScreenDump(buf, 'Test_smooth_long_13', {})

  " Repeat the step and move the cursor down again.
  " This time, use a shorter long line that is barely long enough to span more
  " than one window. Note that the cursor is at the bottom this time because
  " Vim prefers to do so if we are scrolling a few lines only.
  call term_sendkeys(buf, ":call setline(1, ['one', 'two', 'Line' .. (' with lots of text'->repeat(10)) .. ' end', 'four'])\<CR>")
  " Currently visible lines were replaced, test that the lines and cursor
  " are correctly displayed.
  call VerifyScreenDump(buf, 'Test_smooth_long_14', {})
  call term_sendkeys(buf, "3Gzt")
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_smooth_long_15', {})

  " Repeat the step but this time start it when the line is smooth-scrolled by
  " one line. This tests that the offset calculation is still correct and
  " still end up scrolling down to the next line with cursor at bottom of
  " screen.
  call term_sendkeys(buf, "3Gzt")
  call term_sendkeys(buf, "\<C-E>j")
  call VerifyScreenDump(buf, 'Test_smooth_long_16', {})
  
  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_one_long_line()
  CheckScreendump

  let lines =<< trim END
      vim9script
      setline(1, 'with lots of text '->repeat(7))
      set smoothscroll scrolloff=0
  END
  call writefile(lines, 'XSmoothOneLong', 'D')
  let buf = RunVimInTerminal('-S XSmoothOneLong', #{rows: 6, cols: 40})
  call VerifyScreenDump(buf, 'Test_smooth_one_long_1', {})
  
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_one_long_2', {})

  call term_sendkeys(buf, "0")
  call VerifyScreenDump(buf, 'Test_smooth_one_long_1', {})

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_long_line_showbreak()
  CheckScreendump

  let lines =<< trim END
      vim9script
      # a line that spans four screen lines
      setline(1, 'with lots of text in one line '->repeat(6))
      set smoothscroll scrolloff=0 showbreak=+++\ 
  END
  call writefile(lines, 'XSmoothLongShowbreak', 'D')
  let buf = RunVimInTerminal('-S XSmoothLongShowbreak', #{rows: 6, cols: 40})
  call VerifyScreenDump(buf, 'Test_smooth_long_showbreak_1', {})
  
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_long_showbreak_2', {})

  call term_sendkeys(buf, "0")
  call VerifyScreenDump(buf, 'Test_smooth_long_showbreak_1', {})

  call StopVimInTerminal(buf)
endfunc

" Check that 'smoothscroll' marker is drawn over double-width char correctly.
" Run with multiple encodings.
func Test_smoothscroll_marker_over_double_width()
  " Run this in a separate Vim instance to avoid messing up.
  let after =<< trim [CODE]
    scriptencoding utf-8
    call setline(1, 'a'->repeat(&columns) .. '口'->repeat(10))
    setlocal smoothscroll
    redraw
    exe "norm \<C-E>"
    redraw
    " Check the chars one by one. Don't check the whole line concatenated.
    call assert_equal('<', screenstring(1, 1))
    call assert_equal('<', screenstring(1, 2))
    call assert_equal('<', screenstring(1, 3))
    call assert_equal(' ', screenstring(1, 4))
    call assert_equal('口', screenstring(1, 5))
    call assert_equal('口', screenstring(1, 7))
    call assert_equal('口', screenstring(1, 9))
    call assert_equal('口', screenstring(1, 11))
    call assert_equal('口', screenstring(1, 13))
    call assert_equal('口', screenstring(1, 15))
    call writefile(v:errors, 'Xresult')
    qall!
  [CODE]

  let encodings = ['utf-8', 'cp932', 'cp936', 'cp949', 'cp950']
  if !has('win32')
    let encodings += ['euc-jp']
  endif
  if has('nvim')
    let encodings = ['utf-8']
  endif
  for enc in encodings
    let msg = 'enc=' .. enc
    if RunVim([], after, $'--clean --cmd "set encoding={enc}"')
      call assert_equal([], readfile('Xresult'), msg)
    endif
    call delete('Xresult')
  endfor
endfunc

" Same as the test above, but check the text actually shown on screen.
" Only run with UTF-8 encoding.
func Test_smoothscroll_marker_over_double_width_dump()
  CheckScreendump

  let lines =<< trim END
    call setline(1, 'a'->repeat(&columns) .. '口'->repeat(10))
    setlocal smoothscroll
  END
  call writefile(lines, 'XSmoothMarkerOverDoubleWidth', 'D')
  let buf = RunVimInTerminal('-S XSmoothMarkerOverDoubleWidth', #{rows: 6, cols: 40})
  call VerifyScreenDump(buf, 'Test_smooth_marker_over_double_width_1', {})

  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_marker_over_double_width_2', {})

  call StopVimInTerminal(buf)
endfunc

func s:check_col_calc(win_col, win_line, buf_col)
  call assert_equal(a:win_col, wincol())
  call assert_equal(a:win_line, winline())
  call assert_equal(a:buf_col, col('.'))
endfunc

" Test that if the current cursor is on a smooth scrolled line, we correctly
" reposition it. Also check that we don't miscalculate the values by checking
" the consistency between wincol() and col('.') as they are calculated
" separately in code.
func Test_smoothscroll_cursor_position()
  call NewWindow(10, 20)
  setl smoothscroll wrap
  call setline(1, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

  call s:check_col_calc(1, 1, 1)
  exe "normal \<C-E>"

  " Move down another line to avoid blocking the <<< display
  call s:check_col_calc(1, 2, 41)
  exe "normal \<C-Y>"
  call s:check_col_calc(1, 3, 41)

  " Test "g0/g<Home>"
  exe "normal gg\<C-E>"
  norm $gkg0
  call s:check_col_calc(4, 1, 24)

  " Test moving the cursor behind the <<< display with 'virtualedit'
  set virtualedit=all
  exe "normal \<C-E>gkh"
  call s:check_col_calc(3, 2, 23)
  set virtualedit&

  normal gg3l
  exe "normal \<C-E>"

  " Move down only 1 line when we are out of the range of the <<< display
  call s:check_col_calc(4, 1, 24)
  exe "normal \<C-Y>"
  call s:check_col_calc(4, 2, 24)
  normal ggg$
  exe "normal \<C-E>"
  call s:check_col_calc(20, 1, 40)
  exe "normal \<C-Y>"
  call s:check_col_calc(20, 2, 40)
  normal gg

  " Test number, where we have indented lines
  setl number
  call s:check_col_calc(5, 1, 1)
  exe "normal \<C-E>"

  " Move down only 1 line when the <<< display is on the number column
  call s:check_col_calc(5, 1, 17)
  exe "normal \<C-Y>"
  call s:check_col_calc(5, 2, 17)
  normal ggg$
  exe "normal \<C-E>"
  call s:check_col_calc(20, 1, 32)
  exe "normal \<C-Y>"
  call s:check_col_calc(20, 2, 32)
  normal gg

  setl numberwidth=1

  " Move down another line when numberwidth is too short to cover the whole
  " <<< display
  call s:check_col_calc(3, 1, 1)
  exe "normal \<C-E>"
  call s:check_col_calc(3, 2, 37)
  exe "normal \<C-Y>"
  call s:check_col_calc(3, 3, 37)
  normal ggl

  " Only move 1 line down when we are just past the <<< display
  call s:check_col_calc(4, 1, 2)
  exe "normal \<C-E>"
  call s:check_col_calc(4, 1, 20)
  exe "normal \<C-Y>"
  call s:check_col_calc(4, 2, 20)
  normal gg
  setl numberwidth&

  " Test number + showbreak, so test that the additional indentation works
  setl number showbreak=+++
  call s:check_col_calc(5, 1, 1)
  exe "normal \<C-E>"
  call s:check_col_calc(8, 1, 17)
  exe "normal \<C-Y>"
  call s:check_col_calc(8, 2, 17)
  normal gg

  " Test number + cpo+=n mode, where wrapped lines aren't indented
  setl number cpo+=n showbreak=
  call s:check_col_calc(5, 1, 1)
  exe "normal \<C-E>"
  call s:check_col_calc(1, 2, 37)
  exe "normal \<C-Y>"
  call s:check_col_calc(1, 3, 37)
  normal gg

  " Test list + listchars "precedes", where there is always 1 overlap
  " regardless of number and cpo-=n.
  setl number list listchars=precedes:< cpo-=n
  call s:check_col_calc(5, 1, 1)
  exe "normal 3|\<C-E>h"
  call s:check_col_calc(6, 1, 18)
  norm h
  call s:check_col_calc(5, 2, 17)
  normal gg

  bwipe!
endfunc

func Test_smoothscroll_cursor_scrolloff()
  call NewWindow(10, 20)
  setl smoothscroll wrap
  setl scrolloff=3
  
  " 120 chars are 6 screen lines
  call setline(1, "abcdefghijklmnopqrstABCDEFGHIJKLMNOPQRSTabcdefghijklmnopqrstABCDEFGHIJKLMNOPQRSTabcdefghijklmnopqrstABCDEFGHIJKLMNOPQRST")
  call setline(2, "below")

  call s:check_col_calc(1, 1, 1)

  " CTRL-E shows "<<<DEFG...", cursor move four lines down
  exe "normal \<C-E>"
  call s:check_col_calc(1, 4, 81)

  " cursor on start of second line, "gk" moves into first line, skipcol doesn't
  " change
  exe "normal G0gk"
  call s:check_col_calc(1, 5, 101)

  " move cursor left one window width worth, scrolls one screen line
  exe "normal 20h"
  call s:check_col_calc(1, 5, 81)

  " move cursor left one window width worth, scrolls one screen line
  exe "normal 20h"
  call s:check_col_calc(1, 4, 61)

  " cursor on last line, "gk" should not cause a scroll
  set scrolloff=0
  normal G0
  call s:check_col_calc(1, 7, 1)
  normal gk
  call s:check_col_calc(1, 6, 101)

  bwipe!
endfunc


" Test that mouse picking is still accurate when we have smooth scrolled lines
func Test_smoothscroll_mouse_pos()
  CheckNotGui
  CheckUnix

  let save_mouse = &mouse
  "let save_term = &term
  "let save_ttymouse = &ttymouse
  set mouse=a "term=xterm ttymouse=xterm2

  call NewWindow(10, 20)
  setl smoothscroll wrap
  " First line will wrap to 3 physical lines. 2nd/3rd lines are short lines.
  call setline(1, ["abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", "line 2", "line 3"])

  func s:check_mouse_click(row, col, buf_row, buf_col)
    call MouseLeftClick(a:row, a:col)

    call assert_equal(a:col, wincol())
    call assert_equal(a:row, winline())
    call assert_equal(a:buf_row, line('.'))
    call assert_equal(a:buf_col, col('.'))
  endfunc

  " Check that clicking without scroll works first.
  call s:check_mouse_click(3, 5, 1, 45)
  call s:check_mouse_click(4, 1, 2, 1)
  call s:check_mouse_click(4, 6, 2, 6)
  call s:check_mouse_click(5, 1, 3, 1)
  call s:check_mouse_click(5, 6, 3, 6)

  " Smooth scroll, and checks that this didn't mess up mouse clicking
  exe "normal \<C-E>"
  call s:check_mouse_click(2, 5, 1, 45)
  call s:check_mouse_click(3, 1, 2, 1)
  call s:check_mouse_click(3, 6, 2, 6)
  call s:check_mouse_click(4, 1, 3, 1)
  call s:check_mouse_click(4, 6, 3, 6)

  exe "normal \<C-E>"
  call s:check_mouse_click(1, 5, 1, 45)
  call s:check_mouse_click(2, 1, 2, 1)
  call s:check_mouse_click(2, 6, 2, 6)
  call s:check_mouse_click(3, 1, 3, 1)
  call s:check_mouse_click(3, 6, 3, 6)

  " Make a new first line 11 physical lines tall so it's taller than window
  " height, to test overflow calculations with really long lines wrapping.
  normal gg
  call setline(1, "12345678901234567890"->repeat(11))
  exe "normal 6\<C-E>"
  call s:check_mouse_click(5, 1, 1, 201)
  call s:check_mouse_click(6, 1, 2, 1)
  call s:check_mouse_click(7, 1, 3, 1)

  let &mouse = save_mouse
  "let &term = save_term
  "let &ttymouse = save_ttymouse
  bwipe!
endfunc

" this was dividing by zero
func Test_smoothscroll_zero_width()
  CheckScreendump

  let lines =<< trim END
      winsize 0 0
      vsplit
      vsplit
      vsplit
      vsplit
      vsplit
      sil norm H
      set wrap
      set smoothscroll
      set number
  END
  call writefile(lines, 'XSmoothScrollZero', 'D')
  let buf = RunVimInTerminal('-u NONE -i NONE -n -m -X -Z -e -s -S XSmoothScrollZero', #{rows: 6, cols: 60, wait_for_ruler: 0})
  call VerifyScreenDump(buf, 'Test_smoothscroll_zero_1', {})

  call term_sendkeys(buf, ":sil norm \<C-V>\<C-W>\<C-V>\<C-N>\<CR>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_zero_2', {})

  call StopVimInTerminal(buf)
endfunc

" this was unnecessarily inserting lines
func Test_smoothscroll_ins_lines()
  CheckScreendump

  let lines =<< trim END
      set wrap
      set smoothscroll
      set scrolloff=0
      set conceallevel=2
      call setline(1, [
        \'line one' .. 'with lots of text in one line '->repeat(2),
        \'line two',
        \'line three',
        \'line four',
        \'line five'
      \])
  END
  call writefile(lines, 'XSmoothScrollInsLines', 'D')
  let buf = RunVimInTerminal('-S XSmoothScrollInsLines', #{rows: 6, cols: 40})

  call term_sendkeys(buf, "\<C-E>gjgk")
  call VerifyScreenDump(buf, 'Test_smooth_ins_lines', {})

  call StopVimInTerminal(buf)
endfunc

" this placed the cursor in the command line
func Test_smoothscroll_cursormoved_line()
  CheckScreendump

  let lines =<< trim END
      set smoothscroll
      call setline(1, [
        \'',
        \'_'->repeat(&lines * &columns),
        \(('_')->repeat(&columns - 2) .. 'xxx')->repeat(2)
      \])
      autocmd CursorMoved * eval [line('w0'), line('w$')]
      call search('xxx')
  END
  call writefile(lines, 'XSmoothCursorMovedLine', 'D')
  let buf = RunVimInTerminal('-S XSmoothCursorMovedLine', #{rows: 6})

  call VerifyScreenDump(buf, 'Test_smooth_cursormoved_line', {})

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_eob()
  CheckScreendump

  let lines =<< trim END
      set smoothscroll
      call setline(1, ['']->repeat(100))
      norm G
  END
  call writefile(lines, 'XSmoothEob', 'D')
  let buf = RunVimInTerminal('-S XSmoothEob', #{rows: 10})

  " does not scroll halfway when scrolling to end of buffer
  call VerifyScreenDump(buf, 'Test_smooth_eob_1', {})

  " cursor is not placed below window
  call term_sendkeys(buf, ":call setline(92, 'a'->repeat(100))\<CR>\<C-L>\<C-B>G")
  call VerifyScreenDump(buf, 'Test_smooth_eob_2', {})

  call StopVimInTerminal(buf)
endfunc

" skipcol should not reset when doing incremental search on the same word
func Test_smoothscroll_incsearch()
  CheckScreendump

  let lines =<< trim END
      set smoothscroll number scrolloff=0 incsearch
      call setline(1, repeat([''], 20))
      call setline(11, repeat('a', 100))
      call setline(14, 'bbbb')
  END
  call writefile(lines, 'XSmoothIncsearch', 'D')
  let buf = RunVimInTerminal('-S XSmoothIncsearch', #{rows: 8, cols: 40})

  call term_sendkeys(buf, "/b")
  call VerifyScreenDump(buf, 'Test_smooth_incsearch_1', {})
  call term_sendkeys(buf, "b")
  call VerifyScreenDump(buf, 'Test_smooth_incsearch_2', {})
  call term_sendkeys(buf, "b")
  call VerifyScreenDump(buf, 'Test_smooth_incsearch_3', {})
  call term_sendkeys(buf, "b")
  call VerifyScreenDump(buf, 'Test_smooth_incsearch_4', {})
  call term_sendkeys(buf, "\<CR>")

  call StopVimInTerminal(buf)
endfunc

" Test scrolling multiple lines and stopping at non-zero skipcol.
func Test_smoothscroll_multi_skipcol()
  CheckScreendump

  let lines =<< trim END
      setlocal cursorline scrolloff=0 smoothscroll
      call setline(1, repeat([''], 8))
      call setline(3, repeat('a', 50))
      call setline(4, repeat('a', 50))
      call setline(7, 'bbb')
      call setline(8, 'ccc')
      redraw
  END
  call writefile(lines, 'XSmoothMultiSkipcol', 'D')
  let buf = RunVimInTerminal('-S XSmoothMultiSkipcol', #{rows: 10, cols: 40})
  call VerifyScreenDump(buf, 'Test_smooth_multi_skipcol_1', {})

  call term_sendkeys(buf, "3\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_multi_skipcol_2', {})

  call term_sendkeys(buf, "2\<C-E>")
  call VerifyScreenDump(buf, 'Test_smooth_multi_skipcol_3', {})

  call StopVimInTerminal(buf)
endfunc

" this was dividing by zero bug in scroll_cursor_bot
func Test_smoothscroll_zero_width_scroll_cursor_bot()
  CheckScreendump

  let lines =<< trim END
      silent normal yy
      silent normal 19p
      set cpoptions+=n
      vsplit
      vertical resize 0
      set foldcolumn=1
      set number
      set smoothscroll
      silent normal 20G
  END
  call writefile(lines, 'XSmoothScrollZeroBot', 'D')
  let buf = RunVimInTerminal('-u NONE -S XSmoothScrollZeroBot', #{rows: 19})
  call VerifyScreenDump(buf, 'Test_smoothscroll_zero_bot', {})

  call StopVimInTerminal(buf)
endfunc

" scroll_cursor_top() should reset skipcol when it changes topline
func Test_smoothscroll_cursor_top()
  CheckScreendump

  let lines =<< trim END
      set smoothscroll scrolloff=2
      new | 11resize | wincmd j
      call setline(1, ['line1', 'line2', 'line3'->repeat(20), 'line4'])
      exe "norm G3\<C-E>k"
  END
  call writefile(lines, 'XSmoothScrollCursorTop', 'D')
  let buf = RunVimInTerminal('-u NONE -S XSmoothScrollCursorTop', #{rows: 12, cols: 40})
  call VerifyScreenDump(buf, 'Test_smoothscroll_cursor_top', {})

  call StopVimInTerminal(buf)
endfunc

" Division by zero, shouldn't crash
func Test_smoothscroll_crash()
  CheckScreendump

  let lines =<< trim END
      20 new
      vsp
      put =repeat('aaaa', 20)
      set nu fdc=1  smoothscroll cpo+=n
      vert resize 0
      exe "norm! 0\<c-e>"
  END
  call writefile(lines, 'XSmoothScrollCrash', 'D')
  let buf = RunVimInTerminal('-u NONE -S XSmoothScrollCrash', #{rows: 12, cols: 40})
  call term_sendkeys(buf, "2\<C-E>\<C-L>")

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_insert_bottom()
  CheckScreendump

  let lines =<< trim END
    call setline(1, repeat([repeat('A very long line ...', 10)], 5))
    set wrap smoothscroll scrolloff=0
  END
  call writefile(lines, 'XSmoothScrollInsertBottom', 'D')
  let buf = RunVimInTerminal('-u NONE -S XSmoothScrollInsertBottom', #{rows: 9, cols: 40})
  call term_sendkeys(buf, "Go123456789\<CR>")
  call VerifyScreenDump(buf, 'Test_smoothscroll_insert_bottom', {})

  call StopVimInTerminal(buf)
endfunc

func Test_smoothscroll_in_zero_width_window()
  set cpo+=n number smoothscroll
  set winwidth=99999 winminwidth=0

  vsplit
  call assert_equal(0, winwidth(winnr('#')))
  call win_execute(win_getid(winnr('#')), "norm! \<C-Y>")

  only!
  set winwidth& winminwidth&
  set cpo-=n nonumber nosmoothscroll
endfunc

func Test_smoothscroll_textoff_small_winwidth()
  set smoothscroll number
  call setline(1, 'llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch')
  vsplit

  let textoff = getwininfo(win_getid())[0].textoff
  execute 'vertical resize' textoff + 1
  redraw
  call assert_equal(0, winsaveview().skipcol)
  execute "normal! 0\<C-E>"
  redraw
  call assert_equal(1, winsaveview().skipcol)
  execute 'vertical resize' textoff - 1
  " This caused a signed integer overflow.
  redraw
  call assert_equal(1, winsaveview().skipcol)
  execute 'vertical resize' textoff
  " This caused an infinite loop.
  redraw
  call assert_equal(1, winsaveview().skipcol)

  %bw!
  set smoothscroll& number&
endfunc

func Test_smoothscroll_page()
  call NewWindow(10, 40)
  setlocal smoothscroll
  call setline(1, 'abcde '->repeat(150))

  exe "norm! \<C-F>"
  call assert_equal(400, winsaveview().skipcol)
  exe "norm! \<C-F>"
  call assert_equal(800, winsaveview().skipcol)
  exe "norm! \<C-F>"
  call assert_equal(880, winsaveview().skipcol)
  exe "norm! \<C-B>"
  call assert_equal(480, winsaveview().skipcol)
  exe "norm! \<C-B>"
  call assert_equal(80, winsaveview().skipcol)
  exe "norm! \<C-B>"
  call assert_equal(0, winsaveview().skipcol)

  " Half-page scrolling does not go beyond end of buffer and moves the cursor.
  " Even with 'nostartofline', the correct amount of lines is scrolled.
  setl nostartofline
  exe "norm! 15|\<C-D>"
  call assert_equal(200, winsaveview().skipcol)
  call assert_equal(215, col('.'))
  exe "norm! \<C-D>"
  call assert_equal(400, winsaveview().skipcol)
  call assert_equal(415, col('.'))
  exe "norm! \<C-D>"
  call assert_equal(520, winsaveview().skipcol)
  call assert_equal(615, col('.'))
  exe "norm! \<C-D>"
  call assert_equal(520, winsaveview().skipcol)
  call assert_equal(815, col('.'))
  exe "norm! \<C-D>"
  call assert_equal(520, winsaveview().skipcol)
  call assert_equal(895, col('.'))
  exe "norm! \<C-U>"
  call assert_equal(320, winsaveview().skipcol)
  call assert_equal(695, col('.'))
  exe "norm! \<C-U>"
  call assert_equal(120, winsaveview().skipcol)
  call assert_equal(495, col('.'))
  exe "norm! \<C-U>"
  call assert_equal(0, winsaveview().skipcol)
  call assert_equal(295, col('.'))
  exe "norm! \<C-U>"
  call assert_equal(0, winsaveview().skipcol)
  call assert_equal(95, col('.'))
  exe "norm! \<C-U>"
  call assert_equal(0, winsaveview().skipcol)
  call assert_equal(15, col('.'))

  bwipe!
endfunc

func Test_smoothscroll_next_topline()
  call NewWindow(10, 40)
  setlocal smoothscroll
  call setline(1, ['abcde '->repeat(150)]->repeat(2))

  " Scrolling a screenline that causes the cursor to move to the next buffer
  " line should not skip part of that line to bring the cursor into view.
  exe "norm! 22\<C-E>"
  call assert_equal(880, winsaveview().skipcol)
  exe "norm! \<C-E>"
  redraw
  call assert_equal(0, winsaveview().skipcol)

  " Also when scrolling back.
  exe "norm! G\<C-Y>"
  redraw
  call assert_equal(880, winsaveview().skipcol)

  " Cursor in correct place when not in the first screenline of a buffer line.
  exe "norm! gg4gj20\<C-D>\<C-D>"
  redraw
  call assert_equal(2, line('w0'))

  " Cursor does not end up above topline, adjusting topline later.
  setlocal nu cpo+=n
  exe "norm! G$g013\<C-Y>"
  redraw
  call assert_equal(2, line('.'))
  call assert_equal(0, winsaveview().skipcol)

  set cpo-=n
  bwipe!
endfunc

func Test_smoothscroll_long_line_zb()
  call NewWindow(10, 40)
  call setline(1, 'abcde '->repeat(150))

  " Also works without 'smoothscroll' when last line of buffer doesn't fit.
  " Used to set topline to buffer line count plus one, causing an empty screen.
  norm zb
  redraw
  call assert_equal(1, winsaveview().topline)

  " Moving cursor to bottom works on line that doesn't fit with 'smoothscroll'.
  " Skipcol was adjusted later for cursor being on not visible part of line.
  setlocal smoothscroll
  norm zb
  redraw
  call assert_equal(520, winsaveview().skipcol)

  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
