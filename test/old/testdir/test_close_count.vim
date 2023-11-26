
" Tests for :[count]close! command
func Test_close_count()
  enew! | only

  let wids = [win_getid()]
  for i in range(5)
    new
    call add(wids, win_getid())
  endfor

  4wincmd w
  close!
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[5], wids[4], wids[3], wids[1], wids[0]], ids)

  1close!
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[3], wids[1], wids[0]], ids)

  $close!
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[3], wids[1]], ids)

  1wincmd w
  2close!
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[1]], ids)

  1wincmd w
  new
  call add(wids, win_getid())
  new
  call add(wids, win_getid())
  2wincmd w
  -1close!
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[6], wids[4], wids[1]], ids)

  2wincmd w
  +1close!
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[6], wids[4]], ids)

  only!
endfunc

" Tests for :[count]hide command
func Test_hide_count()
  enew! | only

  let wids = [win_getid()]
  for i in range(5)
    new
    call add(wids, win_getid())
  endfor

  4wincmd w
  .hide
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[5], wids[4], wids[3], wids[1], wids[0]], ids)

  1hide
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[3], wids[1], wids[0]], ids)

  $hide
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[3], wids[1]], ids)

  1wincmd w
  2hide
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[1]], ids)

  1wincmd w
  new
  call add(wids, win_getid())
  new
  call add(wids, win_getid())
  3wincmd w
  -hide
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[7], wids[4], wids[1]], ids)

  2wincmd w
  +hide
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[7], wids[4]], ids)

  only!
endfunc

" Tests for :[count]close! command with 'hidden'
func Test_hidden_close_count()
  enew! | only

  let wids = [win_getid()]
  for i in range(5)
    new
    call add(wids, win_getid())
  endfor

  set hidden

  $ hide
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[5], wids[4], wids[3], wids[2], wids[1]], ids)

  $-1 close!
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[5], wids[4], wids[3], wids[1]], ids)

  1wincmd w
  .+close!
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[5], wids[3], wids[1]], ids)

  set nohidden
  only!
endfunc

" Tests for 'CTRL-W c' command to close windows.
func Test_winclose_command()
  enew! | only

  let wids = [win_getid()]
  for i in range(5)
    new
    call add(wids, win_getid())
  endfor

  set hidden

  4wincmd w
  exe "normal \<C-W>c"
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[5], wids[4], wids[3], wids[1], wids[0]], ids)

  exe "normal 1\<C-W>c"
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[3], wids[1], wids[0]], ids)

  exe "normal 9\<C-W>c"
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[3], wids[1]], ids)

  1wincmd w
  exe "normal 2\<C-W>c"
  let ids = []
  windo call add(ids, win_getid())
  call assert_equal([wids[4], wids[1]], ids)

  set nohidden
  only!
endfunc
