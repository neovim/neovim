" Vim syntax file
" Language:		Cabal Project
" Maintainer:		profunctor@pm.me
" Last Change:		Marcin Szamotulski
" Original Author:	Marcin Szamotulski

if exists("b:current_syntax")
  finish
endif

syn match CabalProjectComment /^\s*--.*/ contains=@Spell
syn match CabalProjectField /^\w\%(\w\|-\)\+/ contains=@NoSpell

syn keyword CabalProjectBoolean true false True False
syn keyword CabalProjectCompiler ghc ghcjs jhc lhc uhc haskell-suite
syn match CabalProjectNat /\<\d\+\>/
syn keyword CabalProjectJobs $ncpus
syn keyword CabalProjectProfilingLevel default none exported-functions toplevel-functions all-functions

hi def link CabalProjectComment Comment
hi def link CabalProjectField Statement
hi def link CabalProjectBoolean Boolean
hi def link CabalProjectCompiler Identifier
hi def link CabalProjectNat Number
hi def link CabalProjectJobs Number
hi def link CabalProjectProfilingLevel Statement

let b:current_syntax = "cabal.project"
