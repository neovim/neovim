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
  call assert_fails('silent! quit!', 'E162')
  call assert_equal('Xtest1', bufname('%'))

  call delete('Xtest1')
  call delete('Xtest2')
  call delete('Xtest3')
endfunc
