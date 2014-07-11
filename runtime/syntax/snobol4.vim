" Vim syntax file
" Language:     SNOBOL4
" Maintainer:   Rafal Sulejman <rms@poczta.onet.pl>
" Site: http://rms.republika.pl/vim/syntax/snobol4.vim
" Last change:  2006 may 10
" Changes: 
" - strict snobol4 mode (set snobol4_strict_mode to activate)
" - incorrect HL of dots in strings corrected
" - incorrect HL of dot-variables in parens corrected 
" - one character labels weren't displayed correctly.
" - nonexistent Snobol4 keywords displayed as errors.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syntax case ignore

" Snobol4 keywords
syn keyword     snobol4Keyword      any apply arb arbno arg array
syn keyword     snobol4Keyword      break
syn keyword     snobol4Keyword      char clear code collect convert copy
syn keyword     snobol4Keyword      data datatype date define detach differ dump dupl
syn keyword     snobol4Keyword      endfile eq eval
syn keyword     snobol4Keyword      field
syn keyword     snobol4Keyword      ge gt ident
syn keyword     snobol4Keyword      input integer item
syn keyword     snobol4Keyword      le len lgt local lpad lt
syn keyword     snobol4Keyword      ne notany
syn keyword     snobol4Keyword      opsyn output
syn keyword     snobol4Keyword      pos prototype
syn keyword     snobol4Keyword      remdr replace rpad rpos rtab rewind
syn keyword     snobol4Keyword      size span stoptr
syn keyword     snobol4Keyword      tab table time trace trim terminal
syn keyword     snobol4Keyword      unload
syn keyword     snobol4Keyword      value

" CSNOBOL keywords
syn keyword     snobol4ExtKeyword   breakx
syn keyword     snobol4ExtKeyword   char chop
syn keyword     snobol4ExtKeyword   date delete
syn keyword     snobol4ExtKeyword   exp
syn keyword     snobol4ExtKeyword   freeze function
syn keyword     snobol4ExtKeyword   host
syn keyword     snobol4ExtKeyword   io_findunit
syn keyword     snobol4ExtKeyword   label lpad leq lge lle llt lne log
syn keyword     snobol4ExtKeyword   ord
syn keyword     snobol4ExtKeyword   reverse rpad rsort rename
syn keyword     snobol4ExtKeyword   serv_listen sset set sort sqrt substr
syn keyword     snobol4ExtKeyword   thaw
syn keyword     snobol4ExtKeyword   vdiffer

syn region      snobol4String       matchgroup=Quote start=+"+ end=+"+
syn region      snobol4String       matchgroup=Quote start=+'+ end=+'+
syn match       snobol4BogusStatement    "^-[^ ][^ ]*"
syn match       snobol4Statement    "^-\(include\|copy\|module\|line\|plusopts\|case\|error\|noerrors\|list\|unlist\|execute\|noexecute\|copy\)"
syn match       snobol4Constant     /"[^a-z"']\.[a-z][a-z0-9\-]*"/hs=s+1
syn region      snobol4Goto         start=":[sf]\{0,1}(" end=")\|$\|;" contains=ALLBUT,snobol4ParenError
syn match       snobol4Number       "\<\d*\(\.\d\d*\)*\>" 
syn match       snobol4BogusSysVar  "&\w\{1,}"
syn match       snobol4SysVar       "&\(abort\|alphabet\|anchor\|arb\|bal\|case\|code\|dump\|errlimit\|errtext\|errtype\|fail\|fence\|fnclevel\|ftrace\|fullscan\|input\|lastno\|lcase\|maxlngth\|output\|parm\|rem\|rtntype\|stcount\|stfcount\|stlimit\|stno\|succeed\|trace\|trim\|ucase\)"
syn match       snobol4ExtSysVar    "&\(gtrace\|line\|file\|lastline\|lastfile\)"
syn match       snobol4Label        "\(^\|;\)[^-\.\+ \t\*\.]\{1,}[^ \t\*\;]*"
syn match       snobol4Comment      "\(^\|;\)\([\*\|!;#].*$\)"

" Parens matching
syn cluster     snobol4ParenGroup   contains=snobol4ParenError
syn region      snobol4Paren        transparent start='(' end=')' contains=ALLBUT,@snobol4ParenGroup,snobol4ErrInBracket
syn match       snobol4ParenError   display "[\])]"
syn match       snobol4ErrInParen   display contained "[\]{}]\|<%\|%>"
syn region      snobol4Bracket      transparent start='\[\|<:' end=']\|:>' contains=ALLBUT,@snobol4ParenGroup,snobol4ErrInParen
syn match       snobol4ErrInBracket display contained "[){}]\|<%\|%>"

" optional shell shebang line
" syn match       snobol4Comment      "^\#\!.*$"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_snobol4_syntax_inits")
  if version < 508
    let did_snobol4_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink snobol4Constant        Constant
  HiLink snobol4Label           Label
  HiLink snobol4Goto            Repeat
  HiLink snobol4Conditional     Conditional
  HiLink snobol4Repeat          Repeat
  HiLink snobol4Number          Number
  HiLink snobol4Error           Error
  HiLink snobol4Statement       PreProc
  HiLink snobol4BogusStatement  snobol4Error
  HiLink snobol4String          String
  HiLink snobol4Comment         Comment
  HiLink snobol4Special         Special
  HiLink snobol4Todo            Todo
  HiLink snobol4Keyword         Keyword
  HiLink snobol4Function        Function
  HiLink snobol4MathsOperator   Operator
  HiLink snobol4ParenError      snobol4Error
  HiLink snobol4ErrInParen      snobol4Error
  HiLink snobol4ErrInBracket    snobol4Error
  HiLink snobol4SysVar          Keyword
  HiLink snobol4BogusSysVar     snobol4Error
  if exists("snobol4_strict_mode")
    HiLink snobol4ExtSysVar       WarningMsg
    HiLink snobol4ExtKeyword      WarningMsg
  else
    HiLink snobol4ExtSysVar       snobol4SysVar
    HiLink snobol4ExtKeyword      snobol4Keyword
  endif

  delcommand HiLink
endif

let b:current_syntax = "snobol4"
" vim: ts=8
