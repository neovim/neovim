source lib/shared.vim

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

function! SetUp_Test_Mappings_Are_Added_VISUAL_STUDIO()
  let g:vimspector_enable_mappings = 'VISUAL_STUDIO'
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
  edit testdata/cpp/simple/simple.cpp
  call feedkeys( "/printf\<CR>", 'xt' )

  " Set breakpoint
  call vimspector#ToggleBreakpoint()

  call assert_true( exists( '*vimspector#ToggleBreakpoint' ) )

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_equal( 1, len( signs ) )
  call assert_equal( 1, len( signs[ 0 ].signs ) )
  call assert_equal( 'vimspectorBP', signs[ 0 ].signs[ 0 ].name )

  " Disable breakpoint
  call vimspector#ToggleBreakpoint()

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_equal( 1, len( signs ) )
  call assert_equal( 1, len( signs[ 0 ].signs ) )
  call assert_equal( 'vimspectorBPDisabled', signs[ 0 ].signs[ 0 ].name )

  " Remove breakpoint
  call vimspector#ToggleBreakpoint()

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_equal( 1, len( signs ) )
  call assert_equal( 0, len( signs[ 0 ].signs ) )

  call vimspector#ClearBreakpoints()
  %bwipeout!
endfunction

function! SetUp_Test_Use_Mappings_HUMAN()
  let g:vimspector_enable_mappings = 'HUMAN'
endfunction

function! Test_Use_Mappings_HUMAN()
  lcd testdata/cpp/simple
  edit simple.cpp

  15
  call assert_equal( 15, line( '.' ) )

  " Add the breakpoing
  call feedkeys( "\<F9>", 'xt' )

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_equal( 1, len( signs ), 1 )
  call assert_equal( 1, len( signs[ 0 ].signs ), 1 )
  call assert_equal( 'vimspectorBP', signs[ 0 ].signs[ 0 ].name )

  " Disable the breakpoint
  call feedkeys( "\<F9>", 'xt' )

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )
  call assert_equal( 1, len( signs ), 1 )
  call assert_equal( 1, len( signs[ 0 ].signs ), 1 )
  call assert_equal( 'vimspectorBPDisabled', signs[ 0 ].signs[ 0 ].name )

  " Delete the breakpoint
  call feedkeys( "\<F9>", 'xt' )

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )
  call assert_equal( 1, len( signs ), 1 )
  call assert_equal( 0, len( signs[ 0 ].signs ) )

  " Add it again
  call feedkeys( "\<F9>", 'xt' )

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_equal( 1, len( signs ), 1 )
  call assert_equal( 1, len( signs[ 0 ].signs ), 1 )
  call assert_equal( 'vimspectorBP', signs[ 0 ].signs[ 0 ].name )

  " Here we go. Start Debugging
  call feedkeys( "\<F5>", 'xt' )

  call assert_equal( 2, len( gettabinfo() ) )
  let cur_tabnr = tabpagenr()
  call assert_equal( 5, len( gettabinfo( cur_tabnr )[ 0 ].windows ) )

  call WaitForAssert( {->
        \ assert_equal( 'simple.cpp', bufname( '%' ), 'Current buffer' )
        \ }, 10000 )
  call assert_equal( 15, line( '.' ), 'Current line' )
  call assert_equal( 1, col( '.' ), 'Current column' )

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorCode',
    \ } )

  call assert_equal( 1, len( signs ), 'Sign-buffers' )
  call assert_equal( 2, len( signs[ 0 ].signs ), 'Signs in buffer' )

  let pc_index = -1
  let index = 0
  while index < len( signs[ 0 ].signs )
    let s = signs[ 0 ].signs[ index ]
    if s.name ==# 'vimspectorPC'
      if pc_index >= 0
        call assert_report( 'Found too many PC signs!' )
      endif
      let pc_index = index
    endif
    let index = index + 1
  endwhile
  call assert_true( pc_index >= 0 )
  call assert_equal( 15, signs[ 0 ].signs[ pc_index ].lnum )

  " Step
  call feedkeys( "\<F10>", 'xt' )

  call WaitForAssert( {-> assert_equal( 16, line( '.' ), 'Current line' ) } )
  call assert_equal( 'simple.cpp', bufname( '%' ), 'Current buffer' )
  call assert_equal( 1, col( '.' ), 'Current column' )

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorCode',
    \ } )

  call assert_equal( 1, len( signs ), 'Sign-buffers' )
  call assert_equal( 2, len( signs[ 0 ].signs ), 'Signs in buffer' )

  let pc_index = -1
  let index = 0
  while index < len( signs[ 0 ].signs )
    let s = signs[ 0 ].signs[ index ]
    if s.name ==# 'vimspectorPC'
      if pc_index >= 0
        call assert_report( 'Found too many PC signs!' )
      endif
      let pc_index = index
    endif
    let index = index + 1
  endwhile
  call assert_true( pc_index >= 0 )
  call assert_equal( 16, signs[ 0 ].signs[ pc_index ].lnum )

  call vimspector#Reset()

  call vimspector#ClearBreakpoints()

  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP'
    \ } )
  call assert_equal( 1, len( signs ), 1 )
  call assert_equal( 0, len( signs[ 0 ].signs ) )

  lcd -
  %bwipeout!
endfunction
