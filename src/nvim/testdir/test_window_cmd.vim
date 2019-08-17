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
  let efmt = 'Expected 0 but got %d (in ls=%d, %s window)'
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

function Test_window_cmd_wincmd_gf()
  let fname = 'test_gf.txt'
  let swp_fname = '.' . fname . '.swp'
  call writefile([], fname)
  call writefile([], swp_fname)
  function s:swap_exists()
    let v:swapchoice = s:swap_choice
  endfunc
  " Remove the catch-all that runtest.vim adds
  au! SwapExists
  augroup test_window_cmd_wincmd_gf
    autocmd!
    exec "autocmd SwapExists " . fname . " call s:swap_exists()"
  augroup END

  call setline(1, fname)
  " (E)dit anyway
  let s:swap_choice = 'e'
  wincmd gf
  call assert_equal(2, tabpagenr())
  call assert_equal(fname, bufname("%"))
  quit!

  " (Q)uit
  let s:swap_choice = 'q'
  wincmd gf
  call assert_equal(1, tabpagenr())
  call assert_notequal(fname, bufname("%"))
  new | only!

  call delete(fname)
  call delete(swp_fname)
  augroup! test_window_cmd_wincmd_gf
endfunc

func Test_next_split_all()
  " This was causing an illegal memory access.
  n x
  norm axxx
  split
  split
  s/x
  s/x
  all
  bwipe!
endfunc

func Test_window_quit()
  e Xa
  split Xb
  call assert_equal(2, winnr('$'))
  call assert_equal('Xb', bufname(winbufnr(1)))
  call assert_equal('Xa', bufname(winbufnr(2)))

  wincmd q
  call assert_equal(1, winnr('$'))
  call assert_equal('Xa', bufname(winbufnr(1)))

  bw Xa Xb
endfunc

func Test_window_horizontal_split()
  call assert_equal(1, winnr('$'))
  3wincmd s
  call assert_equal(2, winnr('$'))
  call assert_equal(3, winheight(0))
  call assert_equal(winwidth(1), winwidth(2))

  call assert_fails('botright topleft wincmd s', 'E442:')
  bw
endfunc

func Test_window_vertical_split()
  call assert_equal(1, winnr('$'))
  3wincmd v
  call assert_equal(2, winnr('$'))
  call assert_equal(3, winwidth(0))
  call assert_equal(winheight(1), winheight(2))

  call assert_fails('botright topleft wincmd v', 'E442:')
  bw
endfunc

func Test_window_split_edit_alternate()
  e Xa
  e Xb

  wincmd ^
  call assert_equal('Xa', bufname(winbufnr(1)))
  call assert_equal('Xb', bufname(winbufnr(2)))

  bw Xa Xb
endfunc

func Test_window_preview()
  " Open a preview window
  pedit Xa
  call assert_equal(2, winnr('$'))
  call assert_equal(0, &previewwindow)

  " Go to the preview window
  wincmd P
  call assert_equal(1, &previewwindow)

  " Close preview window
  wincmd z
  call assert_equal(1, winnr('$'))
  call assert_equal(0, &previewwindow)

  call assert_fails('wincmd P', 'E441:')
endfunc

func Test_window_preview_from_help()
  filetype on
  call writefile(['/* some C code */'], 'Xpreview.c')
  help
  pedit Xpreview.c
  wincmd P
  call assert_equal(1, &previewwindow)
  call assert_equal('c', &filetype)
  wincmd z

  filetype off
  close
  call delete('Xpreview.c')
endfunc

func Test_window_exchange()
  e Xa

  " Nothing happens with window exchange when there is 1 window
  wincmd x
  call assert_equal(1, winnr('$'))

  split Xb
  split Xc

  call assert_equal('Xc', bufname(winbufnr(1)))
  call assert_equal('Xb', bufname(winbufnr(2)))
  call assert_equal('Xa', bufname(winbufnr(3)))

  " Exchange current window 1 with window 3
  3wincmd x
  call assert_equal('Xa', bufname(winbufnr(1)))
  call assert_equal('Xb', bufname(winbufnr(2)))
  call assert_equal('Xc', bufname(winbufnr(3)))

  " Exchange window with next when at the top window
  wincmd x
  call assert_equal('Xb', bufname(winbufnr(1)))
  call assert_equal('Xa', bufname(winbufnr(2)))
  call assert_equal('Xc', bufname(winbufnr(3)))

  " Exchange window with next when at the middle window
  wincmd j
  wincmd x
  call assert_equal('Xb', bufname(winbufnr(1)))
  call assert_equal('Xc', bufname(winbufnr(2)))
  call assert_equal('Xa', bufname(winbufnr(3)))

  " Exchange window with next when at the bottom window.
  " When there is no next window, it exchanges with the previous window.
  wincmd j
  wincmd x
  call assert_equal('Xb', bufname(winbufnr(1)))
  call assert_equal('Xa', bufname(winbufnr(2)))
  call assert_equal('Xc', bufname(winbufnr(3)))

  bw Xa Xb Xc
endfunc

func Test_window_rotate()
  e Xa
  split Xb
  split Xc
  call assert_equal('Xc', bufname(winbufnr(1)))
  call assert_equal('Xb', bufname(winbufnr(2)))
  call assert_equal('Xa', bufname(winbufnr(3)))

  " Rotate downwards
  wincmd r
  call assert_equal('Xa', bufname(winbufnr(1)))
  call assert_equal('Xc', bufname(winbufnr(2)))
  call assert_equal('Xb', bufname(winbufnr(3)))

  2wincmd r
  call assert_equal('Xc', bufname(winbufnr(1)))
  call assert_equal('Xb', bufname(winbufnr(2)))
  call assert_equal('Xa', bufname(winbufnr(3)))

  " Rotate upwards
  wincmd R
  call assert_equal('Xb', bufname(winbufnr(1)))
  call assert_equal('Xa', bufname(winbufnr(2)))
  call assert_equal('Xc', bufname(winbufnr(3)))

  2wincmd R
  call assert_equal('Xc', bufname(winbufnr(1)))
  call assert_equal('Xb', bufname(winbufnr(2)))
  call assert_equal('Xa', bufname(winbufnr(3)))

  bot vsplit
  call assert_fails('wincmd R', 'E443:')

  bw Xa Xb Xc
endfunc

func Test_window_height()
  e Xa
  split Xb

  let [wh1, wh2] = [winheight(1), winheight(2)]
  " Active window (1) should have the same height or 1 more
  " than the other window.
  call assert_inrange(wh2, wh2 + 1, wh1)

  wincmd -
  call assert_equal(wh1 - 1, winheight(1))
  call assert_equal(wh2 + 1, winheight(2))

  wincmd +
  call assert_equal(wh1, winheight(1))
  call assert_equal(wh2, winheight(2))

  2wincmd _
  call assert_equal(2, winheight(1))
  call assert_equal(wh1 + wh2 - 2, winheight(2))

  wincmd =
  call assert_equal(wh1, winheight(1))
  call assert_equal(wh2, winheight(2))

  2wincmd _
  set winfixheight
  split Xc
  let [wh1, wh2, wh3] = [winheight(1), winheight(2), winheight(3)]
  call assert_equal(2, winheight(2))
  call assert_inrange(wh3, wh3 + 1, wh1)
  3wincmd +
  call assert_equal(2,       winheight(2))
  call assert_equal(wh1 + 3, winheight(1))
  call assert_equal(wh3 - 3, winheight(3))
  wincmd =
  call assert_equal(2,   winheight(2))
  call assert_equal(wh1, winheight(1))
  call assert_equal(wh3, winheight(3))

  wincmd j
  set winfixheight&

  wincmd =
  let [wh1, wh2, wh3] = [winheight(1), winheight(2), winheight(3)]
  " Current window (2) should have the same height or 1 more
  " than the other windows.
  call assert_inrange(wh1, wh1 + 1, wh2)
  call assert_inrange(wh3, wh3 + 1, wh2)

  bw Xa Xb Xc
endfunc

func Test_window_width()
  e Xa
  vsplit Xb

  let [ww1, ww2] = [winwidth(1), winwidth(2)]
  " Active window (1) should have the same width or 1 more
  " than the other window.
  call assert_inrange(ww2, ww2 + 1, ww1)

  wincmd <
  call assert_equal(ww1 - 1, winwidth(1))
  call assert_equal(ww2 + 1, winwidth(2))

  wincmd >
  call assert_equal(ww1, winwidth(1))
  call assert_equal(ww2, winwidth(2))

  2wincmd |
  call assert_equal(2, winwidth(1))
  call assert_equal(ww1 + ww2 - 2, winwidth(2))

  wincmd =
  call assert_equal(ww1, winwidth(1))
  call assert_equal(ww2, winwidth(2))

  2wincmd |
  set winfixwidth
  vsplit Xc
  let [ww1, ww2, ww3] = [winwidth(1), winwidth(2), winwidth(3)]
  call assert_equal(2, winwidth(2))
  call assert_inrange(ww3, ww3 + 1, ww1)
  3wincmd >
  call assert_equal(2,       winwidth(2))
  call assert_equal(ww1 + 3, winwidth(1))
  call assert_equal(ww3 - 3, winwidth(3))
  wincmd =
  call assert_equal(2,   winwidth(2))
  call assert_equal(ww1, winwidth(1))
  call assert_equal(ww3, winwidth(3))

  wincmd l
  set winfixwidth&

  wincmd =
  let [ww1, ww2, ww3] = [winwidth(1), winwidth(2), winwidth(3)]
  " Current window (2) should have the same width or 1 more
  " than the other windows.
  call assert_inrange(ww1, ww1 + 1, ww2)
  call assert_inrange(ww3, ww3 + 1, ww2)

  bw Xa Xb Xc
endfunc

func Test_equalalways_on_close()
  set equalalways
  vsplit
  windo split
  split
  wincmd J
  " now we have a frame top-left with two windows, a frame top-right with two
  " windows and a frame at the bottom, full-width.
  let height_1 = winheight(1)
  let height_2 = winheight(2)
  let height_3 = winheight(3)
  let height_4 = winheight(4)
  " closing the bottom window causes all windows to be resized.
  close
  call assert_notequal(height_1, winheight(1))
  call assert_notequal(height_2, winheight(2))
  call assert_notequal(height_3, winheight(3))
  call assert_notequal(height_4, winheight(4))
  call assert_equal(winheight(1), winheight(3))
  call assert_equal(winheight(2), winheight(4))

  1wincmd w
  split
  4wincmd w
  resize + 5
  " left column has three windows, equalized heights.
  " right column has two windows, top one a bit higher
  let height_1 = winheight(1)
  let height_2 = winheight(2)
  let height_4 = winheight(4)
  let height_5 = winheight(5)
  3wincmd w
  " closing window in left column equalizes heights in left column but not in
  " the right column
  close
  call assert_notequal(height_1, winheight(1))
  call assert_notequal(height_2, winheight(2))
  call assert_equal(height_4, winheight(3))
  call assert_equal(height_5, winheight(4))

  only
  set equalalways&
endfunc

func Test_win_screenpos()
  call assert_equal(1, winnr('$'))
  split
  vsplit
  10wincmd _
  30wincmd |
  call assert_equal([1, 1], win_screenpos(1))
  call assert_equal([1, 32], win_screenpos(2))
  call assert_equal([12, 1], win_screenpos(3))
  call assert_equal([0, 0], win_screenpos(4))
  only
endfunc

func Test_window_jump_tag()
  help
  /iccf
  call assert_match('^|iccf|',  getline('.'))
  call assert_equal(2, winnr('$'))
  2wincmd }
  call assert_equal(3, winnr('$'))
  call assert_match('^|iccf|',  getline('.'))
  wincmd k
  call assert_match('\*iccf\*',  getline('.'))
  call assert_equal(2, winheight(0))

  wincmd z
  set previewheight=4
  help
  /bugs
  wincmd }
  wincmd k
  call assert_match('\*bugs\*',  getline('.'))
  call assert_equal(4, winheight(0))
  set previewheight&

  %bw!
endfunc

func Test_window_newtab()
  e Xa

  call assert_equal(1, tabpagenr('$'))
  call assert_equal("\nAlready only one window", execute('wincmd T'))

  split Xb
  split Xc

  wincmd T
  call assert_equal(2, tabpagenr('$'))
  call assert_equal(['Xb', 'Xa'], map(tabpagebuflist(1), 'bufname(v:val)'))
  call assert_equal(['Xc'      ], map(tabpagebuflist(2), 'bufname(v:val)'))

  %bw!
endfunc


" Tests for adjusting window and contents
func GetScreenStr(row)
   let str = ""
   for c in range(1,3)
       let str .= nr2char(screenchar(a:row, c))
   endfor
   return str
endfunc

func Test_window_contents()
  enew! | only | new
  call setline(1, range(1,256))

  exe "norm! \<C-W>t\<C-W>=1Gzt\<C-W>w\<C-W>+"
  redraw
  let s3 = GetScreenStr(1)
  wincmd p
  call assert_equal(1, line("w0"))
  call assert_equal('1  ', s3)

  exe "norm! \<C-W>t\<C-W>=50Gzt\<C-W>w\<C-W>+"
  redraw
  let s3 = GetScreenStr(1)
  wincmd p
  call assert_equal(50, line("w0"))
  call assert_equal('50 ', s3)

  exe "norm! \<C-W>t\<C-W>=59Gzt\<C-W>w\<C-W>+"
  redraw
  let s3 = GetScreenStr(1)
  wincmd p
  call assert_equal(59, line("w0"))
  call assert_equal('59 ', s3)

  bwipeout!
  call test_garbagecollect_now()
endfunc

func Test_access_freed_mem()
  " This was accessing freed memory
  au * 0 vs xxx
  arg 0
  argadd
  all
  all
  au!
  bwipe xxx
endfunc

func Test_visual_cleared_after_window_split()
  new | only!
  let smd_save = &showmode
  set showmode
  let ls_save = &laststatus
  set laststatus=1
  call setline(1, ['a', 'b', 'c', 'd', ''])
  norm! G
  exe "norm! kkvk"
  redraw
  exe "norm! \<C-W>v"
  redraw
  " check if '-- VISUAL --' disappeared from command line
  let columns = range(1, &columns)
  let cmdlinechars = map(columns, 'nr2char(screenchar(&lines, v:val))')
  let cmdline = join(cmdlinechars, '')
  let cmdline_ltrim = substitute(cmdline, '^\s*', "", "")
  let mode_shown = substitute(cmdline_ltrim, '\s*$', "", "")
  call assert_equal('', mode_shown)
  let &showmode = smd_save
  let &laststatus = ls_save
  bwipe!
endfunc

func Test_winrestcmd()
  2split
  3vsplit
  let a = winrestcmd()
  call assert_equal(2, winheight(0))
  call assert_equal(3, winwidth(0))
  wincmd =
  call assert_notequal(2, winheight(0))
  call assert_notequal(3, winwidth(0))
  exe a
  call assert_equal(2, winheight(0))
  call assert_equal(3, winwidth(0))
  only
endfunc

function! Fun_RenewFile()
  " Need to wait a bit for the timestamp to be older.
  sleep 2
  silent execute '!echo "1" > tmp.txt'
  sp
  wincmd p
  edit! tmp.txt
endfunction

func Test_window_prevwin()
  " Can we make this work on MS-Windows?
  if !has('unix')
    return
  endif

  set hidden autoread
  call writefile(['2'], 'tmp.txt')
  new tmp.txt
  q
  call Fun_RenewFile()
  call assert_equal(2, winnr())
  wincmd p
  call assert_equal(1, winnr())
  wincmd p
  q
  call Fun_RenewFile()
  call assert_equal(2, winnr())
  wincmd p
  call assert_equal(1, winnr())
  wincmd p
  " reset
  q
  call delete('tmp.txt')
  set hidden&vim autoread&vim
  delfunc Fun_RenewFile
endfunc

func Test_relative_cursor_position_in_one_line_window()
  new
  only
  call setline(1, range(1, 10000))
  normal 50%
  let lnum = getcurpos()[1]
  split
  split
  " make third window take as many lines as possible, other windows will
  " become one line
  3wincmd w
  for i in range(1, &lines - 6)
    wincmd +
    redraw!
  endfor

  " first and second window should show cursor line
  let wininfo = getwininfo()
  call assert_equal(lnum, wininfo[0].topline)
  call assert_equal(lnum, wininfo[1].topline)

  only!
  bwipe!
endfunc

func Test_relative_cursor_position_after_move_and_resize()
  let so_save = &so
  set so=0
  enew
  call setline(1, range(1, 10000))
  normal 50%
  split
  1wincmd w
  " Move cursor to first line in window
  normal H
  redraw!
  " Reduce window height to two lines
  let height = winheight(0)
  while winheight(0) > 2
    wincmd -
    redraw!
  endwhile
  " move cursor to second/last line in window
  normal j
  " restore previous height
  while winheight(0) < height
    wincmd +
    redraw!
  endwhile
  " make window two lines again
  while winheight(0) > 2
    wincmd -
    redraw!
  endwhile

  " cursor should be at bottom line
  let info = getwininfo(win_getid())[0]
  call assert_equal(info.topline + 1, getcurpos()[1])

  only!
  bwipe!
  let &so = so_save
endfunc

func Test_relative_cursor_position_after_resize()
  let so_save = &so
  set so=0
  enew
  call setline(1, range(1, 10000))
  normal 50%
  split
  1wincmd w
  let winid1 = win_getid()
  let info = getwininfo(winid1)[0]
  " Move cursor to second line in window
  exe "normal " . (info.topline + 1) . "G"
  redraw!
  let lnum = getcurpos()[1]

  " Make the window only two lines high, cursor should end up in top line
  2wincmd w
  exe (info.height - 2) . "wincmd +"
  redraw!
  let info = getwininfo(winid1)[0]
  call assert_equal(lnum, info.topline)

  only!
  bwipe!
  let &so = so_save
endfunc

func Test_relative_cursor_second_line_after_resize()
  let so_save = &so
  set so=0
  enew
  call setline(1, range(1, 10000))
  normal 50%
  split
  1wincmd w
  let winid1 = win_getid()
  let info = getwininfo(winid1)[0]

  " Make the window only two lines high
  2wincmd _

  " Move cursor to second line in window
  normal H
  normal j

  " Make window size bigger, then back to 2 lines
  for i in range(1, 10)
    wincmd +
    redraw!
  endfor
  for i in range(1, 10)
    wincmd -
    redraw!
  endfor

  " cursor should end up in bottom line
  let info = getwininfo(winid1)[0]
  call assert_equal(info.topline + 1, getcurpos()[1])

  only!
  bwipe!
  let &so = so_save
endfunc

" Tests for the winnr() function
func Test_winnr()
  only | tabonly
  call assert_equal(1, winnr('j'))
  call assert_equal(1, winnr('k'))
  call assert_equal(1, winnr('h'))
  call assert_equal(1, winnr('l'))

  " create a set of horizontally and vertically split windows
  leftabove new | wincmd p
  leftabove new | wincmd p
  rightbelow new | wincmd p
  rightbelow new | wincmd p
  leftabove vnew | wincmd p
  leftabove vnew | wincmd p
  rightbelow vnew | wincmd p
  rightbelow vnew | wincmd p

  call assert_equal(8, winnr('j'))
  call assert_equal(2, winnr('k'))
  call assert_equal(4, winnr('h'))
  call assert_equal(6, winnr('l'))
  call assert_equal(9, winnr('2j'))
  call assert_equal(1, winnr('2k'))
  call assert_equal(3, winnr('2h'))
  call assert_equal(7, winnr('2l'))

  " Error cases
  call assert_fails("echo winnr('0.2k')", 'E15:')
  call assert_equal(2, winnr('-2k'))
  call assert_fails("echo winnr('-2xj')", 'E15:')
  call assert_fails("echo winnr('j2j')", 'E15:')
  call assert_fails("echo winnr('ll')", 'E15:')
  call assert_fails("echo winnr('5')", 'E15:')
  call assert_equal(4, winnr('0h'))

  tabnew
  call assert_equal(8, tabpagewinnr(1, 'j'))
  call assert_equal(2, tabpagewinnr(1, 'k'))
  call assert_equal(4, tabpagewinnr(1, 'h'))
  call assert_equal(6, tabpagewinnr(1, 'l'))

  only | tabonly
endfunc

func Test_window_colon_command()
  " This was reading invalid memory.
  exe "norm! v\<C-W>:\<C-U>echo v:version"
endfunc

" vim: shiftwidth=2 sts=2 expandtab
