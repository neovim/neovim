" Vim compiler file
" Compiler:      perlcritic
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Author:        Doug Kearns <dougkearns@gmail.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2021 Oct 20

if exists("current_compiler")
  finish
endif
let current_compiler = "perlcritic"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=perlcritic\ --nocolor\ --quiet\ --verbose\ \"\\%f:\\%l:\\%c:\\%s:\\%m\\n\"
CompilerSet errorformat=%f:%l:%c:%n:%m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
