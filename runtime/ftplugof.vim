" Vim support file to switch off loading plugins for file types
"
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

if exists("did_load_ftplugin")
  unlet did_load_ftplugin
endif

" Remove all autocommands in the filetypeplugin group, if any exist.
if exists("#filetypeplugin")
  silent! au! filetypeplugin *
endif
