" Vim compiler file
" Compiler:         Cargo Compiler
" Maintainer:       Damien Radtke <damienradtke@gmail.com>
" Latest Revision:  2014 Sep 24
" For bugs, patches and license go to https://github.com/rust-lang/rust.vim

if exists('current_compiler')
	finish
endif
runtime compiler/rustc.vim
let current_compiler = "cargo"

let s:save_cpo = &cpo
set cpo&vim

if exists(':CompilerSet') != 2
	command -nargs=* CompilerSet setlocal <args>
endif

if exists('g:cargo_makeprg_params')
	execute 'CompilerSet makeprg=cargo\ '.escape(g:cargo_makeprg_params, ' \|"').'\ $*'
else
	CompilerSet makeprg=cargo\ $*
endif

" Ignore general cargo progress messages
CompilerSet errorformat+=
			\%-G%\\s%#Downloading%.%#,
			\%-G%\\s%#Compiling%.%#,
			\%-G%\\s%#Finished%.%#,
			\%-G%\\s%#error:\ Could\ not\ compile\ %.%#,
			\%-G%\\s%#To\ learn\ more\\,%.%#

let &cpo = s:save_cpo
unlet s:save_cpo
