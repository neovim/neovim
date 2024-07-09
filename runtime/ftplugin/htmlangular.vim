" Vim filetype plugin file
" Language: Angular HTML Template
" Maintainer: Dennis van den Berg <dennis@vdberg.dev>
" Last Change: 2024 Jul 8

" Only use this filetype plugin when no other was loaded.
if exists("b:did_ftplugin")
  finish
endif

" Use HTML and Angular template ftplugins
runtime! ftplugin/html.vim
