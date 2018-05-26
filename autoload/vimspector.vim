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

  py3 << EOF
from vimspector import debug_session
_vimspector_session = debug_session.DebugSession()
EOF

" TODO: Test function
function! vimspector#Launch() abort
  py3 _vimspector_session.Start()
endfunction

function! vimspector#Restart() abort
  py3 _vimspector_session.Restart()
endfunction

function! vimspector#ToggleBreakpoint() abort
  py3 _vimspector_session.ToggleBreakpoint()
endfunction

function! vimspector#StepOver() abort
  py3 _vimspector_session.StepOver()
endfunction

function! vimspector#StepInto() abort
  py3 _vimspector_session.StepInto()
endfunction

function! vimspector#StepOut() abort
  py3 _vimspector_session.StepOut()
endfunction

function! vimspector#Continue() abort
  py3 _vimspector_session.Continue()
endfunction

function! vimspector#Pause() abort
  py3 _vimspector_session.Pause()
endfunction

function! vimspector#Stop() abort
  py3 _vimspector_session.Stop()
endfunction

function! vimspector#ExpandVariable() abort
  py3 _vimspector_session.ExpandVariable()
endfunction

function! vimspector#GoToFrame() abort
  py3 _vimspector_session.GoToFrame()
endfunction

" Boilerplate {{{
let &cpo=s:save_cpo
unlet s:save_cpo
" }}}
