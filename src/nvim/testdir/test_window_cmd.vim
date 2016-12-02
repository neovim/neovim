" Tests for window cmd (:wincmd, :split, :vsplit, :resize and etc...)

func Test_window_cmd_ls0_with_split()
  set ls=0
  set splitbelow
  split
  quit
  call assert_equal(0, &lines - &cmdheight - winheight(0))
  new | only!
  "
  set splitbelow&vim
  botright split
  quit
  call assert_equal(0, &lines - &cmdheight - winheight(0))
  new | only!
  set ls&vim
endfunc

func Test_window_cmd_cmdwin_with_vsp()
  let efmt='Expected 0 but got %d (in ls=%d, %s window)'
  for v in range(0, 2)
    exec "set ls=" . v
    vsplit
    call feedkeys("q:\<CR>")
    let ac = &lines - (&cmdheight + winheight(0) + !!v)
    let emsg = printf(efmt, ac, v, 'left')
    call assert_equal(0, ac, emsg)
    wincmd w
    let ac = &lines - (&cmdheight + winheight(0) + !!v)
    let emsg = printf(efmt, ac, v, 'right')
    call assert_equal(0, ac, emsg)
    new | only!
  endfor
  set ls&vim
endfunc

" vim: sw=2 et
