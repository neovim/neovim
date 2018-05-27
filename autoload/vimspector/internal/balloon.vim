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

function vimspector#internal#balloon#BalloonExpr()
  " winnr + 1 because for *no good reason* winnr is 0 based here unlike
  " everywhere else
  " int() because for *no good reason* winnr is a string.
  py3 _vimspector_session.ShowBalloon( int( vim.eval( 'v:beval_winnr' ) ) + 1,
        \ vim.eval( 'v:beval_text' ) )
  return ''
endfunction

" Boilerplate {{{
let &cpo=s:save_cpo
unlet s:save_cpo
" }}}
