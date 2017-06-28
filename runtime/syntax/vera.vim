" Vim syntax file
" Language:	Vera
" Maintainer:	Dave Eggum (opine at bluebottle dOt com)
" Last Change:	2005 Dec 19

" NOTE: extra white space at the end of the line will be highlighted if you
" add this line to your colorscheme:

" highlight SpaceError    guibg=#204050

" (change the value for guibg to any color you like)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" A bunch of useful Vera keywords
syn keyword	veraStatement	break return continue fork join terminate
syn keyword	veraStatement	breakpoint proceed

syn keyword	veraLabel	bad_state bad_trans bind constraint coverage_group
syn keyword	veraLabel	class CLOCK default function interface m_bad_state
syn keyword	veraLabel	m_bad_trans m_state m_trans program randseq state
syn keyword	veraLabel	task trans

syn keyword	veraConditional	if else case casex casez randcase
syn keyword 	veraRepeat      repeat while for do foreach
syn keyword 	veraModifier	after all any around assoc_size async
syn keyword 	veraModifier	before big_endian bit_normal bit_reverse export
syn keyword 	veraModifier	extends extern little_endian local hdl_node hdl_task
syn keyword 	veraModifier	negedge none packed protected posedge public rules
syn keyword 	veraModifier	shadow soft static super this typedef unpacked var
syn keyword 	veraModifier	vca virtual virtuals wildcard with

syn keyword 	veraType	reg string enum event bit
syn keyword 	veraType	rand randc integer port prod

syn keyword     veraDeprecated	call_func call_task close_conn get_bind get_bind_id
syn keyword     veraDeprecated	get_conn_err mailbox_receive mailbox_send make_client
syn keyword     veraDeprecated	make_server simwave_plot up_connections

" predefined tasks and functions
syn keyword 	veraTask	alloc assoc_index cast_assign cm_coverage
syn keyword 	veraTask	cm_get_coverage cm_get_limit delay error error_mode
syn keyword 	veraTask	exit fclose feof ferror fflush flag fopen fprintf
syn keyword 	veraTask	freadb freadh freadstr get_cycle get_env get_memsize
syn keyword 	veraTask	get_plus_arg getstate get_systime get_time get_time_unit
syn keyword 	veraTask	initstate lock_file mailbox_get mailbox_put os_command
syn keyword 	veraTask	printf prodget prodset psprintf query query_str query_x
syn keyword 	veraTask	rand48 random region_enter region_exit rewind
syn keyword 	veraTask	semaphore_get semaphore_put setstate signal_connect
syn keyword 	veraTask	sprintf srandom sscanf stop suspend_thread sync
syn keyword 	veraTask	timeout trace trigger unit_delay unlock_file urand48
syn keyword 	veraTask	urandom urandom_range vera_bit_reverse vera_crc
syn keyword 	veraTask	vera_pack vera_pack_big_endian vera_plot
syn keyword 	veraTask	vera_report_profile vera_unpack vera_unpack_big_endian
syn keyword 	veraTask	vsv_call_func vsv_call_task vsv_get_conn_err
syn keyword 	veraTask	vsv_make_client vsv_make_server vsv_up_connections
syn keyword 	veraTask	vsv_wait_for_done vsv_wait_for_input wait_child wait_var

syn cluster	veraOperGroup	contains=veraOperator,veraOperParen,veraNumber,veraString,veraOperOk,veraType
" syn match	veraOperator	"++\|--\|&\|\~&\||\|\~|\|^\|\~^\|\~\|><"
" syn match	veraOperator	"*\|/\|%\|+\|-\|<<\|>>\|<\|<=\|>\|>=\|!in"
" syn match	veraOperator	"=?=\|!?=\|==\|!=\|===\|!==\|&\~\|^\~\||\~"
" syn match	veraOperator	"&&\|||\|=\|+=\|-=\|*=\|/=\|%=\|<<=\|>>=\|&="
" syn match	veraOperator	"|=\|^=\|\~&=\|\~|=\|\~^="

syn match	veraOperator	"[&|\~><!*@+/=,.\^\-]"
syn keyword	veraOperator	or in dist not

" open vera class methods
syn keyword	veraMethods	atobin atohex atoi atooct backref bittostr capacity
syn keyword	veraMethods	compare Configure constraint_mode delete DisableTrigger
syn keyword	veraMethods	DoAction empty EnableCount EnableTrigger Event find
syn keyword	veraMethods	find_index first first_index GetAssert get_at_least
syn keyword	veraMethods	get_auto_bin getc GetCount get_coverage_goal get_cov_weight
syn keyword	veraMethods	get_cross_bin_max GetFirstAssert GetName GetNextAssert
syn keyword	veraMethods	get_status get_status_msg hide hash icompare insert
syn keyword	veraMethods	inst_get_at_least inst_get_auto_bin_max inst_get_collect
syn keyword	veraMethods	inst_get_coverage_goal inst_get_cov_weight inst_getcross_bin_max
syn keyword	veraMethods	inst_query inst_set_at_least inst_set_auto_bin_max
syn keyword	veraMethods	inst_set_bin_activiation inst_set_collect inst_set_coverage_goal
syn keyword	veraMethods	inst_set_cov_weight inst_set_cross_bin_max itoa last last_index
syn keyword	veraMethods	len load match max max_index min min_index new object_compare
syn keyword	veraMethods	object_compare object_copy object_print pack pick_index
syn keyword	veraMethods	pop_back pop_front post_boundary postmatch post_pack post_pack
syn keyword	veraMethods	post_randomize post_randomize post_unpack post_unpack
syn keyword	veraMethods	pre_boundary prematch pre_pack pre_pack pre_randomize
syn keyword	veraMethods	pre-randomize pre_unpack push_back push_front putc query
syn keyword	veraMethods	query_str rand_mode randomize reserve reverse rsort search
syn keyword	veraMethods	set_at_least set_auto_bin_max set_bin_activiation
syn keyword	veraMethods	set_coverage_goal set_cov_weight set_cross_bin_max set_name
syn keyword	veraMethods	size sort substr sum thismatch tolower toupper unique_index
syn keyword	veraMethods	unpack Wait

" interface keywords
syn keyword	veraInterface	ASYNC CLOCK gnr gr0 gr1 grx grz NHOLD nr NR0 NR1
syn keyword	veraInterface	NRZ NRZ NSAMPLE PHOLD PR0 PR1 PRX PRZ r0 r1 rx snr
syn keyword	veraInterface	sr0 sr1 srx srz depth inout input output
syn match       veraInterface   "\$\w\+"


syn keyword	veraTodo	contained TODO FIXME XXX FINISH

" veraCommentGroup allows adding matches for special things in comments
syn cluster	veraCommentGroup	contains=veraTodo

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match	veraSpecial	display contained "\\\(x\x\+\|\o\{1,3}\|.\|$\)"
syn match	veraFormat	display "%\(\d\+\$\)\=[-+' #0*]*\(\d*\|\*\|\*\d\+\$\)\(\.\(\d*\|\*\|\*\d\+\$\)\)\=\([hlL]\|ll\)\=\([bdiuoxXDOUfeEgGcCsSpnm]\|\[\^\=.[^]]*\]\)" contained
syn match	veraFormat	display "%%" contained
syn region	veraString	start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=veraSpecial,veraFormat,@Spell
syn region	veraConcat	contained transparent oneline start='{' end='}'

" veraCppString: same as veraString, but ends at end of line
syn region	veraCppString	start=+"+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end='$' contains=veraSpecial,veraFormat,@Spell

syn match	veraCharacter	"'[^\\]'"
syn match	veraCharacter	"L'[^']*'" contains=veraSpecial
syn match	veraSpecialError	"'\\[^'\"?\\abefnrtv]'"
syn match	veraSpecialCharacter	"'\\['\"?\\abefnrtv]'"
syn match	veraSpecialCharacter	display	"'\\\o\{1,3}'"
syn match	veraSpecialCharacter	display	"'\\x\x\{1,2}'"
syn match	veraSpecialCharacter	display	"L'\\x\x\+'"

" highlight trailing white space
syn match	veraSpaceError	display	excludenl "\s\+$"
syn match	veraSpaceError	display	" \+\t"me=e-1

"catch errors caused by wrong parenthesis and brackets
syn cluster	veraParenGroup	contains=veraParenError,veraIncluded,veraSpecial,veraCommentSkip,veraCommentString,veraComment2String,@veraCommentGroup,veraCommentStartError,veraUserCont,veraUserLabel,veraBitField,veraCommentSkip,veraOctalZero,veraCppOut,veraCppOut2,veraCppSkip,veraFormat,veraNumber,veraFloat,veraOctal,veraOctalError,veraNumbersCom

syn region	veraParen	transparent start='(' end=')' contains=ALLBUT,@veraParenGroup,veraCppParen,veraErrInBracket,veraCppBracket,veraCppString,@Spell
" veraCppParen: same as veraParen but ends at end-of-line; used in veraDefine
syn region	veraCppParen	transparent start='(' skip='\\$' excludenl end=')' end='$' contained contains=ALLBUT,@veraParenGroup,veraErrInBracket,veraParen,veraBracket,veraString,@Spell
syn match	veraParenError	display "[\])]"
" syn match	veraErrInParen	display contained "[\]{}]"
syn match	veraErrInParen	display contained "[\]]"
syn region	veraBracket	transparent start='\[' end=']' contains=ALLBUT,@veraParenGroup,veraErrInParen,veraCppParen,veraCppBracket,veraCppString,@Spell

" veraCppBracket: same as veraParen but ends at end-of-line; used in veraDefine
syn region	veraCppBracket	transparent start='\[' skip='\\$' excludenl end=']' end='$' contained contains=ALLBUT,@veraParenGroup,veraErrInParen,veraParen,veraBracket,veraString,@Spell
syn match	veraErrInBracket	display contained "[);{}]"

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match	veraNumbers	display transparent "\<\d\|\.\d" contains=veraNumber,veraFloat,veraOctalError,veraOctal
" Same, but without octal error (for comments)
syn match	veraNumbersCom	display contained transparent "\<\d\|\.\d" contains=veraNumber,veraFloat,veraOctal
" syn match	veraNumber	display contained "\d\+\(u\=l\{0,2}\|ll\=u\)\>"
" "hex number
" syn match	veraNumber	display contained "0x\x\+\(u\=l\{0,2}\|ll\=u\)\>"
" syn match   veraNumber "\(\<[0-9]\+\|\)'[bdoh][0-9a-fxzA-FXZ_]\+\>"
syn match	veraNumber "\<\(\<[0-9]\+\)\?\('[bdoh]\)\?[0-9a-fxz_]\+\>"
" syn match   veraNumber "\<[+-]\=[0-9]\+\>"
" Flag the first zero of an octal number as something special
syn match	veraOctal	display contained "0\o\+\(u\=l\{0,2}\|ll\=u\)\>" contains=veraOctalZero
syn match	veraOctalZero	display contained "\<0"
syn match	veraFloat	display contained "\d\+f"
"floating point number, with dot, optional exponent
syn match	veraFloat	display contained "\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\="
"floating point number, starting with a dot, optional exponent
syn match	veraFloat	display contained "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match	veraFloat	display contained "\d\+e[-+]\=\d\+[fl]\=\>"
"hexadecimal floating point number, optional leading digits, with dot, with exponent
syn match	veraFloat	display contained "0x\x*\.\x\+p[-+]\=\d\+[fl]\=\>"
"hexadecimal floating point number, with leading digits, optional dot, with exponent
syn match	veraFloat	display contained "0x\x\+\.\=p[-+]\=\d\+[fl]\=\>"

" flag an octal number with wrong digits
syn match	veraOctalError	display contained "0\o*[89]\d*"
syn case match

let vera_comment_strings = 1

if exists("vera_comment_strings")
  " A comment can contain veraString, veraCharacter and veraNumber.
  " But a "*/" inside a veraString in a veraComment DOES end the comment!  So we
  " need to use a special type of veraString: veraCommentString, which also ends on
  " "*/", and sees a "*" at the start of the line as comment again.
  " Unfortunately this doesn't work very well for // type of comments :-(
  syntax match	veraCommentSkip	contained "^\s*\*\($\|\s\+\)"
  syntax region veraCommentString	contained start=+L\=\\\@<!"+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=veraSpecial,veraCommentSkip
  syntax region veraComment2String	contained start=+\\\@<!"+ skip=+\\\\\|\\"+ end=+"+ end="$" contains=veraSpecial
  syntax region  veraCommentL	start="//" skip="\\$" end="$" keepend contains=@veraCommentGroup,veraComment2String,veraCharacter,veraNumbersCom,veraSpaceError,@Spell
  if exists("vera_no_comment_fold")
    syntax region veraComment	matchgroup=veraCommentStart start="/\*" end="\*/" contains=@veraCommentGroup,veraCommentStartError,veraCommentString,veraCharacter,veraNumbersCom,veraSpaceError,@Spell
  else
    syntax region veraComment	matchgroup=veraCommentStart start="/\*" end="\*/" contains=@veraCommentGroup,veraCommentStartError,veraCommentString,veraCharacter,veraNumbersCom,veraSpaceError,@Spell fold
  endif
else
  syn region	veraCommentL	start="//" skip="\\$" end="$" keepend contains=@veraCommentGroup,veraSpaceError,@Spell
  if exists("vera_no_comment_fold")
    syn region	veraComment	matchgroup=veraCommentStart start="/\*" end="\*/" contains=@veraCommentGroup,veraCommentStartError,veraSpaceError,@Spell
  else
    syn region	veraComment	matchgroup=veraCommentStart start="/\*" end="\*/" contains=@veraCommentGroup,veraCommentStartError,veraSpaceError,@Spell fold
  endif
endif
" keep a // comment separately, it terminates a preproc. conditional
syntax match	veraCommentError	display "\*/"
syntax match	veraCommentStartError display "/\*"me=e-1 contained

syntax region	veraBlock		start="{" end="}" transparent fold

" open vera pre-defined constants
syn keyword veraConstant	ALL ANY BAD_STATE BAD_TRANS CALL CHECK CHGEDGE
syn keyword veraConstant	CLEAR COPY_NO_WAIT COPY_WAIT CROSS CROSS_TRANS
syn keyword veraConstant	DEBUG DELETE EC_ARRAYX EC_CODE_END EC_CONFLICT
syn keyword veraConstant	EC_EVNTIMOUT EC_EXPECT EC_FULLEXPECT EC_MBXTMOUT
syn keyword veraConstant	EC_NEXPECT EC_RETURN EC_RGNTMOUT EC_SCONFLICT
syn keyword veraConstant	EC_SEMTMOUT EC_SEXPECT EC_SFULLEXPECT EC_SNEXTPECT
syn keyword veraConstant	EC_USERSET EQ EVENT FAIL FIRST FORK GE GOAL GT
syn keyword veraConstant	HAND_SHAKE HI HIGH HNUM LE LIC_EXIT LIC_PRERR
syn keyword veraConstant	LIC_PRWARN LIC_WAIT LO LOAD LOW LT MAILBOX MAX_COM
syn keyword veraConstant	NAME NE NEGEDGE NEXT NO_OVERLAP NO_OVERLAP_STATE
syn keyword veraConstant	NO_OVERLAP_TRANS NO_VARS NO_WAIT NUM NUM_BIN
syn keyword veraConstant	NUM_DET null OFF OK OK_LAST ON ONE_BLAST ONE_SHOT ORDER
syn keyword veraConstant	PAST_IT PERCENT POSEDGE PROGRAM RAWIN REGION REPORT
syn keyword veraConstant	SAMPLE SAVE SEMAPHORE SET SILENT STATE stderr
syn keyword veraConstant	stdin stdout STR STR_ERR_OUT_OF_RANGE
syn keyword veraConstant	STR_ERR_REGEXP_SYNTAX SUM TRANS VERBOSE void WAIT
syn keyword veraConstant	__LINE__ __FILE__ __DATE__ __TIME__ __VERA__
syn keyword veraConstant	__VERSION__ __VERA_VERSION__ __VERA_MINOR__
syn keyword veraConstant	__VERA_PATCH__ __VERA_VMC__ __VERA_VMC_MINOR__

syn match   veraUserConstant "\<[A-Z][A-Z0-9_]\+\>"

syn match veraClass "\zs\w\+\ze::"
syn match veraClass "\zs\w\+\ze\s\+\w\+\s*[=;,)\[]" contains=veraConstant,veraUserConstant
syn match veraClass "\zs\w\+\ze\s\+\w\+\s*$" contains=veraConstant,veraUserConstant
syn match veraUserMethod "\zs\w\+\ze\s*(" contains=veraConstant,veraUserConstant
syn match veraObject "\zs\w\+\ze\.\w"
syn match veraObject "\zs\w\+\ze\.\$\w"

" Accept ` for # (Verilog)
syn region	veraPreCondit	start="^\s*\(`\|#\)\s*\(if\|ifdef\|ifndef\|elif\)\>" skip="\\$" end="$" end="//"me=s-1 contains=veraComment,veraCppString,veraCharacter,veraCppParen,veraParenError,veraNumbers,veraCommentError,veraSpaceError
syn match	veraPreCondit	display "^\s*\(`\|#\)\s*\(else\|endif\)\>"
if !exists("vera_no_if0")
  syn region	veraCppOut		start="^\s*\(`\|#\)\s*if\s\+0\+\>" end=".\@=\|$" contains=veraCppOut2
  syn region	veraCppOut2	contained start="0" end="^\s*\(`\|#\)\s*\(endif\>\|else\>\|elif\>\)" contains=veraSpaceError,veraCppSkip
  syn region	veraCppSkip	contained start="^\s*\(`\|#\)\s*\(if\>\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*\(`\|#\)\s*endif\>" contains=veraSpaceError,veraCppSkip
endif
syn region	veraIncluded	display contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match	veraIncluded	display contained "<[^>]*>"
syn match	veraInclude	display "^\s*\(`\|#\)\s*include\>\s*["<]" contains=veraIncluded
"syn match veraLineSkip	"\\$"
syn cluster	veraPreProcGroup	contains=veraPreCondit,veraIncluded,veraInclude,veraDefine,veraErrInParen,veraErrInBracket,veraUserLabel,veraSpecial,veraOctalZero,veraCppOut,veraCppOut2,veraCppSkip,veraFormat,veraNumber,veraFloat,veraOctal,veraOctalError,veraNumbersCom,veraString,veraCommentSkip,veraCommentString,veraComment2String,@veraCommentGroup,veraCommentStartError,veraParen,veraBracket,veraMulti
syn region	veraDefine		start="^\s*\(`\|#\)\s*\(define\|undef\)\>" skip="\\$" end="$" end="//"me=s-1 contains=ALLBUT,@veraPreProcGroup,@Spell
syn region	veraPreProc	start="^\s*\(`\|#\)\s*\(pragma\>\|line\>\|warning\>\|error\>\)" skip="\\$" end="$" keepend contains=ALLBUT,@veraPreProcGroup,@Spell

" Highlight User Labels
syn cluster	veraMultiGroup	contains=veraIncluded,veraSpecial,veraCommentSkip,veraCommentString,veraComment2String,@veraCommentGroup,veraCommentStartError,veraUserCont,veraUserLabel,veraBitField,veraOctalZero,veraCppOut,veraCppOut2,veraCppSkip,veraFormat,veraNumber,veraFloat,veraOctal,veraOctalError,veraNumbersCom,veraCppParen,veraCppBracket,veraCppString
syn region	veraMulti		transparent start='?' skip='::' end=':' contains=ALLBUT,@veraMultiGroup,@Spell
" syn region	veraMulti		transparent start='?' skip='::' end=':' contains=ALL
" The above causes veraCppOut2 to catch on:
"    i = (isTrue) ? 0 : 1;
" which ends up commenting the rest of the file

" Avoid matching foo::bar() by requiring that the next char is not ':'
syn cluster	veraLabelGroup	contains=veraUserLabel
syn match	veraUserCont	display "^\s*\I\i*\s*:$" contains=@veraLabelGroup
syn match	veraUserCont	display ";\s*\I\i*\s*:$" contains=@veraLabelGroup
syn match	veraUserCont	display "^\s*\I\i*\s*:[^:]"me=e-1 contains=@veraLabelGroup
syn match	veraUserCont	display ";\s*\I\i*\s*:[^:]"me=e-1 contains=@veraLabelGroup

syn match	veraUserLabel	display "\I\i*" contained

" Avoid recognizing most bitfields as labels
syn match	veraBitField	display "^\s*\I\i*\s*:\s*[1-9]"me=e-1
syn match	veraBitField	display ";\s*\I\i*\s*:\s*[1-9]"me=e-1

if exists("vera_minlines")
  let b:vera_minlines = vera_minlines
else
  if !exists("vera_no_if0")
    let b:vera_minlines = 50	" #if 0 constructs can be long
  else
    let b:vera_minlines = 15	" mostly for () constructs
  endif
endif
exec "syn sync ccomment veraComment minlines=" . b:vera_minlines

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link veraClass		Identifier
hi def link veraObject		Identifier
hi def link veraUserMethod		Function
hi def link veraTask		Keyword
hi def link veraModifier		Tag
hi def link veraDeprecated		veraError
hi def link veraMethods		Statement
" hi def link veraInterface		Label
hi def link veraInterface		Function

hi def link veraFormat		veraSpecial
hi def link veraCppString		veraString
hi def link veraCommentL		veraComment
hi def link veraCommentStart		veraComment
hi def link veraLabel			Label
hi def link veraUserLabel		Label
hi def link veraConditional		Conditional
hi def link veraRepeat		Repeat
hi def link veraCharacter		Character
hi def link veraSpecialCharacter	veraSpecial
hi def link veraNumber		Number
hi def link veraOctal			Number
hi def link veraOctalZero		PreProc	 " link this to Error if you want
hi def link veraFloat			Float
hi def link veraOctalError		veraError
hi def link veraParenError		veraError
hi def link veraErrInParen		veraError
hi def link veraErrInBracket		veraError
hi def link veraCommentError		veraError
hi def link veraCommentStartError	veraError
hi def link veraSpaceError         SpaceError
hi def link veraSpecialError		veraError
hi def link veraOperator		Operator
hi def link veraStructure		Structure
hi def link veraInclude		Include
hi def link veraPreProc		PreProc
hi def link veraDefine		Macro
hi def link veraIncluded		veraString
hi def link veraError			Error
hi def link veraStatement		Statement
hi def link veraPreCondit		PreCondit
hi def link veraType			Type
" hi def link veraConstant		Constant
hi def link veraConstant		Keyword
hi def link veraUserConstant		Constant
hi def link veraCommentString		veraString
hi def link veraComment2String	veraString
hi def link veraCommentSkip		veraComment
hi def link veraString		String
hi def link veraComment		Comment
hi def link veraSpecial		SpecialChar
hi def link veraTodo			Todo
hi def link veraCppSkip		veraCppOut
hi def link veraCppOut2		veraCppOut
hi def link veraCppOut		Comment


let b:current_syntax = "vera"

" vim: ts=8
