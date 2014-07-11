" Vim syntax file
" Language:	jgraph (graph plotting utility)
" Maintainer:	Jonas Munsin jmunsin@iki.fi
" Last Change:	2003 May 04
" this syntax file is not yet complete


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

" comments
syn region	jgraphComment	start="(\* " end=" \*)"

syn keyword	jgraphCmd	newcurve newgraph marktype
syn keyword	jgraphType	xaxis yaxis

syn keyword	jgraphType	circle box diamond triangle x cross ellipse
syn keyword	jgraphType	xbar ybar text postscript eps none general

syn keyword	jgraphType	solid dotted dashed longdash dotdash dodotdash
syn keyword	jgraphType	dotdotdashdash pts

"integer number, or floating point number without a dot. - or no -
syn match  jgraphNumber		 "\<-\=\d\+\>"
"floating point number, with dot - or no -
syn match  jgraphNumber		 "\<-\=\d\+\.\d*\>"
"floating point number, starting with a dot - or no -
syn match  jgraphNumber		 "\-\=\.\d\+\>"


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_jgraph_syn_inits")
  if version < 508
    let did_jgraph_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink jgraphComment	Comment
  HiLink jgraphCmd	Identifier
  HiLink jgraphType	Type
  HiLink jgraphNumber	Number

  delcommand HiLink
endif


let b:current_syntax = "jgraph"
