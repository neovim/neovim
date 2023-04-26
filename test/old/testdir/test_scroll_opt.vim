" Test for reset 'scroll' and 'smoothscroll'

source check.vim
source screendump.vim

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
      set number cpo+=n
      :3
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



" vim: shiftwidth=2 sts=2 expandtab
