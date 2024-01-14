" Vim compiler file
" Compiler:	Microsoft Visual C
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

if exists("current_compiler")
  finish
endif
let current_compiler = "msvc"

" The errorformat for MSVC is the default.
CompilerSet errorformat&
CompilerSet makeprg=nmake
