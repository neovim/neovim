" Vim compiler file
" Compiler:      Perl syntax checks (perl -Wc)
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Author:        Christian J. Robinson <heptite@gmail.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2021 Nov 2

if exists("current_compiler")
  finish
endif
let current_compiler = "perl"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:savecpo = &cpo
set cpo&vim

if get(g:, 'perl_compiler_force_warnings', 1)
	let s:warnopt = 'W'
else
	let s:warnopt = 'w'
endif

if getline(1) =~# '-[^ ]*T'
	let s:taintopt = 'T'
else
	let s:taintopt = ''
endif

exe 'CompilerSet makeprg=perl\ -' . s:warnopt . s:taintopt . 'c\ %:S'

CompilerSet errorformat=
	\%-G%.%#had\ compilation\ errors.,
	\%-G%.%#syntax\ OK,
	\%m\ at\ %f\ line\ %l.,
	\%+A%.%#\ at\ %f\ line\ %l\\,%.%#,
	\%+C%.%#

" Explanation:
" %-G%.%#had\ compilation\ errors.,  - Ignore the obvious.
" %-G%.%#syntax\ OK,                 - Don't include the 'a-okay' message.
" %m\ at\ %f\ line\ %l.,             - Most errors...
" %+A%.%#\ at\ %f\ line\ %l\\,%.%#,  - As above, including ', near ...'
" %+C%.%#                            -   ... Which can be multi-line.

let &cpo = s:savecpo
unlet s:savecpo
