" Vim filetype plugin file
" Language:	BTM
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Behaves just like dosbatch
runtime! ftplugin/dosbatch.vim ftplugin/dosbatch_*.vim ftplugin/dosbatch/*.vim
