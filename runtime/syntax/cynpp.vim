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





" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the Cynlib syntax to start with - this includes the C++ syntax
runtime! syntax/cynlib.vim
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
" Only when an item doesn't have highlighting yet

hi def link cLabel		Label
hi def link cynppMacro  Statement


let b:current_syntax = "cynpp"
