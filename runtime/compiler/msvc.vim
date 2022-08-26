" Vim compiler file
" Compiler:	Microsoft Visual C
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2014 Sep 20

if exists("current_compiler")
  finish
endif
let current_compiler = "msvc"

" The errorformat for MSVC is the default.
CompilerSet errorformat&
CompilerSet makeprg=nmake
