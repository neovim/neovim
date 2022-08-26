" Vim syntax file
" Language:	ecd (Embedix Component Description) files
" Maintainer:	John Beppu <beppu@opensource.lineo.com>
" URL:		http://opensource.lineo.com/~beppu/prose/ecd_vim.html
" Last Change:	2001 Sep 27

" An ECD file contains meta-data for packages in the Embedix Linux distro.
" This syntax file was derived from apachestyle.vim
" by Christian Hammers <ch@westend.com>

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

" specials
syn match  ecdComment	"^\s*#.*"

" options and values
syn match  ecdAttr	"^\s*[a-zA-Z]\S*\s*[=].*$" contains=ecdAttrN,ecdAttrV
syn match  ecdAttrN	contained "^.*="me=e-1
syn match  ecdAttrV	contained "=.*$"ms=s+1

" tags
syn region ecdTag	start=+<+ end=+>+ contains=ecdTagN,ecdTagError
syn match  ecdTagN	contained +<[/\s]*[-a-zA-Z0-9_]\++ms=s+1
syn match  ecdTagError	contained "[^>]<"ms=s+1

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link ecdComment	Comment
hi def link ecdAttr	Type
hi def link ecdAttrN	Statement
hi def link ecdAttrV	Value
hi def link ecdTag		Function
hi def link ecdTagN	Statement
hi def link ecdTagError	Error


let b:current_syntax = "ecd"
" vim: ts=8
