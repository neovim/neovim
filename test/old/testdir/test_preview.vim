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

func s:goto_preview_and_close()
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

func Test_window_preview()
  CheckFeature quickfix

  " Open a preview window
  pedit Xa
  call assert_equal(2, winnr('$'))
  call assert_equal(0, &previewwindow)

  call s:goto_preview_and_close()
endfunc

func Test_window_preview_from_pbuffer()
  CheckFeature quickfix

  call writefile(['/* some C code */'], 'Xpreview.c', 'D')
  edit Xpreview.c
  const buf_num = bufnr('%')
  enew

  call feedkeys(":pbuffer Xpre\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"pbuffer Xpreview.c", @:)

  call assert_equal(1, winnr('$'))
  exe 'pbuffer ' .  buf_num
  call assert_equal(2, winnr('$'))
  call assert_equal(0, &previewwindow)

  call s:goto_preview_and_close()

  call assert_equal(1, winnr('$'))
  pbuffer Xpreview.c
  call assert_equal(2, winnr('$'))
  call assert_equal(0, &previewwindow)

  call s:goto_preview_and_close()
endfunc

func Test_window_preview_terminal()
  CheckFeature quickfix
  " CheckFeature terminal

  " term ++curwin
  term
  const buf_num = bufnr('$')
  call assert_equal(1, winnr('$'))
  exe 'pbuffer' . buf_num
  call assert_equal(2, winnr('$'))
  call assert_equal(0, &previewwindow)

  call s:goto_preview_and_close()
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
