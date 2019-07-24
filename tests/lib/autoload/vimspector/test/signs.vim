function! vimspector#test#signs#AssertCursorIsAtLineInBuffer( buffer,
                                                            \ line,
                                                            \ column ) abort
  call WaitForAssert( {->
        \ assert_equal( a:buffer, bufname( '%' ), 'Current buffer' )
        \ }, 10000 )
  call WaitForAssert( {->
        \ assert_equal( a:line, line( '.' ), 'Current line' )
        \ }, 10000 )
  call assert_equal( a:column, col( '.' ), 'Current column' )
endfunction

function! vimspector#test#signs#AssertPCIsAtLineInBuffer( buffer, line ) abort
  let signs = sign_getplaced( a:buffer, {
    \ 'group': 'VimspectorCode',
    \ } )

  if assert_equal( 1, len( signs ), 'Number of buffers named ' . a:buffer )
    return 1
  endif

  if assert_true( len( signs[ 0 ].signs ) >= 1,
                \ 'At least one VimspectorCode sign' )
    return 1
  endif

  let pc_index = -1
  let index = 0
  while index < len( signs[ 0 ].signs )
    let s = signs[ 0 ].signs[ index ]
    if s.name ==# 'vimspectorPC'
      if assert_false( pc_index >= 0, 'Too many PC signs' )
        return 1
      endif
      let pc_index = index
    endif
    let index = index + 1
  endwhile
  return assert_true( pc_index >= 0 ) ||
       \ assert_equal( a:line, signs[ 0 ].signs[ pc_index ].lnum )
endfunction

function! vimspector#test#signs#AssertSignGroupSingletonAtLine( group,
                                                              \ line,
                                                              \ sign_name )
                                                              \ abort

  let signs = sign_getplaced( '%', {
    \ 'group': a:group,
    \ 'lnum': a:line,
    \ } )

  return assert_equal( 1,
                     \ len( signs ),
                     \ 'Num buffers named %' ) ||
       \ assert_equal( 1,
                     \ len( signs[ 0 ].signs ),
                     \ 'Num signs in ' . a:group . ' at ' . a:line ) ||
       \ assert_equal( a:sign_name,
                     \ signs[ 0 ].signs[ 0 ].name,
                     \ 'Sign in group ' . a:group . ' at ' . a:line )
endfunction


function! vimspector#test#signs#AssertSignGroupEmptyAtLine( group, line ) abort
  let signs = sign_getplaced( '%', {
    \ 'group': a:group,
    \ 'lnum': line( '.' )
    \ } )

  return assert_equal( 1,
                     \ len( signs ),
                     \ 'Num buffers named %' ) ||
       \ assert_equal( 0,
                     \ len( signs[ 0 ].signs ),
                     \ 'Num signs in ' . a:group . ' at ' . a:line )
endfunction


function! vimspector#test#signs#AssertSignGroupEmpty( group ) abort
  let signs = sign_getplaced( '%', {
    \ 'group': a:group,
    \ } )
  return assert_equal( 1,
                     \ len( signs ),
                     \ 'Num buffers named %' ) ||
       \ assert_equal( 0,
                     \ len( signs[ 0 ].signs ),
                     \ 'Num signs in ' . a:group )
endfunction



