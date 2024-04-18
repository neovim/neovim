" Vim compiler file
" Compiler:     ATT neato
" Maintainer:	Marcos Macedo <bar4ka@bol.com.br>
" Last Change:	2024 March 21
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "neato"

CompilerSet makeprg=neato\ -T$*\ \"%:p\"\ -o\ \"%:p:r.$*\"
" matches error messages as below skipping final part after line number
" Error: ./file.dot: syntax error in line 1 near 'rankdir'
CompilerSet errorformat=%trror:\ %f:\ %m\ in\ line\ %l%.%#
