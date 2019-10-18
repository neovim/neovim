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
  let fn='main.py'
  lcd ../support/test/python/simple_python
  exe 'edit ' . fn
  call setpos( '.', [ 0, 6, 1 ] )

  call vimspector#test#signs#AssertCursorIsAtLineInBuffer( fn, 6, 1 )
  call vimspector#test#signs#AssertSignGroupEmptyAtLine( 'VimspectorBP', 6 )

  " Add the breakpoint
  call feedkeys( "\<F9>", 'xt' )
  call vimspector#test#signs#AssertSignGroupSingletonAtLine( 'VimspectorBP',
                                                           \ 6,
                                                           \ 'vimspectorBP' )

  call setpos( '.', [ 0, 1, 1 ] )

  " Here we go. Start Debugging
  pyx << EOF
from unittest.mock import patch
with patch( 'vimspector.utils.SelectFromList',
            return_value=None ) as p:
  with patch( 'vimspector.utils.AskForInput',
              return_value=None ) as p:
    vim.eval( 'vimspector#LaunchWithSettings( { "configuration": "run" } )' )
    vim.eval( 'vimspector#test#signs#AssertCursorIsAtLineInBuffer( fn, 6, 1 )' )
    p.assert_called()
EOF

  " Step
  call feedkeys( "\<F10>", 'xt' )

  call vimspector#test#signs#AssertCursorIsAtLineInBuffer( fn, 7, 1 )
  call WaitForAssert( {->
        \ vimspector#test#signs#AssertPCIsAtLineInBuffer( fn, 7 )
        \ } )

  call vimspector#test#setup#Reset()

  lcd -
  %bwipeout!
endfunction

