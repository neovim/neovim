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

function! vimspector#internal#term#Start( cmd, opts ) abort
  return term_start( a:cmd, a:opts )
endfunction

function! vimspector#internal#term#IsFinished( bufno ) abort
  return index( split( term_getstatus( a:bufno ), ',' ), 'finished' ) >= 0
endfunction

function! vimspector#internal#term#GetPID( bufno ) abort
  return job_info( term_getjob( a:bufno ) ).process
endfunction

" Boilerplate {{{
let &cpoptions=s:save_cpo
unlet s:save_cpo
" }}}
