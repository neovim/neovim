" Tests for window cmd (:wincmd, :split, :vsplit, :resize and etc...)

source check.vim
source screendump.vim

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

func Test_window_cmd_ls0_split_scrolling()
  CheckRunVimInTerminal

  let lines =<< trim END
    set laststatus=0
    call setline(1, range(1, 100))
    normal! G
  END
  call writefile(lines, 'XTestLs0SplitScrolling', 'D')
  let buf = RunVimInTerminal('-S XTestLs0SplitScrolling', #{rows: 10})

  call term_sendkeys(buf, ":botright split\<CR>")
  call WaitForAssert({-> assert_match('Bot$', term_getline(buf, 5))})
  call assert_equal('100', term_getline(buf, 4))

  call StopVimInTerminal(buf)
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

func Test_cmdheight_not_changed()
  throw 'Skipped: N/A'
  set cmdheight=2
  set winminheight=0
  augroup Maximize
    autocmd WinEnter * wincmd _
  augroup END
  split
  tabnew
  tabfirst
  call assert_equal(2, &cmdheight)

  tabonly!
  only
  set winminheight& cmdheight&
  augroup Maximize
    au!
  augroup END
  augroup! Maximize
endfunc

" Test for jumping to windows
func Test_window_jump()
  new
  " jumping to a window with a count greater than the max windows
  exe "normal 4\<C-W>w"
  call assert_equal(2, winnr())
  only
endfunc

func Test_window_cmd_wincmd_gf()
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

func Test_window_quit()
  e Xa
  split Xb
  call assert_equal(2, '$'->winnr())
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
  call assert_equal(winwidth(1), 2->winwidth())

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

" Test the ":wincmd ^" and "<C-W>^" commands.
func Test_window_split_edit_alternate()
  " Test for failure when the alternate buffer/file no longer exists.
  edit Xfoo | %bw
  call assert_fails(':wincmd ^', 'E23:')

  " Test for the expected behavior when we have two named buffers.
  edit Xfoo | edit Xbar
  wincmd ^
  call assert_equal('Xfoo', bufname(winbufnr(1)))
  call assert_equal('Xbar', bufname(winbufnr(2)))
  only

  " Test for the expected behavior when the alternate buffer is not named.
  enew | let l:nr1 = bufnr('%')
  edit Xfoo | let l:nr2 = bufnr('%')
  wincmd ^
  call assert_equal(l:nr1, winbufnr(1))
  call assert_equal(l:nr2, winbufnr(2))
  only

  " FIXME: this currently fails on AppVeyor, but passes locally
  if !has('win32')
    " Test the Normal mode command.
    call feedkeys("\<C-W>\<C-^>", 'tx')
    call assert_equal(l:nr2, winbufnr(1))
    call assert_equal(l:nr1, winbufnr(2))
  endif

  %bw!
endfunc

" Test the ":[count]wincmd ^" and "[count]<C-W>^" commands.
func Test_window_split_edit_bufnr()
  %bwipeout
  let l:nr = bufnr('%') + 1
  call assert_fails(':execute "normal! ' . l:nr . '\<C-W>\<C-^>"', 'E92:')
  call assert_fails(':' . l:nr . 'wincmd ^', 'E16:')
  call assert_fails(':0wincmd ^', 'E16:')

  edit Xfoo | edit Xbar | edit Xbaz
  let l:foo_nr = bufnr('Xfoo')
  let l:bar_nr = bufnr('Xbar')
  let l:baz_nr = bufnr('Xbaz')

  " FIXME: this currently fails on AppVeyor, but passes locally
  if !has('win32')
    call feedkeys(l:foo_nr . "\<C-W>\<C-^>", 'tx')
    call assert_equal('Xfoo', bufname(winbufnr(1)))
    call assert_equal('Xbaz', bufname(winbufnr(2)))
    only

    call feedkeys(l:bar_nr . "\<C-W>\<C-^>", 'tx')
    call assert_equal('Xbar', bufname(winbufnr(1)))
    call assert_equal('Xfoo', bufname(winbufnr(2)))
    only

    execute l:baz_nr . 'wincmd ^'
    call assert_equal('Xbaz', bufname(winbufnr(1)))
    call assert_equal('Xbar', bufname(winbufnr(2)))
  endif

  %bw!
endfunc

func s:win_layout_info(tp = tabpagenr()) abort
  return #{
        \ layout: winlayout(a:tp),
        \ pos_sizes: range(1, tabpagewinnr(a:tp, '$'))
        \            ->map({_, nr -> win_getid(nr, a:tp)->getwininfo()[0]})
        \            ->map({_, wininfo -> #{id: wininfo.winid,
        \                                   row: wininfo.winrow,
        \                                   col: wininfo.wincol,
        \                                   width: wininfo.width,
        \                                   height: wininfo.height}})
        \            ->sort({a, b -> a.id - b.id})
        \ }
endfunc

func Test_window_split_no_room()
  " N horizontal windows need >= 2*N + 1 lines:
  " - 1 line + 1 status line in each window
  " - 1 Ex command line
  "
  " 2*N + 1 <= &lines
  " N <= (lines - 1)/2
  "
  " Beyond that number of windows, E36: Not enough room is expected.
  let hor_win_count = (&lines - 1)/2
  let hor_split_count = hor_win_count - 1
  for s in range(1, hor_split_count) | split | endfor
  call assert_fails('split', 'E36:')

  botright vsplit
  wincmd |
  let info = s:win_layout_info()
  call assert_fails('wincmd J', 'E36:')
  call assert_fails('wincmd K', 'E36:')
  call assert_equal(info, s:win_layout_info())
  only

  " N vertical windows need >= 2*(N - 1) + 1 columns:
  " - 1 column + 1 separator for each window (except last window)
  " - 1 column for the last window which does not have separator
  "
  " 2*(N - 1) + 1 <= &columns
  " 2*N - 1 <= &columns
  " N <= (&columns + 1)/2
  let ver_win_count = (&columns + 1)/2
  let ver_split_count = ver_win_count - 1
  for s in range(1, ver_split_count) | vsplit | endfor
  call assert_fails('vsplit', 'E36:')

  split
  wincmd |
  let info = s:win_layout_info()
  call assert_fails('wincmd H', 'E36:')
  call assert_fails('wincmd L', 'E36:')
  call assert_equal(info, s:win_layout_info())

  " Check that the last statusline isn't lost.
  " Set its window's width to 2 for the test.
  wincmd j
  set laststatus=0 winminwidth=0
  vertical resize 2
  " Update expected positions/sizes after the resize.  Layout is unchanged.
  let info.pos_sizes = s:win_layout_info().pos_sizes
  set winminwidth&
  call setwinvar(winnr('k'), '&statusline', '@#')
  let last_stl_row = win_screenpos(0)[0] - 1
  redraw
  call assert_equal('@#|', GetScreenStr(last_stl_row))
  call assert_equal('~ |', GetScreenStr(&lines - &cmdheight))

  call assert_fails('wincmd H', 'E36:')
  call assert_fails('wincmd L', 'E36:')
  call assert_equal(info, s:win_layout_info())
  call setwinvar(winnr('k'), '&statusline', '=-')
  redraw
  call assert_equal('=-|', GetScreenStr(last_stl_row))
  call assert_equal('~ |', GetScreenStr(&lines - &cmdheight))

  %bw!
  set laststatus&
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
  call assert_equal(wh2, 2->winheight())

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

func Test_wincmd_equal()
  edit Xone
  below split Xtwo
  rightbelow vsplit Xthree
  call assert_equal('Xone', bufname(winbufnr(1)))
  call assert_equal('Xtwo', bufname(winbufnr(2)))
  call assert_equal('Xthree', bufname(winbufnr(3)))

  " Xone and Xtwo should be about the same height
  let [wh1, wh2] = [winheight(1), winheight(2)]
  call assert_inrange(wh1 - 1, wh1 + 1, wh2)
  " Xtwo and Xthree should be about the same width
  let [ww2, ww3] = [winwidth(2), winwidth(3)]
  call assert_inrange(ww2 - 1, ww2 + 1, ww3)

  1wincmd w
  10wincmd _
  2wincmd w
  20wincmd |
  call assert_equal(10, winheight(1))
  call assert_equal(20, winwidth(2))

  " equalizing horizontally doesn't change the heights
  hor wincmd =
  call assert_equal(10, winheight(1))
  let [ww2, ww3] = [winwidth(2), winwidth(3)]
  call assert_inrange(ww2 - 1, ww2 + 1, ww3)

  2wincmd w
  20wincmd |
  call assert_equal(20, winwidth(2))
  " equalizing vertically doesn't change the widths
  vert wincmd =
  call assert_equal(20, winwidth(2))
  let [wh1, wh2] = [winheight(1), winheight(2)]
  call assert_inrange(wh1 - 1, wh1 + 1, wh2)

  bwipe Xone Xtwo Xthree
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

  " when the current window width is less than the new 'winwidth', the current
  " window width should be increased.
  enew | only
  split
  10vnew
  set winwidth=15
  call assert_equal(15, winwidth(0))

  %bw!
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
  resize +5
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
  CheckFeature quickfix

  call assert_equal(1, winnr('$'))
  split
  vsplit
  10wincmd _
  30wincmd |
  call assert_equal([1, 1], win_screenpos(1))
  call assert_equal([1, 32], win_screenpos(2))
  call assert_equal([12, 1], win_screenpos(3))
  call assert_equal([0, 0], win_screenpos(4))
  call assert_fails('let l = win_screenpos([])', 'E745:')
  only
endfunc

func Test_window_jump_tag()
  CheckFeature quickfix

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
  call assert_equal(['Xc'      ], map(2->tabpagebuflist(), 'bufname(v:val)'))
  call assert_equal(['Xc'      ], map(tabpagebuflist(), 'bufname(v:val)'))

  %bw!
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

  %d
  call setline(1, ['one', 'two', 'three'])
  call assert_equal(1, line('w0'))
  call assert_equal(3, line('w$'))

  bwipeout!
  call test_garbagecollect_now()
endfunc

func Test_window_colon_command()
  " This was reading invalid memory.
  exe "norm! v\<C-W>:\<C-U>echo v:version"
endfunc

func Test_access_freed_mem()
  call assert_equal(&columns, winwidth(0))
  " This was accessing freed memory (but with what events?)
  au BufEnter,BufLeave,WinEnter,WinLeave 0 vs xxx
  arg 0
  argadd
  call assert_fails("all", "E242:")
  au!
  bwipe xxx
  call assert_equal(&columns, winwidth(0))
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
  let restcmd = winrestcmd()
  call assert_equal(2, winheight(0))
  call assert_equal(3, winwidth(0))
  wincmd =
  call assert_notequal(2, winheight(0))
  call assert_notequal(3, winwidth(0))
  exe restcmd
  call assert_equal(2, winheight(0))
  call assert_equal(3, winwidth(0))
  only

  wincmd v
  wincmd s
  wincmd v
  redraw
  let restcmd = winrestcmd()
  wincmd _
  wincmd |
  exe restcmd
  redraw
  call assert_equal(restcmd, winrestcmd())

  only
endfunc

func Fun_RenewFile()
  " Need to wait a bit for the timestamp to be older.
  let old_ftime = getftime("tmp.txt")
  while getftime("tmp.txt") == old_ftime
    sleep 100m
    silent execute '!echo "1" > tmp.txt'
  endwhile
  sp
  wincmd p
  edit! tmp.txt
endfunc

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
  call assert_fails('call winrestview(v:_null_dict)', 'E1297:')
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

func Test_split_noscroll()
  let so_save = &so
  enew
  call setline(1, range(1, 8))
  normal 100%
  split

  1wincmd w
  let winid1 = win_getid()
  let info1 = getwininfo(winid1)[0]

  2wincmd w
  let winid2 = win_getid()
  let info2 = getwininfo(winid2)[0]

  call assert_equal(1, info1.topline)
  call assert_equal(1, info2.topline)

  " window that fits all lines by itself, but not when split: closing other
  " window should restore fraction.
  only!
  call setline(1, range(1, &lines - 10))
  exe &lines / 4
  let winid1 = win_getid()
  let info1 = getwininfo(winid1)[0]
  call assert_equal(1, info1.topline)
  new
  redraw
  close
  let info1 = getwininfo(winid1)[0]
  call assert_equal(1, info1.topline)

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
  call assert_fails("let w = winnr([])", 'E730:')
  call assert_equal('unknown', win_gettype(-1))
  call assert_equal(-1, winheight(-1))
  call assert_equal(-1, winwidth(-1))

  tabnew
  call assert_equal(8, tabpagewinnr(1, 'j'))
  call assert_equal(2, 1->tabpagewinnr('k'))
  call assert_equal(4, tabpagewinnr(1, 'h'))
  call assert_equal(6, tabpagewinnr(1, 'l'))

  only | tabonly
endfunc

func Test_winrestview()
  split runtest.vim
  normal 50%
  let view = winsaveview()
  close
  split runtest.vim
  eval view->winrestview()
  call assert_equal(view, winsaveview())

  bwipe!
  call assert_fails('call winrestview(v:_null_dict)', 'E1297:')
endfunc

func Test_win_splitmove()
  CheckFeature quickfix

  edit a
  leftabove split b
  leftabove vsplit c
  leftabove split d

  " win_splitmove doesn't actually create or close any windows, so expect an
  " unchanged winid and no WinNew/WinClosed events, like :wincmd H/J/K/L.
  let s:triggered = []
  augroup WinSplitMove
    au!
    " Nvim: WinNewPre not ported yet. Also needs full port of v9.1.0117 to pass.
    " au WinNewPre * let s:triggered += ['WinNewPre']
    au WinNew * let s:triggered += ['WinNew', win_getid()]
    au WinClosed * let s:triggered += ['WinClosed', str2nr(expand('<afile>'))]
  augroup END
  let winid = win_getid()

  call assert_equal(0, win_splitmove(winnr(), winnr('l')))
  call assert_equal(bufname(winbufnr(1)), 'c')
  call assert_equal(bufname(winbufnr(2)), 'd')
  call assert_equal(bufname(winbufnr(3)), 'b')
  call assert_equal(bufname(winbufnr(4)), 'a')
  call assert_equal(0, win_splitmove(winnr(), winnr('j'), {'vertical': 1}))
  call assert_equal(0, win_splitmove(winnr(), winnr('j'), {'vertical': 1}))
  call assert_equal(bufname(winbufnr(1)), 'c')
  call assert_equal(bufname(winbufnr(2)), 'b')
  call assert_equal(bufname(winbufnr(3)), 'd')
  call assert_equal(bufname(winbufnr(4)), 'a')
  call assert_equal(0, win_splitmove(winnr(), winnr('k'), {'vertical': 1}))
  call assert_equal(bufname(winbufnr(1)), 'd')
  call assert_equal(bufname(winbufnr(2)), 'c')
  call assert_equal(bufname(winbufnr(3)), 'b')
  call assert_equal(bufname(winbufnr(4)), 'a')
  call assert_equal(0, win_splitmove(winnr(), winnr('j'), {'rightbelow': v:true}))
  call assert_equal(bufname(winbufnr(1)), 'c')
  call assert_equal(bufname(winbufnr(2)), 'b')
  call assert_equal(bufname(winbufnr(3)), 'a')
  call assert_equal(bufname(winbufnr(4)), 'd')
  call assert_fails('call win_splitmove(winnr(), winnr("k"), v:_null_dict)', 'E1297:')
  call assert_equal([], s:triggered)
  call assert_equal(winid, win_getid())

  unlet! s:triggered
  au! WinSplitMove
  only | bd

  call assert_fails('call win_splitmove(winnr(), 123)', 'E957:')
  call assert_fails('call win_splitmove(123, winnr())', 'E957:')
  call assert_fails('call win_splitmove(winnr(), winnr())', 'E957:')

  tabnew
  call assert_fails('call win_splitmove(1, win_getid(1, 1))', 'E957:')
  tabclose

  split
  augroup WinSplitMove
    au!
    au WinEnter * ++once call win_gotoid(win_getid(winnr('#')))
  augroup END
  call assert_fails('call win_splitmove(winnr(), winnr("#"))', 'E855:')

  augroup WinSplitMove
    au!
    au WinLeave * ++once quit
  augroup END
  call assert_fails('call win_splitmove(winnr(), winnr("#"))', 'E855:')

  split
  split
  augroup WinSplitMove
    au!
    au WinEnter * ++once let s:triggered = v:true
          \| call assert_fails('call win_splitmove(winnr(), winnr("$"))', 'E242:')
          \| call assert_fails('call win_splitmove(winnr("$"), winnr())', 'E242:')
  augroup END
  quit
  call assert_equal(v:true, s:triggered)
  unlet! s:triggered

  new
  augroup WinSplitMove
    au!
    au BufHidden * ++once let s:triggered = v:true
          \| call assert_fails('call win_splitmove(winnr(), winnr("#"))', 'E1159:')
  augroup END
  hide
  call assert_equal(v:true, s:triggered)
  unlet! s:triggered

  split
  let close_win = winnr('#')
  augroup WinSplitMove
    au!
    au WinEnter * ++once quit!
  augroup END
  call win_splitmove(close_win, winnr())
  call assert_equal(0, win_id2win(close_win))

  au! WinSplitMove
  augroup! WinSplitMove
  %bw!
endfunc

" Test for the :only command
func Test_window_only()
  new
  set modified
  new
  call assert_fails('only', 'E445:')
  only!
  " Test for :only with a count
  let wid = win_getid()
  new
  new
  3only
  call assert_equal(1, winnr('$'))
  call assert_equal(wid, win_getid())
  call assert_fails('close', 'E444:')
  call assert_fails('%close', 'E16:')
endfunc

" Test for errors with :wincmd
func Test_wincmd_errors()
  call assert_fails('wincmd g', 'E474:')
  call assert_fails('wincmd ab', 'E474:')
endfunc

" Test for errors with :winpos
func Test_winpos_errors()
  throw 'Skipped: Nvim does not have :winpos'
  if !has("gui_running") && !has('win32')
    call assert_fails('winpos', 'E188:')
  endif
  call assert_fails('winpos 10', 'E466:')
endfunc

" Test for +cmd in a :split command
func Test_split_cmd()
  split +set\ readonly
  call assert_equal(1, &readonly)
  call assert_equal(2, winnr('$'))
  close
endfunc

" Create maximum number of horizontally or vertically split windows and then
" run commands that create a new horizontally/vertically split window
func Run_noroom_for_newwindow_test(dir_arg)
  let dir = (a:dir_arg == 'v') ? 'vert ' : ''

  " Open as many windows as possible
  while v:true
    try
      exe dir . 'new'
    catch /E36:/
      break
    endtry
  endwhile

  call writefile(['first', 'second', 'third'], 'Xnorfile1')
  call writefile([], 'Xnorfile2')
  call writefile([], 'Xnorfile3')

  " Argument list related commands
  args Xnorfile1 Xnorfile2 Xnorfile3
  next
  for cmd in ['sargument 2', 'snext', 'sprevious', 'sNext', 'srewind',
			\ 'sfirst', 'slast']
    call assert_fails(dir .. cmd, 'E36:')
  endfor
  %argdelete

  " Buffer related commands
  set modified
  hide enew
  for cmd in ['sbuffer Xnorfile1', 'sbnext', 'sbprevious', 'sbNext', 'sbrewind',
		\ 'sbfirst', 'sblast', 'sball', 'sbmodified', 'sunhide']
    call assert_fails(dir .. cmd, 'E36:')
  endfor

  " Window related commands
  for cmd in ['split', 'split Xnorfile2', 'new', 'new Xnorfile3', 'sview Xnorfile1',
		\ 'sfind runtest.vim']
    call assert_fails(dir .. cmd, 'E36:')
  endfor

  " Help
  call assert_fails(dir .. 'help', 'E36:')
  call assert_fails(dir .. 'helpgrep window', 'E36:')

  " Command-line window
  if a:dir_arg == 'h'
    " Cmd-line window is always a horizontally split window
    call assert_beeps('call feedkeys("q:\<CR>", "xt")')
  endif

  " Quickfix and location list window
  if has('quickfix')
    cexpr ''
    call assert_fails(dir .. 'copen', 'E36:')
    lexpr ''
    call assert_fails(dir .. 'lopen', 'E36:')

    " Preview window
    call assert_fails(dir .. 'pedit Xnorfile2', 'E36:')
    call assert_fails(dir .. 'pbuffer', 'E36:')
    call setline(1, 'abc')
    call assert_fails(dir .. 'psearch abc', 'E36:')
  endif

  " Window commands (CTRL-W ^ and CTRL-W f)
  if a:dir_arg == 'h'
    call assert_fails('call feedkeys("\<C-W>^", "xt")', 'E36:')
    call setline(1, 'Xnorfile1')
    call assert_fails('call feedkeys("gg\<C-W>f", "xt")', 'E36:')
  endif
  enew!

  " Tag commands (:stag, :stselect and :stjump)
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "second\tXnorfile1\t2",
        \ "third\tXnorfile1\t3",],
        \ 'Xtags')
  set tags=Xtags
  call assert_fails(dir .. 'stag second', 'E36:')
  call assert_fails('call feedkeys(":" .. dir .. "stselect second\n1\n", "xt")', 'E36:')
  call assert_fails(dir .. 'stjump second', 'E36:')
  call assert_fails(dir .. 'ptag second', 'E36:')
  set tags&
  call delete('Xtags')

  " :isplit and :dsplit
  call setline(1, ['#define FOO 1', 'FOO'])
  normal 2G
  call assert_fails(dir .. 'isplit FOO', 'E36:')
  call assert_fails(dir .. 'dsplit FOO', 'E36:')

  " terminal
  if has('terminal')
    call assert_fails(dir .. 'terminal', 'E36:')
  endif

  %bwipe!
  call delete('Xnorfile1')
  call delete('Xnorfile2')
  call delete('Xnorfile3')
  only
endfunc

func Test_split_cmds_with_no_room()
  call Run_noroom_for_newwindow_test('h')
  call Run_noroom_for_newwindow_test('v')
endfunc

" Test for various wincmd failures
func Test_wincmd_fails()
  only!
  call assert_beeps("normal \<C-W>w")
  call assert_beeps("normal \<C-W>p")
  call assert_beeps("normal \<C-W>gk")
  call assert_beeps("normal \<C-W>r")
  call assert_beeps("normal \<C-W>K")
  call assert_beeps("normal \<C-W>H")
  call assert_beeps("normal \<C-W>2gt")
endfunc

func Test_window_resize()
  " Vertical :resize (absolute, relative, min and max size).
  vsplit
  vert resize 8
  call assert_equal(8, winwidth(0))
  vert resize +2
  call assert_equal(10, winwidth(0))
  vert resize -2
  call assert_equal(8, winwidth(0))
  vert resize
  call assert_equal(&columns - 2, winwidth(0))
  vert resize 0
  call assert_equal(1, winwidth(0))
  vert resize 99999
  call assert_equal(&columns - 2, winwidth(0))

  %bwipe!

  " Horizontal :resize (with absolute, relative size, min and max size).
  split
  resize 8
  call assert_equal(8, winheight(0))
  resize +2
  call assert_equal(10, winheight(0))
  resize -2
  call assert_equal(8, winheight(0))
  resize
  call assert_equal(&lines - 4, winheight(0))
  resize 0
  call assert_equal(1, winheight(0))
  resize 99999
  call assert_equal(&lines - 4, winheight(0))

  " :resize with explicit window number.
  let other_winnr = winnr('j')
  exe other_winnr .. 'resize 10'
  call assert_equal(10, winheight(other_winnr))
  call assert_equal(&lines - 10 - 3, winheight(0))
  exe other_winnr .. 'resize +1'
  exe other_winnr .. 'resize +1'
  call assert_equal(12, winheight(other_winnr))
  call assert_equal(&lines - 10 - 3 -2, winheight(0))
  close

  vsplit
  wincmd l
  let other_winnr = winnr('h')
  call assert_notequal(winnr(), other_winnr)
  exe 'vert ' .. other_winnr .. 'resize -' .. &columns
  call assert_equal(0, winwidth(other_winnr))

  %bwipe!
endfunc

" Test for adjusting the window width when a window is closed with some
" windows using 'winfixwidth'
func Test_window_width_adjust()
  only
  " Three vertical windows. Windows 1 and 2 have 'winfixwidth' set and close
  " window 2.
  wincmd v
  vert resize 10
  set winfixwidth
  wincmd v
  set winfixwidth
  wincmd c
  call assert_inrange(10, 12, winwidth(1))
  " Three vertical windows. Windows 2 and 3 have 'winfixwidth' set and close
  " window 3.
  only
  set winfixwidth
  wincmd v
  vert resize 10
  set winfixwidth
  wincmd v
  set nowinfixwidth
  wincmd b
  wincmd c
  call assert_inrange(10, 12, winwidth(2))

  new | only
endfunc

" Test for jumping to a vertical/horizontal neighbor window based on the
" current cursor position
func Test_window_goto_neighbor()
  %bw!

  " Vertical window movement

  " create the following window layout:
  "     +--+--+
  "     |w1|w3|
  "     +--+  |
  "     |w2|  |
  "     +--+--+
  "     |w4   |
  "     +-----+
  new
  vsplit
  split
  " vertically jump from w4
  wincmd b
  call setline(1, repeat(' ', &columns))
  call cursor(1, 1)
  wincmd k
  call assert_equal(2, winnr())
  wincmd b
  call cursor(1, &columns)
  redraw!
  wincmd k
  call assert_equal(3, winnr())
  %bw!

  " create the following window layout:
  "     +--+--+--+
  "     |w1|w2|w3|
  "     +--+--+--+
  "     |w4      |
  "     +--------+
  new
  vsplit
  vsplit
  wincmd b
  call setline(1, repeat(' ', &columns))
  call cursor(1, 1)
  wincmd k
  call assert_equal(1, winnr())
  wincmd b
  call cursor(1, &columns / 2)
  redraw!
  wincmd k
  call assert_equal(2, winnr())
  wincmd b
  call cursor(1, &columns)
  redraw!
  wincmd k
  call assert_equal(3, winnr())
  %bw!

  " Horizontal window movement

  " create the following window layout:
  "     +--+--+--+
  "     |w1|w2|w4|
  "     +--+--+  |
  "     |w3   |  |
  "     +-----+--+
  vsplit
  split
  vsplit
  4wincmd l
  call setline(1, repeat([' '], &lines))
  call cursor(1, 1)
  redraw!
  wincmd h
  call assert_equal(2, winnr())
  4wincmd l
  call cursor(&lines, 1)
  redraw!
  wincmd h
  call assert_equal(3, winnr())
  %bw!

  " create the following window layout:
  "     +--+--+
  "     |w1|w4|
  "     +--+  +
  "     |w2|  |
  "     +--+  +
  "     |w3|  |
  "     +--+--+
  vsplit
  split
  split
  wincmd l
  call setline(1, repeat([' '], &lines))
  call cursor(1, 1)
  redraw!
  wincmd h
  call assert_equal(1, winnr())
  wincmd l
  call cursor(&lines / 2, 1)
  redraw!
  wincmd h
  call assert_equal(2, winnr())
  wincmd l
  call cursor(&lines, 1)
  redraw!
  wincmd h
  call assert_equal(3, winnr())
  %bw!
endfunc

" Test for an autocmd closing the destination window when jumping from one
" window to another.
func Test_close_dest_window()
  split
  edit Xfile

  " Test for BufLeave
  augroup T1
    au!
    au BufLeave Xfile $wincmd c
  augroup END
  wincmd b
  call assert_equal(1, winnr('$'))
  call assert_equal('Xfile', @%)
  augroup T1
    au!
  augroup END

  " Test for WinLeave
  new
  wincmd p
  augroup T1
    au!
    au WinLeave * 1wincmd c
  augroup END
  wincmd t
  call assert_equal(1, winnr('$'))
  call assert_equal('Xfile', @%)
  augroup T1
    au!
  augroup END
  augroup! T1
  %bw!
endfunc

func Test_win_move_separator()
  edit a
  leftabove vsplit b
  let w = winwidth(0)
  " check win_move_separator from left window on left window
  call assert_equal(1, winnr())
  for offset in range(5)
    call assert_true(win_move_separator(0, offset))
    call assert_equal(w + offset, winwidth(0))
    call assert_true(0->win_move_separator(-offset))
    call assert_equal(w, winwidth(0))
  endfor
  " check win_move_separator from right window on left window number
  wincmd l
  call assert_notequal(1, winnr())
  for offset in range(5)
    call assert_true(1->win_move_separator(offset))
    call assert_equal(w + offset, winwidth(1))
    call assert_true(win_move_separator(1, -offset))
    call assert_equal(w, winwidth(1))
  endfor
  " check win_move_separator from right window on left window ID
  let id = win_getid(1)
  for offset in range(5)
    call assert_true(win_move_separator(id, offset))
    call assert_equal(w + offset, winwidth(id))
    call assert_true(id->win_move_separator(-offset))
    call assert_equal(w, winwidth(id))
  endfor
  " check win_move_separator from right window on right window is no-op
  let w0 = winwidth(0)
  call assert_true(win_move_separator(0, 1))
  call assert_equal(w0, winwidth(0))
  call assert_true(win_move_separator(0, -1))
  call assert_equal(w0, winwidth(0))

  " check that win_move_separator doesn't error with offsets beyond moving
  " possibility
  call assert_true(win_move_separator(id, 5000))
  call assert_true(winwidth(id) > w)
  call assert_true(win_move_separator(id, -5000))
  call assert_true(winwidth(id) < w)

  " check that win_move_separator returns false for an invalid window
  wincmd =
  let w = winwidth(0)
  call assert_false(win_move_separator(-1, 1))
  call assert_equal(w, winwidth(0))

  " check that win_move_separator returns false for a floating window
  let id = nvim_open_win(
        \ 0, 0, #{relative: 'editor', row: 2, col: 2, width: 5, height: 3})
  let w = winwidth(id)
  call assert_false(win_move_separator(id, 1))
  call assert_equal(w, winwidth(id))
  call nvim_win_close(id, 1)

  " check that using another tabpage fails without crash
  let id = win_getid()
  tabnew
  call assert_fails('call win_move_separator(id, -1)', 'E1308:')
  tabclose

  %bwipe!
endfunc

func Test_win_move_statusline()
  edit a
  leftabove split b
  let h = winheight(0)
  " check win_move_statusline from top window on top window
  call assert_equal(1, winnr())
  for offset in range(5)
    call assert_true(win_move_statusline(0, offset))
    call assert_equal(h + offset, winheight(0))
    call assert_true(0->win_move_statusline(-offset))
    call assert_equal(h, winheight(0))
  endfor
  " check win_move_statusline from bottom window on top window number
  wincmd j
  call assert_notequal(1, winnr())
  for offset in range(5)
    call assert_true(1->win_move_statusline(offset))
    call assert_equal(h + offset, winheight(1))
    call assert_true(win_move_statusline(1, -offset))
    call assert_equal(h, winheight(1))
  endfor
  " check win_move_statusline from bottom window on bottom window
  let h0 = winheight(0)
  for offset in range(5)
    call assert_true(0->win_move_statusline(-offset))
    call assert_equal(h0 - offset, winheight(0))
    call assert_equal(1 + offset, &cmdheight)
    call assert_true(win_move_statusline(0, offset))
    call assert_equal(h0, winheight(0))
    call assert_equal(1, &cmdheight)
  endfor
  " supports cmdheight=0
  set cmdheight=0
  call assert_true(win_move_statusline(0, 1))
  call assert_equal(h0 + 1, winheight(0))
  call assert_equal(0, &cmdheight)
  set cmdheight&
  " check win_move_statusline from bottom window on top window ID
  let id = win_getid(1)
  for offset in range(5)
    call assert_true(win_move_statusline(id, offset))
    call assert_equal(h + offset, winheight(id))
    call assert_true(id->win_move_statusline(-offset))
    call assert_equal(h, winheight(id))
  endfor

  " check that win_move_statusline doesn't error with offsets beyond moving
  " possibility
  call assert_true(win_move_statusline(id, 5000))
  call assert_true(winheight(id) > h)
  call assert_true(win_move_statusline(id, -5000))
  call assert_true(winheight(id) < h)

  " check that win_move_statusline returns false for an invalid window
  wincmd =
  let h = winheight(0)
  call assert_false(win_move_statusline(-1, 1))
  call assert_equal(h, winheight(0))

  " check that win_move_statusline returns false for a floating window
  let id = nvim_open_win(
        \ 0, 0, #{relative: 'editor', row: 2, col: 2, width: 5, height: 3})
  let h = winheight(id)
  call assert_false(win_move_statusline(id, 1))
  call assert_equal(h, winheight(id))
  call nvim_win_close(id, 1)

  " check that using another tabpage fails without crash
  let id = win_getid()
  tabnew
  call assert_fails('call win_move_statusline(id, -1)', 'E1308:')
  tabclose

  %bwipe!
endfunc

" Test for window allocation failure
func Test_window_alloc_failure()
  CheckFunction test_alloc_fail
  %bw!

  " test for creating a new window above current window
  call test_alloc_fail(GetAllocId('newwin_wvars'), 0, 0)
  call assert_fails('above new', 'E342:')
  call assert_equal(1, winnr('$'))

  " test for creating a new window below current window
  call test_alloc_fail(GetAllocId('newwin_wvars'), 0, 0)
  call assert_fails('below new', 'E342:')
  call assert_equal(1, winnr('$'))

  " test for popup window creation failure
  call test_alloc_fail(GetAllocId('newwin_wvars'), 0, 0)
  call assert_fails('call popup_create("Hello", {})', 'E342:')
  call assert_equal([], popup_list())

  call test_alloc_fail(GetAllocId('newwin_wvars'), 0, 0)
  call assert_fails('split', 'E342:')
  call assert_equal(1, winnr('$'))

  edit Xfile1
  edit Xfile2
  call test_alloc_fail(GetAllocId('newwin_wvars'), 0, 0)
  call assert_fails('sb Xfile1', 'E342:')
  call assert_equal(1, winnr('$'))
  call assert_equal('Xfile2', @%)
  %bw!

  " FIXME: The following test crashes Vim
  " test for new tabpage creation failure
  " call test_alloc_fail(GetAllocId('newwin_wvars'), 0, 0)
  " call assert_fails('tabnew', 'E342:')
  " call assert_equal(1, tabpagenr('$'))
  " call assert_equal(1, winnr('$'))

  " This test messes up the internal Vim window/frame information. So the
  " Test_window_cmd_cmdwin_with_vsp() test fails after running this test.
  " Open a new tab and close everything else to fix this issue.
  tabnew
  tabonly
endfunc

func Test_win_equal_last_status()
  let save_lines = &lines
  set lines=20
  set splitbelow
  set laststatus=0

  split | split | quit
  call assert_equal(winheight(1), winheight(2))

  let &lines = save_lines
  set splitbelow&
  set laststatus&
endfunc

" Test "screen" and "cursor" values for 'splitkeep' with a sequence of
" split operations for various options: with and without a winbar,
" tabline, for each possible value of 'laststatus', 'scrolloff',
" 'equalalways', and with the cursor at the top, middle and bottom.
func Test_splitkeep_options()
  " disallow window resizing
  " let save_WS = &t_WS
  " set t_WS=

  let gui = has("gui_running")
  inoremap <expr> c "<cmd>copen<bar>wincmd k<CR>"
  for run in range(0, 20)
    let &splitkeep = run > 10 ? 'topline' : 'screen'
    let &scrolloff = (!(run % 4) ? 0 : run)
    let &laststatus = (run % 3)
    let &splitbelow = (run % 3)
    let &equalalways = (run % 2)
    " Nvim: both windows have a winbar after splitting
    " let wsb = (run % 2) && &splitbelow
    let wsb = 0
    let tl = (gui ? 0 : ((run % 5) ? 1 : 0))
    let pos = !(run % 3) ? 'H' : ((run % 2) ? 'M' : 'L')
    tabnew | tabonly! | redraw
    execute (run % 5) ? 'tabnew' : ''
    " execute (run % 2) ? 'nnoremenu 1.10 WinBar.Test :echo' : ''
    let &winbar = (run % 2) ? '%f' : ''
    call setline(1, range(1, 256))
    " No scroll for restore_snapshot
    norm G
    try
      copen | close | colder
    catch /E380/
    endtry
    call assert_equal(257 - winheight(0), line("w0"))

    " No scroll for firstwin horizontal split
    execute 'norm gg' . pos
    split | redraw | wincmd k
    call assert_equal(1, line("w0"))
    call assert_equal(&scroll, winheight(0) / 2)
    wincmd j
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))

    " No scroll when resizing windows
    wincmd k | resize +2 | redraw
    call assert_equal(1, line("w0"))
    wincmd j
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))

    " No scroll when dragging statusline
    call win_move_statusline(1, -3)
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))
    wincmd k
    call assert_equal(1, line("w0"))

    " No scroll when changing shellsize
    set lines+=2
    call assert_equal(1, line("w0"))
    wincmd j
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))
    set lines-=2
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))
    wincmd k
    call assert_equal(1, line("w0"))

    " No scroll when equalizing windows
    wincmd =
    call assert_equal(1, line("w0"))
    wincmd j
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))
    wincmd k
    call assert_equal(1, line("w0"))

    " No scroll in windows split multiple times
    vsplit | split | 4wincmd w
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))
    1wincmd w | quit | wincmd l | split
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))
    wincmd j
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))

    " No scroll in small window
    2wincmd w | only | 5split | wincmd k
    call assert_equal(1, line("w0"))
    wincmd j
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))

    " No scroll for vertical split
    quit | vsplit | wincmd l
    call assert_equal(1, line("w0"))
    wincmd h
    call assert_equal(1, line("w0"))

    " No scroll in windows split and quit multiple times
    quit | redraw | split | split | quit | redraw
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl - wsb, line("w0"))

    " No scroll for new buffer
    1wincmd w | only | copen | wincmd k
    call assert_equal(1, line("w0"))
    only
    call assert_equal(1, line("w0"))
    above copen | wincmd j
    call assert_equal(&spk == 'topline' ? 1 : win_screenpos(0)[0] - tl, line("w0"))

    " No scroll when opening cmdwin, and no cursor move when closing cmdwin.
    only | norm ggL
    let curpos = getcurpos()
    norm q:
    call assert_equal(1, line("w0"))
    call assert_equal(curpos, getcurpos())

    " Scroll when cursor becomes invalid in insert mode.
    norm Lic
    call assert_equal(curpos, getcurpos(), 'run ' .. run)

    " No scroll when topline not equal to 1
    only | execute "norm gg5\<C-e>" | split | wincmd k
    call assert_equal(6, line("w0"))
    wincmd j
    call assert_equal(&spk == 'topline' ? 6 : 5 + win_screenpos(0)[0] - tl - wsb, line("w0"))
  endfor

  tabnew | tabonly! | %bwipeout!
  iunmap c
  set scrolloff&
  set splitbelow&
  set laststatus&
  set equalalways&
  set splitkeep&
  " let &t_WS = save_WS
endfunc

func Test_splitkeep_cmdwin_cursor_position()
  set splitkeep=screen
  call setline(1, range(&lines))

  " No scroll when cursor is at near bottom of window and cusor position
  " recompution (done by line('w0') in this test) happens while in cmdwin.
  normal! G
  let firstline = line('w0')
  autocmd CmdwinEnter * ++once autocmd WinEnter * ++once call line('w0')
  execute "normal! q:\<C-w>q"
  redraw!
  call assert_equal(firstline, line('w0'))

  " User script can change cursor position successfully while in cmdwin and it
  " shouldn't be changed when closing cmdwin.
  execute "normal! Gq:\<Cmd>call win_execute(winnr('#')->win_getid(), 'call cursor(1, 1)')\<CR>\<C-w>q"
  call assert_equal(1, line('.'))
  call assert_equal(1, col('.'))

  execute "normal! Gq:\<Cmd>autocmd WinEnter * ++once call cursor(1, 1)\<CR>\<C-w>q"
  call assert_equal(1, line('.'))
  call assert_equal(1, col('.'))

  %bwipeout!
  set splitkeep&
endfunc

func Test_splitkeep_misc()
  set splitkeep=screen

  call setline(1, range(1, &lines))
  " Cursor is adjusted to start and end of buffer
  norm M
  wincmd s
  resize 1
  call assert_equal(1, line('.'))
  wincmd j
  norm GM
  resize 1
  call assert_equal(&lines, line('.'))
  only!

  set splitbelow
  norm Gzz
  let top = line('w0')
  " No scroll when aucmd_win is opened
  call setbufvar(bufnr("test", 1) , '&buftype', 'nofile')
  call assert_equal(top, line('w0'))
  " No scroll when tab is changed/closed
  tab help | close
  call assert_equal(top, line('w0'))
  " No scroll when help is closed and buffer line count < window height
  norm ggdG
  call setline(1, range(1, &lines - 10))
  norm G
  let top = line('w0')
  help | quit
  call assert_equal(top, line('w0'))
  " No error when resizing window in autocmd and buffer length changed
  autocmd FileType qf exe "resize" line('$')
  cexpr getline(1, '$')
  copen
  wincmd p
  norm dd
  cexpr getline(1, '$')

  %bwipeout!
  set splitbelow&
  set splitkeep&
endfunc

func Test_splitkeep_cursor()
  CheckScreendump
  let lines =<< trim END
    set splitkeep=screen
    autocmd CursorMoved * wincmd p | wincmd p
    call setline(1, range(1, 200))
    func CursorEqualize()
      call cursor(100, 1)
      wincmd =
    endfunc
    wincmd s
    call CursorEqualize()
  END
  call writefile(lines, 'XTestSplitkeepCallback', 'D')
  let buf = RunVimInTerminal('-S XTestSplitkeepCallback', #{rows: 8})

  call VerifyScreenDump(buf, 'Test_splitkeep_cursor_1', {})

  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_splitkeep_cursor_2', {})

  call term_sendkeys(buf, ":set scrolloff=0\<CR>G")
  call VerifyScreenDump(buf, 'Test_splitkeep_cursor_3', {})

  call StopVimInTerminal(buf)
endfunc

func Test_splitkeep_callback()
  CheckScreendump
  let lines =<< trim END
    set splitkeep=screen
    call setline(1, range(&lines))
    function C1(a, b)
      split | wincmd p
    endfunction
    function C2(a, b)
      close | split
    endfunction
    nn j <cmd>call job_start([&sh, &shcf, "true"], { 'exit_cb': 'C1' })<CR>
    nn t <cmd>call popup_create(term_start([&sh, &shcf, "true"],
          \ { 'hidden': 1, 'exit_cb': 'C2' }), {})<CR>
  END
  call writefile(lines, 'XTestSplitkeepCallback', 'D')
  let buf = RunVimInTerminal('-S XTestSplitkeepCallback', #{rows: 8})

  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_splitkeep_callback_1', {})

  call term_sendkeys(buf, ":quit\<CR>Ht")
  call VerifyScreenDump(buf, 'Test_splitkeep_callback_2', {})

  call term_sendkeys(buf, ":set sb\<CR>:quit\<CR>Gj")
  call VerifyScreenDump(buf, 'Test_splitkeep_callback_3', {})

  call term_sendkeys(buf, ":quit\<CR>Gt")
  call VerifyScreenDump(buf, 'Test_splitkeep_callback_4', {})

  call StopVimInTerminal(buf)
endfunc

func Test_splitkeep_fold()
  CheckScreendump

  let lines =<< trim END
    set splitkeep=screen
    set foldmethod=marker
    set number
    let line = 1
    for n in range(1, &lines)
      call setline(line, ['int FuncName() {/*{{{*/', 1, 2, 3, 4, 5, '}/*}}}*/',
            \ 'after fold'])
      let line += 8
    endfor
  END
  call writefile(lines, 'XTestSplitkeepFold', 'D')
  let buf = RunVimInTerminal('-S XTestSplitkeepFold', #{rows: 10})

  call term_sendkeys(buf, "L:wincmd s\<CR>")
  call VerifyScreenDump(buf, 'Test_splitkeep_fold_1', {})

  call term_sendkeys(buf, ":quit\<CR>")
  call VerifyScreenDump(buf, 'Test_splitkeep_fold_2', {})

  call term_sendkeys(buf, "H:below split\<CR>")
  call VerifyScreenDump(buf, 'Test_splitkeep_fold_3', {})

  call term_sendkeys(buf, ":wincmd k\<CR>:quit\<CR>")
  call VerifyScreenDump(buf, 'Test_splitkeep_fold_4', {})

  call StopVimInTerminal(buf)
endfunc

func Test_splitkeep_status()
  CheckScreendump

  let lines =<< trim END
    call setline(1, ['a', 'b', 'c'])
    set nomodified
    set splitkeep=screen
    let win = winnr()
    wincmd s
    wincmd j
  END
  call writefile(lines, 'XTestSplitkeepStatus', 'D')
  let buf = RunVimInTerminal('-S XTestSplitkeepStatus', #{rows: 10})

  call term_sendkeys(buf, ":call win_move_statusline(win, 1)\<CR>")
  call VerifyScreenDump(buf, 'Test_splitkeep_status_1', {})

  call StopVimInTerminal(buf)
endfunc

" skipcol is not reset unnecessarily and is copied to new window
func Test_splitkeep_skipcol()
  CheckScreendump

  let lines =<< trim END
    set splitkeep=topline smoothscroll splitbelow scrolloff=0
    call setline(1, 'with lots of text in one line '->repeat(6))
    norm 2
    wincmd s
  END

  call writefile(lines, 'XTestSplitkeepSkipcol', 'D')
  let buf = RunVimInTerminal('-S XTestSplitkeepSkipcol', #{rows: 12, cols: 40})

  call VerifyScreenDump(buf, 'Test_splitkeep_skipcol_1', {})
endfunc

func Test_new_help_window_on_error()
  help change.txt
  execute "normal! /CTRL-@\<CR>"
  silent! execute "normal! \<C-W>]"

  let wincount = winnr('$')
  help 'mod'

  call assert_equal(wincount, winnr('$'))
  call assert_equal(expand("<cword>"), "'mod'")
endfunc

func Test_splitmove_flatten_frame()
  split
  vsplit

  wincmd L
  let layout = winlayout()
  wincmd K
  wincmd L
  call assert_equal(winlayout(), layout)

  only!
endfunc

func Test_autocmd_window_force_room()
  " Open as many windows as possible
  while v:true
    try
      split
    catch /E36:/
      break
    endtry
  endwhile
  while v:true
    try
      vsplit
    catch /E36:/
      break
    endtry
  endwhile

  wincmd j
  vsplit
  call assert_fails('wincmd H', 'E36:')
  call assert_fails('wincmd J', 'E36:')
  call assert_fails('wincmd K', 'E36:')
  call assert_fails('wincmd L', 'E36:')

  edit unload me
  enew
  bunload! unload\ me
  augroup AucmdWinForceRoom
    au!
    au BufEnter * ++once let s:triggered = v:true
                      \| call assert_equal('autocmd', win_gettype())
  augroup END
  let info = s:win_layout_info()
  " bufload opening the autocommand window shouldn't give E36.
  call bufload('unload me')
  call assert_equal(v:true, s:triggered)
  call assert_equal(info, s:win_layout_info())

  unlet! s:triggered
  au! AucmdWinForceRoom
  augroup! AucmdWinForceRoom
  %bw!
endfunc

func Test_win_gotoid_splitmove_textlock_cmdwin()
  call setline(1, 'foo')
  new
  let curwin = win_getid()
  call setline(1, 'bar')

  set debug+=throw indentexpr=win_gotoid(win_getid(winnr('#')))
  call assert_fails('normal! ==', 'E565:')
  call assert_equal(curwin, win_getid())
  " No error if attempting to switch to curwin; nothing happens.
  set indentexpr=assert_equal(1,win_gotoid(win_getid()))
  normal! ==
  call assert_equal(curwin, win_getid())

  set indentexpr=win_splitmove(winnr('#'),winnr())
  call assert_fails('normal! ==', 'E565:')
  call assert_equal(curwin, win_getid())

  %bw!
  set debug-=throw indentexpr&

  call feedkeys('q:'
           \ .. ":call assert_fails('call win_splitmove(winnr(''#''), winnr())', 'E11:')\<CR>"
           \ .. ":call assert_equal('command', win_gettype())\<CR>"
           \ .. ":call assert_equal('', win_gettype(winnr('#')))\<CR>", 'ntx')

  call feedkeys('q:'
           \ .. ":call assert_fails('call win_gotoid(win_getid(winnr(''#'')))', 'E11:')\<CR>"
           "\ No error if attempting to switch to curwin; nothing happens.
           \ .. ":call assert_equal(1, win_gotoid(win_getid()))\<CR>"
           \ .. ":call assert_equal('command', win_gettype())\<CR>"
           \ .. ":call assert_equal('', win_gettype(winnr('#')))\<CR>", 'ntx')
endfunc

func Test_winfixsize_positions()
  " Check positions are correct when closing a window in a non-current tabpage
  " causes non-adjacent window to fill the space due to 'winfix{width,height}'.
  tabnew
  vsplit
  wincmd |
  split
  set winfixheight
  split foo
  tabfirst

  bwipe! foo
  " Save actual values before entering the tabpage.
  let info = s:win_layout_info(2)
  tabnext
  " Compare it with the expected value (after win_comp_pos) from entering.
  call assert_equal(s:win_layout_info(), info)

  $tabnew
  split
  split
  wincmd k
  belowright vsplit
  set winfixwidth
  belowright vsplit foo
  tabprevious

  bwipe! foo
  " Save actual values before entering the tabpage.
  let info = s:win_layout_info(3)
  tabnext
  " Compare it with the expected value (after win_comp_pos) from entering.
  call assert_equal(s:win_layout_info(), info)

  " Check positions unchanged when failing to move a window, if 'winfix{width,
  " height}' would otherwise cause a non-adjacent window to fill the space.
  %bwipe
  call assert_fails('execute "split|"->repeat(&lines)', 'E36:')
  wincmd p
  vsplit
  set winfixwidth
  vsplit
  set winfixwidth
  vsplit
  vsplit
  set winfixwidth
  wincmd p

  let info = s:win_layout_info()
  call assert_fails('wincmd J', 'E36:')
  call assert_equal(info, s:win_layout_info())

  only
  call assert_fails('execute "vsplit|"->repeat(&columns)', 'E36:')
  belowright split
  set winfixheight
  belowright split

  let info = s:win_layout_info()
  call assert_fails('wincmd H', 'E36:')
  call assert_equal(info, s:win_layout_info())

  %bwipe
endfunc

" vim: shiftwidth=2 sts=2 expandtab
