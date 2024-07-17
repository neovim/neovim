" Test for commands that close windows and/or buffers:
" :quit
" :close
" :hide
" :only
" :sall
" :all
" :ball
" :buf
" :edit
"
func Test_winbuf_close()
  enew | only

  call writefile(['testtext 1'], 'Xtest1')
  call writefile(['testtext 2'], 'Xtest2')
  call writefile(['testtext 3'], 'Xtest3')

  next! Xtest1 Xtest2
  call setline(1, 'testtext 1 1')

  " test for working :n when hidden set
  set hidden
  next
  call assert_equal('Xtest2', bufname('%'))

  " test for failing :rew when hidden not set
  set nohidden
  call setline(1, 'testtext 2 2')
  call assert_fails('rewind', 'E37')
  call assert_equal('Xtest2', bufname('%'))
  call assert_equal('testtext 2 2', getline(1))

  " test for working :rew when hidden set
  set hidden
  rewind
  call assert_equal('Xtest1', bufname('%'))
  call assert_equal('testtext 1 1', getline(1))

  " test for :all keeping a buffer when it's modified
  set nohidden
  call setline(1, 'testtext 1 1 1')
  split
  next Xtest2 Xtest3
  all
  1wincmd w
  call assert_equal('Xtest1', bufname('%'))
  call assert_equal('testtext 1 1 1', getline(1))

  " test abandoning changed buffer, should be unloaded even when 'hidden' set
  set hidden
  call setline(1, 'testtext 1 1 1 1')
  quit!
  call assert_equal('Xtest2', bufname('%'))
  call assert_equal('testtext 2 2', getline(1))
  unhide
  call assert_equal('Xtest2', bufname('%'))
  call assert_equal('testtext 2 2', getline(1))

  " test ":hide" hides anyway when 'hidden' not set
  set nohidden
  call setline(1, 'testtext 2 2 2')
  hide
  call assert_equal('Xtest3', bufname('%'))
  call assert_equal('testtext 3', getline(1))

  " test ":edit" failing in modified buffer when 'hidden' not set
  call setline(1, 'testtext 3 3')
  call assert_fails('edit Xtest1', 'E37')
  call assert_equal('Xtest3', bufname('%'))
  call assert_equal('testtext 3 3', getline(1))

  " test ":edit" working in modified buffer when 'hidden' set
  set hidden
  edit Xtest1
  call assert_equal('Xtest1', bufname('%'))
  call assert_equal('testtext 1', getline(1))

  " test ":close" not hiding when 'hidden' not set in modified buffer
  split Xtest3
  set nohidden
  call setline(1, 'testtext 3 3 3')
  call assert_fails('close', 'E37')
  call assert_equal('Xtest3', bufname('%'))
  call assert_equal('testtext 3 3 3', getline(1))

  " test ":close!" does hide when 'hidden' not set in modified buffer;
  call setline(1, 'testtext 3 3 3 3')
  close!
  call assert_equal('Xtest1', bufname('%'))
  call assert_equal('testtext 1', getline(1))

  set nohidden

  " test ":all!" hides changed buffer
  split Xtest4
  call setline(1, 'testtext 4')
  all!
  1wincmd w
  call assert_equal('Xtest2', bufname('%'))
  call assert_equal('testtext 2 2 2', getline(1))

  " test ":q!" and hidden buffer.
  bwipe! Xtest1 Xtest2 Xtest3 Xtest4
  split Xtest1
  wincmd w
  bwipe!
  set modified
  bot split Xtest2
  set modified
  bot split Xtest3
  set modified
  wincmd t
  hide
  call assert_equal('Xtest2', bufname('%'))
  quit!
  call assert_equal('Xtest3', bufname('%'))
  call assert_fails('silent! quit!', 'E37')
  call assert_equal('Xtest1', bufname('%'))

  call delete('Xtest1')
  call delete('Xtest2')
  call delete('Xtest3')
endfunc

" Test that ":close" will respect 'winfixheight' when possible.
func Test_winfixheight_on_close()
  set nosplitbelow nosplitright

  split | split | vsplit

  $wincmd w
  setlocal winfixheight
  let l:height = winheight(0)

  3close

  call assert_equal(l:height, winheight(0))

  %bwipeout!
  setlocal nowinfixheight splitbelow& splitright&
endfunc

" Test that ":close" will respect 'winfixwidth' when possible.
func Test_winfixwidth_on_close()
  set nosplitbelow nosplitright

  vsplit | vsplit | split

  $wincmd w
  setlocal winfixwidth
  let l:width = winwidth(0)

  3close

  call assert_equal(l:width, winwidth(0))

  %bwipeout!
  setlocal nowinfixwidth splitbelow& splitright&
endfunction

" Test that 'winfixheight' will be respected even there is non-leaf frame
func Test_winfixheight_non_leaf_frame()
  vsplit
  botright 11new
  let l:wid = win_getid()
  setlocal winfixheight
  call assert_equal(11, winheight(l:wid))
  botright new
  bwipe!
  call assert_equal(11, winheight(l:wid))
  %bwipe!
endf

" Test that 'winfixwidth' will be respected even there is non-leaf frame
func Test_winfixwidth_non_leaf_frame()
  split
  topleft 11vnew
  let l:wid = win_getid()
  setlocal winfixwidth
  call assert_equal(11, winwidth(l:wid))
  topleft new
  bwipe!
  call assert_equal(11, winwidth(l:wid))
  %bwipe!
endf

func Test_tabwin_close()
  enew
  let l:wid = win_getid()
  tabedit
  call win_execute(l:wid, 'close')
  " Should not crash.
  call assert_true(v:true)

  " This tests closing a window in another tab, while leaving the tab open
  " i.e. two windows in another tab.
  tabedit
  let w:this_win = 42
  new
  let othertab_wid = win_getid()
  tabprevious
  call win_execute(othertab_wid, 'q')
  " drawing the tabline helps check that the other tab's windows and buffers
  " are still valid
  redrawtabline
  " but to be certain, ensure we can focus the other tab too
  tabnext
  call assert_equal(42, w:this_win)

  bwipe!
endfunc

" Test when closing a split window (above/below) restores space to the window
" below when 'noequalalways' and 'splitright' are set.
func Test_window_close_splitright_noequalalways()
  set noequalalways
  set splitright
  new
  let w1 = win_getid()
  new
  let w2 = win_getid()
  execute "normal \<c-w>b"
  let h = winheight(0)
  let w = win_getid()
  new
  q
  call assert_equal(h, winheight(0), "Window height does not match eight before opening and closing another window")
  call assert_equal(w, win_getid(), "Did not return to original window after opening and closing a window")
endfunc

