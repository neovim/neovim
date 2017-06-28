" Vim syntax file
" Language:	MOO
" Maintainer:	Timo Frenay <timo@frenay.net>
" Last Change:	2001 Oct 06
" Note:		Requires Vim 6.0 or above

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Initializations
syn case ignore

" C-style comments
syn match mooUncommentedError display ~\*/~
syn match mooCStyleCommentError display ~/\ze\*~ contained
syn region mooCStyleComment matchgroup=mooComment start=~/\*~ end=~\*/~ contains=mooCStyleCommentError

" Statements
if exists("moo_extended_cstyle_comments")
  syn match mooIdentifier display ~\%(\%(/\*.\{-}\*/\s*\)*\)\@>\<\h\w*\>~ contained transparent contains=mooCStyleComment,@mooKeyword,mooType,mooVariable
else
  syn match mooIdentifier display ~\<\h\w*\>~ contained transparent contains=@mooKeyword,mooType,mooVariable
endif
syn keyword mooStatement break continue else elseif endfor endfork endif endtry endwhile finally for if try
syn keyword mooStatement except fork while nextgroup=mooIdentifier skipwhite
syn keyword mooStatement return nextgroup=mooString skipwhite

" Operators
syn keyword mooOperatorIn in

" Error constants
syn keyword mooAny ANY
syn keyword mooErrorConstant E_ARGS E_INVARG E_DIV E_FLOAT E_INVIND E_MAXREC E_NACC E_NONE E_PERM E_PROPNF E_QUOTA E_RANGE E_RECMOVE E_TYPE E_VARNF E_VERBNF

" Builtin variables
syn match mooType display ~\<\%(ERR\|FLOAT\|INT\|LIST\|NUM\|OBJ\|STR\)\>~
syn match mooVariable display ~\<\%(args\%(tr\)\=\|caller\|dobj\%(str\)\=\|iobj\%(str\)\=\|player\|prepstr\|this\|verb\)\>~

" Strings
syn match mooStringError display ~[^\t -[\]-~]~ contained
syn match mooStringSpecialChar display ~\\["\\]~ contained
if !exists("moo_no_regexp")
  " Regular expressions
  syn match mooRegexp display ~%%~ contained containedin=mooString,mooRegexpParentheses transparent contains=NONE
  syn region mooRegexpParentheses display matchgroup=mooRegexpOr start=~%(~ skip=~%%~ end=~%)~ contained containedin=mooString,mooRegexpParentheses transparent oneline
  syn match mooRegexpOr display ~%|~ contained containedin=mooString,mooRegexpParentheses
endif
if !exists("moo_no_pronoun_sub")
  " Pronoun substitutions
  syn match mooPronounSub display ~%%~ contained containedin=mooString transparent contains=NONE
  syn match mooPronounSub display ~%[#dilnopqrst]~ contained containedin=mooString
  syn match mooPronounSub display ~%\[#[dilnt]\]~ contained containedin=mooString
  syn match mooPronounSub display ~%(\h\w*)~ contained containedin=mooString
  syn match mooPronounSub display ~%\[[dilnt]\h\w*\]~ contained containedin=mooString
  syn match mooPronounSub display ~%<\%([dilnt]:\)\=\a\+>~ contained containedin=mooString
endif
if exists("moo_unmatched_quotes")
  syn region mooString matchgroup=mooStringError start=~"~ end=~$~ contains=@mooStringContents keepend
  syn region mooString start=~"~ skip=~\\.~ end=~"~ contains=@mooStringContents oneline keepend
else
  syn region mooString start=~"~ skip=~\\.~ end=~"\|$~ contains=@mooStringContents keepend
endif

" Numbers and object numbers
syn match mooNumber display ~\%(\%(\<\d\+\)\=\.\d\+\|\<\d\+\)\%(e[+\-]\=\d\+\)\=\>~
syn match mooObject display ~#-\=\d\+\>~

" Properties and verbs
if exists("moo_builtin_properties")
  "Builtin properties
  syn keyword mooBuiltinProperty contents f location name owner programmer r w wizard contained containedin=mooPropRef
endif
if exists("moo_extended_cstyle_comments")
  syn match mooPropRef display ~\.\s*\%(\%(/\*.\{-}\*/\s*\)*\)\@>\h\w*\>~ transparent contains=mooCStyleComment,@mooKeyword
  syn match mooVerbRef display ~:\s*\%(\%(/\*.\{-}\*/\s*\)*\)\@>\h\w*\>~ transparent contains=mooCStyleComment,@mooKeyword
else
  syn match mooPropRef display ~\.\s*\h\w*\>~ transparent contains=@mooKeyword
  syn match mooVerbRef display ~:\s*\h\w*\>~ transparent contains=@mooKeyword
endif

" Builtin functions, core properties and core verbs
if exists("moo_extended_cstyle_comments")
  syn match mooBuiltinFunction display ~\<\h\w*\s*\%(\%(/\*.\{-}\*/\s*\)*\)\@>\ze(~ contains=mooCStyleComment
  syn match mooCorePropOrVerb display ~\$\s*\%(\%(/\*.\{-}\*/\s*\)*\)\@>\%(in\>\)\@!\h\w*\>~ contains=mooCStyleComment,@mooKeyword
else
  syn match mooBuiltinFunction display ~\<\h\w*\s*\ze(~ contains=NONE
  syn match mooCorePropOrVerb display ~\$\s*\%(in\>\)\@!\h\w*\>~ contains=@mooKeyword
endif
if exists("moo_unknown_builtin_functions")
  syn match mooUnknownBuiltinFunction ~\<\h\w*\>~ contained containedin=mooBuiltinFunction contains=mooKnownBuiltinFunction
  " Known builtin functions as of version 1.8.1 of the server
  " Add your own extensions to this group if you like
  syn keyword mooKnownBuiltinFunction abs acos add_property add_verb asin atan binary_hash boot_player buffered_output_length callers caller_perms call_function ceil children chparent clear_property connected_players connected_seconds connection_name connection_option connection_options cos cosh create crypt ctime db_disk_size decode_binary delete_property delete_verb disassemble dump_database encode_binary equal eval exp floatstr floor flush_input force_input function_info idle_seconds index is_clear_property is_member is_player kill_task length listappend listdelete listen listeners listinsert listset log log10 match max max_object memory_usage min move notify object_bytes open_network_connection output_delimiters parent pass players properties property_info queued_tasks queue_info raise random read recycle renumber reset_max_object resume rindex rmatch seconds_left server_log server_version setadd setremove set_connection_option set_player_flag set_property_info set_task_perms set_verb_args set_verb_code set_verb_info shutdown sin sinh sqrt strcmp string_hash strsub substitute suspend tan tanh task_id task_stack ticks_left time tofloat toint toliteral tonum toobj tostr trunc typeof unlisten valid value_bytes value_hash verbs verb_args verb_code verb_info contained
endif

" Enclosed expressions
syn match mooUnenclosedError display ~[')\]|}]~
syn match mooParenthesesError display ~[';\]|}]~ contained
syn region mooParentheses start=~(~ end=~)~ transparent contains=@mooEnclosedContents,mooParenthesesError
syn match mooBracketsError display ~[');|}]~ contained
syn region mooBrackets start=~\[~ end=~\]~ transparent contains=@mooEnclosedContents,mooBracketsError
syn match mooBracesError display ~[');\]|]~ contained
syn region mooBraces start=~{~ end=~}~ transparent contains=@mooEnclosedContents,mooBracesError
syn match mooQuestionError display ~[');\]}]~ contained
syn region mooQuestion start=~?~ end=~|~ transparent contains=@mooEnclosedContents,mooQuestionError
syn match mooCatchError display ~[);\]|}]~ contained
syn region mooCatch matchgroup=mooExclamation start=~`~ end=~'~ transparent contains=@mooEnclosedContents,mooCatchError,mooExclamation
if exists("moo_extended_cstyle_comments")
  syn match mooExclamation display ~[\t !%&(*+,\-/<=>?@[^`{|]\@<!\s*\%(\%(/\*.\{-}\*/\s*\)*\)\@>!=\@!~ contained contains=mooCStyleComment
else
  syn match mooExclamation display ~[\t !%&(*+,\-/<=>?@[^`{|]\@<!\s*!=\@!~ contained
endif

" Comments
syn match mooCommentSpecialChar display ~\\["\\]~ contained transparent contains=NONE
syn match mooComment ~[\t !%&*+,\-/<=>?@^|]\@<!\s*"\([^\"]\|\\.\)*"\s*;~ contains=mooStringError,mooCommentSpecialChar

" Non-code
syn region mooNonCode start=~^\s*@\<~ end=~$~
syn match mooNonCode display ~^\.$~
syn match mooNonCode display ~^\s*\d\+:~he=e-1

" Overriding matches
syn match mooRangeOperator display ~\.\.~ transparent contains=NONE
syn match mooOrOperator display ~||~ transparent contains=NONE
if exists("moo_extended_cstyle_comments")
  syn match mooScattering ~[,{]\@<=\s*\%(\%(/\*.\{-}\*/\s*\)*\)\@>?~ transparent contains=mooCStyleComment
else
  syn match mooScattering ~[,{]\@<=\s*?~ transparent contains=NONE
endif

" Clusters
syn cluster mooKeyword contains=mooStatement,mooOperatorIn,mooAny,mooErrorConstant
syn cluster mooStringContents contains=mooStringError,mooStringSpecialChar
syn cluster mooEnclosedContents contains=TOP,mooUnenclosedError,mooComment,mooNonCode

" Define the default highlighting.
hi def link mooUncommentedError Error
hi def link mooCStyleCommentError Error
hi def link mooCStyleComment Comment
hi def link mooStatement Statement
hi def link mooOperatorIn Operator
hi def link mooAny Constant " link this to Keyword if you want
hi def link mooErrorConstant Constant
hi def link mooType Type
hi def link mooVariable Type
hi def link mooStringError Error
hi def link mooStringSpecialChar SpecialChar
hi def link mooRegexpOr SpecialChar
hi def link mooPronounSub SpecialChar
hi def link mooString String
hi def link mooNumber Number
hi def link mooObject Number
hi def link mooBuiltinProperty Type
hi def link mooBuiltinFunction Function
hi def link mooUnknownBuiltinFunction Error
hi def link mooKnownBuiltinFunction Function
hi def link mooCorePropOrVerb Identifier
hi def link mooUnenclosedError Error
hi def link mooParenthesesError Error
hi def link mooBracketsError Error
hi def link mooBracesError Error
hi def link mooQuestionError Error
hi def link mooCatchError Error
hi def link mooExclamation Exception
hi def link mooComment Comment
hi def link mooNonCode PreProc

let b:current_syntax = "moo"

" vim: ts=8
