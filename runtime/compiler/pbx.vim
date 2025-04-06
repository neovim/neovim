" Vim compiler file
" Compiler:	Apple Project Builder
" Maintainer:	Alexander von Below (public@vonBelow.Com)
" Last Change:	2004 Mar 27
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
   finish
endif
let current_compiler = "pbx"

" The compiler actually is gcc, so the errorformat is unchanged
CompilerSet errorformat&

" default make
CompilerSet makeprg=pbxbuild

