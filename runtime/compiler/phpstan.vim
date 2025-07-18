" Vim compiler file
" Compiler:	PHPStan
" Maintainer:	Dietrich Moerman <dietrich.moerman@gmail.com>
" Last Change:	2025 Jul 17

if exists("current_compiler")
  finish
endif
let current_compiler = "phpstan"

CompilerSet makeprg=composer\ exec\ --\ phpstan\ analyse\ -v\ --no-progress\ --error-format=raw
CompilerSet errorformat=%f:%l:%m,%-G%.%#
