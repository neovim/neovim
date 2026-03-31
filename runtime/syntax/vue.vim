" Vim syntax file
" Language:	Vue.js Single File Component
" Maintainer:	Ralph Giles <giles@thaumas.net>
" URL:		https://vuejs.org/v2/guide/single-file-components.html
" Last Change:	2019 Jul 8

" Quit if a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif

" We have a collection of html, css and javascript wrapped in
" tags. The default HTML syntax highlight works well enough.
runtime! syntax/html.vim
