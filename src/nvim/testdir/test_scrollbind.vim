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
