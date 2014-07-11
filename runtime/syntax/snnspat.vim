" Vim syntax file
" Language:	SNNS pattern file
" Maintainer:	Davide Alberani <alberanid@bigfoot.com>
" Last Change:	2012 Feb 03 by Thilo Six
" Version:	0.2
" URL:		http://digilander.iol.it/alberanid/vim/syntax/snnspat.vim
"
" SNNS http://www-ra.informatik.uni-tuebingen.de/SNNS/
" is a simulator for neural networks.

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" anything that isn't part of the header, a comment or a number
" is wrong
syn match	snnspatError	".*"
" hoping that matches any kind of notation...
syn match	snnspatAccepted	"\([-+]\=\(\d\+\.\|\.\)\=\d\+\([Ee][-+]\=\d\+\)\=\)"
syn match	snnspatAccepted "\s"
syn match	snnspatBrac	"\[\s*\d\+\(\s\|\d\)*\]" contains=snnspatNumbers

" the accepted fields in the header
syn match	snnspatNoHeader	"No\. of patterns\s*:\s*" contained
syn match	snnspatNoHeader	"No\. of input units\s*:\s*" contained
syn match	snnspatNoHeader	"No\. of output units\s*:\s*" contained
syn match	snnspatNoHeader	"No\. of variable input dimensions\s*:\s*" contained
syn match	snnspatNoHeader	"No\. of variable output dimensions\s*:\s*" contained
syn match	snnspatNoHeader	"Maximum input dimensions\s*:\s*" contained
syn match	snnspatNoHeader	"Maximum output dimensions\s*:\s*" contained
syn match	snnspatGen	"generated at.*" contained contains=snnspatNumbers
syn match	snnspatGen	"SNNS pattern definition file [Vv]\d\.\d" contained contains=snnspatNumbers

" the header, what is not an accepted field, is an error
syn region	snnspatHeader	start="^SNNS" end="^\s*[-+\.]\=[0-9#]"me=e-2 contains=snnspatNoHeader,snnspatNumbers,snnspatGen,snnspatBrac

" numbers inside the header
syn match	snnspatNumbers	"\d" contained
syn match	snnspatComment	"#.*$" contains=snnspatTodo
syn keyword	snnspatTodo	TODO XXX FIXME contained

if version >= 508 || !exists("did_snnspat_syn_inits")
  if version < 508
    let did_snnspat_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink snnspatGen		Statement
  HiLink snnspatHeader		Error
  HiLink snnspatNoHeader	Define
  HiLink snnspatNumbers		Number
  HiLink snnspatComment		Comment
  HiLink snnspatError		Error
  HiLink snnspatTodo		Todo
  HiLink snnspatAccepted	NONE
  HiLink snnspatBrac		NONE

  delcommand HiLink
endif

let b:current_syntax = "snnspat"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8 sw=2
