" Vim syntax file
" Language:	jgraph (graph plotting utility)
" Maintainer:	Jonas Munsin jmunsin@iki.fi
" Last Change:	2003 May 04
" this syntax file is not yet complete


" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet

hi def link jgraphComment	Comment
hi def link jgraphCmd	Identifier
hi def link jgraphType	Type
hi def link jgraphNumber	Number



let b:current_syntax = "jgraph"
