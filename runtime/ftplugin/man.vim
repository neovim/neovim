" Vim filetype plugin file
" Language:	man
" Maintainer:	SungHyun Nam <goweol@gmail.com>

if has('vim_starting') && &filetype !=# 'man'
  finish
endif

" Only do this when not done yet for this buffer
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Ensure Vim is not recursively invoked (man-db does this)
" when doing ctrl-[ on a man page reference.
if exists('$MANPAGER')
  let $MANPAGER = ''
endif

setlocal iskeyword+=\.,-,(,)

setlocal buftype=nofile noswapfile
setlocal nomodifiable readonly bufhidden=hide nobuflisted tabstop=8

if !exists("g:no_plugin_maps") && !exists("g:no_man_maps")
  nnoremap <silent> <buffer> <C-]>    :call man#get_page(v:count, expand('<cword>'))<CR>
  nnoremap <silent> <buffer> <C-T>    :call man#pop_page()<CR>
  nnoremap <silent> <nowait><buffer>  q <C-W>c
  if &keywordprg !=# ':Man'
    nnoremap <silent> <buffer> K      :call man#get_page(v:count, expand('<cword>'))<CR>
  endif
endif

if exists('g:ft_man_folding_enable') && (g:ft_man_folding_enable == 1)
  setlocal foldmethod=indent foldnestmax=1 foldenable
endif

let b:undo_ftplugin = 'setlocal iskeyword<'

" vim: set sw=2:
