function! SetUp()
  call vimspector#test#setup#SetUpWithMappings( v:none )
endfunction

function! ClearDown()
  call vimspector#test#setup#ClearDown()
endfunction

function! SetUp_Test_Go_Simple()
  let g:vimspector_enable_mappings = 'HUMAN'
endfunction

function! Test_Go_Simple()
  let fn='hello-world.go'
  lcd ../support/test/go/hello_world
  exe 'edit ' . fn
  call setpos( '.', [ 0, 4, 1 ] )

  call vimspector#test#signs#AssertCursorIsAtLineInBuffer( fn, 4, 1 )
  call vimspector#test#signs#AssertSignGroupEmptyAtLine( 'VimspectorBP', 4 )

  " Add the breakpoint
  call feedkeys( "\<F9>", 'xt' )
  call vimspector#test#signs#AssertSignGroupSingletonAtLine( 'VimspectorBP',
                                                           \ 4,
                                                           \ 'vimspectorBP' )

  call setpos( '.', [ 0, 1, 1 ] )

  " Here we go. Start Debugging
  call feedkeys( "\<F5>", 'xt' )
  call vimspector#test#signs#AssertCursorIsAtLineInBuffer( fn, 4, 1 )

  " Step
  call feedkeys( "\<F10>", 'xt' )

  call vimspector#test#signs#AssertCursorIsAtLineInBuffer( fn, 5, 1 )
  call WaitForAssert( {->
        \ vimspector#test#signs#AssertPCIsAtLineInBuffer( fn, 5 )
        \ } )

  call vimspector#test#setup#Reset()

  lcd -
  %bwipeout!
endfunction
