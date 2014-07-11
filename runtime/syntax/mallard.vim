" Vim syntax file
" Language:    Mallard
" Maintainer:  Jaromir Hradilek <jhradilek@gmail.com>
" URL:         https://github.com/jhradilek/vim-syntax
" Last Change: 11 February 2013
" Description: A syntax file for the Mallard markup language according to
"              Mallard 1.0 DRAFT as of 2013-02-11.

if exists("b:current_syntax")
  finish
endif

do Syntax xml
syn cluster xmlTagHook add=mallardTagName
syn spell toplevel
syn case match

syn keyword mallardTagName app cite cmd code col colgroup comment contained
syn keyword mallardTagName credit desc em email example figure contained
syn keyword mallardTagName file gui guiseq info input item key contained
syn keyword mallardTagName keyseq license link links list listing contained
syn keyword mallardTagName media name note output p page quote contained
syn keyword mallardTagName revision screen section span steps contained
syn keyword mallardTagName subtitle synopsis sys table tbody td contained
syn keyword mallardTagName terms tfoot thead title tr tree var contained
syn keyword mallardTagName years contained

syn region mallardComment start="<comment\>" end="</comment>"me=e-10 contains=xmlTag,xmlNamespace,xmlTagName,xmlEndTag,xmlRegion,xmlEntity,@Spell keepend
syn region mallardEmphasis start="<em\>" end="</em>"me=e-5 contains=xmlTag,xmlNamespace,xmlTagName,xmlEndTag,xmlRegion,xmlEntity,@Spell keepend
syn region mallardTitle start="<title\>" end="</title>"me=e-8 contains=xmlTag,xmlNamespace,xmlTagName,xmlEndTag,xmlRegion,xmlEntity,@Spell keepend

hi def link mallardComment  Comment
hi def link mallardTagName  Statement
hi def link mallardTitle    Title
hi def mallardEmphasis term=italic cterm=italic gui=italic

let b:current_syntax = "mallard"
