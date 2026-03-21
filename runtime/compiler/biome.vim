" Vim compiler file
" Compiler:     Biome (= linter for JavaScript, TypeScript, JSX, TSX, JSON,
"               JSONC, HTML, Vue, Svelte, Astro, CSS, GraphQL and GritQL files)
" Maintainer:   @Konfekt
" Last Change:  2025 Nov 12
if exists("current_compiler") | finish | endif
let current_compiler = "biome"

let s:cpo_save = &cpo
set cpo&vim

exe 'CompilerSet makeprg=' .. escape('biome check --linter-enabled=true --formatter-enabled=false --assist-enabled=false --reporter=github '
      \ .. get(b:, 'biome_makeprg_params', get(g:, 'biome_makeprg_params', '')), ' \|"')

CompilerSet errorformat=::%trror%.%#file=%f\\,line=%l\\,%.%#col=%c\\,%.%#::%m
CompilerSet errorformat+=::%tarning%.%#file=%f\\,line=%l\\,%.%#col=%c\\,%.%#::%m
CompilerSet errorformat+=::%totice%.%#file=%f\\,line=%l\\,%.%#col=%c\\,%.%#::%m
CompilerSet errorformat+=%-G\\s%#
CompilerSet errorformat+=%-Gcheck\ %.%#
CompilerSet errorformat+=%-G%.%#Some\ errors\ were\ emitted\ while\ running\ checks%.

let &cpo = s:cpo_save
unlet s:cpo_save
