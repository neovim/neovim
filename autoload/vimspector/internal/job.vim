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
let s:command = [
      \   'node',
      \   '/Users/ben/.vscode/extensions/webfreak.debug-0.22.0/out/src/lldb.js'
      \ ]

" let s:command = [
"       \ '/Users/ben/.vscode/extensions/ms-vscode.cpptools-0.17.1/'
"       \ 'debugAdapters/OpenDebugAD7'
"       \ ]
"
"      \ 'node',
"      \ '/Users/ben/Development/debugger/vscode-mock-debug/out/debugAdapter.js'
"      \ ]


function! s:_OnServerData( channel, data ) abort
  py3 << EOF
_vimspector_session.OnChannelData( vim.eval( 'a:data' ) )
EOF
endfunction

function! s:_OnServerError( channel, data ) abort
  echom "Channel received error: " . a:data
endfunction

function! s:_OnExit( channel, status ) abort
  echom "Channel exit with status " . a:status
endfunction

function! s:_OnClose( channel ) abort
  echom "Channel closed"
endfunction

function! s:_Send( msg ) abort
  if job_status( s:job ) != 'run'
    echom "Server isnt running"
    return
  endif

  let ch = job_getchannel( s:job )
  if ch == 'channel fail'
    echom "Channel was closed unexpectedly!"
    return
  endif

  call ch_sendraw( ch, a:msg )
endfunction

function! vimspector#internal#job#StartDebugSession( config ) abort
  if exists( 's:job' )
    echo "Job is already running"
    return v:none
  endif

  let s:job = job_start( a:config[ 'command' ],
        \                {
        \                    'in_mode': 'raw',
        \                    'out_mode': 'raw',
        \                    'err_mode': 'raw',
        \                    'exit_cb': function( 's:_OnExit' ),
        \                    'close_cb': function( 's:_OnClose' ),
        \                    'out_cb': function( 's:_OnServerData' ),
        \                    'err_cb': function( 's:_OnServerError' )
        \                }
        \              )

  if job_status( s:job ) != 'run'
    echom 'Fail whale. Job is ' . job_status( s:job )
    return v:none
  endif

  return funcref( 's:_Send' )
endfunction

function! vimspector#internal#job#StopDebugSession() abort
  py3 _vimspector_session.Stop()

  if job_status( s:job ) == 'run'
    job_stop( s:job, 'term' )
  endif

  unlet s:job
endfunction

" Boilerplate {{{
let &cpo=s:save_cpo
unlet s:save_cpo
" }}}
