" Vim filetype plugin file
" Language:     Ch
" Maintainer:   SoftIntegration, Inc. <info@softintegration.com>
" URL:		http://www.softintegration.com/download/vim/ftplugin/ch.vim
" Last change:	2004 May 16
"		Created based on cpp.vim
"
" Ch is a C/C++ interpreter with many high level extensions
"

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Behaves just like C
runtime! ftplugin/c.vim ftplugin/c_*.vim ftplugin/c/*.vim
