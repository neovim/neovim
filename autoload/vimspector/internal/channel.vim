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
  py3 << EOF
_vimspector_session.OnChannelData( vim.eval( 'a:data' ) )
EOF
endfunction

function! s:_OnClose( channel ) abort
  echom 'Channel closed'
  redraw
  unlet s:ch
  py3 _vimspector_session.OnServerExit( 0 )
endfunction

function! vimspector#internal#channel#StartDebugSession( config ) abort

  if exists( 's:ch' )
    echo 'Channel is already running'
    return v:false
  endif

  let l:addr = 'localhost:' . a:config[ 'port' ]

  echo 'Connecting to ' . l:addr . '... (waiting fo up to 10 seconds)'
  let s:ch = ch_open( l:addr,
        \             {
        \                 'mode': 'raw',
        \                 'callback': funcref( 's:_OnServerData' ),
        \                 'close_cb': funcref( 's:_OnClose' ),
        \                 'waittime': 10000,
        \             }
        \           )

  if ch_status( s:ch ) !=# 'open'
    echom 'Unable to connect to debug adapter'
    redraw
    return v:false
  endif

  return v:true
endfunction

function! vimspector#internal#channel#Send( msg ) abort
  call ch_sendraw( s:ch, a:msg )
  return 1
endfunction

function! vimspector#internal#channel#Timeout( id ) abort
  py3 << EOF
_vimspector_session.OnRequestTimeout( vim.eval( 'a:id' ) )
EOF
endfunction

function! vimspector#internal#channel#StopDebugSession() abort
  if !exists( 's:ch' )
    return
  endif

  if ch_status( s:ch ) ==# 'open'
    " channel is open, close it and trigger the callback. The callback is _not_
    " triggered when manually calling ch_close. if we get here and the channel
    " is not open, then we there is a _OnClose callback waiting for us, so do
    " nothing.
    call ch_close( s:ch )
    call s:_OnClose( s:ch )
  endif
endfunction

function! vimspector#internal#channel#Reset() abort
  if exists( 's:ch' )
    call vimspector#internal#channel#StopDebugSession()
  endif
endfunction

" Boilerplate {{{
let &cpoptions=s:save_cpo
unlet s:save_cpo
" }}}

