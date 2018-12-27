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

func Test_vim_function()
  " Check creating vim.Function object
  py3 import vim

  func s:foo()
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+_foo$')
  endfunc
  let name = '<SNR>' . s:foo()

  try
    py3 f = vim.bindeval('function("s:foo")')
    call assert_equal(name, py3eval('f.name'))
  catch
    call assert_false(v:exception)
  endtry

  try
    py3 f = vim.Function(b'\x80\xfdR' + vim.eval('s:foo()').encode())
    call assert_equal(name, py3eval('f.name'))
  catch
    call assert_false(v:exception)
  endtry

  py3 del f
  delfunc s:foo
endfunc
