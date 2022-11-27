" Vim filetype plugin file
" Language:    Oblivion Language (obl)
" Original Creator: Kat <katisntgood@gmail.com>
" Maintainer:  Kat <katisntgood@gmail.com>
" Created:     August 08, 2021
" Last Change: 13 November 2022

if exists("b:did_ftplugin")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms<"

noremap <script> <buffer> <silent> [[ <nop>
noremap <script> <buffer> <silent> ]] <nop>

noremap <script> <buffer> <silent> [] <nop>
noremap <script> <buffer> <silent> ][ <nop>

setlocal commentstring=;%s
setlocal comments=:;

function s:NextSection(type, backwards, visual)
    if a:visual
        normal! gv
    endif

  if a:type == 1
    let pattern = '\v(\n\n^\S|%^)'
    let flags = 'e'
  elseif a:type == 2
    let pattern = '\v^\S.*'
    let flags = ''
  endif

  if a:backwards
    let dir = '?'
  else
    let dir = '/'
  endif

  execute 'silent normal! ' . dir . pattern . dir . flags . "\r"
endfunction

noremap <script> <buffer> <silent> ]]
  \ :call <SID>NextSection(1, 0, 0)<cr>

noremap <script> <buffer> <silent> [[
  \ :call <SID>NextSection(1, 1, 0)<cr>

noremap <script> <buffer> <silent> ][
  \ :call <SID>NextSection(2, 0, 0)<cr>

noremap <script> <buffer> <silent> []
  \ :call <SID>NextSection(2, 1, 0)<cr>

vnoremap <script> <buffer> <silent> ]]
  \ :<c-u>call <SID>NextSection(1, 0, 1)<cr>
vnoremap <script> <buffer> <silent> [[
  \ :<c-u>call <SID>NextSection(1, 1, 1)<cr>
vnoremap <script> <buffer> <silent> ][
  \ :<c-u>call <SID>NextSection(2, 0, 1)<cr>
vnoremap <script> <buffer> <silent> []
  \ :<c-u>call <SID>NextSection(2, 1, 1)<cr>

let &cpo = s:cpo_save
unlet s:cpo_save
