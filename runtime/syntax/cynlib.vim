" Vim syntax file
" Language:     Cynlib(C++)
" Maintainer:   Phil Derrick <phild@forteds.com>
" Last change:  2001 Sep 02
" URL http://www.derrickp.freeserve.co.uk/vim/syntax/cynlib.vim
"
" Language Information
"
"		Cynlib is a library of C++ classes to allow hardware
"		modelling in C++. Combined with a simulation kernel,
"		the compiled and linked executable forms a hardware
"		simulation of the described design.
"
"		Further information can be found from www.forteds.com


" Remove any old syntax stuff hanging around
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif



" Read the C++ syntax to start with - this includes the C syntax
runtime! syntax/cpp.vim
unlet b:current_syntax

" Cynlib extensions

syn keyword	cynlibMacro	   Default CYNSCON
syn keyword	cynlibMacro	   Case CaseX EndCaseX
syn keyword	cynlibType	   CynData CynSignedData CynTime
syn keyword	cynlibType	   In Out InST OutST
syn keyword	cynlibType	   Struct
syn keyword	cynlibType	   Int Uint Const
syn keyword	cynlibType	   Long Ulong
syn keyword	cynlibType	   OneHot
syn keyword	cynlibType	   CynClock Cynclock0
syn keyword     cynlibFunction     time configure my_name
syn keyword     cynlibFunction     CynModule epilog execute_on
syn keyword     cynlibFunction     my_name
syn keyword     cynlibFunction     CynBind bind
syn keyword     cynlibFunction     CynWait CynEvent
syn keyword     cynlibFunction     CynSetName
syn keyword     cynlibFunction     CynTick CynRun
syn keyword     cynlibFunction     CynFinish
syn keyword     cynlibFunction     Cynprintf CynSimTime
syn keyword     cynlibFunction     CynVcdFile
syn keyword     cynlibFunction     CynVcdAdd CynVcdRemove
syn keyword     cynlibFunction     CynVcdOn CynVcdOff
syn keyword     cynlibFunction     CynVcdScale
syn keyword     cynlibFunction     CynBgnName CynEndName
syn keyword     cynlibFunction     CynClock configure time
syn keyword     cynlibFunction     CynRedAnd CynRedNand
syn keyword     cynlibFunction     CynRedOr CynRedNor
syn keyword     cynlibFunction     CynRedXor CynRedXnor
syn keyword     cynlibFunction     CynVerify


syn match       cynlibOperator     "<<="
syn keyword	cynlibType	   In Out InST OutST Int Uint Const Cynclock

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link cynlibOperator   Operator
hi def link cynlibMacro      Statement
hi def link cynlibFunction   Statement
hi def link cynlibppMacro      Statement
hi def link cynlibType       Type


let b:current_syntax = "cynlib"
