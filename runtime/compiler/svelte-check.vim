" Vim compiler file
" Compiler:	svelte-check
" Maintainer:	@Konfekt
" Last Change:	2025 Feb 27

if exists("current_compiler") | finish | endif
let current_compiler = "svelte-check"

CompilerSet makeprg=npx\ svelte-check\ --output\ machine
CompilerSet errorformat=%*\\d\ %t%*\\a\ \"%f\"\ %l:%c\ \"%m\",
CompilerSet errorformat+=%-G%*\\d\ START\ %.%#,
CompilerSet errorformat+=%-G%*\\d\ COMPLETED\ %.%#,
CompilerSet errorformat+=%-G%.%#

" " Fall-back for versions of svelte-check that don't support --output machine
" " before  May 2020 https://github.com/sveltejs/language-tools/commit/9f7a90379d287a41621a5e78af5b010a8ab810c3
" " which is before the first production release 1.1.31 of Svelte-Check
" CompilerSet makeprg=npx\ svelte-check
" CompilerSet errorformat=%A%f:%l:%c,
" CompilerSet errorformat+=%C%t%*\\a\\:\ %m,
" CompilerSet errorformat+=%-G%.%#,
