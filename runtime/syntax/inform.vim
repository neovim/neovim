" Vim syntax file
" Language:     Inform
" Maintainer:   Stephen Thomas (stephen@gowarthomas.com)
" URL:		http://www.gowarthomas.com/informvim
" Last Change:  2006 April 20

" Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" A bunch of useful Inform keywords.  First, case insensitive stuff

syn case ignore

syn keyword informDefine Constant

syn keyword informType Array Attribute Class Nearby
syn keyword informType Object Property String Routine
syn match   informType "\<Global\>"

syn keyword informInclude Import Include Link Replace System_file

syn keyword informPreCondit End Endif Ifdef Ifndef Iftrue Iffalse Ifv3 Ifv5
syn keyword informPreCondit Ifnot

syn keyword informPreProc Abbreviate Default Fake_action Lowstring
syn keyword informPreProc Message Release Serial Statusline Stub Switches
syn keyword informPreProc Trace Zcharacter

syn region  informGlobalRegion matchgroup=informType start="\<Global\>" matchgroup=NONE skip=+!.*$\|".*"\|'.*'+ end=";" contains=ALLBUT,informGramPreProc,informPredicate,informGrammar,informAsm,informAsmObsolete

syn keyword informGramPreProc contained Verb Extend

if !exists("inform_highlight_simple")
  syn keyword informLibAttrib absent animate clothing concealed container
  syn keyword informLibAttrib door edible enterable female general light
  syn keyword informLibAttrib lockable locked male moved neuter on open
  syn keyword informLibAttrib openable pluralname proper scenery scored
  syn keyword informLibAttrib static supporter switchable talkable
  syn keyword informLibAttrib visited workflag worn
  syn match informLibAttrib "\<transparent\>"

  syn keyword informLibProp e_to se_to s_to sw_to w_to nw_to n_to ne_to
  syn keyword informLibProp u_to d_to in_to out_to before after life
  syn keyword informLibProp door_to with_key door_dir invent plural
  syn keyword informLibProp add_to_scope list_together react_before
  syn keyword informLibProp react_after grammar orders initial when_open
  syn keyword informLibProp when_closed when_on when_off description
  syn keyword informLibProp describe article cant_go found_in time_left
  syn keyword informLibProp number time_out daemon each_turn capacity
  syn keyword informLibProp name short_name short_name_indef parse_name
  syn keyword informLibProp articles inside_description
  if !exists("inform_highlight_old")
    syn keyword informLibProp compass_look before_implicit
    syn keyword informLibProp ext_initialise ext_messages
  endif

  syn keyword informLibObj e_obj se_obj s_obj sw_obj w_obj nw_obj n_obj
  syn keyword informLibObj ne_obj u_obj d_obj in_obj out_obj compass
  syn keyword informLibObj thedark selfobj player location second actor
  syn keyword informLibObj noun
  if !exists("inform_highlight_old")
    syn keyword informLibObj LibraryExtensions
  endif

  syn keyword informLibRoutine Achieved AfterRoutines AddToScope
  syn keyword informLibRoutine AllowPushDir Banner ChangeDefault
  syn keyword informLibRoutine ChangePlayer CommonAncestor DictionaryLookup
  syn keyword informLibRoutine DisplayStatus DoMenu DrawStatusLine
  syn keyword informLibRoutine EnglishNumber HasLightSource GetGNAOfObject
  syn keyword informLibRoutine IndirectlyContains IsSeeThrough Locale
  syn keyword informLibRoutine LoopOverScope LTI_Insert MoveFloatingObjects
  syn keyword informLibRoutine NextWord NextWordStopped NounDomain
  syn keyword informLibRoutine ObjectIsUntouchable OffersLight ParseToken
  syn keyword informLibRoutine PlaceInScope PlayerTo PrintShortName
  syn keyword informLibRoutine PronounNotice ScopeWithin SetPronoun SetTime
  syn keyword informLibRoutine StartDaemon StartTimer StopDaemon StopTimer
  syn keyword informLibRoutine TestScope TryNumber UnsignedCompare
  syn keyword informLibRoutine WordAddress WordInProperty WordLength
  syn keyword informLibRoutine WriteListFrom YesOrNo ZRegion RunRoutines
  syn keyword informLibRoutine AfterLife AfterPrompt Amusing BeforeParsing
  syn keyword informLibRoutine ChooseObjects DarkToDark DeathMessage
  syn keyword informLibRoutine GamePostRoutine GamePreRoutine Initialise
  syn keyword informLibRoutine InScope LookRoutine NewRoom ParseNoun
  syn keyword informLibRoutine ParseNumber ParserError PrintRank PrintVerb
  syn keyword informLibRoutine PrintTaskName TimePasses UnknownVerb
  if exists("inform_highlight_glulx")
     syn keyword informLibRoutine  IdentifyGlkObject HandleGlkEvent
     syn keyword informLibRoutine  InitGlkWindow
  endif
  if !exists("inform_highlight_old")
     syn keyword informLibRoutine  KeyCharPrimitive KeyDelay ClearScreen
     syn keyword informLibRoutine  MoveCursor MainWindow StatusLineHeight
     syn keyword informLibRoutine  ScreenWidth ScreenHeight SetColour
     syn keyword informLibRoutine  DecimalNumber PrintToBuffer Length
     syn keyword informLibRoutine  UpperCase LowerCase PrintCapitalised
     syn keyword informLibRoutine  Cap Centre
     if exists("inform_highlight_glulx")
	syn keyword informLibRoutine  PrintAnything PrintAnyToArray
     endif
  endif

  syn keyword informLibAction  Quit Restart Restore Verify Save
  syn keyword informLibAction  ScriptOn ScriptOff Pronouns Score
  syn keyword informLibAction  Fullscore LMode1 LMode2 LMode3
  syn keyword informLibAction  NotifyOn NotifyOff Version Places
  syn keyword informLibAction  Objects TraceOn TraceOff TraceLevel
  syn keyword informLibAction  ActionsOn ActionsOff RoutinesOn
  syn keyword informLibAction  RoutinesOff TimersOn TimersOff
  syn keyword informLibAction  CommandsOn CommandsOff CommandsRead
  syn keyword informLibAction  Predictable XPurloin XAbstract XTree
  syn keyword informLibAction  Scope Goto Gonear Inv InvTall InvWide
  syn keyword informLibAction  Take Drop Remove PutOn Insert Transfer
  syn keyword informLibAction  Empty Enter Exit GetOff Go Goin Look
  syn keyword informLibAction  Examine Search Give Show Unlock Lock
  syn keyword informLibAction  SwitchOn SwitchOff Open Close Disrobe
  syn keyword informLibAction  Wear Eat Yes No Burn Pray Wake
  syn keyword informLibAction  WakeOther Consult Kiss Think Smell
  syn keyword informLibAction  Listen Taste Touch Dig Cut Jump
  syn keyword informLibAction  JumpOver Tie Drink Fill Sorry Strong
  syn keyword informLibAction  Mild Attack Swim Swing Blow Rub Set
  syn keyword informLibAction  SetTo WaveHands Wave Pull Push PushDir
  syn keyword informLibAction  Turn Squeeze LookUnder ThrowAt Tell
  syn keyword informLibAction  Answer Buy Ask AskFor Sing Climb Wait
  syn keyword informLibAction  Sleep LetGo Receive ThrownAt Order
  syn keyword informLibAction  TheSame PluralFound Miscellany Prompt
  syn keyword informLibAction  ChangesOn ChangesOff Showverb Showobj
  syn keyword informLibAction  EmptyT VagueGo
  if exists("inform_highlight_glulx")
     syn keyword informLibAction  GlkList
  endif

  syn keyword informLibVariable keep_silent deadflag action special_number
  syn keyword informLibVariable consult_from consult_words etype verb_num
  syn keyword informLibVariable verb_word the_time real_location c_style
  syn keyword informLibVariable parser_one parser_two listing_together wn
  syn keyword informLibVariable parser_action scope_stage scope_reason
  syn keyword informLibVariable action_to_be menu_item item_name item_width
  syn keyword informLibVariable lm_o lm_n inventory_style task_scores
  syn keyword informLibVariable inventory_stage

  syn keyword informLibConst AMUSING_PROVIDED DEBUG Headline MAX_CARRIED
  syn keyword informLibConst MAX_SCORE MAX_TIMERS NO_PLACES NUMBER_TASKS
  syn keyword informLibConst OBJECT_SCORE ROOM_SCORE SACK_OBJECT Story
  syn keyword informLibConst TASKS_PROVIDED WITHOUT_DIRECTIONS
  syn keyword informLibConst NEWLINE_BIT INDENT_BIT FULLINV_BIT ENGLISH_BIT
  syn keyword informLibConst RECURSE_BIT ALWAYS_BIT TERSE_BIT PARTINV_BIT
  syn keyword informLibConst DEFART_BIT WORKFLAG_BIT ISARE_BIT CONCEAL_BIT
  syn keyword informLibConst PARSING_REASON TALKING_REASON EACHTURN_REASON
  syn keyword informLibConst REACT_BEFORE_REASON REACT_AFTER_REASON
  syn keyword informLibConst TESTSCOPE_REASON LOOPOVERSCOPE_REASON
  syn keyword informLibConst STUCK_PE UPTO_PE NUMBER_PE CANTSEE_PE TOOLIT_PE
  syn keyword informLibConst NOTHELD_PE MULTI_PE MMULTI_PE VAGUE_PE EXCEPT_PE
  syn keyword informLibConst ANIMA_PE VERB_PE SCENERY_PE ITGONE_PE
  syn keyword informLibConst JUNKAFTER_PE TOOFEW_PE NOTHING_PE ASKSCOPE_PE
  if !exists("inform_highlight_old")
     syn keyword informLibConst WORDSIZE TARGET_ZCODE TARGET_GLULX
     syn keyword informLibConst LIBRARY_PARSER LIBRARY_VERBLIB LIBRARY_GRAMMAR
     syn keyword informLibConst LIBRARY_ENGLISH NO_SCORE START_MOVE
     syn keyword informLibConst CLR_DEFAULT CLR_BLACK CLR_RED CLR_GREEN
     syn keyword informLibConst CLR_YELLOW CLR_BLUE CLR_MAGENTA CLR_CYAN
     syn keyword informLibConst CLR_WHITE CLR_PURPLE CLR_AZURE
     syn keyword informLibConst WIN_ALL WIN_MAIN WIN_STATUS
  endif
endif

" Now the case sensitive stuff.

syntax case match

syn keyword informSysFunc child children elder indirect parent random
syn keyword informSysFunc sibling younger youngest metaclass
if exists("inform_highlight_glulx")
  syn keyword informSysFunc glk
endif

syn keyword informSysConst adjectives_table actions_table classes_table
syn keyword informSysConst identifiers_table preactions_table version_number
syn keyword informSysConst largest_object strings_offset code_offset
syn keyword informSysConst dict_par1 dict_par2 dict_par3
syn keyword informSysConst actual_largest_object static_memory_offset
syn keyword informSysConst array_names_offset readable_memory_offset
syn keyword informSysConst cpv__start cpv__end ipv__start ipv__end
syn keyword informSysConst array__start array__end lowest_attribute_number
syn keyword informSysConst highest_attribute_number attribute_names_array
syn keyword informSysConst lowest_property_number highest_property_number
syn keyword informSysConst property_names_array lowest_action_number
syn keyword informSysConst highest_action_number action_names_array
syn keyword informSysConst lowest_fake_action_number highest_fake_action_number
syn keyword informSysConst fake_action_names_array lowest_routine_number
syn keyword informSysConst highest_routine_number routines_array
syn keyword informSysConst routine_names_array routine_flags_array
syn keyword informSysConst lowest_global_number highest_global_number globals_array
syn keyword informSysConst global_names_array global_flags_array
syn keyword informSysConst lowest_array_number highest_array_number arrays_array
syn keyword informSysConst array_names_array array_flags_array lowest_constant_number
syn keyword informSysConst highest_constant_number constants_array constant_names_array
syn keyword informSysConst lowest_class_number highest_class_number class_objects_array
syn keyword informSysConst lowest_object_number highest_object_number
if !exists("inform_highlight_old")
  syn keyword informSysConst sys_statusline_flag
endif

syn keyword informConditional default else if switch

syn keyword informRepeat break continue do for objectloop until while

syn keyword informStatement box font give inversion jump move new_line
syn keyword informStatement print print_ret quit read remove restore return
syn keyword informStatement rfalse rtrue save spaces string style

syn keyword informOperator roman reverse bold underline fixed on off to
syn keyword informOperator near from

syn keyword informKeyword dictionary symbols objects verbs assembly
syn keyword informKeyword expressions lines tokens linker on off alias long
syn keyword informKeyword additive score time string table
syn keyword informKeyword with private has class error fatalerror
syn keyword informKeyword warning self
if !exists("inform_highlight_old")
  syn keyword informKeyword buffer
endif

syn keyword informMetaAttrib remaining create destroy recreate copy call
syn keyword informMetaAttrib print_to_array

syn keyword informPredicate has hasnt in notin ofclass or
syn keyword informPredicate provides

syn keyword informGrammar contained noun held multi multiheld multiexcept
syn keyword informGrammar contained multiinside creature special number
syn keyword informGrammar contained scope topic reverse meta only replace
syn keyword informGrammar contained first last

syn keyword informKeywordObsolete contained initial data initstr

syn keyword informTodo contained TODO

" Assembly language mnemonics must be preceded by a '@'.

syn match informAsmContainer "@\s*\k*" contains=informAsm,informAsmObsolete

if exists("inform_highlight_glulx")
  syn keyword informAsm contained nop add sub mul div mod neg bitand bitor
  syn keyword informAsm contained bitxor bitnot shiftl sshiftr ushiftr jump jz
  syn keyword informAsm contained jnz jeq jne jlt jge jgt jle jltu jgeu jgtu
  syn keyword informAsm contained jleu call return catch throw tailcall copy
  syn keyword informAsm contained copys copyb sexs sexb aload aloads aloadb
  syn keyword informAsm contained aloadbit astore astores astoreb astorebit
  syn keyword informAsm contained stkcount stkpeek stkswap stkroll stkcopy
  syn keyword informAsm contained streamchar streamnum streamstr gestalt
  syn keyword informAsm contained debugtrap getmemsize setmemsize jumpabs
  syn keyword informAsm contained random setrandom quit verify restart save
  syn keyword informAsm contained restore saveundo restoreundo protect glk
  syn keyword informAsm contained getstringtbl setstringtbl getiosys setiosys
  syn keyword informAsm contained linearsearch binarysearch linkedsearch
  syn keyword informAsm contained callf callfi callfii callfiii
else
  syn keyword informAsm contained je jl jg dec_chk inc_chk jin test or and
  syn keyword informAsm contained test_attr set_attr clear_attr store
  syn keyword informAsm contained insert_obj loadw loadb get_prop
  syn keyword informAsm contained get_prop_addr get_next_prop add sub mul div
  syn keyword informAsm contained mod call storew storeb put_prop sread
  syn keyword informAsm contained print_num random push pull
  syn keyword informAsm contained split_window set_window output_stream
  syn keyword informAsm contained input_stream sound_effect jz get_sibling
  syn keyword informAsm contained get_child get_parent get_prop_len inc dec
  syn keyword informAsm contained remove_obj print_obj ret jump
  syn keyword informAsm contained load not rtrue rfalse print
  syn keyword informAsm contained print_ret nop save restore restart
  syn keyword informAsm contained ret_popped pop quit new_line show_status
  syn keyword informAsm contained verify call_2s call_vs aread call_vs2
  syn keyword informAsm contained erase_window erase_line set_cursor get_cursor
  syn keyword informAsm contained set_text_style buffer_mode read_char
  syn keyword informAsm contained scan_table call_1s call_2n set_colour throw
  syn keyword informAsm contained call_vn call_vn2 tokenise encode_text
  syn keyword informAsm contained copy_table print_table check_arg_count
  syn keyword informAsm contained call_1n catch piracy log_shift art_shift
  syn keyword informAsm contained set_font save_undo restore_undo draw_picture
  syn keyword informAsm contained picture_data erase_picture set_margins
  syn keyword informAsm contained move_window window_size window_style
  syn keyword informAsm contained get_wind_prop scroll_window pop_stack
  syn keyword informAsm contained read_mouse mouse_window push_stack
  syn keyword informAsm contained put_wind_prop print_form make_menu
  syn keyword informAsm contained picture_table
  if !exists("inform_highlight_old")
     syn keyword informAsm contained check_unicode print_unicode
  endif
  syn keyword informAsmObsolete contained print_paddr print_addr print_char
endif

" Handling for different versions of VIM.

if version >= 600
  setlocal iskeyword+=$
  command -nargs=+ SynDisplay syntax <args> display
else
  set iskeyword+=$
  command -nargs=+ SynDisplay syntax <args>
endif

" Grammar sections.

syn region informGrammarSection matchgroup=informGramPreProc start="\<Verb\|Extend\>" skip=+".*"+ end=";"he=e-1 contains=ALLBUT,informAsm

" Special character forms.

SynDisplay match informBadAccent contained "@[^{[:digit:]]\D"
SynDisplay match informBadAccent contained "@{[^}]*}"
SynDisplay match informAccent contained "@:[aouAOUeiyEI]"
SynDisplay match informAccent contained "@'[aeiouyAEIOUY]"
SynDisplay match informAccent contained "@`[aeiouAEIOU]"
SynDisplay match informAccent contained "@\^[aeiouAEIOU]"
SynDisplay match informAccent contained "@\~[anoANO]"
SynDisplay match informAccent contained "@/[oO]"
SynDisplay match informAccent contained "@ss\|@<<\|@>>\|@oa\|@oA\|@ae\|@AE\|@cc\|@cC"
SynDisplay match informAccent contained "@th\|@et\|@Th\|@Et\|@LL\|@oe\|@OE\|@!!\|@??"
SynDisplay match informAccent contained "@{\x\{1,4}}"
SynDisplay match informBadStrUnicode contained "@@\D"
SynDisplay match informStringUnicode contained "@@\d\+"
SynDisplay match informStringCode contained "@\d\d"

" String and Character constants.  Ordering is important here.
syn region informString start=+"+ skip=+\\\\+ end=+"+ contains=informAccent,informStringUnicode,informStringCode,informBadAccent,informBadStrUnicode
syn region informDictString start="'" end="'" contains=informAccent,informBadAccent
SynDisplay match informBadDictString "''"
SynDisplay match informDictString "'''"

" Integer numbers: decimal, hexadecimal and binary.
SynDisplay match informNumber "\<\d\+\>"
SynDisplay match informNumber "\<\$\x\+\>"
SynDisplay match informNumber "\<\$\$[01]\+\>"

" Comments
syn match informComment "!.*" contains=informTodo

" Syncronization
syn sync match informSyncStringEnd grouphere NONE /"[;,]\s*$/
syn sync match informSyncRoutineEnd grouphere NONE /][;,]\s*$/
syn sync match informSyncCommentEnd grouphere NONE /^\s*!.*$/
syn sync match informSyncRoutine groupthere informGrammarSection "\<Verb\|Extend\>"
syn sync maxlines=500

delcommand SynDisplay

" The default highlighting.
if version >= 508 || !exists("did_inform_syn_inits")
  if version < 508
    let did_inform_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink informDefine		Define
  HiLink informType		Type
  HiLink informInclude		Include
  HiLink informPreCondit	PreCondit
  HiLink informPreProc		PreProc
  HiLink informGramPreProc	PreProc
  HiLink informAsm		Special
  if !exists("inform_suppress_obsolete")
    HiLink informAsmObsolete		informError
    HiLink informKeywordObsolete	informError
  else
    HiLink informAsmObsolete		Special
    HiLink informKeywordObsolete	Keyword
  endif
  HiLink informPredicate	Operator
  HiLink informSysFunc		Identifier
  HiLink informSysConst		Identifier
  HiLink informConditional	Conditional
  HiLink informRepeat		Repeat
  HiLink informStatement	Statement
  HiLink informOperator		Operator
  HiLink informKeyword		Keyword
  HiLink informGrammar		Keyword
  HiLink informDictString	String
  HiLink informNumber		Number
  HiLink informError		Error
  HiLink informString		String
  HiLink informComment		Comment
  HiLink informAccent		Special
  HiLink informStringUnicode	Special
  HiLink informStringCode	Special
  HiLink informTodo		Todo
  if !exists("inform_highlight_simple")
    HiLink informLibAttrib	Identifier
    HiLink informLibProp	Identifier
    HiLink informLibObj		Identifier
    HiLink informLibRoutine	Identifier
    HiLink informLibVariable	Identifier
    HiLink informLibConst	Identifier
    HiLink informLibAction	Identifier
  endif
  HiLink informBadDictString	informError
  HiLink informBadAccent	informError
  HiLink informBadStrUnicode	informError

  delcommand HiLink
endif

let b:current_syntax = "inform"

" vim: ts=8
