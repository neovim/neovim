" Vim compiler file
" Compiler:         Rust Compiler
" Maintainer:       Chris Morgan <me@chrismorgan.info>
" Latest Revision:  2013 Jul 12
" For bugs, patches and license go to https://github.com/rust-lang/rust.vim

if exists("current_compiler")
	finish
endif
let current_compiler = "rustc"

let s:cpo_save = &cpo
set cpo&vim

if exists(":CompilerSet") != 2
	command -nargs=* CompilerSet setlocal <args>
endif

if exists("g:rustc_makeprg_no_percent") && g:rustc_makeprg_no_percent != 0
	CompilerSet makeprg=rustc
else
	CompilerSet makeprg=rustc\ \%:S
endif

" Old errorformat (before nightly 2016/08/10)
CompilerSet errorformat=
			\%f:%l:%c:\ %t%*[^:]:\ %m,
			\%f:%l:%c:\ %*\\d:%*\\d\ %t%*[^:]:\ %m,
			\%-G%f:%l\ %s,
			\%-G%*[\ ]^,
			\%-G%*[\ ]^%*[~],
			\%-G%*[\ ]...

" New errorformat (after nightly 2016/08/10)
CompilerSet errorformat+=
			\%-G,
			\%-Gerror:\ aborting\ %.%#,
			\%-Gerror:\ Could\ not\ compile\ %.%#,
			\%Eerror:\ %m,
			\%Eerror[E%n]:\ %m,
			\%Wwarning:\ %m,
			\%Inote:\ %m,
			\%C\ %#-->\ %f:%l:%c

let &cpo = s:cpo_save
unlet s:cpo_save
