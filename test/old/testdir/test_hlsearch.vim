" Test for v:hlsearch

source check.vim
source screendump.vim

func Test_hlsearch()
  new
  call setline(1, repeat(['aaa'], 10))
  set hlsearch nolazyredraw
  " redraw is needed to make hlsearch highlight the matches
  exe "normal! /aaa\<CR>" | redraw
  let r1 = screenattr(1, 1)
  nohlsearch | redraw
  call assert_notequal(r1, screenattr(1,1))
  let v:hlsearch=1 | redraw
  call assert_equal(r1, screenattr(1,1))
  let v:hlsearch=0 | redraw
  call assert_notequal(r1, screenattr(1,1))
  set hlsearch | redraw
  call assert_equal(r1, screenattr(1,1))
  let v:hlsearch=0 | redraw
  call assert_notequal(r1, screenattr(1,1))
  exe "normal! n" | redraw
  call assert_equal(r1, screenattr(1,1))
  let v:hlsearch=0 | redraw
  call assert_notequal(r1, screenattr(1,1))
  exe "normal! /\<CR>" | redraw
  call assert_equal(r1, screenattr(1,1))
  set nohls
  exe "normal! /\<CR>" | redraw
  call assert_notequal(r1, screenattr(1,1))
  call assert_fails('let v:hlsearch=[]', 'E745')
  call garbagecollect(1)
  call getchar(1)
  enew!
endfunc

func Test_hlsearch_hangs()
  if !has('reltime') || !has('float')
    return
  endif

  " This pattern takes a long time to match, it should timeout.
  new
  call setline(1, ['aaa', repeat('abc ', 100000), 'ccc'])
  let start = reltime()
  set hlsearch nolazyredraw redrawtime=101
  let @/ = '\%#=1a*.*X\@<=b*'
  redraw
  let elapsed = reltimefloat(reltime(start))
  call assert_true(elapsed > 0.1)
  call assert_true(elapsed < 1.0)
  set nohlsearch redrawtime&
  bwipe!
endfunc

func Test_hlsearch_eol_highlight()
  new
  call append(1, repeat([''], 9))
  set hlsearch nolazyredraw
  exe "normal! /$\<CR>" | redraw
  let attr = screenattr(1, 1)
  for row in range(2, 10)
    call assert_equal(attr, screenattr(row, 1), 'in line ' . row)
  endfor
  set nohlsearch
  bwipe!
endfunc

func Test_hlsearch_Ctrl_R()
  CheckRunVimInTerminal

  let lines =<< trim END
      set incsearch hlsearch
      let @" = "text"
      put
  END
  call writefile(lines, 'XhlsearchCtrlR', 'D')
  let buf = RunVimInTerminal('-S XhlsearchCtrlR', #{rows: 6, cols: 60})

  call term_sendkeys(buf, "/\<C-R>\<C-R>\"")
  call VerifyScreenDump(buf, 'Test_hlsearch_ctrlr_1', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
endfunc

func Test_hlsearch_clipboard()
  CheckRunVimInTerminal
  CheckFeature clipboard_working

  let lines =<< trim END
      set incsearch hlsearch
      let @* = "text"
      put *
  END
  call writefile(lines, 'XhlsearchClipboard', 'D')
  let buf = RunVimInTerminal('-S XhlsearchClipboard', #{rows: 6, cols: 60})

  call term_sendkeys(buf, "/\<C-R>*")
  call VerifyScreenDump(buf, 'Test_hlsearch_ctrlr_1', {})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
