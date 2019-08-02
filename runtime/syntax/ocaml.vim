" Vim syntax file
" Language:     OCaml
" Filenames:    *.ml *.mli *.mll *.mly
" Maintainers:  Markus Mottl      <markus.mottl@gmail.com>
"               Karl-Heinz Sylla  <Karl-Heinz.Sylla@gmd.de>
"               Issac Trotts      <ijtrotts@ucdavis.edu>
" URL:          https://github.com/rgrinberg/vim-ocaml
" Last Change:
"               2018 Nov 08 - Improved highlighting of operators (Maëlan)
"               2018 Apr 22 - Improved support for PPX (Andrey Popp)
"               2018 Mar 16 - Remove raise, lnot and not from keywords (Étienne Millon, "copy")
"               2017 Apr 11 - Improved matching of negative numbers (MM)
"               2016 Mar 11 - Improved support for quoted strings (Glen Mével)
"               2015 Aug 13 - Allow apostrophes in identifiers (Jonathan Chan, Einar Lielmanis)
"               2015 Jun 17 - Added new "nonrec" keyword (MM)

" A minor patch was applied to the official version so that object/end
" can be distinguished from begin/end, which is used for indentation,
" and folding. (David Baelde)

" quit when a syntax file was already loaded
if exists("b:current_syntax") && b:current_syntax == "ocaml"
  finish
endif

" ' can be used in OCaml identifiers
setlocal iskeyword+='

" OCaml is case sensitive.
syn case match

" Access to the method of an object
syn match    ocamlMethod       "#"

" Script headers highlighted like comments
syn match    ocamlComment   "^#!.*" contains=@Spell

" Scripting directives
syn match    ocamlScript "^#\<\(quit\|labels\|warnings\|warn_error\|directory\|remove_directory\|cd\|load\|load_rec\|use\|mod_use\|install_printer\|remove_printer\|require\|list\|ppx\|principal\|predicates\|rectypes\|thread\|trace\|untrace\|untrace_all\|print_depth\|print_length\|camlp4o\|camlp4r\|topfind_log\|topfind_verbose\)\>"

" lowercase identifier - the standard way to match
syn match    ocamlLCIdentifier /\<\(\l\|_\)\(\w\|'\)*\>/

syn match    ocamlKeyChar    "|"

" Errors
syn match    ocamlBraceErr   "}"
syn match    ocamlBrackErr   "\]"
syn match    ocamlParenErr   ")"
syn match    ocamlArrErr     "|]"

syn match    ocamlCommentErr "\*)"

syn match    ocamlCountErr   "\<downto\>"
syn match    ocamlCountErr   "\<to\>"

if !exists("ocaml_revised")
  syn match    ocamlDoErr      "\<do\>"
endif

syn match    ocamlDoneErr    "\<done\>"
syn match    ocamlThenErr    "\<then\>"

" Error-highlighting of "end" without synchronization:
" as keyword or as error (default)
if exists("ocaml_noend_error")
  syn match    ocamlKeyword    "\<end\>"
else
  syn match    ocamlEndErr     "\<end\>"
endif

" Some convenient clusters
syn cluster  ocamlAllErrs contains=ocamlBraceErr,ocamlBrackErr,ocamlParenErr,ocamlCommentErr,ocamlCountErr,ocamlDoErr,ocamlDoneErr,ocamlEndErr,ocamlThenErr

syn cluster  ocamlAENoParen contains=ocamlBraceErr,ocamlBrackErr,ocamlCommentErr,ocamlCountErr,ocamlDoErr,ocamlDoneErr,ocamlEndErr,ocamlThenErr

syn cluster  ocamlContained contains=ocamlTodo,ocamlPreDef,ocamlModParam,ocamlModParam1,ocamlMPRestr,ocamlMPRestr1,ocamlMPRestr2,ocamlMPRestr3,ocamlModRHS,ocamlFuncWith,ocamlFuncStruct,ocamlModTypeRestr,ocamlModTRWith,ocamlWith,ocamlWithRest,ocamlModType,ocamlFullMod,ocamlVal


" Enclosing delimiters
syn region   ocamlEncl transparent matchgroup=ocamlKeyword start="(" matchgroup=ocamlKeyword end=")" contains=ALLBUT,@ocamlContained,ocamlParenErr
syn region   ocamlEncl transparent matchgroup=ocamlKeyword start="{" matchgroup=ocamlKeyword end="}"  contains=ALLBUT,@ocamlContained,ocamlBraceErr
syn region   ocamlEncl transparent matchgroup=ocamlKeyword start="\[" matchgroup=ocamlKeyword end="\]" contains=ALLBUT,@ocamlContained,ocamlBrackErr
syn region   ocamlEncl transparent matchgroup=ocamlKeyword start="\[|" matchgroup=ocamlKeyword end="|\]" contains=ALLBUT,@ocamlContained,ocamlArrErr


" Comments
syn region   ocamlComment start="(\*" end="\*)" contains=@Spell,ocamlComment,ocamlTodo
syn keyword  ocamlTodo contained TODO FIXME XXX NOTE


" Objects
syn region   ocamlEnd matchgroup=ocamlObject start="\<object\>" matchgroup=ocamlObject end="\<end\>" contains=ALLBUT,@ocamlContained,ocamlEndErr


" Blocks
if !exists("ocaml_revised")
  syn region   ocamlEnd matchgroup=ocamlKeyword start="\<begin\>" matchgroup=ocamlKeyword end="\<end\>" contains=ALLBUT,@ocamlContained,ocamlEndErr
endif


" "for"
syn region   ocamlNone matchgroup=ocamlKeyword start="\<for\>" matchgroup=ocamlKeyword end="\<\(to\|downto\)\>" contains=ALLBUT,@ocamlContained,ocamlCountErr


" "do"
if !exists("ocaml_revised")
  syn region   ocamlDo matchgroup=ocamlKeyword start="\<do\>" matchgroup=ocamlKeyword end="\<done\>" contains=ALLBUT,@ocamlContained,ocamlDoneErr
endif

" "if"
syn region   ocamlNone matchgroup=ocamlKeyword start="\<if\>" matchgroup=ocamlKeyword end="\<then\>" contains=ALLBUT,@ocamlContained,ocamlThenErr

"" PPX nodes

syn match ocamlPpxIdentifier /\(\[@\{1,3\}\)\@<=\w\+\(\.\w\+\)*/
syn region ocamlPpx matchgroup=ocamlPpxEncl start="\[@\{1,3\}" contains=TOP end="\]"

"" Modules

" "sig"
syn region   ocamlSig matchgroup=ocamlSigEncl start="\<sig\>" matchgroup=ocamlSigEncl end="\<end\>" contains=ALLBUT,@ocamlContained,ocamlEndErr,ocamlModule
syn region   ocamlModSpec matchgroup=ocamlKeyword start="\<module\>" matchgroup=ocamlModule end="\<\u\(\w\|'\)*\>" contained contains=@ocamlAllErrs,ocamlComment skipwhite skipempty nextgroup=ocamlModTRWith,ocamlMPRestr

" "open"
syn region   ocamlNone matchgroup=ocamlKeyword start="\<open\>" matchgroup=ocamlModule end="\<\u\(\w\|'\)*\( *\. *\u\(\w\|'\)*\)*\>" contains=@ocamlAllErrs,ocamlComment

" "include"
syn match    ocamlKeyword "\<include\>" skipwhite skipempty nextgroup=ocamlModParam,ocamlFullMod

" "module" - somewhat complicated stuff ;-)
syn region   ocamlModule matchgroup=ocamlKeyword start="\<module\>" matchgroup=ocamlModule end="\<\u\(\w\|'\)*\>" contains=@ocamlAllErrs,ocamlComment skipwhite skipempty nextgroup=ocamlPreDef
syn region   ocamlPreDef start="."me=e-1 matchgroup=ocamlKeyword end="\l\|=\|)"me=e-1 contained contains=@ocamlAllErrs,ocamlComment,ocamlModParam,ocamlGenMod,ocamlModTypeRestr,ocamlModTRWith nextgroup=ocamlModPreRHS
syn region   ocamlModParam start="([^*]" end=")" contained contains=ocamlGenMod,ocamlModParam1,ocamlSig,ocamlVal
syn match    ocamlModParam1 "\<\u\(\w\|'\)*\>" contained skipwhite skipempty
syn match    ocamlGenMod "()" contained skipwhite skipempty

syn region   ocamlMPRestr start=":" end="."me=e-1 contained contains=@ocamlComment skipwhite skipempty nextgroup=ocamlMPRestr1,ocamlMPRestr2,ocamlMPRestr3
syn region   ocamlMPRestr1 matchgroup=ocamlSigEncl start="\ssig\s\=" matchgroup=ocamlSigEncl end="\<end\>" contained contains=ALLBUT,@ocamlContained,ocamlEndErr,ocamlModule
syn region   ocamlMPRestr2 start="\sfunctor\(\s\|(\)\="me=e-1 matchgroup=ocamlKeyword end="->" contained contains=@ocamlAllErrs,ocamlComment,ocamlModParam,ocamlGenMod skipwhite skipempty nextgroup=ocamlFuncWith,ocamlMPRestr2
syn match    ocamlMPRestr3 "\w\(\w\|'\)*\( *\. *\w\(\w\|'\)*\)*" contained
syn match    ocamlModPreRHS "=" contained skipwhite skipempty nextgroup=ocamlModParam,ocamlFullMod
syn keyword  ocamlKeyword val
syn region   ocamlVal matchgroup=ocamlKeyword start="\<val\>" matchgroup=ocamlLCIdentifier end="\<\l\(\w\|'\)*\>" contains=@ocamlAllErrs,ocamlComment,ocamlFullMod skipwhite skipempty nextgroup=ocamlMPRestr
syn region   ocamlModRHS start="." end=". *\w\|([^*]"me=e-2 contained contains=ocamlComment skipwhite skipempty nextgroup=ocamlModParam,ocamlFullMod
syn match    ocamlFullMod "\<\u\(\w\|'\)*\( *\. *\u\(\w\|'\)*\)*" contained skipwhite skipempty nextgroup=ocamlFuncWith

syn region   ocamlFuncWith start="([^*)]"me=e-1 end=")" contained contains=ocamlComment,ocamlWith,ocamlFuncStruct skipwhite skipempty nextgroup=ocamlFuncWith
syn region   ocamlFuncStruct matchgroup=ocamlStructEncl start="[^a-zA-Z]struct\>"hs=s+1 matchgroup=ocamlStructEncl end="\<end\>" contains=ALLBUT,@ocamlContained,ocamlEndErr

syn match    ocamlModTypeRestr "\<\w\(\w\|'\)*\( *\. *\w\(\w\|'\)*\)*\>" contained
syn region   ocamlModTRWith start=":\s*("hs=s+1 end=")" contained contains=@ocamlAENoParen,ocamlWith
syn match    ocamlWith "\<\(\u\(\w\|'\)* *\. *\)*\w\(\w\|'\)*\>" contained skipwhite skipempty nextgroup=ocamlWithRest
syn region   ocamlWithRest start="[^)]" end=")"me=e-1 contained contains=ALLBUT,@ocamlContained

" "struct"
syn region   ocamlStruct matchgroup=ocamlStructEncl start="\<\(module\s\+\)\=struct\>" matchgroup=ocamlStructEncl end="\<end\>" contains=ALLBUT,@ocamlContained,ocamlEndErr

" "module type"
syn region   ocamlKeyword start="\<module\>\s*\<type\>\(\s*\<of\>\)\=" matchgroup=ocamlModule end="\<\w\(\w\|'\)*\>" contains=ocamlComment skipwhite skipempty nextgroup=ocamlMTDef
syn match    ocamlMTDef "=\s*\w\(\w\|'\)*\>"hs=s+1,me=s+1 skipwhite skipempty nextgroup=ocamlFullMod

" Quoted strings
syn region ocamlString matchgroup=ocamlQuotedStringDelim start="{\z\([a-z_]*\)|" end="|\z1}" contains=@Spell

syn keyword  ocamlKeyword  and as assert class
syn keyword  ocamlKeyword  constraint else
syn keyword  ocamlKeyword  exception external fun

syn keyword  ocamlKeyword  in inherit initializer
syn keyword  ocamlKeyword  lazy let match
syn keyword  ocamlKeyword  method mutable new nonrec of
syn keyword  ocamlKeyword  parser private rec
syn keyword  ocamlKeyword  try type
syn keyword  ocamlKeyword  virtual when while with

if exists("ocaml_revised")
  syn keyword  ocamlKeyword  do value
  syn keyword  ocamlBoolean  True False
else
  syn keyword  ocamlKeyword  function
  syn keyword  ocamlBoolean  true false
endif

syn keyword  ocamlType     array bool char exn float format format4
syn keyword  ocamlType     int int32 int64 lazy_t list nativeint option
syn keyword  ocamlType     bytes string unit

syn match    ocamlConstructor  "(\s*)"
syn match    ocamlConstructor  "\[\s*\]"
syn match    ocamlConstructor  "\[|\s*>|]"
syn match    ocamlConstructor  "\[<\s*>\]"
syn match    ocamlConstructor  "\u\(\w\|'\)*\>"

" Polymorphic variants
syn match    ocamlConstructor  "`\w\(\w\|'\)*\>"

" Module prefix
syn match    ocamlModPath      "\u\(\w\|'\)* *\."he=e-1

syn match    ocamlCharacter    "'\\\d\d\d'\|'\\[\'ntbr]'\|'.'"
syn match    ocamlCharacter    "'\\x\x\x'"
syn match    ocamlCharErr      "'\\\d\d'\|'\\\d'"
syn match    ocamlCharErr      "'\\[^\'ntbr]'"
syn region   ocamlString       start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell

syn match    ocamlTopStop      ";;"

syn match    ocamlAnyVar       "\<_\>"
syn match    ocamlKeyChar      "|[^\]]"me=e-1
syn match    ocamlKeyChar      ";"
syn match    ocamlKeyChar      "\~"
syn match    ocamlKeyChar      "?"

"" Operators

" The grammar of operators is found there:
"     https://caml.inria.fr/pub/docs/manual-ocaml/names.html#operator-name
"     https://caml.inria.fr/pub/docs/manual-ocaml/extn.html#s:ext-ops
"     https://caml.inria.fr/pub/docs/manual-ocaml/extn.html#s:index-operators
" =, *, < and > are both operator names and keywords, we let the user choose how
" to display them (has to be declared before regular infix operators):
syn match    ocamlEqual        "="
syn match    ocamlStar         "*"
syn match    ocamlAngle        "<"
syn match    ocamlAngle        ">"
" Custom indexing operators:
syn match    ocamlIndexingOp   "\.[~?!:|&$%=>@^/*+-][~?!.:|&$%<=>@^*/+-]*\(()\|\[]\|{}\)\(<-\)\?"
" Extension operators (has to be declared before regular infix operators):
syn match    ocamlExtensionOp          "#[#~?!.:|&$%<=>@^*/+-]\+"
" Infix and prefix operators:
syn match    ocamlPrefixOp              "![~?!.:|&$%<=>@^*/+-]*"
syn match    ocamlPrefixOp           "[~?][~?!.:|&$%<=>@^*/+-]\+"
syn match    ocamlInfixOp      "[&$%@^/+-][~?!.:|&$%<=>@^*/+-]*"
syn match    ocamlInfixOp         "[|<=>*][~?!.:|&$%<=>@^*/+-]\+"
syn match    ocamlInfixOp               "#[~?!.:|&$%<=>@^*/+-]\+#\@!"
syn match    ocamlInfixOp              "!=[~?!.:|&$%<=>@^*/+-]\@!"
syn keyword  ocamlInfixOpKeyword      asr land lor lsl lsr lxor mod or
" := is technically an infix operator, but we may want to show it as a keyword
" (somewhat analogously to = for let‐bindings and <- for assignations):
syn match    ocamlRefAssign    ":="
" :: is technically not an operator, but we may want to show it as such:
syn match    ocamlCons         "::"
" -> and <- are keywords, not operators (but can appear in longer operators):
syn match    ocamlArrow        "->[~?!.:|&$%<=>@^*/+-]\@!"
if exists("ocaml_revised")
  syn match    ocamlErr        "<-[~?!.:|&$%<=>@^*/+-]\@!"
else
  syn match    ocamlKeyChar    "<-[~?!.:|&$%<=>@^*/+-]\@!"
endif

syn match    ocamlNumber        "-\=\<\d\(_\|\d\)*[l|L|n]\?\>"
syn match    ocamlNumber        "-\=\<0[x|X]\(\x\|_\)\+[l|L|n]\?\>"
syn match    ocamlNumber        "-\=\<0[o|O]\(\o\|_\)\+[l|L|n]\?\>"
syn match    ocamlNumber        "-\=\<0[b|B]\([01]\|_\)\+[l|L|n]\?\>"
syn match    ocamlFloat         "-\=\<\d\(_\|\d\)*\.\?\(_\|\d\)*\([eE][-+]\=\d\(_\|\d\)*\)\=\>"

" Labels
syn match    ocamlLabel        "\~\(\l\|_\)\(\w\|'\)*"lc=1
syn match    ocamlLabel        "?\(\l\|_\)\(\w\|'\)*"lc=1
syn region   ocamlLabel transparent matchgroup=ocamlLabel start="[~?](\(\l\|_\)\(\w\|'\)*"lc=2 end=")"me=e-1 contains=ALLBUT,@ocamlContained,ocamlParenErr


" Synchronization
syn sync minlines=50
syn sync maxlines=500

if !exists("ocaml_revised")
  syn sync match ocamlDoSync      grouphere  ocamlDo      "\<do\>"
  syn sync match ocamlDoSync      groupthere ocamlDo      "\<done\>"
endif

if exists("ocaml_revised")
  syn sync match ocamlEndSync     grouphere  ocamlEnd     "\<\(object\)\>"
else
  syn sync match ocamlEndSync     grouphere  ocamlEnd     "\<\(begin\|object\)\>"
endif

syn sync match ocamlEndSync     groupthere ocamlEnd     "\<end\>"
syn sync match ocamlStructSync  grouphere  ocamlStruct  "\<struct\>"
syn sync match ocamlStructSync  groupthere ocamlStruct  "\<end\>"
syn sync match ocamlSigSync     grouphere  ocamlSig     "\<sig\>"
syn sync match ocamlSigSync     groupthere ocamlSig     "\<end\>"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link ocamlBraceErr	   Error
hi def link ocamlBrackErr	   Error
hi def link ocamlParenErr	   Error
hi def link ocamlArrErr	   Error

hi def link ocamlCommentErr   Error

hi def link ocamlCountErr	   Error
hi def link ocamlDoErr	   Error
hi def link ocamlDoneErr	   Error
hi def link ocamlEndErr	   Error
hi def link ocamlThenErr	   Error

hi def link ocamlCharErr	   Error

hi def link ocamlErr	   Error

hi def link ocamlComment	   Comment

hi def link ocamlModPath	   Include
hi def link ocamlObject	   Include
hi def link ocamlModule	   Include
hi def link ocamlModParam1    Include
hi def link ocamlModType	   Include
hi def link ocamlMPRestr3	   Include
hi def link ocamlFullMod	   Include
hi def link ocamlModTypeRestr Include
hi def link ocamlWith	   Include
hi def link ocamlMTDef	   Include
hi def link ocamlSigEncl    ocamlModule
hi def link ocamlStructEncl ocamlModule

hi def link ocamlScript	   Include

hi def link ocamlConstructor  Constant

hi def link ocamlVal          Keyword
hi def link ocamlModPreRHS    Keyword
hi def link ocamlMPRestr2	   Keyword
hi def link ocamlKeyword	   Keyword
hi def link ocamlMethod	   Include
hi def link ocamlKeyChar	   Keyword
hi def link ocamlAnyVar	   Keyword
hi def link ocamlTopStop	   Keyword

hi def link ocamlRefAssign  ocamlKeyChar
hi def link ocamlEqual	    ocamlKeyChar
hi def link ocamlStar	    ocamlInfixOp
hi def link ocamlAngle	    ocamlInfixOp
hi def link ocamlCons	    ocamlInfixOp

hi def link ocamlPrefixOp	ocamlOperator
hi def link ocamlInfixOp	ocamlOperator
hi def link ocamlExtensionOp	ocamlOperator
hi def link ocamlIndexingOp	ocamlOperator

if exists("ocaml_highlight_operators")
    hi def link ocamlInfixOpKeyword ocamlOperator
    hi def link ocamlOperator	    Operator
else
    hi def link ocamlInfixOpKeyword Keyword
endif

hi def link ocamlBoolean	   Boolean
hi def link ocamlCharacter    Character
hi def link ocamlNumber	   Number
hi def link ocamlFloat	   Float
hi def link ocamlString	   String
hi def link ocamlQuotedStringDelim  Identifier

hi def link ocamlLabel	   Identifier

hi def link ocamlType	   Type

hi def link ocamlTodo	   Todo

hi def link ocamlEncl	   Keyword

hi def link ocamlPpxEncl    ocamlEncl

let b:current_syntax = "ocaml"

" vim: ts=8
