" Vim syntax file
" Language:	VHDL
" Maintainer:	Daniel Kho <daniel.kho@tauhop.com>
" Previous Maintainer:	Czo <Olivier.Sirol@lip6.fr>
" Credits:	Stephan Hegel <stephan.hegel@snc.siemens.com.cn>
" Last Changed:	2015 Apr 25 by Daniel Kho
" $Id: vhdl.vim,v 1.1 2004/06/13 15:34:56 vimboss Exp $

" VHSIC (Very High Speed Integrated Circuit) Hardware Description Language

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" This is not VHDL. I use the C-Preprocessor cpp to generate different binaries
" from one VHDL source file. Unfortunately there is no preprocessor for VHDL
" available. If you don't like this, please remove the following lines.
"syn match cDefine "^#ifdef[ ]\+[A-Za-z_]\+"
"syn match cDefine "^#endif"

" case is not significant
syn case ignore

" VHDL keywords
syn keyword vhdlStatement access after alias all assert
syn keyword vhdlStatement architecture array attribute
syn keyword vhdlStatement assume assume_guarantee
syn keyword vhdlStatement begin block body buffer bus
syn keyword vhdlStatement case component configuration constant
syn keyword vhdlStatement context cover
syn keyword vhdlStatement default disconnect downto
syn keyword vhdlStatement elsif end entity exit
syn keyword vhdlStatement file for function
syn keyword vhdlStatement fairness force
syn keyword vhdlStatement generate generic group guarded
syn keyword vhdlStatement impure in inertial inout is
syn keyword vhdlStatement label library linkage literal loop
syn keyword vhdlStatement map
syn keyword vhdlStatement new next null
syn keyword vhdlStatement of on open others out
syn keyword vhdlStatement package port postponed procedure process pure
syn keyword vhdlStatement parameter property protected
syn keyword vhdlStatement range record register reject report return
syn keyword vhdlStatement release restrict restrict_guarantee
syn keyword vhdlStatement select severity signal shared
syn keyword vhdlStatement subtype
syn keyword vhdlStatement sequence strong
syn keyword vhdlStatement then to transport type
syn keyword vhdlStatement unaffected units until use
syn keyword vhdlStatement variable
syn keyword vhdlStatement vmode vprop vunit
syn keyword vhdlStatement wait when while with
syn keyword vhdlStatement note warning error failure

" Special match for "if" and "else" since "else if" shouldn't be highlighted.
" The right keyword is "elsif"
syn match   vhdlStatement "\<\(if\|else\)\>"
syn match   vhdlNone      "\<else\s\+if\>$"
syn match   vhdlNone      "\<else\s\+if\>\s"

" Predefined VHDL types
syn keyword vhdlType bit bit_vector
syn keyword vhdlType character boolean integer real time
syn keyword vhdlType boolean_vector integer_vector real_vector time_vector
syn keyword vhdlType string severity_level
" Predefined standard ieee VHDL types
syn keyword vhdlType positive natural signed unsigned
syn keyword vhdlType line text
syn keyword vhdlType std_logic std_logic_vector
syn keyword vhdlType std_ulogic std_ulogic_vector
" Predefined non standard VHDL types for Mentor Graphics Sys1076/QuickHDL
"syn keyword vhdlType qsim_state qsim_state_vector
"syn keyword vhdlType qsim_12state qsim_12state_vector
"syn keyword vhdlType qsim_strength
" Predefined non standard VHDL types for Alliance VLSI CAD
"syn keyword vhdlType mux_bit mux_vector reg_bit reg_vector wor_bit wor_vector

" array attributes
syn match vhdlAttribute "\'high"
syn match vhdlAttribute "\'left"
syn match vhdlAttribute "\'length"
syn match vhdlAttribute "\'low"
syn match vhdlAttribute "\'range"
syn match vhdlAttribute "\'reverse_range"
syn match vhdlAttribute "\'right"
syn match vhdlAttribute "\'ascending"
" block attributes
syn match vhdlAttribute "\'behaviour"
syn match vhdlAttribute "\'structure"
syn match vhdlAttribute "\'simple_name"
syn match vhdlAttribute "\'instance_name"
syn match vhdlAttribute "\'path_name"
syn match vhdlAttribute "\'foreign"
" signal attribute
syn match vhdlAttribute "\'active"
syn match vhdlAttribute "\'delayed"
syn match vhdlAttribute "\'event"
syn match vhdlAttribute "\'last_active"
syn match vhdlAttribute "\'last_event"
syn match vhdlAttribute "\'last_value"
syn match vhdlAttribute "\'quiet"
syn match vhdlAttribute "\'stable"
syn match vhdlAttribute "\'transaction"
syn match vhdlAttribute "\'driving"
syn match vhdlAttribute "\'driving_value"
" type attributes
syn match vhdlAttribute "\'base"
syn match vhdlAttribute "\'high"
syn match vhdlAttribute "\'left"
syn match vhdlAttribute "\'leftof"
syn match vhdlAttribute "\'low"
syn match vhdlAttribute "\'pos"
syn match vhdlAttribute "\'pred"
syn match vhdlAttribute "\'rightof"
syn match vhdlAttribute "\'succ"
syn match vhdlAttribute "\'val"
syn match vhdlAttribute "\'image"
syn match vhdlAttribute "\'value"

syn keyword vhdlBoolean true false

" for this vector values case is significant
syn case match
" Values for standard VHDL types
syn match vhdlVector "\'[0L1HXWZU\-\?]\'"
" Values for non standard VHDL types qsim_12state for Mentor Graphics Sys1076/QuickHDL
"syn keyword vhdlVector S0S S1S SXS S0R S1R SXR S0Z S1Z SXZ S0I S1I SXI
syn case ignore

syn match  vhdlVector "B\"[01_]\+\""
syn match  vhdlVector "O\"[0-7_]\+\""
syn match  vhdlVector "X\"[0-9a-f_]\+\""
syn match  vhdlCharacter "'.'"
syn region vhdlString start=+"+  end=+"+

" floating numbers
syn match vhdlNumber "-\=\<\d\+\.\d\+\(E[+\-]\=\d\+\)\>"
syn match vhdlNumber "-\=\<\d\+\.\d\+\>"
syn match vhdlNumber "0*2#[01_]\+\.[01_]\+#\(E[+\-]\=\d\+\)\="
syn match vhdlNumber "0*16#[0-9a-f_]\+\.[0-9a-f_]\+#\(E[+\-]\=\d\+\)\="
" integer numbers
syn match vhdlNumber "-\=\<\d\+\(E[+\-]\=\d\+\)\>"
syn match vhdlNumber "-\=\<\d\+\>"
syn match vhdlNumber "0*2#[01_]\+#\(E[+\-]\=\d\+\)\="
syn match vhdlNumber "0*16#[0-9a-f_]\+#\(E[+\-]\=\d\+\)\="
" operators
syn keyword vhdlOperator and nand or nor xor xnor
syn keyword vhdlOperator rol ror sla sll sra srl
syn keyword vhdlOperator mod rem abs not
syn match   vhdlOperator "[&><=:+\-*\/|]"
syn match   vhdlSpecial  "[().,;]"
" time
syn match vhdlTime "\<\d\+\s\+\(\([fpnum]s\)\|\(sec\)\|\(min\)\|\(hr\)\)\>"
syn match vhdlTime "\<\d\+\.\d\+\s\+\(\([fpnum]s\)\|\(sec\)\|\(min\)\|\(hr\)\)\>"

syn keyword vhdlTodo	contained TODO NOTE
syn keyword vhdlFixme	contained FIXME

" Regex for space is '\s'
"   Any number of spaces: \s*
"   At least one space:	  \s+
syn region vhdlComment start="/\*" end="\*/" contains=vhdlTodo,vhdlFixme,@Spell
syn match vhdlComment "--.*" contains=vhdlTodo,vhdlFixme,@Spell
syn match vhdlPreProc "/\* synthesis .* \*/"
syn match vhdlPreProc "/\* pragma .* \*/"
syn match vhdlPreProc "/\* synopsys .* \*/"
syn match vhdlPreProc "--\s*synthesis .*"
syn match vhdlPreProc "--\s*pragma .*"
syn match vhdlPreProc "--\s*synopsys .*"
" syn match vhdlGlobal "[\'$#~!%@?\^\[\]{}\\]"

"Modify the following as needed.  The trade-off is performance versus functionality.
syn sync minlines=200

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_vhdl_syntax_inits")
  if version < 508
    let did_vhdl_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink vhdlSpecial	Special
  HiLink vhdlStatement	Statement
  HiLink vhdlCharacter	Character
  HiLink vhdlString	String
  HiLink vhdlVector	Number
  HiLink vhdlBoolean  	Number
  HiLink vhdlTodo	Todo
  HiLink vhdlFixme	Fixme
  HiLink vhdlComment	Comment
  HiLink vhdlNumber	Number
  HiLink vhdlTime	Number
  HiLink vhdlType	Type
  HiLink vhdlOperator	Operator
"  HiLink vhdlGlobal    Error
  HiLink vhdlAttribute	Special
  HiLink vhdlPreProc	PreProc

  delcommand HiLink
endif

let b:current_syntax = "vhdl"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
