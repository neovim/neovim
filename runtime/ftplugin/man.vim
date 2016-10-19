" Maintainer:          Anmol Sethi <anmol@aubble.com>
" Previous Maintainer: SungHyun Nam <goweol@gmail.com>

if exists('b:did_ftplugin') || &filetype !=# 'man'
  finish
endif
let b:did_ftplugin = 1

let s:pager = 0

if has('vim_starting')
  let s:pager = 1
  " remove all those backspaces
  silent execute 'keeppatterns keepjumps %substitute,.\b,,e'.(&gdefault?'':'g')
  if getline(1) =~# '^\s*$'
    silent keepjumps 1delete _
  else
    keepjumps 1
  endif
  " This is not perfect. See `man glDrawArraysInstanced`. Since the title is
  " all caps it is impossible to tell what the original capitilization was.
  let ref = tolower(matchstr(getline(1), '^\S\+'))
  let b:man_sect = man#extract_sect_and_name_ref(ref)[0]
  execute 'silent file man://'.ref
endif

setlocal buftype=nofile
setlocal noswapfile
setlocal bufhidden=hide
setlocal nomodified
setlocal readonly
setlocal nomodifiable
setlocal noexpandtab
setlocal tabstop=8
setlocal softtabstop=8
setlocal shiftwidth=8

setlocal nonumber
setlocal norelativenumber
setlocal foldcolumn=0
setlocal colorcolumn=0
setlocal nolist
setlocal nofoldenable

if !exists('g:no_plugin_maps') && !exists('g:no_man_maps')
  nmap     <silent> <buffer> <C-]>      :Man<CR>
  nmap     <silent> <buffer> K          :Man<CR>
  nnoremap <silent> <buffer> <C-T>      :call man#pop_tag()<CR>
  if s:pager
    nnoremap <silent> <buffer> <nowait> q :q<CR>
  else
    nnoremap <silent> <buffer> <nowait> q <C-W>c
  endif
endif

if get(g:, 'ft_man_folding_enable', 0)
  setlocal foldenable
  setlocal foldmethod=indent
  setlocal foldnestmax=1
endif

let b:undo_ftplugin = ''
" vim: set sw=2:
