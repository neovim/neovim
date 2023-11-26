" Vim filetype plugin
" Language:	SCSS
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2016 Aug 29

if exists("b:did_ftplugin")
  finish
endif

runtime! ftplugin/sass.vim
setlocal comments=s1:/*,mb:*,ex:*/,://

" vim:set sw=2:
