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
" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" I took this section from c.vim, but I didn't succeed in making it work
" ANY one who dares to jump into this deep water is more than welcome!
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
" Only when an item doesn't have highlighting yet
" The default methods for highlighting.  Can be overridden later
hi def link specmanConditional	Conditional
hi def link specmanConstraint	Conditional
hi def link specmanRepeat		Repeat
hi def link specmanString		String
hi def link specmanComment		Comment
hi def link specmanConstant		Macro
hi def link specmanNumber		Number
hi def link specmanCompare		Operator
hi def link specmanOperator		Operator
hi def link specmanLogical		Operator
hi def link specmanStatement	Statement
hi def link specmanHDL		SpecialChar
hi def link specmanMethod		Function
hi def link specmanInclude		Include
hi def link specmanStructure	Structure
hi def link specmanBoolean		Boolean
hi def link specmanFSM		Label
hi def link specmanSpecial		Special
hi def link specmanType		Type
hi def link specmanTemporal		Type
hi def link specmanFile		Include
hi def link specmanPreCondit	Include
hi def link specmanDefine		Typedef
hi def link specmanLabel		Label
hi def link specmanPacking		keyword
hi def link specmanTodo		Todo
hi def link specmanParenError	Error
hi def link specmanErrInParen	Error
hi def link specmanErrInBracket	Error

let b:current_syntax = "specman"
