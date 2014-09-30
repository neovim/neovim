" Vim syntax file
" Language:	SNNS result file
" Maintainer:	Davide Alberani <alberanid@bigfoot.com>
" Last Change:	28 Apr 2001
" Version:	0.2
" URL:		http://digilander.iol.it/alberanid/vim/syntax/snnsres.vim
"
" SNNS http://www-ra.informatik.uni-tuebingen.de/SNNS/
" is a simulator for neural networks.

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" the accepted fields in the header
syn match	snnsresNoHeader	"No\. of patterns\s*:\s*" contained
syn match	snnsresNoHeader	"No\. of input units\s*:\s*" contained
syn match	snnsresNoHeader	"No\. of output units\s*:\s*" contained
syn match	snnsresNoHeader	"No\. of variable input dimensions\s*:\s*" contained
syn match	snnsresNoHeader	"No\. of variable output dimensions\s*:\s*" contained
syn match	snnsresNoHeader	"Maximum input dimensions\s*:\s*" contained
syn match	snnsresNoHeader	"Maximum output dimensions\s*:\s*" contained
syn match	snnsresNoHeader	"startpattern\s*:\s*" contained
syn match	snnsresNoHeader "endpattern\s*:\s*" contained
syn match	snnsresNoHeader "input patterns included" contained
syn match	snnsresNoHeader "teaching output included" contained
syn match	snnsresGen	"generated at.*" contained contains=snnsresNumbers
syn match	snnsresGen	"SNNS result file [Vv]\d\.\d" contained contains=snnsresNumbers

" the header, what is not an accepted field, is an error
syn region	snnsresHeader	start="^SNNS" end="^\s*[-+\.]\=[0-9#]"me=e-2 contains=snnsresNoHeader,snnsresNumbers,snnsresGen

" numbers inside the header
syn match	snnsresNumbers	"\d" contained
syn match	snnsresComment	"#.*$" contains=snnsresTodo
syn keyword	snnsresTodo	TODO XXX FIXME contained

if version >= 508 || !exists("did_snnsres_syn_inits")
  if version < 508
    let did_snnsres_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink snnsresGen		Statement
  HiLink snnsresHeader		Statement
  HiLink snnsresNoHeader	Define
  HiLink snnsresNumbers		Number
  HiLink snnsresComment		Comment
  HiLink snnsresTodo		Todo

  delcommand HiLink
endif

let b:current_syntax = "snnsres"

" vim: ts=8 sw=2
