" Vim syntax file
" Language:     PPWizard (preprocessor by Dennis Bareis)
" Maintainer:   Stefan Schwarzer <s.schwarzer@ndh.net>
" URL:			http://www.ndh.net/home/sschwarzer/download/ppwiz.vim
" Last Change:  2003 May 11
" Filename:     ppwiz.vim

" Remove old syntax stuff
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

if !exists("ppwiz_highlight_defs")
    let ppwiz_highlight_defs = 1
endif

if !exists("ppwiz_with_html")
    let ppwiz_with_html = 1
endif

" comments
syn match   ppwizComment  "^;.*$"
syn match   ppwizComment  ";;.*$"
" HTML
if ppwiz_with_html > 0
    syn region ppwizHTML  start="<" end=">" contains=ppwizArg,ppwizMacro
    syn match  ppwizHTML  "\&\w\+;"
endif
" define, evaluate etc.
if ppwiz_highlight_defs == 1
    syn match  ppwizDef   "^\s*\#\S\+\s\+\S\+" contains=ALL
    syn match  ppwizDef   "^\s*\#\(if\|else\|endif\)" contains=ALL
    syn match  ppwizDef   "^\s*\#\({\|break\|continue\|}\)" contains=ALL
" elseif ppwiz_highlight_defs == 2
"     syn region ppwizDef   start="^\s*\#" end="[^\\]$" end="^$" keepend contains=ALL
else
    syn region ppwizDef   start="^\s*\#" end="[^\\]$" end="^$" keepend contains=ppwizCont
endif
syn match   ppwizError    "\s.\\$"
syn match   ppwizCont     "\s\([+\-%]\|\)\\$"
" macros to execute
syn region  ppwizMacro    start="<\$" end=">" contains=@ppwizArgVal,ppwizCont
" macro arguments
syn region  ppwizArg      start="{" end="}" contains=ppwizEqual,ppwizString
syn match   ppwizEqual    "=" contained
syn match   ppwizOperator "<>\|=\|<\|>" contained
" standard variables (builtin)
syn region  ppwizStdVar   start="<?[^?]" end=">" contains=@ppwizArgVal
" Rexx variables
syn region  ppwizRexxVar  start="<??" end=">" contains=@ppwizArgVal
" Constants
syn region  ppwizString   start=+"+ end=+"+ contained contains=ppwizMacro,ppwizArg,ppwizHTML,ppwizCont,ppwizStdVar,ppwizRexxVar
syn region  ppwizString   start=+'+ end=+'+ contained contains=ppwizMacro,ppwizArg,ppwizHTML,ppwizCont,ppwizStdVar,ppwizRexxVar
syn match   ppwizInteger  "\d\+" contained

" Clusters
syn cluster ppwizArgVal add=ppwizString,ppwizInteger

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link ppwizSpecial  Special
hi def link ppwizEqual    ppwizSpecial
hi def link ppwizOperator ppwizSpecial
hi def link ppwizComment  Comment
hi def link ppwizDef      PreProc
hi def link ppwizMacro    Statement
hi def link ppwizArg      Identifier
hi def link ppwizStdVar   Identifier
hi def link ppwizRexxVar  Identifier
hi def link ppwizString   Constant
hi def link ppwizInteger  Constant
hi def link ppwizCont     ppwizSpecial
hi def link ppwizError    Error
hi def link ppwizHTML     Type


let b:current_syntax = "ppwiz"

" vim: ts=4

