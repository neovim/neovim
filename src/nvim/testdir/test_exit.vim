" Tests for exiting Vim.

source shared.vim

func Test_exiting()
  let after =<< trim [CODE]
    au QuitPre * call writefile(["QuitPre"], "Xtestout")
    au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")
    quit
  [CODE]

  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre'], readfile('Xtestout'))
  endif
  call delete('Xtestout')

  let after =<< trim [CODE]
    au QuitPre * call writefile(["QuitPre"], "Xtestout")
    au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")
    help
    wincmd w
    quit
  [CODE]

  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre'], readfile('Xtestout'))
  endif
  call delete('Xtestout')

  let after =<< trim [CODE]
    au QuitPre * call writefile(["QuitPre"], "Xtestout")
    au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")
    split
    new
    qall
  [CODE]

  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre'], readfile('Xtestout'))
  endif
  call delete('Xtestout')

  " ExitPre autocommand splits the window, so that it's no longer the last one.
  let after =<< trim [CODE]
    au QuitPre * call writefile(["QuitPre"], "Xtestout", "a")
    au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")
    augroup nasty
      au ExitPre * split
    augroup END
    quit
    augroup nasty
      au! ExitPre
    augroup END
    quit
  [CODE]

  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre', 'QuitPre', 'ExitPre'],
	  \ readfile('Xtestout'))
  endif
  call delete('Xtestout')

  " ExitPre autocommand splits and closes the window, so that there is still
  " one window but it's a different one.
  let after =<< trim [CODE]
    au QuitPre * call writefile(["QuitPre"], "Xtestout", "a")
    au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")
    augroup nasty
      au ExitPre * split | only
    augroup END
    quit
    augroup nasty
      au! ExitPre
    augroup END
    quit
  [CODE]

  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre', 'QuitPre', 'ExitPre'],
	  \ readfile('Xtestout'))
  endif
  call delete('Xtestout')
endfunc
