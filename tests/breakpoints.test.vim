function! SetUp()
  call vimspector#test#setup#SetUpWithMappings( v:none )
endfunction

function! ClearDown()
  call vimspector#test#setup#ClearDown()
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

function! AssertSignGroupSingletonAtLine( group,
                                        \ line,
                                        \ sign_name )

  let signs = sign_getplaced( '%', {
    \ 'group': a:group,
    \ 'line': a:line,
    \ } )

  call assert_equal( 1, len( signs ) )
  call assert_equal( 1, len( signs[ 0 ].signs ) )
  call assert_equal( a:sign_name, signs[ 0 ].signs[ 0 ].name )
endfunction


function! AssertSignGroupEmptyAtLine( group, line )
  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP',
    \ 'line': line( '.' )
    \ } )

  call assert_equal( 1, len( signs ) )
  call assert_equal( 0, len( signs[ 0 ].signs ) )
endfunction


function! AssertSignGroupEmpty( group )
  let signs = sign_getplaced( '%', {
    \ 'group': 'VimspectorBP'
    \ } )
  call assert_equal( 1, len( signs ) )
  call assert_equal( 0, len( signs[ 0 ].signs ) )
endfunction


function! Test_Signs_Placed_Using_API_Are_Shown()
  " We need a real file
  edit testdata/cpp/simple/simple.cpp
  call feedkeys( "/printf\<CR>", 'xt' )

  " Set breakpoint
  call vimspector#ToggleBreakpoint()

  call assert_true( exists( '*vimspector#ToggleBreakpoint' ) )
  call AssertSignGroupSingletonAtLine( 'VimspectorBP',
                                     \ line( '.' ),
                                     \ 'vimspectorBP' )

  " Disable breakpoint
  call vimspector#ToggleBreakpoint()
  call AssertSignGroupSingletonAtLine( 'VimspectorBP',
                                     \ line( '.' ),
                                     \ 'vimspectorBPDisabled' )

  " Remove breakpoint
  call vimspector#ToggleBreakpoint()

  call AssertSignGroupEmptyAtLine( 'VimspectorBP', line( '.' ) )

  call vimspector#ClearBreakpoints()
  call AssertSignGroupEmpty( 'VimspectorBP' )

  %bwipeout!
endfunction

function! AssertCursorIsAtLineInBuffer( buffer, line, column )
  call WaitForAssert( {->
        \ assert_equal( a:buffer, bufname( '%' ), 'Current buffer' )
        \ }, 10000 )
  call WaitForAssert( {->
        \ assert_equal( a:line, line( '.' ), 'Current line' )
        \ }, 10000 )
  call assert_equal( a:column, col( '.' ), 'Current column' )
endfunction

function! AssertPCIsAtLineInBuffer( buffer, line )
  let signs = sign_getplaced( a:buffer, {
    \ 'group': 'VimspectorCode',
    \ } )

  call assert_equal( 1, len( signs ), 'Sign-buffers' )
  call assert_true( len( signs[ 0 ].signs ) >= 1, 'Signs in buffer' )

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
  call assert_equal( a:line, signs[ 0 ].signs[ pc_index ].lnum )

endfunction

function! SetUp_Test_Use_Mappings_HUMAN()
  let g:vimspector_enable_mappings = 'HUMAN'
endfunction

function! Test_Use_Mappings_HUMAN()
  lcd testdata/cpp/simple
  edit simple.cpp
  call setpos( '.', [ 0, 15, 1 ] )

  call AssertCursorIsAtLineInBuffer( 'simple.cpp', 15, 1 )

  call AssertSignGroupEmptyAtLine( 'VimspectorBP',
                                 \ 15 )

  " Add the breakpoint
  call feedkeys( "\<F9>", 'xt' )
  call AssertSignGroupSingletonAtLine( 'VimspectorBP',
                                     \ 15,
                                     \ 'vimspectorBP' )

  " Disable the breakpoint
  call feedkeys( "\<F9>", 'xt' )
  call AssertSignGroupSingletonAtLine( 'VimspectorBP',
                                     \ 15,
                                     \ 'vimspectorBPDisabled' )

  " Delete the breakpoint
  call feedkeys( "\<F9>", 'xt' )
  call AssertSignGroupEmptyAtLine( 'VimspectorBP', 15 )

  " Add it again
  call feedkeys( "\<F9>", 'xt' )
  call AssertSignGroupSingletonAtLine( 'VimspectorBP',
                                     \ 15,
                                     \ 'vimspectorBP' )

  " Here we go. Start Debugging
  call feedkeys( "\<F5>", 'xt' )

  call assert_equal( 2, len( gettabinfo() ) )
  let cur_tabnr = tabpagenr()
  call assert_equal( 5, len( gettabinfo( cur_tabnr )[ 0 ].windows ) )

  call AssertCursorIsAtLineInBuffer( 'simple.cpp', 15, 1 )

  " Step
  call feedkeys( "\<F10>", 'xt' )

  call AssertCursorIsAtLineInBuffer( 'simple.cpp', 16, 1 )
  call AssertPCIsAtLineInBuffer( '%', 16 )

  call vimspector#test#setup#Reset()

  lcd -
  %bwipeout!
endfunction

function! SetUp_Test_StopAtEntry()
  let g:vimspector_enable_mappings = 'HUMAN'
endfunction

function Test_StopAtEntry()
  lcd testdata/cpp/simple
  edit simple.cpp
  call setpos( '.', [ 0, 15, 1 ] )

  " Test stopAtEntry behaviour
  call feedkeys( "\<F5>", 'xt' )

  call AssertCursorIsAtLineInBuffer( 'simple.cpp', 15, 1 )
  call AssertPCIsAtLineInBuffer( 'simple.cpp', 15 )

  call vimspector#test#setup#Reset()

  lcd -
  %bwipeout!
endfunction
