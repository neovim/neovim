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

" Test for getting the Vim exit code from v:exiting
func Test_exit_code()
  call assert_equal(v:null, v:exiting)

  let before =<< trim [CODE]
    au QuitPre * call writefile(['qp = ' .. v:exiting], 'Xtestout', 'a')
    au ExitPre * call writefile(['ep = ' .. v:exiting], 'Xtestout', 'a')
    au VimLeavePre * call writefile(['lp = ' .. v:exiting], 'Xtestout', 'a')
    au VimLeave * call writefile(['l = ' .. v:exiting], 'Xtestout', 'a')
  [CODE]

  if RunVim(before, ['quit'], '')
    call assert_equal(['qp = null', 'ep = null', 'lp = 0', 'l = 0'], readfile('Xtestout'))
  endif
  call delete('Xtestout')

  if RunVim(before, ['cquit'], '')
    call assert_equal(['lp = 1', 'l = 1'], readfile('Xtestout'))
  endif
  call delete('Xtestout')

  if RunVim(before, ['cquit 4'], '')
    call assert_equal(['lp = 4', 'l = 4'], readfile('Xtestout'))
  endif
  call delete('Xtestout')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
