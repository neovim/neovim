" Vim syntax file
" Language:		Cabal Config
" Maintainer:		profunctor@pm.me
" Last Change:		Marcin Szamotulski
" Original Author:	Marcin Szamotulski

if exists("b:current_syntax")
  finish
endif

syn match CabalConfigSection /^\S[[:alpha:]]\+\%(-[[:alpha:]]\+\)*[^:]*$/
syn region CabalConfigRegion matchgroup=CabalConfigKey start=/^\s*[[:alpha:]]\+\%(-[[:alpha:]]\+\)*:/ matchgroup=NONE end=/$/ contains=CabalConfigSeparator,CabalConfigKeyword,CabalConfigPath keepend
syn match CabalConfigComment /^\s*--.*$/
syn match CabalConfigValue /.*$/ contained
syn match CabalConfigKey /[[:alpha:]]\+\%(-[[:alpha:]]\+\)*\ze:/
syn keyword CabalConfigSeparator : contained
syn match CabalConfigVariable /\$[[:alpha:]]\+/
syn keyword CabalConfigKeyword True False ghc
syn match CabalConfigPath /\%([[:alpha:]]\+:\)\?\%(\/[[:print:]]\+\)\+/

hi def link CabalConfigComment Comment
hi def link CabalConfigSection Title
hi def link CabalConfigKey Statement
hi def link CabalConfigSeparator NonText
hi def link CabalConfigValue Normal
hi def link CabalConfigVariable Identifier
hi def link CabalConfigKeyword Keyword
hi def link CabalConfigPath Directory

let b:current_syntax = "cabal.config"
