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

" Compiler plugin to help running vimspector tests

if exists("current_compiler")
  finish
endif
let current_compiler = "vimspector_test"

setlocal errorformat=
        \Found\ errors\ in\ %f:%.%#:

let s:run_tests = findfile( 'run_tests', '.;' )
let s:root_dir = fnamemodify( s:run_tests, ':h' )
let &l:makeprg=fnamemodify( s:run_tests, ':p' ) . ' $* 2>&1'

let s:make_cmd = get( g:, 'vimspector_test_make_cmd', 'Make' )

" If :Make doesn't exist, then use :make
if ! exists( ':' . s:make_cmd )
  let s:make_cmd = 'make'
endif

function! VimGetCurrentFunction()
  echom s:GetCurrentFunction()
endfunction

function! s:GetCurrentFunction()
  " Store the cursor position; we'll need to reset it
  let [ l:buf, l:row, l:col, l:offset ] = getpos( '.' )

  let l:test_function = ''

  let l:pattern = '\V\C\s\*function!\?\s\+\(\<\w\+\>\)\.\*\$'

  let l:lnum = prevnonblank( '.' )

  " Find the top-level method and class
  while l:lnum > 0
    call cursor( l:lnum, 1 )
    let l:lnum = search( l:pattern, 'bcnWz' )

    if l:lnum <= 0
      call cursor( l:row, l:col )
      return l:test_function
    endif

    let l:this_decl = substitute( getline( l:lnum ), l:pattern, '\1', '' )
    let l:this_decl_is_test = match( l:this_decl, '\V\C\^Test_' ) >= 0

    if l:this_decl_is_test
      let l:test_function = l:this_decl

      if indent( l:lnum ) == 0
        call cursor( l:row, l:col )
        return l:test_function
      endif
    endif

    let l:lnum = prevnonblank( l:lnum - 1 )
  endwhile

endfunction

function! s:RunTestUnderCursor()
  update
  let l:test_func_name = s:GetCurrentFunction()

  if l:test_func_name ==# ''
    echo "No test method found"
    return
  endif

  echo "Running test '" . l:test_func_name . "'"

  let l:test_arg = expand( '%:p:t' ) . ':' . l:test_func_name
  let l:cwd = getcwd()
  execute 'lcd ' . s:root_dir
  try
    execute s:make_cmd . ' ' . l:test_arg
  finally
    execute 'lcd ' . l:cwd
  endtry
endfunction

function! s:RunTest()
  update
  let l:cwd = getcwd()
  execute 'lcd ' . s:root_dir
  try
    execute s:make_cmd . ' %:p:t'
  finally
    execute 'lcd ' . l:cwd
  endtry
endfunction

function! s:RunAllTests()
  update
  let l:cwd = getcwd()
  execute 'lcd ' . s:root_dir
  try
    execute s:make_cmd
  finally
    execute 'lcd ' . l:cwd
  endtry
endfunction

if ! has( 'gui_running' )
  " ® is right-option+r
  nnoremap <buffer> ® :call <SID>RunTest()<CR>
  " ® is right-option+r
  nnoremap <buffer> Â :call <SID>RunAllTests()<CR>
  " † is right-option+t
  nnoremap <buffer> † :call <SID>RunTestUnderCursor()<CR>
  " å is the right-option+q
  nnoremap <buffer> å :cfirst<CR>
  " å is the right-option+a
  nnoremap <buffer> œ :cnext<CR>
  " Ω is the right-option+z
  nnoremap <buffer> Ω :cprevious<CR>
endif
