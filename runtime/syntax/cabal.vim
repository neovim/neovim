" Vim syntax file
" Language:     Haskell Cabal Build file
" Author:	Vincent Berthoux <twinside@gmail.com>
" Maintainer:   Marcin Szamotulski <profunctor@pm.me>
" Previous Maintainer:	Vincent Berthoux <twinside@gmail.com>
" File Types:   .cabal
" Last Change:  3 Oct 2020
" v1.5: Incorporated changes from
"       https://github.com/sdiehl/haskell-vim-proto/blob/master/vim/syntax/cabal.vim
"       Use `syn keyword` instead of `syn match`.
"       Added cabalStatementRegion to limit matches of keywords, which fixes
"       the highlighting of description's value.
"       Added cabalVersionRegion to limit the scope of cabalVersionOperator
"       and cabalVersion matches.
"       Added cabalLanguage keyword.
"       Added calbalTitle, cabalAuthor and cabalMaintainer syntax groups.
"       Added ! and ^>= operators (calbal 2.0)
"       Added build-type keywords
" v1.4: Add benchmark support, thanks to Simon Meier
" v1.3: Updated to the last version of cabal
"       Added more highlighting for cabal function, true/false
"       and version number. Also added missing comment highlighting.
"       Cabal known compiler are highlighted too.
"
" V1.2: Added cpp-options which was missing. Feature implemented
"       by GHC, found with a GHC warning, but undocumented. 
"       Whatever...
"
" v1.1: Fixed operator problems and added ftdetect file
"       (thanks to Sebastian Schwarz)
"
" v1.0: Cabal syntax in vimball format
"       (thanks to Magnus Therning)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" this file uses line continuation
let s:cpo_save = &cpo
set cpo&vim

" set iskeyword for this syntax script
syn iskeyword @,48-57,192-255,-

" Case sensitive matches
syn case match

syn keyword cabalConditional	if else
syn keyword cabalFunction	os arche impl flag
syn match cabalComment		/--.*$/

" Case insensitive matches
syn case ignore

syn keyword cabalCategory contained
	\ executable
	\ library
	\ benchmark
	\ test-suite
	\ source-repository
	\ flag
	\ custom-setup
	\ common
syn match cabalCategoryTitle contained /[^{]*\ze{\?/
syn match cabalCategoryRegion
	\ contains=cabalCategory,cabalCategoryTitle
	\ nextgroup=cabalCategory skipwhite
	\ /^\c\s*\(contained\|executable\|library\|benchmark\|test-suite\|source-repository\|flag\|custom-setup\|common\)\+\s*\%(.*$\|$\)/
syn keyword cabalTruth true false

" cabalStatementRegion which limits the scope of cabalStatement keywords, this
" way they are not highlighted in description.
syn region cabalStatementRegion start=+^\s*\(--\)\@<!\k\+\s*:+ end=+:+
syn keyword cabalStatement contained containedin=cabalStatementRegion
	\ default-language
	\ default-extensions
	\ author
        \ autogen-modules
	\ branch
	\ bug-reports
	\ build-depends
	\ build-tools
	\ build-type
	\ buildable
	\ c-sources
	\ cabal-version
	\ category
	\ cc-options
	\ copyright
	\ cpp-options
	\ data-dir
	\ data-files
	\ default
	\ description
	\ executable
	\ exposed-modules
	\ exposed
	\ extensions
	\ extra-tmp-files
	\ extra-doc-files
	\ extra-lib-dirs
	\ extra-libraries
	\ extra-source-files
	\ exta-tmp-files
	\ for example
	\ frameworks
	\ ghc-options
	\ ghc-prof-options
	\ ghc-shared-options
	\ homepage
	\ hs-source-dirs
	\ hugs-options
	\ import
	\ include-dirs
	\ includes
	\ install-includes
	\ ld-options
	\ license
	\ license-file
	\ location
	\ main-is
	\ maintainer
	\ manual
	\ module
	\ name
	\ nhc98-options
	\ other-extensions
	\ other-modules
	\ package-url
	\ pkgconfig-depends
	\ setup-depends
	\ stability
	\ subdir
	\ synopsis
	\ tag
	\ tested-with
	\ type
	\ version
	\ virtual-modules

" operators and version operators
syn match cabalOperator /&&\|||\|!/
syn match cabalVersionOperator contained
	\ /!\|==\|\^\?>=\|<=\|<\|>/
" match version: `[%]\@<!` is to exclude `%20` in http addresses.
syn match cabalVersion contained
	\ /[%$_-]\@<!\<\d\+\%(\.\d\+\)*\%(\.\*\)\?\>/
" cabalVersionRegion which limits the scope of cabalVersion pattern.
syn match cabalVersionRegionA
	\ contains=cabalVersionOperator,cabalVersion
	\ keepend
	\ /\%(==\|\^\?>=\|<=\|<\|>\)\s*\d\+\%(\.\d\+\)*\%(\.\*\)\?\>/
" version inside `version: ...` 
syn match cabalVersionRegionB
	\ contains=cabalStatementRegion,cabalVersionOperator,cabalVersion
	\ /^\s*\%(cabal-\)\?version\s*:.*$/

syn keyword cabalLanguage Haskell98 Haskell2010

" title region
syn match cabalName contained /:\@<=.*/
syn match cabalNameRegion
	\ contains=cabalStatementRegion,cabalName
	\ nextgroup=cabalStatementRegion
	\ oneline
	\ /^\c\s*name\s*:.*$/

" author region
syn match cabalAuthor contained /:\@<=.*/
syn match cabalAuthorRegion
	\ contains=cabalStatementRegion,cabalStatement,cabalAuthor
	\ nextgroup=cabalStatementRegion
	\ oneline
	\ /^\c\s*author\s*:.*$/

" maintainer region
syn match cabalMaintainer contained /:\@<=.*/
syn match cabalMaintainerRegion
	\ contains=cabalStatementRegion,cabalStatement,cabalMaintainer
	\ nextgroup=cabalStatementRegion
	\ oneline
	\ /^\c\s*maintainer\s*:.*$/

" license region
syn match cabalLicense contained /:\@<=.*/
syn match cabalLicenseRegion
	\ contains=cabalStatementRegion,cabalStatement,cabalLicense
	\ nextgroup=cabalStatementRegion
	\ oneline
	\ /^\c\s*license\s*:.*$/

" license-file region
syn match cabalLicenseFile contained /:\@<=.*/
syn match cabalLicenseFileRegion
	\ contains=cabalStatementRegion,cabalStatement,cabalLicenseFile
	\ nextgroup=cabalStatementRegion
	\ oneline
	\ /^\c\s*license-file\s*:.*$/

" tested-with region with compilers and versions
syn keyword cabalCompiler contained ghc nhc yhc hugs hbc helium jhc lhc
syn match cabalTestedWithRegion
	\ contains=cabalStatementRegion,cabalStatement,cabalCompiler,cabalVersionRegionA
	\ nextgroup=cabalStatementRegion
	\ oneline
	\ /^\c\s*tested-with\s*:.*$/

" build type keywords
syn keyword cabalBuildType contained
	\ simple custom configure
syn match cabalBuildTypeRegion
	\ contains=cabalStatementRegion,cabalStatement,cabalBuildType
	\ nextgroup=cabalStatementRegion
	\ /^\c\s*build-type\s*:.*$/

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link cabalName	      Title
hi def link cabalAuthor	      Normal
hi def link cabalMaintainer   Normal
hi def link cabalCategoryTitle Title
hi def link cabalLicense      Normal
hi def link cabalLicenseFile  Normal
hi def link cabalBuildType    Keyword
hi def link cabalVersion      Number
hi def link cabalTruth        Boolean
hi def link cabalComment      Comment
hi def link cabalStatement    Statement
hi def link cabalLanguage     Type
hi def link cabalCategory     Type
hi def link cabalFunction     Function
hi def link cabalConditional  Conditional
hi def link cabalOperator     Operator
hi def link cabalVersionOperator Operator
hi def link cabalCompiler     Constant

let b:current_syntax = "cabal"

let &cpo = s:cpo_save
unlet! s:cpo_save

" vim: ts=8
