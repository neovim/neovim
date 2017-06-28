" Vim syntax file
" Language:	SNNS network file
" Maintainer:	Davide Alberani <alberanid@bigfoot.com>
" Last Change:	28 Apr 2001
" Version:	0.2
" URL:		http://digilander.iol.it/alberanid/vim/syntax/snnsnet.vim
"
" SNNS http://www-ra.informatik.uni-tuebingen.de/SNNS/
" is a simulator for neural networks.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match	snnsnetTitle	"no\."
syn match	snnsnetTitle	"type name"
syn match	snnsnetTitle	"unit name"
syn match	snnsnetTitle	"act\( func\)\="
syn match	snnsnetTitle	"out func"
syn match	snnsnetTitle	"site\( name\)\="
syn match	snnsnetTitle	"site function"
syn match	snnsnetTitle	"source:weight"
syn match	snnsnetTitle	"unitNo\."
syn match	snnsnetTitle	"delta x"
syn match	snnsnetTitle	"delta y"
syn keyword	snnsnetTitle	typeName unitName bias st position subnet layer sites name target z LLN LUN Toff Soff Ctype

syn match	snnsnetType	"SNNS network definition file [Vv]\d.\d.*" contains=snnsnetNumbers
syn match	snnsnetType	"generated at.*" contains=snnsnetNumbers
syn match	snnsnetType	"network name\s*:"
syn match	snnsnetType	"source files\s*:"
syn match	snnsnetType	"no\. of units\s*:.*" contains=snnsnetNumbers
syn match	snnsnetType	"no\. of connections\s*:.*" contains=snnsnetNumbers
syn match	snnsnetType	"no\. of unit types\s*:.*" contains=snnsnetNumbers
syn match	snnsnetType	"no\. of site types\s*:.*" contains=snnsnetNumbers
syn match	snnsnetType	"learning function\s*:"
syn match	snnsnetType	"pruning function\s*:"
syn match	snnsnetType	"subordinate learning function\s*:"
syn match	snnsnetType	"update function\s*:"

syn match	snnsnetSection	"unit definition section"
syn match	snnsnetSection	"unit default section"
syn match	snnsnetSection	"site definition section"
syn match	snnsnetSection	"type definition section"
syn match	snnsnetSection	"connection definition section"
syn match	snnsnetSection	"layer definition section"
syn match	snnsnetSection	"subnet definition section"
syn match	snnsnetSection	"3D translation section"
syn match	snnsnetSection	"time delay section"

syn match	snnsnetNumbers	"\d" contained
syn match	snnsnetComment	"#.*$" contains=snnsnetTodo
syn keyword	snnsnetTodo	TODO XXX FIXME contained


hi def link snnsnetType		Type
hi def link snnsnetComment		Comment
hi def link snnsnetNumbers		Number
hi def link snnsnetSection		Statement
hi def link snnsnetTitle		Label
hi def link snnsnetTodo		Todo


let b:current_syntax = "snnsnet"

" vim: ts=8 sw=2
