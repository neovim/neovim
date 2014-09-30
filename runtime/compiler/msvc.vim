" Vim compiler file
" Compiler:	Miscrosoft Visual C
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2005 Nov 30

if exists("current_compiler")
  finish
endif
let current_compiler = "msvc"

" The errorformat for MSVC is the default.
CompilerSet errorformat&
CompilerSet makeprg=nmake
