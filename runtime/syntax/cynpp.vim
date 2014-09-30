" Vim syntax file
" Language:     Cyn++
" Maintainer:   Phil Derrick <phild@forteds.com>
" Last change:  2001 Sep 02
"
" Language Information
"
"		Cynpp (Cyn++) is a macro language to ease coding in Cynlib.
"		Cynlib is a library of C++ classes to allow hardware
"		modelling in C++. Combined with a simulation kernel,
"		the compiled and linked executable forms a hardware
"		simulation of the described design.
"
"		Cyn++ is designed to be HDL-like.
"
"		Further information can be found from www.forteds.com





" Remove any old syntax stuff hanging around
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Read the Cynlib syntax to start with - this includes the C++ syntax
if version < 600
  source <sfile>:p:h/cynlib.vim
else
  runtime! syntax/cynlib.vim
endif
unlet b:current_syntax



" Cyn++ extensions

syn keyword     cynppMacro      Always EndAlways
syn keyword     cynppMacro      Module EndModule
syn keyword     cynppMacro      Initial EndInitial
syn keyword     cynppMacro      Posedge Negedge Changed
syn keyword     cynppMacro      At
syn keyword     cynppMacro      Thread EndThread
syn keyword     cynppMacro      Instantiate

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cynpp_syntax_inits")
  if version < 508
    let did_cynpp_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink cLabel		Label
  HiLink cynppMacro  Statement

  delcommand HiLink
endif

let b:current_syntax = "cynpp"
