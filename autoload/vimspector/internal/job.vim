" vimspector - A multi-language debugging system for Vim
" Copyright 2018 Ben Jackson
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

function! s:_OnServerData( channel, data ) abort
  py3 _vimspector_session.OnChannelData( vim.eval( 'a:data' ) )
endfunction

function! s:_OnServerError( channel, data ) abort
  py3 _vimspector_session.OnServerStderr( vim.eval( 'a:data' ) )
endfunction

function! s:_OnExit( channel, status ) abort
  echom 'Channel exit with status ' . a:status
  redraw
  unlet s:job
  py3 _vimspector_session.OnServerExit( vim.eval( 'a:status' ) )
endfunction

function! s:_OnClose( channel ) abort
  echom 'Channel closed'
  redraw
endfunction

function! vimspector#internal#job#StartDebugSession( config ) abort
  if exists( 's:job' )
    echom 'Not starging: Job is already running'
    redraw
    return v:false
  endif

  let s:job = job_start( a:config[ 'command' ],
        \                {
        \                    'in_mode': 'raw',
        \                    'out_mode': 'raw',
        \                    'err_mode': 'raw',
        \                    'exit_cb': funcref( 's:_OnExit' ),
        \                    'close_cb': funcref( 's:_OnClose' ),
        \                    'out_cb': funcref( 's:_OnServerData' ),
        \                    'err_cb': funcref( 's:_OnServerError' ),
        \                    'stoponexit': 'term',
        \                    'env': a:config[ 'env' ],
        \                    'cwd': a:config[ 'cwd' ],
        \                }
        \              )

  echom 'Started job, status is: ' . job_status( s:job )
  redraw

  if job_status( s:job ) !=# 'run'
    echom 'Unable to start job, status is: ' . job_status( s:job )
    redraw
    return v:false
  endif

  return v:true
endfunction

function! vimspector#internal#job#Send( msg ) abort
  if ! exists( 's:job' )
    echom "Can't send message: Job was not initialised correctly"
    redraw
    return 0
  endif

  if job_status( s:job ) !=# 'run'
    echom "Can't send message: Job is not running"
    redraw
    return 0
  endif

  let ch = job_getchannel( s:job )
  if ch ==# 'channel fail'
    echom 'Channel was closed unexpectedly!'
    redraw
    return 0
  endif

  call ch_sendraw( ch, a:msg )
  return 1
endfunction

function! vimspector#internal#job#StopDebugSession() abort
  if !exists( 's:job' )
    echom "Not stopping session: Job doesn't exist"
    redraw
    return
  endif

  if job_status( s:job ) ==# 'run'
      echom 'Terminating job'
      redraw
    call job_stop( s:job, 'kill' )
  endif
endfunction

function! vimspector#internal#job#Reset() abort
  call vimspector#internal#job#StopDebugSession()
endfunction

function! vimspector#internal#job#StartCommandWithLog( cmd, category ) abort
  if ! exists( 's:commands' )
    let s:commands = {}
  endif

  if ! has_key( s:commands, a:category )
    let s:commands[ a:category ] = []
  endif

  let l:index = len( s:commands[ a:category ] )

  call add( s:commands[ a:category ], job_start(
        \ a:cmd,
        \ {
        \   'out_io': 'buffer',
        \   'in_io': 'null',
        \   'err_io': 'buffer',
        \   'out_name': '_vimspector_log_' . a:category . '_out',
        \   'err_name': '_vimspector_log_' . a:category . '_err',
        \   'out_modifiable': 0,
        \   'err_modifiable': 0,
        \   'stoponexit': 'kill'
        \ } ) )

  if job_status( s:commands[ a:category ][ index ] ) !=# 'run'
    echom 'Unable to start job for ' . a:cmd
    redraw
    return v:none
  endif

  let l:stdout = ch_getbufnr(
        \ job_getchannel( s:commands[ a:category ][ index ] ), 'out' )
  let l:stderr = ch_getbufnr(
        \ job_getchannel( s:commands[ a:category ][ index ] ), 'err' )

  return [ l:stdout, l:stderr ]
endfunction


function! vimspector#internal#job#CleanUpCommand( category ) abort
  if ! exists( 's:commands' )
    let s:commands = {}
  endif

  if ! has_key( s:commands, a:category )
    return
  endif
  for j in s:commands[ a:category ]
    call job_stop( j, 'kill' )
  endfor

  unlet s:commands[ a:category ]
endfunction

" Boilerplate {{{
let &cpoptions=s:save_cpo
unlet s:save_cpo
" }}}
