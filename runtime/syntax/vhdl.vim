" Vim syntax file
" Language:		VHDL [VHSIC (Very High Speed Integrated Circuit) Hardware Description Language]
" Maintainer:		Daniel Kho <daniel.kho@tauhop.com>
" Previous Maintainer:	Czo <Olivier.Sirol@lip6.fr>
" Credits:		Stephan Hegel <stephan.hegel@snc.siemens.com.cn>
" Last Changed:		2018 May 06 by Daniel Kho

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" case is not significant
syn case	ignore

" VHDL keywords
syn keyword	vhdlStatement	access after alias all assert
syn keyword 	vhdlStatement	architecture array attribute
syn keyword 	vhdlStatement	assume assume_guarantee
syn keyword 	vhdlStatement	begin block body buffer bus
syn keyword 	vhdlStatement	case component configuration constant
syn keyword 	vhdlStatement	context cover
syn keyword 	vhdlStatement	default disconnect downto
syn keyword 	vhdlStatement	elsif end entity exit
syn keyword 	vhdlStatement	file for function
syn keyword 	vhdlStatement	fairness force
syn keyword 	vhdlStatement	generate generic group guarded
syn keyword 	vhdlStatement	impure in inertial inout is
syn keyword 	vhdlStatement	label library linkage literal loop
syn keyword 	vhdlStatement	map
syn keyword 	vhdlStatement	new next null
syn keyword 	vhdlStatement	of on open others out
syn keyword 	vhdlStatement	package port postponed procedure process pure
syn keyword 	vhdlStatement	parameter property protected
syn keyword 	vhdlStatement	range record register reject report return
syn keyword 	vhdlStatement	release restrict restrict_guarantee
syn keyword 	vhdlStatement	select severity signal shared
syn keyword 	vhdlStatement	subtype
syn keyword 	vhdlStatement	sequence strong
syn keyword 	vhdlStatement	then to transport type
syn keyword 	vhdlStatement	unaffected units until use
syn keyword 	vhdlStatement	variable
" VHDL-2017 interface
syn keyword 	vhdlStatement	view
syn keyword 	vhdlStatement	vmode vprop vunit
syn keyword 	vhdlStatement	wait when while with
syn keyword 	vhdlStatement	note warning error failure

" Linting of conditionals.
syn match	vhdlStatement	"\<\(if\|else\)\>"
syn match	vhdlError	"\<else\s\+if\>"

" Types and type qualifiers
" Predefined standard VHDL types
syn match	vhdlType	"\<bit\>\'\="
syn match	vhdlType	"\<boolean\>\'\="
syn match	vhdlType	"\<natural\>\'\="
syn match	vhdlType	"\<positive\>\'\="
syn match	vhdlType	"\<integer\>\'\="
syn match	vhdlType	"\<real\>\'\="
syn match	vhdlType	"\<time\>\'\="

syn match	vhdlType	"\<bit_vector\>\'\="
syn match	vhdlType	"\<boolean_vector\>\'\="
syn match	vhdlType	"\<integer_vector\>\'\="
syn match	vhdlType	"\<real_vector\>\'\="
syn match	vhdlType	"\<time_vector\>\'\="

syn match	vhdlType	"\<character\>\'\="
syn match	vhdlType	"\<string\>\'\="
syn keyword	vhdlType	line text side width

" Predefined standard IEEE VHDL types
syn match	vhdlType	"\<std_ulogic\>\'\="
syn match	vhdlType	"\<std_logic\>\'\="
syn match	vhdlType	"\<std_ulogic_vector\>\'\="
syn match	vhdlType	"\<std_logic_vector\>\'\="
syn match	vhdlType	"\<unresolved_signed\>\'\="
syn match	vhdlType	"\<unresolved_unsigned\>\'\="
syn match	vhdlType	"\<u_signed\>\'\="
syn match	vhdlType	"\<u_unsigned\>\'\="
syn match	vhdlType	"\<signed\>\'\="
syn match	vhdlType	"\<unsigned\>\'\="


" array attributes
syn match	vhdlAttribute	"\'high"
syn match	vhdlAttribute	"\'left"
syn match	vhdlAttribute	"\'length"
syn match	vhdlAttribute	"\'low"
syn match	vhdlAttribute	"\'range"
syn match	vhdlAttribute	"\'reverse_range"
syn match	vhdlAttribute	"\'right"
syn match	vhdlAttribute	"\'ascending"
" block attributes
syn match	vhdlAttribute	"\'simple_name"
syn match   	vhdlAttribute	"\'instance_name"
syn match   	vhdlAttribute	"\'path_name"
syn match   	vhdlAttribute	"\'foreign"	    " VHPI
" signal attribute
syn match	vhdlAttribute	"\'active"
syn match   	vhdlAttribute	"\'delayed"
syn match   	vhdlAttribute	"\'event"
syn match   	vhdlAttribute	"\'last_active"
syn match   	vhdlAttribute	"\'last_event"
syn match   	vhdlAttribute	"\'last_value"
syn match   	vhdlAttribute	"\'quiet"
syn match   	vhdlAttribute	"\'stable"
syn match   	vhdlAttribute	"\'transaction"
syn match   	vhdlAttribute	"\'driving"
syn match   	vhdlAttribute	"\'driving_value"
" type attributes
syn match	vhdlAttribute	"\'base"
syn match   	vhdlAttribute	"\'subtype"
syn match   	vhdlAttribute	"\'element"
syn match   	vhdlAttribute	"\'leftof"
syn match   	vhdlAttribute	"\'pos"
syn match   	vhdlAttribute	"\'pred"
syn match   	vhdlAttribute	"\'rightof"
syn match   	vhdlAttribute	"\'succ"
syn match   	vhdlAttribute	"\'val"
syn match   	vhdlAttribute	"\'image"
syn match   	vhdlAttribute	"\'value"
" VHDL-2017 interface attribute
syn match   	vhdlAttribute	"\'converse"

syn keyword	vhdlBoolean	true false

" for this vector values case is significant
syn case	match
" Values for standard VHDL types
syn match	vhdlVector	"\'[0L1HXWZU\-\?]\'"
syn case	ignore

syn match	vhdlVector	"B\"[01_]\+\""
syn match   	vhdlVector	"O\"[0-7_]\+\""
syn match   	vhdlVector	"X\"[0-9a-f_]\+\""
syn match   	vhdlCharacter   "'.'"
syn region  	vhdlString	start=+"+  end=+"+

" floating numbers
syn match	vhdlNumber	"-\=\<\d\+\.\d\+\(E[+\-]\=\d\+\)\>"
syn match	vhdlNumber	"-\=\<\d\+\.\d\+\>"
syn match	vhdlNumber	"0*2#[01_]\+\.[01_]\+#\(E[+\-]\=\d\+\)\="
syn match	vhdlNumber	"0*16#[0-9a-f_]\+\.[0-9a-f_]\+#\(E[+\-]\=\d\+\)\="
" integer numbers
syn match	vhdlNumber	"-\=\<\d\+\(E[+\-]\=\d\+\)\>"
syn match	vhdlNumber	"-\=\<\d\+\>"
syn match	vhdlNumber	"0*2#[01_]\+#\(E[+\-]\=\d\+\)\="
syn match	vhdlNumber	"0*16#[0-9a-f_]\+#\(E[+\-]\=\d\+\)\="

" operators
syn keyword	vhdlOperator	and nand or nor xor xnor
syn keyword	vhdlOperator	rol ror sla sll sra srl
syn keyword	vhdlOperator	mod rem abs not

" Concatenation and math operators
syn match	vhdlOperator	"&\|+\|-\|\*\|\/"

" Equality and comparison operators
syn match	vhdlOperator	"=\|\/=\|>\|<\|>="

" Assignment operators
syn match	vhdlOperator	"<=\|:="
syn match	vhdlOperator	"=>"

" VHDL-2017 concurrent signal association (spaceship) operator
syn match	vhdlOperator	"<=>"

" VHDL-2008 conversion, matching equality/non-equality operators
syn match	vhdlOperator	"??\|?=\|?\/=\|?<\|?<=\|?>\|?>="

" VHDL-2008 external names
syn match	vhdlOperator	"<<\|>>"

" Linting for illegal operators
" '='
syn match	vhdlError	"\(=\)[<=&+\-\*\/\\]\+"
syn match	vhdlError	"[=&+\-\*\\]\+\(=\)"
" '>', '<'
" Allow external names: '<< ... >>'
syn match	vhdlError	"\(>\)[<&+\-\/\\]\+"
syn match	vhdlError	"[&+\-\/\\]\+\(>\)"
syn match	vhdlError	"\(<\)[&+\-\/\\]\+"
syn match	vhdlError	"[>=&+\-\/\\]\+\(<\)"
" Covers most operators
" support negative sign after operators. E.g. q<=-b;
" Supports VHDL-2017 spaceship (concurrent simple signal association).
syn match	vhdlError	"\(<=\)[<=&+\*\\?:]\+"
syn match	vhdlError	"[>=&+\-\*\\:]\+\(=>\)"
syn match	vhdlError	"\(&\|+\|\-\|\*\*\|\/=\|??\|?=\|?\/=\|?<=\|?>=\|>=\|:=\|=>\)[<>=&+\*\\?:]\+"
syn match	vhdlError	"[<>=&+\-\*\\:]\+\(&\|+\|\*\*\|\/=\|??\|?=\|?\/=\|?<\|?<=\|?>\|?>=\|>=\|<=\|:=\)"
syn match	vhdlError	"\(?<\|?>\)[<>&+\*\/\\?:]\+"
syn match	vhdlError	"\(<<\|>>\)[<>&+\*\/\\?:]\+"

"syn match	vhdlError	"[?]\+\(&\|+\|\-\|\*\*\|??\|?=\|?\/=\|?<\|?<=\|?>\|?>=\|:=\|=>\)"
" '/'
syn match	vhdlError	"\(\/\)[<>&+\-\*\/\\?:]\+"
syn match	vhdlError	"[<>=&+\-\*\/\\:]\+\(\/\)"

syn match	vhdlSpecial	"<>"
syn match	vhdlSpecial	"[().,;]"


" time
syn match	vhdlTime	"\<\d\+\s\+\(\([fpnum]s\)\|\(sec\)\|\(min\)\|\(hr\)\)\>"
syn match	vhdlTime	"\<\d\+\.\d\+\s\+\(\([fpnum]s\)\|\(sec\)\|\(min\)\|\(hr\)\)\>"

syn case	match
syn keyword	vhdlTodo	contained TODO NOTE
syn keyword	vhdlFixme	contained FIXME
syn case	ignore

syn region	vhdlComment	start="/\*" end="\*/"	contains=vhdlTodo,vhdlFixme,@Spell
syn match	vhdlComment	"\(^\|\s\)--.*"		contains=vhdlTodo,vhdlFixme,@Spell

" Standard IEEE P1076.6 preprocessor directives (metacomments).
syn match	vhdlPreProc	"/\*\s*rtl_synthesis\s\+\(on\|off\)\s*\*/"
syn match	vhdlPreProc	"\(^\|\s\)--\s*rtl_synthesis\s\+\(on\|off\)\s*"
syn match	vhdlPreProc	"/\*\s*rtl_syn\s\+\(on\|off\)\s*\*/"
syn match	vhdlPreProc	"\(^\|\s\)--\s*rtl_syn\s\+\(on\|off\)\s*"

" Industry-standard directives. These are not standard VHDL, but are commonly
" used in the industry.
syn match	vhdlPreProc	"/\*\s*synthesis\s\+translate_\(on\|off\)\s*\*/"
"syn match	vhdlPreProc	"/\*\s*simulation\s\+translate_\(on\|off\)\s*\*/"
syn match	vhdlPreProc	"/\*\s*pragma\s\+translate_\(on\|off\)\s*\*/"
syn match	vhdlPreProc	"/\*\s*pragma\s\+synthesis_\(on\|off\)\s*\*/"
syn match	vhdlPreProc	"/\*\s*synopsys\s\+translate_\(on\|off\)\s*\*/"

syn match	vhdlPreProc	"\(^\|\s\)--\s*synthesis\s\+translate_\(on\|off\)\s*"
"syn match	vhdlPreProc	"\(^\|\s\)--\s*simulation\s\+translate_\(on\|off\)\s*"
syn match	vhdlPreProc	"\(^\|\s\)--\s*pragma\s\+translate_\(on\|off\)\s*"
syn match	vhdlPreProc	"\(^\|\s\)--\s*pragma\s\+synthesis_\(on\|off\)\s*"
syn match	vhdlPreProc	"\(^\|\s\)--\s*synopsys\s\+translate_\(on\|off\)\s*"

"Modify the following as needed.  The trade-off is performance versus functionality.
syn sync	minlines=600

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link vhdlSpecial	Special
hi def link vhdlStatement   Statement
hi def link vhdlCharacter   Character
hi def link vhdlString	String
hi def link vhdlVector	Number
hi def link vhdlBoolean	Number
hi def link vhdlTodo	Todo
hi def link vhdlFixme	Fixme
hi def link vhdlComment	Comment
hi def link vhdlNumber	Number
hi def link vhdlTime	Number
hi def link vhdlType	Type
hi def link vhdlOperator    Operator
hi def link vhdlError	Error
hi def link vhdlAttribute   Special
hi def link vhdlPreProc	PreProc


let b:current_syntax = "vhdl"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
