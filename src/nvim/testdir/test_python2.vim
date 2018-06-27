" Test for python 2 commands.
" TODO: move tests from test87.in here.

if !has('python')
  finish
endif

func Test_pydo()
  " Check deleting lines does not trigger ml_get error.
  py import vim
  new
  call setline(1, ['one', 'two', 'three'])
  pydo vim.command("%d_")
  bwipe!

  " Disabled until neovim/neovim#8554 is resolved
  if 0
    " Check switching to another buffer does not trigger ml_get error.
    new
    let wincount = winnr('$')
    call setline(1, ['one', 'two', 'three'])
    pydo vim.command("new")
    call assert_equal(wincount + 1, winnr('$'))
    bwipe!
    bwipe!
  endif
endfunc
