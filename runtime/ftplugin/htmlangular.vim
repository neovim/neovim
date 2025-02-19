" Vim filetype plugin file
" Language: Angular HTML Template
" Maintainer: Dennis van den Berg <dennis@vdberg.dev>
" Last Change: 2024 Jul 9

" Only use this filetype plugin when no other was loaded.
if exists("b:did_ftplugin")
  finish
endif

" source the HTML ftplugin
runtime! ftplugin/html.vim
