" Test for 'scrollbind' causing an unexpected scroll of one of the windows.
func Test_scrollbind()
  " We don't want the status line to cause problems:
  set laststatus=0
  let totalLines = &lines * 20
  let middle = totalLines / 2
  new | only
  for i in range(1, totalLines)
      call setline(i, 'LINE ' . i)
  endfor
  exe string(middle)
  normal zt
  normal M
  aboveleft vert new
  for i in range(1, totalLines)
      call setline(i, 'line ' . i)
  endfor
  exe string(middle)
  normal zt
  normal M
  " Execute the following two commands at once to reproduce the problem.
  setl scb | wincmd p
  setl scb
  wincmd w
  let topLineLeft = line('w0')
  wincmd p
  let topLineRight = line('w0')
  setl noscrollbind
  wincmd p
  setl noscrollbind
  call assert_equal(0, topLineLeft - topLineRight)
endfunc

" Test for 'scrollbind'
func Test_scrollbind_opt()
  new | only
  set noscrollbind
  set scrollopt=ver,jump scrolloff=2 nowrap noequalalways splitbelow

  " Insert the text used for the test
  append


start of window 1
. line 01 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 01
. line 02 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02
. line 03 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 03
. line 04 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 04
. line 05 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 05
. line 06 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 06
. line 07 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 07
. line 08 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 08
. line 09 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 09
. line 10 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 10
. line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11
. line 12 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 12
. line 13 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 13
. line 14 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 14
. line 15 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 15
end of window 1


start of window 2
. line 01 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 01
. line 02 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 02
. line 03 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 03
. line 04 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 04
. line 05 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 05
. line 06 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 06
. line 07 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 07
. line 08 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 08
. line 09 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 09
. line 10 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 10
. line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11
. line 12 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 12
. line 13 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 13
. line 14 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 14
. line 15 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 15
. line 16 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 16
end of window 2

.

  " Test using two windows open to one buffer, one extra empty window
  split
  new
  wincmd t
  resize 8
  call search('^start of window 1$')
  normal zt
  set scrollbind
  wincmd j
  resize 7
  call search('^start of window 2$')
  normal zt
  set scrollbind

  " -- start of tests --
  " Test scrolling down
  normal L5jHyy
  wincmd b | normal pr0
  wincmd t | normal Hyy
  wincmd b | normal pr1
  wincmd t | normal L6jHyy
  wincmd b | normal pr2
  wincmd k | normal Hyy
  wincmd b | normal pr3

  " Test scrolling up
  wincmd t | normal H4k
  wincmd j | normal H
  wincmd t | normal Hyy
  wincmd b | normal pr4
  wincmd k | normal Hyy
  wincmd b | normal pr5
  wincmd k | normal 3k
  wincmd t | normal H
  wincmd j | normal Hyy
  wincmd b | normal pr6
  wincmd t | normal Hyy
  wincmd b | normal pr7

  " Test horizontal scrolling
  set scrollopt+=hor
  normal gg"zyyG"zpG
  wincmd t | normal 015zly$
  wincmd b | normal p"zpG
  wincmd k | normal y$
  wincmd b | normal p"zpG
  wincmd k | normal 10jH7zhg0y$
  wincmd b | normal p"zpG
  wincmd t | normal Hg0y$
  wincmd b | normal p"zpG
  set scrollopt-=hor

  wincmd b
  call assert_equal([
	      \ '',
	      \ '0 line 05 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 05',
	      \ '1 line 05 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 05',
	      \ '2 line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11',
	      \ '3 line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11',
	      \ '4 line 06 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 06',
	      \ '5 line 06 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 06',
	      \ '6 line 02 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 02',
	      \ '7 line 02 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02',
	      \ '56789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02',
	      \ 'UTSRQPONMLKJIHGREDCBA9876543210 02',
	      \ '. line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11',
	      \ '. line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11',
	      \ ''],  getline(1, '$'))
  enew!

  " ****** tests using two different buffers *****
  wincmd t | wincmd j | close
  wincmd t | set noscrollbind
  /start of window 2$/,/^end of window 2$/y
  new
  wincmd t | wincmd j | normal 4"zpGp
  wincmd t
  call search('^start of window 1$')
  normal zt
  set scrollbind
  wincmd j
  call search('^start of window 2$')
  normal zt
  set scrollbind

  " -- start of tests --
  " Test scrolling down
  normal L5jHyy
  wincmd b | normal pr0
  wincmd t | normal Hyy
  wincmd b | normal pr1
  wincmd t | normal L6jHyy
  wincmd b | normal pr2
  wincmd k | normal Hyy
  wincmd b | normal pr3

  " Test scrolling up
  wincmd t | normal H4k
  wincmd j | normal H
  wincmd t | normal Hyy
  wincmd b | normal pr4
  wincmd k | normal Hyy
  wincmd b | normal pr5
  wincmd k | normal 3k
  wincmd t | normal H
  wincmd j | normal Hyy
  wincmd b | normal pr6
  wincmd t | normal Hyy
  wincmd b | normal pr7

  " Test horizontal scrolling
  set scrollopt+=hor
  normal gg"zyyG"zpG
  wincmd t | normal 015zly$
  wincmd b | normal p"zpG
  wincmd k | normal y$
  wincmd b | normal p"zpG
  wincmd k | normal 10jH7zhg0y$
  wincmd b | normal p"zpG
  wincmd t | normal Hg0y$
  wincmd b | normal p"zpG
  set scrollopt-=hor

  wincmd b
  call assert_equal([
	      \ '',
	      \ '0 line 05 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 05',
	      \ '1 line 05 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 05',
	      \ '2 line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11',
	      \ '3 line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11',
	      \ '4 line 06 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 06',
	      \ '5 line 06 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 06',
	      \ '6 line 02 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 02',
	      \ '7 line 02 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02',
	      \ '56789ABCDEFGHIJKLMNOPQRSTUVWXYZ 02',
	      \ 'UTSRQPONMLKJIHGREDCBA9876543210 02',
	      \ '. line 11 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 11',
	      \ '. line 11 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 11',
	      \ ''],  getline(1, '$'))
  enew!

  " Test 'syncbind'
  wincmd t | set noscrollbind | normal ggL
  wincmd j | set noscrollbind | normal ggL
  set scrollbind
  wincmd t | set scrollbind | normal G
  wincmd j | normal G
  syncbind
  normal Hk
  wincmd t | normal H
  wincmd j | normal Hyy
  wincmd b | normal p
  wincmd t | normal yy
  wincmd b | normal p
  wincmd t | set noscrollbind | normal ggL
  wincmd j | set noscrollbind
  normal ggL
  set scrollbind
  wincmd t | set scrollbind
  wincmd t | normal G
  wincmd j | normal G
  wincmd t | syncbind | normal Hk
  wincmd j | normal H
  wincmd t | normal Hyy
  wincmd b | normal p
  wincmd t | wincmd j | normal yy
  wincmd b | normal p
  wincmd t | normal H3k
  wincmd j | normal H
  wincmd t | normal Hyy
  wincmd b | normal p
  wincmd t | wincmd j | normal yy
  wincmd b | normal p

  wincmd b
  call assert_equal([
	      \ '',
	      \ '. line 16 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 16',
	      \ 'start of window 2',
	      \ 'start of window 2',
	      \ '. line 16 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 16',
	      \ '. line 15 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ 15',
	      \ '. line 12 ZYXWVUTSRQPONMLKJIHGREDCBA9876543210 12',
	      \ ],  getline(1, '$'))
  enew!

  new | only!
  set scrollbind& scrollopt& scrolloff& wrap& equalalways& splitbelow&
endfunc
