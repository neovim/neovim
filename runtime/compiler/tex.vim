" Vim compiler file
" Compiler:     TeX
" Maintainer:   Artem Chuprina <ran@ran.pp.ru>
" Last Change:  2012 Apr 30

if exists("current_compiler")
	finish
endif
let s:keepcpo= &cpo
set cpo&vim

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

" If makefile exists and we are not asked to ignore it, we use standard make
" (do not redefine makeprg)
if exists('b:tex_ignore_makefile') || exists('g:tex_ignore_makefile') ||
			\(!filereadable('Makefile') && !filereadable('makefile'))
	" If buffer-local variable 'tex_flavor' exists, it defines TeX flavor,
	" otherwise the same for global variable with same name, else it will be
	" LaTeX
	if exists("b:tex_flavor")
		let current_compiler = b:tex_flavor
	elseif exists("g:tex_flavor")
		let current_compiler = g:tex_flavor
	else
		let current_compiler = "latex"
	endif
	let &l:makeprg=current_compiler.' -interaction=nonstopmode'
else
	let current_compiler = 'make'
endif

" Value errorformat are taken from vim help, see :help errorformat-LaTeX, with
" addition from Srinath Avadhanula <srinath@fastmail.fm>
CompilerSet errorformat=%E!\ LaTeX\ %trror:\ %m,
	\%E!\ %m,
	\%+WLaTeX\ %.%#Warning:\ %.%#line\ %l%.%#,
	\%+W%.%#\ at\ lines\ %l--%*\\d,
	\%WLaTeX\ %.%#Warning:\ %m,
	\%Cl.%l\ %m,
	\%+C\ \ %m.,
	\%+C%.%#-%.%#,
	\%+C%.%#[]%.%#,
	\%+C[]%.%#,
	\%+C%.%#%[{}\\]%.%#,
	\%+C<%.%#>%.%#,
	\%C\ \ %m,
	\%-GSee\ the\ LaTeX%m,
	\%-GType\ \ H\ <return>%m,
	\%-G\ ...%.%#,
	\%-G%.%#\ (C)\ %.%#,
	\%-G(see\ the\ transcript%.%#),
	\%-G\\s%#,
	\%+O(%*[^()])%r,
	\%+O%*[^()](%*[^()])%r,
	\%+P(%f%r,
	\%+P\ %\\=(%f%r,
	\%+P%*[^()](%f%r,
	\%+P[%\\d%[^()]%#(%f%r,
	\%+Q)%r,
	\%+Q%*[^()])%r,
	\%+Q[%\\d%*[^()])%r

let &cpo = s:keepcpo
unlet s:keepcpo
