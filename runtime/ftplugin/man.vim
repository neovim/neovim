" Maintainer:          Anmol Sethi <hi@nhooyr.io>
" Previous Maintainer: SungHyun Nam <goweol@gmail.com>

if exists('b:did_ftplugin') || &filetype !=# 'man'
  finish
endif
let b:did_ftplugin = 1

setlocal noexpandtab tabstop=8 softtabstop=8 shiftwidth=8
setlocal wrap breakindent linebreak

" Parentheses and '-' for references like `git-ls-files(1)`; '@' for systemd
" pages; ':' for Perl and C++ pages.  Here, I intentionally omit the locale
" specific characters matched by `@`.
setlocal iskeyword=@-@,:,a-z,A-Z,48-57,_,.,-,(,)

setlocal nonumber norelativenumber
setlocal foldcolumn=0 colorcolumn=0 nolist nofoldenable

setlocal tagfunc=v:lua.require'man'.goto_tag

if !exists('g:no_plugin_maps') && !exists('g:no_man_maps')
  nnoremap <silent> <buffer> j             gj
  nnoremap <silent> <buffer> k             gk
  nnoremap <silent> <buffer> gO            :lua require'man'.show_toc()<CR>
  nnoremap <silent> <buffer> <2-LeftMouse> :Man<CR>
  if get(b:, 'pager')
    nnoremap <silent> <buffer> <nowait> q :lclose<CR><C-W>q
  else
    nnoremap <silent> <buffer> <nowait> q :lclose<CR><C-W>c
  endif
endif

if get(g:, 'ft_man_folding_enable', 0)
  setlocal foldenable
  setlocal foldmethod=indent
  setlocal foldnestmax=1
endif

let b:undo_ftplugin = ''
" vim: set sw=2:
