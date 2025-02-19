" Vim support file to switch off loading indent files for file types
"
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

if exists("did_indent_on")
  unlet did_indent_on
endif

" Remove all autocommands in the filetypeindent group
silent! au! filetypeindent *
