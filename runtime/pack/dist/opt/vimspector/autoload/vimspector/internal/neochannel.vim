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
  if a:data == ['']
    echom 'Channel closed'
    redraw
    unlet s:ch
    py3 _vimspector_session.OnServerExit( 0 )
  else
    py3 _vimspector_session.OnChannelData( '\n'.join( vim.eval( 'a:data' ) ) )
  endif
endfunction

function! vimspector#internal#neochannel#StartDebugSession( config ) abort
  if exists( 's:ch' )
    echom 'Not starging: Channel is already running'
    redraw
    return v:false
  endif

  let addr = 'localhost:' . a:config[ 'port' ]

  let s:ch = sockconnect( 'tcp', addr, { 'on_data': funcref( 's:_OnEvent' ) } )
  if s:ch <= 0
    unlet s:ch
    return v:false
  endif

  return v:true
endfunction

function! vimspector#internal#neochannel#Send( msg ) abort
  if ! exists( 's:ch' )
    echom "Can't send message: Channel was not initialised correctly"
    redraw
    return 0
  endif

  call chansend( s:ch, a:msg )
  return 1
endfunction

function! vimspector#internal#neochannel#StopDebugSession() abort
  if !exists( 's:ch' )
    echom "Not stopping session: Channel doesn't exist"
    redraw
    return
  endif

  call chanclose( s:ch )
  " It doesn't look like we get a callback after chanclos. Who knows if we will
  " subsequently receive data callbacks.
  call s:_OnEvent( s:ch, [ '' ], 'data' )
endfunction

function! vimspector#internal#neochannel#Reset() abort
  call vimspector#internal#neochannel#StopDebugSession()
endfunction

" Boilerplate {{{
let &cpoptions=s:save_cpo
unlet s:save_cpo
" }}}

