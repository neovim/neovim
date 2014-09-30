" Vim syntax file
" Language:	ecd (Embedix Component Description) files
" Maintainer:	John Beppu <beppu@opensource.lineo.com>
" URL:		http://opensource.lineo.com/~beppu/prose/ecd_vim.html
" Last Change:	2001 Sep 27

" An ECD file contains meta-data for packages in the Embedix Linux distro.
" This syntax file was derived from apachestyle.vim
" by Christian Hammers <ch@westend.com>

" Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_ecd_syn_inits")
  if version < 508
    let did_ecd_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink ecdComment	Comment
  HiLink ecdAttr	Type
  HiLink ecdAttrN	Statement
  HiLink ecdAttrV	Value
  HiLink ecdTag		Function
  HiLink ecdTagN	Statement
  HiLink ecdTagError	Error

  delcommand HiLink
endif

let b:current_syntax = "ecd"
" vim: ts=8
