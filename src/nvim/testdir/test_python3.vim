" Test for python 3 commands.
" TODO: move tests from test87.in here.

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

func Test_set_cursor()
  " Check that setting the cursor position works.
  py3 import vim
  new
  call setline(1, ['first line', 'second line'])
  normal gg
  py3do vim.current.window.cursor = (1, 5)
  call assert_equal([1, 6], [line('.'), col('.')])

  " Check that movement after setting cursor position keeps current column.
  normal j
  call assert_equal([2, 6], [line('.'), col('.')])
endfunc

func Test_vim_function()
  throw 'skipped: Nvim does not support vim.bindeval()'
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

func Test_skipped_python3_command_does_not_affect_pyxversion()
  set pyxversion=0
  if 0
    python3 import vim
  endif
  call assert_equal(0, &pyxversion)  " This assertion would have failed with Vim 8.0.0251. (pyxversion was introduced in 8.0.0251.)
endfunc

func _SetUpHiddenBuffer()
  py3 import vim
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

func _CleanUpHiddenBuffer()
  bwipe! hidden
  bwipe!
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_Clear()
  call _SetUpHiddenBuffer()
  py3 vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][:] = None
  call assert_equal( line( '.' ), 11 )
  call _CleanUpHiddenBuffer()
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_List()
  call _SetUpHiddenBuffer()
  py3 vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][:] = [ 'test' ]
  call assert_equal( line( '.' ), 11 )
  call _CleanUpHiddenBuffer()
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_Str()
  call _SetUpHiddenBuffer()
  py3 vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][0] = 'test'
  call assert_equal( line( '.' ), 11 )
  call _CleanUpHiddenBuffer()
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_ClearLine()
  call _SetUpHiddenBuffer()
  py3 vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][0] = None
  call assert_equal( line( '.' ), 11 )
  call _CleanUpHiddenBuffer()
endfunc

func _SetUpVisibleBuffer()
  py3 import vim
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

  py3 vim.current.buffer[:] = None
  call assert_equal( line( '.' ), 1 )

  bwipe!
endfunc

func Test_Write_To_Current_Buffer_Fixes_Cursor_List()
  call _SetUpVisibleBuffer()

  py3 vim.current.buffer[:] = [ 'test' ]
  call assert_equal( line( '.' ), 1 )

  bwipe!
endfunction

func Test_Write_To_Current_Buffer_Fixes_Cursor_Str()
  call _SetUpVisibleBuffer()

  py3 vim.current.buffer[-1] = None
  call assert_equal( line( '.' ), 10 )

  bwipe!
endfunction

func Test_Catch_Exception_Message()
  try
    py3 raise RuntimeError( 'TEST' )
  catch /.*/
    call assert_match('^Vim(.*):.*RuntimeError: TEST$', v:exception )
  endtry
endfunc

func Test_unicode()
  " this crashed Vim once
  throw "Skipped: nvim does not support changing 'encoding'"

  set encoding=utf32
  py3 print('hello')

  if !has('win32')
    set encoding=debug
    py3 print('hello')

    set encoding=euc-tw
    py3 print('hello')
  endif

  set encoding=utf8
endfunc
