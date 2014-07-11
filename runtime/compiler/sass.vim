" Vim compiler file
" Compiler:	Sass
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2013 May 30

if exists("current_compiler")
  finish
endif
let current_compiler = "sass"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=sass\ -c

CompilerSet errorformat=
      \%f:%l:%m\ (Sass::Syntax%trror),
      \%ESyntax\ %trror:%m,
      \%C%\\s%\\+on\ line\ %l\ of\ %f,
      \%Z%.%#,
      \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2:
