" Maintainer:          Anmol Sethi <anmol@aubble.com>
" Previous Maintainer: SungHyun Nam <goweol@gmail.com>

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:pager = !exists('b:man_sect')

if s:pager
  call man#init_pager()
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
