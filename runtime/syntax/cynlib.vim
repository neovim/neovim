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
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif



" Read the C++ syntax to start with - this includes the C syntax
if version < 600
  source <sfile>:p:h/cpp.vim
else
  runtime! syntax/cpp.vim
endif
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cynlib_syntax_inits")
  if version < 508
    let did_cynlib_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink cynlibOperator   Operator
  HiLink cynlibMacro      Statement
  HiLink cynlibFunction   Statement
  HiLink cynlibppMacro      Statement
  HiLink cynlibType       Type

  delcommand HiLink
endif

let b:current_syntax = "cynlib"
