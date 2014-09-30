" Vim syntax file
" Language:	Haskell Cabal Build file
" Maintainer:	Vincent Berthoux <twinside@gmail.com>
" File Types:	.cabal
" Last Change:  2010 May 18
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

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn keyword	cabalCategory	Library library Executable executable Flag flag
syn keyword	cabalCategory	source-repository Source-Repository

syn keyword     cabalConditional    if else
syn match       cabalOperator       "&&\|||\|!\|==\|>=\|<="
syn keyword     cabalFunction       os arche impl flag
syn match       cabalComment    /--.*$/
syn match       cabalVersion    "\d\+\(.\(\d\)\+\)\+"

syn match       cabalTruth      "\ctrue"
syn match       cabalTruth      "\cfalse"

syn match       cabalCompiler   "\cghc"
syn match       cabalCompiler   "\cnhc"
syn match       cabalCompiler   "\cyhc"
syn match       cabalCompiler   "\chugs"
syn match       cabalCompiler   "\chbc"
syn match       cabalCompiler   "\chelium"
syn match       cabalCompiler   "\cjhc"
syn match       cabalCompiler   "\clhc"


syn match	cabalStatement	"\cauthor"
syn match	cabalStatement	"\cbranch"
syn match	cabalStatement	"\cbug-reports"
syn match	cabalStatement	"\cbuild-depends"
syn match	cabalStatement	"\cbuild-tools"
syn match	cabalStatement	"\cbuild-type"
syn match	cabalStatement	"\cbuildable"
syn match	cabalStatement	"\cc-sources"
syn match	cabalStatement	"\ccabal-version"
syn match	cabalStatement	"\ccategory"
syn match	cabalStatement	"\ccc-options"
syn match	cabalStatement	"\ccopyright"
syn match       cabalStatement  "\ccpp-options"
syn match	cabalStatement	"\cdata-dir"
syn match	cabalStatement	"\cdata-files"
syn match	cabalStatement	"\cdefault"
syn match	cabalStatement	"\cdescription"
syn match	cabalStatement	"\cexecutable"
syn match	cabalStatement	"\cexposed-modules"
syn match	cabalStatement	"\cexposed"
syn match	cabalStatement	"\cextensions"
syn match	cabalStatement	"\cextra-lib-dirs"
syn match	cabalStatement	"\cextra-libraries"
syn match	cabalStatement	"\cextra-source-files"
syn match	cabalStatement	"\cextra-tmp-files"
syn match	cabalStatement	"\cfor example"
syn match	cabalStatement	"\cframeworks"
syn match	cabalStatement	"\cghc-options"
syn match	cabalStatement	"\cghc-prof-options"
syn match	cabalStatement	"\cghc-shared-options"
syn match	cabalStatement	"\chomepage"
syn match	cabalStatement	"\chs-source-dirs"
syn match	cabalStatement	"\chugs-options"
syn match	cabalStatement	"\cinclude-dirs"
syn match	cabalStatement	"\cincludes"
syn match	cabalStatement	"\cinstall-includes"
syn match	cabalStatement	"\cld-options"
syn match	cabalStatement	"\clicense-file"
syn match	cabalStatement	"\clicense"
syn match	cabalStatement	"\clocation"
syn match	cabalStatement	"\cmain-is"
syn match	cabalStatement	"\cmaintainer"
syn match	cabalStatement	"\cmodule"
syn match	cabalStatement	"\cname"
syn match	cabalStatement	"\cnhc98-options"
syn match	cabalStatement	"\cother-modules"
syn match	cabalStatement	"\cpackage-url"
syn match	cabalStatement	"\cpkgconfig-depends"
syn match	cabalStatement	"\cstability"
syn match	cabalStatement	"\csubdir"
syn match	cabalStatement	"\csynopsis"
syn match	cabalStatement	"\ctag"
syn match	cabalStatement	"\ctested-with"
syn match	cabalStatement	"\ctype"
syn match	cabalStatement	"\cversion"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cabal_syn_inits")
  if version < 508
    let did_cabal_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink cabalVersion       Number
  HiLink cabalTruth         Boolean
  HiLink cabalComment       Comment
  HiLink cabalStatement     Statement
  HiLink cabalCategory      Type
  HiLink cabalFunction      Function
  HiLink cabalConditional   Conditional
  HiLink cabalOperator      Operator
  HiLink cabalCompiler      Constant
  delcommand HiLink
endif

let b:current_syntax = "cabal"

" vim: ts=8
