" Vim compiler file
" Compiler:         GHC Haskell Compiler
" Maintainer:       Daniel Campoverde <alx@sillybytes.net>
" Latest Revision:  2016-11-29

if exists("current_compiler")
  finish
endif
let current_compiler = "ghc"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet errorformat=
    \%-G%.%#:\ build,
    \%-G%.%#preprocessing\ library\ %.%#,
    \%-G[%.%#]%.%#,
    \%E%f:%l:%c:\ %m,
    \%-G--%.%#

if exists('g:compiler_ghc_ignore_unmatched_lines')
  CompilerSet errorformat+=%-G%.%#
endif

let &cpo = s:cpo_save
unlet s:cpo_save
