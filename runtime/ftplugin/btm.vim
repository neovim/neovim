" Vim filetype plugin file
" Language:	BTM
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2004 Jul 06

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Behaves just like dosbatch
runtime! ftplugin/dosbatch.vim ftplugin/dosbatch_*.vim ftplugin/dosbatch/*.vim
