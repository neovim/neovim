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
let s:save_cpo = &cpo
set cpo&vim
" }}}

let s:plugin_base = expand( '<sfile>:p:h' ) . '/../'

function! s:_OnServerData( channel, data )
  echom 'Got data: ' . a:data
  py3 << EOF
_PyChannel.OnData( vim.eval( 'a:data' ) )
EOF
endfunction

function! s:_OnServerError( channel, data )
  echom "Channel received error: " . a:data
endfunction

function! s:_OnExit( channel, status )
  echom "Channel exit with status " . a:status
endfunction

function! s:_OnClose( channel )
  echom "Channel closed"
endfunction

function! vimspector#StartDebugSession()
  " TODO:
  "  - Work out the debug configuration (e.g. using RemoteDebug)
  "  - Start a job running the server in raw mode
  "  - Start up the python thread to communicate
  "  - Set up the UI:
  "    - Signs?
  "    - Console?
  "
  " For now, lets:
  "   - start up an echo process
  "   - get python talking to it
  if exists( 's:job' )
    echo "Job is already running"
    return
  endif

  let s:job = job_start( s:plugin_base . 'support/bin/testecho', {
        \ 'in_mode': 'raw',
        \ 'out_mode': 'raw',
        \ 'err_mode': 'raw',
        \ 'exit_cb': function( 's:_OnExit' ),
        \ 'close_cb': function( 's:_OnClose' ),
        \ 'out_cb': function( 's:_OnServerData' ),
        \ 'err_cb': function( 's:_OnServerError' ) } )

  if job_status( s:job ) != 'run'
    echom 'Fail whale. Job is ' . job_status( s:job )
    return
  endif
endfunction

function! s:_Send( msg )
  if job_status( s:job ) != 'run'
    echom "Server isnt running"
    return
  endif

  let ch = job_getchannel( s:job )
  if ch == 'channel fail'
    echom "Channel was closed unexpectedly!"
    return
  endif

  call ch_sendraw( ch, a:msg . "\n" )

endfunction


function! vimspector#StopDebugSession()
  if job_status( s:job ) == 'run'
    job_stop( s:job, 'term' )
  endif

  unlet s:job
endfunction

function! vimspector#Test()
  call vimspector#StartDebugSession()
  " call vimspector#WriteMessageToServer( 'test' )

  let ch = job_getchannel( s:job )

  py3 << EOF
from vimspector import channel
_PyChannel = channel.Channel( vim.Function( 's:_Send' ) )
_PyChannel.Write( 'Another Test' )
EOF

endfunction


" Boilerplate {{{ 
let &cpo=s:save_cpo
unlet s:save_cpo
