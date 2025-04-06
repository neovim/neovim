" Vim support file to switch off detection of file types
"
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

if exists("did_load_filetypes")
  unlet did_load_filetypes
endif

" Remove all autocommands in the filetypedetect group
silent! au! filetypedetect *
