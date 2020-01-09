" vimspector - A multi-language debugging system for Vim
" Copyright 2020 Ben Jackson
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"   http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.


" Boilerplate {{{
let s:save_cpo = &cpoptions
set cpoptions&vim
" }}}



function! s:_OnEvent( chan_id, data, event ) abort
  " In neovim, the data argument is a list.
  if a:event ==# 'stdout'
    py3 _vimspector_session.OnChannelData( '\n'.join( vim.eval( 'a:data' ) ) )
  elseif a:event ==# 'stderr'
    py3 _vimspector_session.OnServerStderr( '\n'.join( vim.eval( 'a:data' ) ) )
  elseif a:event ==# 'exit'
    echom 'Channel exit with status ' . a:data
    redraw
    unlet s:job
    py3 _vimspector_session.OnServerExit( vim.eval( 'a:data' ) )
  endif
endfunction

function! vimspector#internal#neojob#StartDebugSession( config ) abort
  if exists( 's:job' )
    echom 'Not starging: Job is already running'
    redraw
    return v:false
  endif

  let s:job = jobstart( a:config[ 'command' ],
        \                {
        \                    'on_stdout': funcref( 's:_OnEvent' ),
        \                    'on_stderr': funcref( 's:_OnEvent' ),
        \                    'on_exit': funcref( 's:_OnEvent' ),
        \                    'cwd': a:config[ 'cwd' ],
        \                }
        \              )

  " FIXME: Missing in neovim 0.4. But in master:
  "      \                    'env': a:config[ 'env' ],
  "

  " FIXME: error handling ?
  return v:true
endfunction

function! s:JobIsRunning( job ) abort
  return jobwait( [ s:job ], 0 )[ 0 ] == -1
endfunction

function! vimspector#internal#neojob#Send( msg ) abort
  if ! exists( 's:job' )
    echom "Can't send message: Job was not initialised correctly"
    redraw
    return 0
  endif

  if !s:JobIsRunning( s:job )
    echom "Can't send message: Job is not running"
    redraw
    return 0
  endif

  call chansend( s:job, a:msg )
  return 1
endfunction

function! vimspector#internal#neojob#StopDebugSession() abort
  if !exists( 's:job' )
    echom "Not stopping session: Job doesn't exist"
    redraw
    return
  endif

  if s:JobIsRunning( s:job )
      echom 'Terminating job'
      redraw
    call jobstop( s:job )
  endif
endfunction

function! vimspector#internal#neojob#Reset() abort
  call vimspector#internal#neojob#StopDebugSession()
endfunction

function! s:_OnCommandEvent( category, id, data, event ) abort
  if a:data == ['']
    return
  endif

  if a:event ==# 'stdout'
    let buffer = s:commands[ a:category ][ a:id ].stdout
  elseif a:event ==# 'stderr'
    let buffer = s:commands[ a:category ][ a:id ].stderr
  endif

  call bufload( buffer )

  let last_line_list = getbufline( buffer, '$' )

  if len( last_line_list ) == 0
    let last_line = ''
  else
    let last_line = last_line_list[ 0 ]
  endif


  call s:MakeBufferWritable( buffer )
  try
    call setbufline( buffer, '$', last_line . a:data[ 0 ] )
    call appendbufline( buffer, '$', a:data[ 1: ] )
  finally
    call s:MakeBufferReadOnly( buffer )
    call setbufvar( buffer, '&modified', 0 )
  endtry

endfunction

function! s:SetUpHiddenBuffer( buffer ) abort
  call setbufvar( a:buffer, '&hidden', 1 )
  call setbufvar( a:buffer, '&bufhidden', 'hide' )
  call s:MakeBufferReadOnly( a:buffer )
endfunction

function! s:MakeBufferReadOnly( buffer ) abort
  call setbufvar( a:buffer, '&modifiable', 0 )
  call setbufvar( a:buffer, '&readonly', 1 )
endfunction

function! s:MakeBufferWritable( buffer ) abort
  call setbufvar( a:buffer, '&readonly', 0 )
  call setbufvar( a:buffer, '&modifiable', 1 )
endfunction


let s:commands = {}

function! vimspector#internal#neojob#StartCommandWithLog( cmd, category ) abort
  if ! has_key( s:commands, a:category )
    let s:commands[ a:category ] = {}
  endif

  let stdout_buf = bufnr( '_vimspector_log_' . a:category . '_out', v:true )
  let stderr_buf = bufnr( '_vimspector_log_' . a:category . '_err', v:true )

  " FIXME: This largely duplicates the same stuff in the python layer, but we
  " don't want to potentially mess up Vim behaviour where the job output is
  " attached to a buffer set up by Vim. So we sort o mimic that here.
  call s:SetUpHiddenBuffer( stdout_buf )
  call s:SetUpHiddenBuffer( stderr_buf )

  let id = jobstart(a:cmd,
        \          {
        \            'on_stdout': funcref( 's:_OnCommandEvent',
        \                                  [ a:category ] ),
        \            'on_stderr': funcref( 's:_OnCommandEvent',
        \                                  [ a:category ] )
        \          } )

  let s:commands[ a:category ][ id ] = {
        \ 'stdout': stdout_buf,
        \ 'stderr': stderr_buf
        \ }

  return [ stdout_buf, stderr_buf ]
endfunction

function! vimspector#internal#neojob#CleanUpCommand( category ) abort
  if ! has_key( s:commands, a:category )
    return
  endif

  for id in keys( s:commands[ a:category ] )
    call jobstop( id )
    call jobwait( id )
  endfor
  unlet! s:commands[ a:category ]
endfunction

" Boilerplate {{{
let &cpoptions=s:save_cpo
unlet s:save_cpo
" }}}
