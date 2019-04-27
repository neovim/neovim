function! SetUp()
  if exists ( 'g:loaded_vimpector' )
    unlet g:loaded_vimpector
  endif

  source vimrc

  " This is a bit of a hack
  runtime! plugin/**/*.vim
endfunction

function! ClearDown()
  if exists( '*vimspector#internal#state#Reset' )
    call vimspector#internal#state#Reset()
  endif
endfunction

function! SetUp_Test_Mappings_Are_Added_HUMAN()
  let g:vimspector_enable_mappings = 'HUMAN'
endfunction

function! Test_Mappings_Are_Added_HUMAN()
  call assert_true( hasmapto( 'vimspector#Continue()' ) )
  call assert_false( hasmapto( 'vimspector#Launch()' ) )
  call assert_true( hasmapto( 'vimspector#Stop()' ) )
  call assert_true( hasmapto( 'vimspector#Restart()' ) )
  call assert_true( hasmapto( 'vimspector#ToggleBreakpoint()' ) )
  call assert_true( hasmapto( 'vimspector#AddFunctionBreakpoint' ) )
  call assert_true( hasmapto( 'vimspector#StepOver()' ) )
  call assert_true( hasmapto( 'vimspector#StepInto()' ) )
  call assert_true( hasmapto( 'vimspector#StepOut()' ) )
endfunction

function! Test_Mappings_Are_Added_VISUAL_STUDIO()
  call assert_true( hasmapto( 'vimspector#Continue()' ) )
  call assert_false( hasmapto( 'vimspector#Launch()' ) )
  call assert_true( hasmapto( 'vimspector#Stop()' ) )
  call assert_true( hasmapto( 'vimspector#Restart()' ) )
  call assert_true( hasmapto( 'vimspector#ToggleBreakpoint()' ) )
  call assert_true( hasmapto( 'vimspector#AddFunctionBreakpoint' ) )
  call assert_true( hasmapto( 'vimspector#StepOver()' ) )
  call assert_true( hasmapto( 'vimspector#StepInto()' ) )
  call assert_true( hasmapto( 'vimspector#StepOut()' ) )
endfunction

function! SetUp_Test_Signs_Placed_Using_API_Are_Shown()
  let g:vimspector_enable_mappings = 'VISUAL_STUDIO'
endfunction

function! Test_Signs_Placed_Using_API_Are_Shown()
  " We need a real file
  edit testdata/cpp/simple.cpp
  call feedkeys( '/printf<CR>' )

  " Set breakpoint
  call vimspector#ToggleBreakpoint()

  call assert_true( exists( '*vimspector#ToggleBreakpoint' ) )

  let signs = sign_getplaced( '.', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_true( len( signs ) == 1 )
  call assert_true( len( signs[ 0 ].signs ) == 1 )
  call assert_true( signs[ 0 ].signs[ 0 ].name == 'vimspectorBP' )

  " Disable breakpoint
  call vimspector#ToggleBreakpoint()

  let signs = sign_getplaced( '.', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_true( len( signs ) == 1 )
  call assert_true( len( signs[ 0 ].signs ) == 1 )
  call assert_true( signs[ 0 ].signs[ 0 ].name == 'vimspectorBPDisabled' )

  " Remove breakpoint
  call vimspector#ToggleBreakpoint()

  let signs = sign_getplaced( '.', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_true( len( signs ) == 1 )
  call assert_true( len( signs[ 0 ].signs ) == 0 )

  " TODO: Use the screen dump test ?
endfunction
