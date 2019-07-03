source lib/shared.vim

function! SetUp()
  if exists ( 'g:loaded_vimpector' )
    unlet g:loaded_vimpector
  endif

  let g:vimspector_enable_mappings = 'HUMAN'
  source vimrc

  " This is a bit of a hack
  runtime! plugin/**/*.vim
endfunction

function! Test_Step_With_Different_Tabpage()
  lcd testdata/cpp/simple
  edit simple.cpp

  " Add the breakpoing
  " TODO refactor FeedKeys
  15
  call assert_equal( 15, line( '.' ) )
  call feedkeys( "\<F9>", 'xt' )

  " Here we go. Start Debugging
  call feedkeys( "\<F5>", 'xt' )

  call assert_equal( 2, len( gettabinfo() ) )
  let vimspector_tabnr = tabpagenr()
  call WaitForAssert( {->
        \ assert_equal( 'simple.cpp', bufname( '%' ), 'Current buffer' )
        \ }, 10000 )
  call assert_equal( 15, line( '.' ), 'Current line' )
  call assert_equal( 1, col( '.' ), 'Current column' )

  " Switch to the other tab
  normal gt

  call assert_notequal( vimspector_tabnr, tabpagenr() )

  " trigger some output by hacking into the vimspector python
  call py3eval( '_vimspector_session._outputView.Print( "server",'
            \ . '                                       "This is a test" )' )

  " Step - jumps back to our vimspector tab
  call feedkeys( "\<F10>", 'xt' )

  call WaitForAssert( {-> assert_equal( vimspector_tabnr, tabpagenr() ) } )
  call WaitForAssert( {-> assert_equal( 16, line( '.' ), 'Current line' ) } )
  call assert_equal( 'simple.cpp', bufname( '%' ), 'Current buffer' )
  call assert_equal( 1, col( '.' ), 'Current column' )

  call vimspector#Reset()
  call vimspector#ClearBreakpoints()

  lcd -
  %bwipeout!
endfunction

