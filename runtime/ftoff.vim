" Vim support file to switch off detection of file types
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2001 Jun 11

if exists("did_load_filetypes")
  unlet did_load_filetypes
endif

" Remove all autocommands in the filetypedetect group
silent! au! filetypedetect *
