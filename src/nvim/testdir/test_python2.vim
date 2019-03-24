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

func Test_vim_function()
  " Check creating vim.Function object
  py import vim

  func s:foo()
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+_foo$')
  endfunc
  let name = '<SNR>' . s:foo()

  try
    py f = vim.bindeval('function("s:foo")')
    call assert_equal(name, pyeval('f.name'))
  catch
    call assert_false(v:exception)
  endtry

  try
    py f = vim.Function('\x80\xfdR' + vim.eval('s:foo()'))
    call assert_equal(name, pyeval('f.name'))
  catch
    call assert_false(v:exception)
  endtry

  py del f
  delfunc s:foo
endfunc

func _SetUpHiddenBuffer()
  py import vim
  new
  edit hidden
  setlocal bufhidden=hide

  enew
  let lnum = 0
  while lnum < 10
    call append( 1, string( lnum ) )
    let lnum = lnum + 1
  endwhile
  normal G

  call assert_equal( line( '.' ), 11 )
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_Clear()
  call _SetUpHiddenBuffer()
  py vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][:] = None
  call assert_equal( line( '.' ), 11 )
  bwipe!
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_List()
  call _SetUpHiddenBuffer()
  py vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][:] = [ 'test' ]
  call assert_equal( line( '.' ), 11 )
  bwipe!
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_Str()
  call _SetUpHiddenBuffer()
  py vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][0] = 'test'
  call assert_equal( line( '.' ), 11 )
  bwipe!
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_ClearLine()
  call _SetUpHiddenBuffer()
  py vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][0] = None
  call assert_equal( line( '.' ), 11 )
  bwipe!
endfunc

func _SetUpVisibleBuffer()
  py import vim
  new
  let lnum = 0
  while lnum < 10
    call append( 1, string( lnum ) )
    let lnum = lnum + 1
  endwhile
  normal G
  call assert_equal( line( '.' ), 11 )
endfunc

func Test_Write_To_Current_Buffer_Fixes_Cursor_Clear()
  call _SetUpVisibleBuffer()

  py vim.current.buffer[:] = None
  call assert_equal( line( '.' ), 1 )

  bwipe!
endfunc

func Test_Write_To_Current_Buffer_Fixes_Cursor_List()
  call _SetUpVisibleBuffer()

  py vim.current.buffer[:] = [ 'test' ]
  call assert_equal( line( '.' ), 1 )

  bwipe!
endfunction

func Test_Write_To_Current_Buffer_Fixes_Cursor_Str()
  call _SetUpVisibleBuffer()

  py vim.current.buffer[-1] = None
  call assert_equal( line( '.' ), 10 )

  bwipe!
endfunction
