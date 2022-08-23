" Tests for the preview window

source check.vim
CheckFeature quickfix

func Test_Psearch()
  " this used to cause ml_get errors
  help
  let wincount = winnr('$')
  0f
  ps.
  call assert_equal(wincount + 1, winnr('$'))
  pclose
  call assert_equal(wincount, winnr('$'))
  bwipe
endfunc

func Test_window_preview()
  CheckFeature quickfix

  " Open a preview window
  pedit Xa
  call assert_equal(2, winnr('$'))
  call assert_equal(0, &previewwindow)

  " Go to the preview window
  wincmd P
  call assert_equal(1, &previewwindow)
  call assert_equal('preview', win_gettype())

  " Close preview window
  wincmd z
  call assert_equal(1, winnr('$'))
  call assert_equal(0, &previewwindow)

  call assert_fails('wincmd P', 'E441:')
endfunc

func Test_window_preview_from_help()
  CheckFeature quickfix

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

func Test_multiple_preview_windows()
  new
  set previewwindow
  new
  call assert_fails('set previewwindow', 'E590:')
  %bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
