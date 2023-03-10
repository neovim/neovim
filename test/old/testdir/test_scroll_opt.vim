" Test for reset 'scroll'

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

" vim: shiftwidth=2 sts=2 expandtab
