" Test for python 2 commands.
" TODO: move tests from test88.in here.

if !has('python3')
  finish
endif

func Test_py3do()
  " Check deleting lines does not trigger an ml_get error.
  py3 import vim
  new
  call setline(1, ['one', 'two', 'three'])
  py3do vim.command("%d_")
  bwipe!

  " Disabled until neovim/neovim#8554 is resolved
  if 0
    " Check switching to another buffer does not trigger an ml_get error.
    new
    let wincount = winnr('$')
    call setline(1, ['one', 'two', 'three'])
    py3do vim.command("new")
    call assert_equal(wincount + 1, winnr('$'))
    bwipe!
    bwipe!
  endif
endfunc
