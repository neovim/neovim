" Vim compiler file
" Compiler:     ATT dot
" Maintainer:	Marcos Macedo <bar4ka@bol.com.br>
" Last Change:	2004 May 16

if exists("current_compiler")
  finish
endif
let current_compiler = "dot"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=dot\ -T$*\ \"%:p\"\ -o\ \"%:p:r.$*\"
