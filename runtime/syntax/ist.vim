" Vim syntax file
" Language:	Makeindex style file, *.ist
" Maintainer:	Peter Meszaros <pmeszaros@effice.hu>
" Last Change:	2012 Jan 08 by Thilo Six

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

if version >= 600
  setlocal iskeyword=$,@,48-57,_
else
  set iskeyword=$,@,48-57,_
endif

syn case ignore
syn keyword IstInpSpec  actual  arg_close arg_open encap       escape
syn keyword IstInpSpec  keyword level     quote    range_close range_open
syn keyword IstInpSpec  page_compositor

syn keyword IstOutSpec	preamble	 postamble	  setpage_prefix   setpage_suffix   group_skip
syn keyword IstOutSpec	headings_flag	 heading_prefix   heading_suffix
syn keyword IstOutSpec	lethead_flag	 lethead_prefix   lethead_suffix
syn keyword IstOutSpec	symhead_positive symhead_negative numhead_positive numhead_negative
syn keyword IstOutSpec	item_0		 item_1		  item_2	   item_01
syn keyword IstOutSpec	item_x1		 item_12	  item_x2
syn keyword IstOutSpec	delim_0		 delim_1	  delim_2
syn keyword IstOutSpec	delim_n		 delim_r	  delim_t
syn keyword IstOutSpec	encap_prefix	 encap_infix	  encap_suffix
syn keyword IstOutSpec	line_max	 indent_space	  indent_length
syn keyword IstOutSpec	suffix_2p	 suffix_3p	  suffix_mp

syn region  IstString	   matchgroup=IstDoubleQuote start=+"+ skip=+\\"+ end=+"+ contains=IstSpecial
syn match   IstCharacter   "'.'"
syn match   IstNumber	   "\d\+"
syn match   IstComment	   "^[\t ]*%.*$"	 contains=IstTodo
syn match   IstSpecial	   "\\\\\|{\|}\|#\|\\n"  contained
syn match   IstTodo	   "DEBUG\|TODO"	 contained

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dummy_syn_inits")
  if version < 508
    let did_dummy_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink IstInpSpec	Type
  HiLink IstOutSpec	Identifier
  HiLink IstString	String
  HiLink IstNumber	Number
  HiLink IstComment	Comment
  HiLink IstTodo	Todo
  HiLink IstSpecial	Special
  HiLink IstDoubleQuote	Label
  HiLink IstCharacter	Label

  delcommand HiLink
endif

let b:current_syntax = "ist"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8 sw=2
