" Vim compiler file
" Compiler:     ATT dot
" Maintainer:	Marcos Macedo <bar4ka@bol.com.br>
" Last Change:	2024 March 21

if exists("current_compiler")
  finish
endif
let current_compiler = "dot"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=dot\ -T$*\ \"%:p\"\ -o\ \"%:p:r.$*\"
" matches error messages as below skipping final part after line number
" Error: ./file.dot: syntax error in line 1 near 'rankdir'
CompilerSet errorformat=%trror:\ %f:\ %m\ in\ line\ %l%.%#
