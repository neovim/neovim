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

" Ids are unique throughtout the life of neovim, but obviously buffer numbers
" aren't
"
" FIXME: Tidy this map when buffers are closed ?
let s:buffer_to_id = {}

function! vimspector#internal#neoterm#Start( cmd, opts ) abort
  if ! get( a:opts, 'curwin', 0 )
    if get( a:opts, 'vertical', 0 )
      vsplit
    else
      split
    endif
  endif

  " FIXME: 'env' doesn't work
  let id = termopen( a:cmd, { 'cwd': a:opts[ 'cwd' ] } )
  let bufnr = bufnr()
  let s:buffer_to_id[ bufnr ] = id
  return bufnr
endfunction

function! s:JobIsRunning( job ) abort
  return jobwait( [ a:job ], 0 )[ 0 ] == -1
endfunction

function! vimspector#internal#neoterm#IsFinished( bufno ) abort
  if !has_key( s:buffer_to_id, a:bufno )
    return v:true
  endif

  return !s:JobIsRunning( s:buffer_to_id[ a:bufno ] )
endfunction

function! vimspector#internal#neoterm#GetPID( bufno ) abort
  if !has_key( s:buffer_to_id, a:bufno )
    return -1
  endif

  return jobpid( s:buffer_to_id[ a:bufno ] )
endfunction

" Boilerplate {{{
let &cpoptions=s:save_cpo
unlet s:save_cpo
" }}}
