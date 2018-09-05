" Tests for exiting Vim.

source shared.vim

func Test_exiting()
  let after = [
	\ 'au QuitPre * call writefile(["QuitPre"], "Xtestout")',
	\ 'au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")',
	\ 'quit',
	\ ]
  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre'], readfile('Xtestout'))
  endif
  call delete('Xtestout')

  let after = [
	\ 'au QuitPre * call writefile(["QuitPre"], "Xtestout")',
	\ 'au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")',
	\ 'help',
	\ 'wincmd w',
	\ 'quit',
	\ ]
  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre'], readfile('Xtestout'))
  endif
  call delete('Xtestout')

  let after = [
	\ 'au QuitPre * call writefile(["QuitPre"], "Xtestout")',
	\ 'au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")',
	\ 'split',
	\ 'new',
	\ 'qall',
	\ ]
  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre'], readfile('Xtestout'))
  endif
  call delete('Xtestout')

  let after = [
	\ 'au QuitPre * call writefile(["QuitPre"], "Xtestout", "a")',
	\ 'au ExitPre * call writefile(["ExitPre"], "Xtestout", "a")',
	\ 'augroup nasty',
	\ '  au ExitPre * split',
	\ 'augroup END',
	\ 'quit',
	\ 'augroup nasty',
	\ '  au! ExitPre',
	\ 'augroup END',
	\ 'quit',
	\ ]
  if RunVim([], after, '')
    call assert_equal(['QuitPre', 'ExitPre', 'QuitPre', 'ExitPre'],
	  \ readfile('Xtestout'))
  endif
  call delete('Xtestout')
endfunc
