" Vim syntax file
" Language:     PPWizard (preprocessor by Dennis Bareis)
" Maintainer:   Stefan Schwarzer <s.schwarzer@ndh.net>
" URL:			http://www.ndh.net/home/sschwarzer/download/ppwiz.vim
" Last Change:  2003 May 11
" Filename:     ppwiz.vim

" Remove old syntax stuff
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_ppwiz_syn_inits")
    if version < 508
		let did_ppwiz_syn_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
    endif

    HiLink ppwizSpecial  Special
    HiLink ppwizEqual    ppwizSpecial
    HiLink ppwizOperator ppwizSpecial
    HiLink ppwizComment  Comment
    HiLink ppwizDef      PreProc
    HiLink ppwizMacro    Statement
    HiLink ppwizArg      Identifier
    HiLink ppwizStdVar   Identifier
    HiLink ppwizRexxVar  Identifier
    HiLink ppwizString   Constant
    HiLink ppwizInteger  Constant
    HiLink ppwizCont     ppwizSpecial
    HiLink ppwizError    Error
    HiLink ppwizHTML     Type

    delcommand HiLink
endif

let b:current_syntax = "ppwiz"

" vim: ts=4

