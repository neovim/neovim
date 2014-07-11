" Vim syntax file
" Language:	SPECMAN E-LANGUAGE
" Maintainer:	Or Freund <or@mobilian.com ;omf@gmx.co.uk; OrMeir@yahoo.com>
" Last Update: Wed Oct 24 2001

"---------------------------------------------------------
"| If anyone found an error or fix the parenthesis part  |
"| I will be happy to hear about it			 |
"| Thanks Or.						 |
"---------------------------------------------------------

" Remove any old syntax stuff hanging around
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn keyword  specmanTodo	contained TODO todo ToDo FIXME XXX

syn keyword specmanStatement   var instance on compute start event expect check that routine
syn keyword specmanStatement   specman is also first only with like
syn keyword specmanStatement   list of all radix hex dec bin ignore illegal
syn keyword specmanStatement   traceable untraceable
syn keyword specmanStatement   cover using count_only trace_only at_least transition item ranges
syn keyword specmanStatement   cross text call task within

syn keyword specmanMethod      initialize non_terminal testgroup delayed exit finish
syn keyword specmanMethod      out append print outf appendf
syn keyword specmanMethod      post_generate pre_generate setup_test finalize_test extract_test
syn keyword specmanMethod      init run copy as_a set_config dut_error add clear lock quit
syn keyword specmanMethod      lock unlock release swap quit to_string value stop_run
syn keyword specmanMethod      crc_8 crc_32 crc_32_flip get_config add0 all_indices and_all
syn keyword specmanMethod      apply average count delete exists first_index get_indices
syn keyword specmanMethod      has insert is_a_permutation is_empty key key_exists key_index
syn keyword specmanMethod      last last_index max max_index max_value min min_index
syn keyword specmanMethod      min_value or_all pop pop0 push push0 product resize reverse
syn keyword specmanMethod      sort split sum top top0 unique clear is_all_iterations
syn keyword specmanMethod      get_enclosing_unit hdl_path exec deep_compare deep_compare_physical
syn keyword specmanMethod      pack unpack warning error fatal
syn match   specmanMethod      "size()"
syn keyword specmanPacking     packing low high
syn keyword specmanType        locker address
syn keyword specmanType        body code vec chars
syn keyword specmanType        integer real bool int long uint byte bits bit time string
syn keyword specmanType        byte_array external_pointer
syn keyword specmanBoolean     TRUE FALSE
syn keyword specmanPreCondit   #ifdef #ifndef #else

syn keyword specmanConditional choose matches
syn keyword specmanConditional if then else when try



syn keyword specmanLabel  case casex casez default

syn keyword specmanLogical     and or not xor

syn keyword specmanRepeat      until repeat while for from to step each do break continue
syn keyword specmanRepeat      before next sequence always -kind network
syn keyword specmanRepeat      index it me in new return result select

syn keyword specmanTemporal    cycle sample events forever
syn keyword specmanTemporal    wait  change  negedge rise fall delay sync sim true detach eventually emit

syn keyword specmanConstant    MAX_INT MIN_INT NULL UNDEF

syn keyword specmanDefine       define as computed type extend
syn keyword specmanDefine       verilog vhdl variable global sys
syn keyword specmanStructure    struct unit
syn keyword specmanInclude     import
syn keyword specmanConstraint  gen keep keeping soft	before

syn keyword specmanSpecial     untyped symtab ECHO DOECHO
syn keyword specmanFile        files load module ntv source_ref script read write
syn keyword specmanFSM	       initial idle others posedge clock cycles


syn match   specmanOperator    "[&|~><!)(*%@+/=?:;}{,.\^\-\[\]]"
syn match   specmanOperator    "+="
syn match   specmanOperator    "-="
syn match   specmanOperator    "*="

syn match   specmanComment     "//.*"  contains=specmanTodo
syn match   specmanComment     "--.*"
syn region  specmanComment     start="^'>"hs=s+2 end="^<'"he=e-2

syn match   specmanHDL	       "'[`.a-zA-Z0-9_@\[\]]\+\>'"


syn match   specmanCompare    "=="
syn match   specmanCompare    "!==="
syn match   specmanCompare    "==="
syn match   specmanCompare    "!="
syn match   specmanCompare    ">="
syn match   specmanCompare    "<="
syn match   specmanNumber "[0-9]:[0-9]"
syn match   specmanNumber "\(\<\d\+\|\)'[bB]\s*[0-1_xXzZ?]\+\>"
syn match   specmanNumber "0[bB]\s*[0-1_xXzZ?]\+\>"
syn match   specmanNumber "\(\<\d\+\|\)'[oO]\s*[0-7_xXzZ?]\+\>"
syn match   specmanNumber "0[oO]\s*[0-9a-fA-F_xXzZ?]\+\>"
syn match   specmanNumber "\(\<\d\+\|\)'[dD]\s*[0-9_xXzZ?]\+\>"
syn match   specmanNumber "\(\<\d\+\|\)'[hH]\s*[0-9a-fA-F_xXzZ?]\+\>"
syn match   specmanNumber "0[xX]\s*[0-9a-fA-F_xXzZ?]\+\>"
syn match   specmanNumber "\<[+-]\=[0-9_]\+\(\.[0-9_]*\|\)\(e[0-9_]*\|\)\>"

syn region  specmanString start=+"+  end=+"+



"**********************************************************************
" I took this section from c.vim but I didnt succeded to make it work
" ANY one who dare jumping to this deep watter is more than welocome!
"**********************************************************************
""catch errors caused by wrong parenthesis and brackets

"syn cluster     specmanParenGroup     contains=specmanParenError
"" ,specmanNumbera,specmanComment
"if exists("specman_no_bracket_error")
"syn region    specmanParen	     transparent start='(' end=')' contains=ALLBUT,@specmanParenGroup
"syn match     specmanParenError     ")"
"syn match     specmanErrInParen     contained "[{}]"
"else
"syn region    specmanParen	     transparent start='(' end=')' contains=ALLBUT,@specmanParenGroup,specmanErrInBracket
"syn match     specmanParenError     "[\])]"
"syn match     specmanErrInParen     contained "[\]{}]"
"syn region    specmanBracket	     transparent start='\[' end=']' contains=ALLBUT,@specmanParenGroup,specmanErrInParen
"syn match     specmanErrInBracket   contained "[);{}]"
"endif
"

"Modify the following as needed.  The trade-off is performance versus
"functionality.

syn sync lines=50

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_specman_syn_inits")
  if version < 508
    let did_specman_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif
  " The default methods for highlighting.  Can be overridden later
	HiLink	specmanConditional	Conditional
	HiLink	specmanConstraint	Conditional
	HiLink	specmanRepeat		Repeat
	HiLink	specmanString		String
	HiLink	specmanComment		Comment
	HiLink	specmanConstant		Macro
	HiLink	specmanNumber		Number
	HiLink	specmanCompare		Operator
	HiLink	specmanOperator		Operator
	HiLink	specmanLogical		Operator
	HiLink	specmanStatement	Statement
	HiLink	specmanHDL		SpecialChar
	HiLink	specmanMethod		Function
	HiLink	specmanInclude		Include
	HiLink	specmanStructure	Structure
	HiLink	specmanBoolean		Boolean
	HiLink	specmanFSM		Label
	HiLink	specmanSpecial		Special
	HiLink	specmanType		Type
	HiLink	specmanTemporal		Type
	HiLink	specmanFile		Include
	HiLink	specmanPreCondit	Include
	HiLink	specmanDefine		Typedef
	HiLink	specmanLabel		Label
	HiLink	specmanPacking		keyword
	HiLink	specmanTodo		Todo
	HiLink	specmanParenError	Error
	HiLink	specmanErrInParen	Error
	HiLink	specmanErrInBracket	Error
	delcommand	HiLink
endif

let b:current_syntax = "specman"
