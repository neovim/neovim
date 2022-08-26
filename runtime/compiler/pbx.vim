" Vim compiler file
" Compiler:	Apple Project Builder
" Maintainer:	Alexander von Below (public@vonBelow.Com)
" Last Change:	2004 Mar 27

if exists("current_compiler")
   finish
endif
let current_compiler = "pbx"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

" The compiler actually is gcc, so the errorformat is unchanged
CompilerSet errorformat&

" default make
CompilerSet makeprg=pbxbuild

