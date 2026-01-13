" Vim compiler file
" Compiler: Haskell Cabal Build file
" Maintainer: Mateo Gjika <@mateoxh>

if exists('current_compiler')
  finish
endif

let current_compiler = 'cabal'

let s:save_cpo = &cpo
set cpo&vim

CompilerSet makeprg=cabal\ build

CompilerSet errorformat=
      \%W%f:(%l\\,%c)-(%e\\,%k):\ %tarning:\ [%.%#],
      \%W%f:(%l\\,%c)-(%e\\,%k):\ %tarning:%m,
      \%W%f:(%l\\,%c)-(%e\\,%k):\ %tarning:,
      \%W%f:%l:%c-%k:\ %tarning:\ [%.%#],
      \%W%f:%l:%c-%k:\ %tarning:%m,
      \%W%f:%l:%c-%k:\ %tarning:,
      \%W%f:%l:%c:\ %tarning:\ [%.%#],
      \%W%f:%l:%c:\ %tarning:%m,
      \%W%f:%l:%c:\ %tarning:,
      \%E%f:(%l\\,%c)-(%e\\,%k):\ %trror:\ [%.%#],
      \%E%f:(%l\\,%c)-(%e\\,%k):\ %trror:%m,
      \%E%f:(%l\\,%c)-(%e\\,%k):\ %trror:,
      \%E%f:%l:%c-%k:\ %trror:\ [%.%#],
      \%E%f:%l:%c-%k:\ %trror:%m,
      \%E%f:%l:%c-%k:\ %trror:,
      \%E%f:%l:%c:\ %trror:\ [%.%#],
      \%E%f:%l:%c:\ %trror:%m,
      \%E%f:%l:%c:\ %trror:,
      \%Z\ %\\+\|%.%#,
      \%C%m

let &cpo = s:save_cpo
unlet s:save_cpo
