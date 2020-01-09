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

function! s:restore_cpo()
  let &cpoptions=s:save_cpo
  unlet s:save_cpo
endfunction

if exists( 'g:loaded_vimpector' )
  call s:restore_cpo()
  finish
endif
"}}}

" TODO:
"   - Check Vim version (for jobs)
"   - Check python support
"   - Add commands/mappings/menus?

let g:loaded_vimpector = 1

let s:mappings = get( g:, 'vimspector_enable_mappings', '' )

nnoremap <Plug>VimspectorContinue       :<c-u>call vimspector#Continue()<CR>
nnoremap <Plug>VimspectorStop           :<c-u>call vimspector#Stop()<CR>
nnoremap <Plug>VimspectorRestart        :<c-u>call vimspector#Restart()<CR>
nnoremap <Plug>VimspectorPause          :<c-u>call vimspector#Pause()<CR>
nnoremap <Plug>VimspectorToggleBreakpoint
      \ :<c-u>call vimspector#ToggleBreakpoint()<CR>
nnoremap <Plug>VimspectorAddFunctionBreakpoint
      \ :<c-u>call vimspector#AddFunctionBreakpoint( expand( '<cexpr>' ) )<CR>
nnoremap <Plug>VimspectorStopOver       :<c-u>call vimspector#StepOver()<CR>
nnoremap <Plug>VimspectorStepInto       :<c-u>call vimspector#StepInto()<CR>
nnoremap <Plug>VimspectorStepOut        :<c-u>call vimspector#StepOut()<CR>

if s:mappings ==# 'VISUAL_STUDIO'
  nmap <F5>         <Plug>VimspectorContinue
  nmap <S-F5>       <Plug>VimspectorStop
  nmap <C-S-F5>     <Plug>VimspectorRestart
  nmap <F6>         <Plug>VimspectorPause
  nmap <F9>         <Plug>VimspectorToggleBreakpoint
  nmap <S-F9>       <Plug>VimspectorAddFunctionBreakpoint
  nmap <F10>        <Plug>VimspectorStepOver
  nmap <F11>        <Plug>VimspectorStepInto
  nmap <S-F11>      <Plug>VimspectorStepOut
elseif s:mappings ==# 'HUMAN'
  nmap <F5>         <Plug>VimspectorContinue
  nmap <F3>         <Plug>VimspectorStop
  nmap <F4>         <Plug>VimspectorRestart
  nmap <F6>         <Plug>VimspectorPause
  nmap <F9>         <Plug>VimspectorToggleBreakpoint
  nmap <F8>         <Plug>VimspectorAddFunctionBreakpoint
  nmap <F10>        <Plug>VimspectorStepOver
  nmap <F11>        <Plug>VimspectorStepInto
  nmap <F12>        <Plug>VimspectorStepOut
endif

command! -bar -nargs=1 -complete=customlist,vimspector#CompleteExpr
      \ VimspectorWatch
      \ call vimspector#AddWatch( <f-args> )
command! -bar -nargs=1 -complete=customlist,vimspector#CompleteOutput
      \ VimspectorShowOutput
      \ call vimspector#ShowOutput( <f-args> )
command! -bar -nargs=1 -complete=customlist,vimspector#CompleteExpr
      \ VimspectorEval
      \ call vimspector#Evaluate( <f-args> )
command! -bar
      \ VimspectorReset
      \ call vimspector#Reset()

" boilerplate {{{
call s:restore_cpo()
" }}}

