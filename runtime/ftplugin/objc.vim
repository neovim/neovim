" Vim filetype plugin file
" Language:	Objective C
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2003 Jan 15

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Behaves just like C
runtime! ftplugin/c.vim ftplugin/c_*.vim ftplugin/c/*.vim
