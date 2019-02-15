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

function! s:restore_cpo()
  let &cpo=s:save_cpo
  unlet s:save_cpo
endfunction

if exists( "g:loaded_vimpector" )
  call s:restore_cpo()
  finish
endif

" TODO:
"   - Check Vim version (for jobs)
"   - Check python support
"   - Add commands/mappings/menus?

let g:loaded_vimpector = 1

let s:mappings = get( g:, 'vimspector_enable_mappings', '' )

if s:mappings == 'VISUAL_STUDIO'
  nnoremap <F5>         :call vimspector#Continue()<CR>
  nnoremap <S-F5>       :call vimspector#Stop()<CR>
  nnoremap <C-S-F5>     :call vimspector#Restart()<CR>
  nnoremap <F6>         :call vimspector#Pause()<CR>
  nnoremap <F9>         :call vimspector#ToggleBreakpoint()<CR>
  nnoremap <S-F9>       :call vimspector#AddFunctionBreakpoint( expand( '<cexpr>' ) )<CR>
  nnoremap <F10>        :call vimspector#StepOver()<CR>
  nnoremap <F11>        :call vimspector#StepInto()<CR>
  nnoremap <S-F11>      :call vimspector#StepOut()<CR>
elseif s:mappings == 'HUMAN'
  nnoremap <F5>         :call vimspector#Continue()<CR>
  nnoremap <F3>         :call vimspector#Stop()<CR>
  nnoremap <F4>         :call vimspector#Restart()<CR>
  nnoremap <F6>         :call vimspector#Pause()<CR>
  nnoremap <F9>         :call vimspector#ToggleBreakpoint()<CR>
  nnoremap <F8>         :call vimspector#AddFunctionBreakpoint( expand( '<cexpr>' ) )<CR>
  nnoremap <F10>        :call vimspector#StepOver()<CR>
  nnoremap <F11>        :call vimspector#StepInto()<CR>
  nnoremap <F12>        :call vimspector#StepOut()<CR>
endif
"}}}


call s:restore_cpo()
