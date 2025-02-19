" Vim syntax file
" Language:     OCaml
" Filenames:    *.ml *.mli *.mll *.mly
" Maintainers:  Markus Mottl      <markus.mottl@gmail.com>
"               Karl-Heinz Sylla  <Karl-Heinz.Sylla@gmd.de>
"               Issac Trotts      <ijtrotts@ucdavis.edu>
" URL:          https://github.com/ocaml/vim-ocaml
" Last Change:
"               2019 Nov 05 - Accurate type highlighting (Maëlan)
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

" Quit when a syntax file was already loaded
if exists("b:current_syntax") && b:current_syntax == "ocaml"
  finish
endif

let s:keepcpo = &cpo
set cpo&vim

" ' can be used in OCaml identifiers
setlocal iskeyword+='

" ` is part of the name of polymorphic variants
setlocal iskeyword+=`

" OCaml is case sensitive.
syn case match

" Access to the method of an object
syn match    ocamlMethod       "#"

" Scripting directives
syn match    ocamlScript "^#\<\(quit\|labels\|warnings\|warn_error\|directory\|remove_directory\|cd\|load\|load_rec\|use\|mod_use\|install_printer\|remove_printer\|require\|list\|ppx\|principal\|predicates\|rectypes\|thread\|trace\|untrace\|untrace_all\|print_depth\|print_length\|camlp4o\|camlp4r\|topfind_log\|topfind_verbose\)\>"

" lowercase identifier - the standard way to match
syn match    ocamlLCIdentifier /\<\(\l\|_\)\(\w\|'\)*\>/

" Errors
syn match    ocamlBraceErr   "}"
syn match    ocamlBrackErr   "\]"
syn match    ocamlParenErr   ")"
syn match    ocamlArrErr     "|]"

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

" These keywords are only expected nested in constructions that are handled by
" the type linter, so outside of type contexts we highlight them as errors:
syn match    ocamlKwErr  "\<\(mutable\|nonrec\|of\|private\)\>"

" Some convenient clusters
syn cluster  ocamlAllErrs contains=@ocamlAENoParen,ocamlParenErr
syn cluster  ocamlAENoParen contains=ocamlBraceErr,ocamlBrackErr,ocamlCountErr,ocamlDoErr,ocamlDoneErr,ocamlEndErr,ocamlThenErr,ocamlKwErr

syn cluster  ocamlContained contains=ocamlTodo,ocamlPreDef,ocamlModParam,ocamlModParam1,ocamlModTypePre,ocamlModRHS,ocamlFuncWith,ocamlModTypeRestr,ocamlModTRWith,ocamlWith,ocamlWithRest,ocamlFullMod,ocamlVal


" Enclosing delimiters
syn region   ocamlNone transparent matchgroup=ocamlEncl start="(" matchgroup=ocamlEncl end=")" contains=ALLBUT,@ocamlContained,ocamlParenErr
syn region   ocamlNone transparent matchgroup=ocamlEncl start="{" matchgroup=ocamlEncl end="}"  contains=ALLBUT,@ocamlContained,ocamlBraceErr
syn region   ocamlNone transparent matchgroup=ocamlEncl start="\[" matchgroup=ocamlEncl end="\]" contains=ALLBUT,@ocamlContained,ocamlBrackErr
syn region   ocamlNone transparent matchgroup=ocamlEncl start="\[|" matchgroup=ocamlEncl end="|\]" contains=ALLBUT,@ocamlContained,ocamlArrErr


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

" "open"
syn match   ocamlKeyword "\<open\>" skipwhite skipempty nextgroup=ocamlFullMod

" "include"
syn match    ocamlKeyword "\<include\>" skipwhite skipempty nextgroup=ocamlModParam,ocamlFullMod

" "module" - somewhat complicated stuff ;-)
" 2022-10: please document it?
syn region   ocamlModule matchgroup=ocamlKeyword start="\<module\>" matchgroup=ocamlModule end="\<_\|\u\(\w\|'\)*\>" contains=@ocamlAllErrs,ocamlComment skipwhite skipempty nextgroup=ocamlPreDef
syn region   ocamlPreDef start="."me=e-1 end="[a-z:=)]\@=" contained contains=@ocamlAllErrs,ocamlComment,ocamlModParam,ocamlGenMod,ocamlModTypeRestr nextgroup=ocamlModTypePre,ocamlModPreRHS
syn region   ocamlModParam start="(\*\@!" end=")" contained contains=ocamlGenMod,ocamlModParam,ocamlModParam1,ocamlSig,ocamlVal
syn match    ocamlModParam1 "\<\u\(\w\|'\)*\>" contained skipwhite skipempty
syn match    ocamlGenMod "()" contained skipwhite skipempty

syn match    ocamlModTypePre ":" contained skipwhite skipempty nextgroup=ocamlModTRWith,ocamlSig,ocamlFunctor,ocamlModTypeRestr,ocamlModTypeOf
syn match    ocamlModTypeRestr "\<\w\(\w\|'\)*\( *\. *\w\(\w\|'\)*\)*\>" contained

syn match    ocamlModPreRHS "=" contained skipwhite skipempty nextgroup=ocamlModParam,ocamlFullMod
syn keyword  ocamlKeyword val
syn region   ocamlVal matchgroup=ocamlKeyword start="\<val\>" matchgroup=ocamlLCIdentifier end="\<\l\(\w\|'\)*\>" contains=@ocamlAllErrs,ocamlComment,ocamlFullMod skipwhite skipempty nextgroup=ocamlModTypePre
syn region   ocamlModRHS start="." end=". *\w\|([^*]"me=e-2 contained contains=ocamlComment skipwhite skipempty nextgroup=ocamlModParam,ocamlFullMod
syn match    ocamlFullMod "\<\u\(\w\|'\)*\( *\. *\u\(\w\|'\)*\)*" contained skipwhite skipempty nextgroup=ocamlFuncWith

syn region   ocamlFuncWith start="([*)]\@!" end=")" contained contains=ocamlComment,ocamlWith,ocamlStruct skipwhite skipempty nextgroup=ocamlFuncWith

syn region   ocamlModTRWith start="(\*\@!" end=")" contained contains=@ocamlAENoParen,ocamlWith
syn match    ocamlWith "\<\(\u\(\w\|'\)* *\. *\)*\w\(\w\|'\)*\>" contained skipwhite skipempty nextgroup=ocamlWithRest
syn region   ocamlWithRest start="[^)]" end=")"me=e-1 contained contains=ALLBUT,@ocamlContained

" "struct"
syn region   ocamlStruct matchgroup=ocamlStructEncl start="\<\(module\s\+\)\=struct\>" matchgroup=ocamlStructEncl end="\<end\>" contains=ALLBUT,@ocamlContained,ocamlEndErr

" "sig"
syn region   ocamlSig matchgroup=ocamlSigEncl start="\<sig\>" matchgroup=ocamlSigEncl end="\<end\>" contains=ALLBUT,@ocamlContained,ocamlEndErr

" "functor"
syn region   ocamlFunctor start="\<functor\>" matchgroup=ocamlKeyword end="->" contains=@ocamlAllErrs,ocamlComment,ocamlModParam,ocamlGenMod skipwhite skipempty nextgroup=ocamlStruct,ocamlSig,ocamlFuncWith,ocamlFunctor

" "module type"
syn region   ocamlModTypeOf start="\<module\s\+type\(\s\+of\)\=\>" matchgroup=ocamlModule end="\<\w\(\w\|'\)*\>" contains=ocamlComment skipwhite skipempty nextgroup=ocamlMTDef
syn match    ocamlMTDef "=\s*\w\(\w\|'\)*\>"hs=s+1,me=s+1 skipwhite skipempty nextgroup=ocamlFullMod

" Quoted strings
syn region ocamlString matchgroup=ocamlQuotedStringDelim start="{\z\([a-z_]*\)|" end="|\z1}" contains=@Spell
syn region ocamlString matchgroup=ocamlQuotedStringDelim start="{%[a-z_]\+\(\.[a-z_]\+\)\?\( \z\([a-z_]\+\)\)\?|" end="|\z1}" contains=@Spell

syn keyword  ocamlKeyword  and as assert class
syn keyword  ocamlKeyword  else
syn keyword  ocamlKeyword  external
syn keyword  ocamlKeyword  in inherit initializer
syn keyword  ocamlKeyword  lazy let match
syn keyword  ocamlKeyword  method new
syn keyword  ocamlKeyword  parser rec
syn keyword  ocamlKeyword  try
syn keyword  ocamlKeyword  virtual when while with

" Keywords which are handled by the type linter:
"     as (within a type equation)
"     constraint exception mutable nonrec of private type

" The `fun` keyword has special treatment because of the syntax `fun … : t -> e`
" where `->` ends the type context rather than being part of it; to handle that,
" we blacklist the ocamlTypeAnnot matchgroup, and we plug ocamlFunTypeAnnot
" instead (later in this file, by using containedin=ocamlFun):
syn region ocamlFun matchgroup=ocamlKeyword start='\<fun\>' matchgroup=ocamlArrow end='->'
\ contains=ALLBUT,@ocamlContained,ocamlArrow,ocamlInfixOp,ocamlTypeAnnot

if exists("ocaml_revised")
  syn keyword  ocamlKeyword  do value
  syn keyword  ocamlBoolean  True False
else
  syn keyword  ocamlKeyword  function
  syn keyword  ocamlBoolean  true false
endif

syn match    ocamlEmptyConstructor  "(\s*)"
syn match    ocamlEmptyConstructor  "\[\s*\]"
syn match    ocamlEmptyConstructor  "\[|\s*>|]"
syn match    ocamlEmptyConstructor  "\[<\s*>\]"
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

syn match    ocamlAnyVar       "\<_\>"
syn match    ocamlKeyChar      "|]\@!"
syn match    ocamlKeyChar      ";"
syn match    ocamlKeyChar      "\~"
syn match    ocamlKeyChar      "?"

" NOTE: for correct precedence, the rule for ";;" must come after that for ";"
syn match    ocamlTopStop      ";;"

"" Operators

" The grammar of operators is found there:
"     https://caml.inria.fr/pub/docs/manual-ocaml/names.html#operator-name
"     https://caml.inria.fr/pub/docs/manual-ocaml/extn.html#s:ext-ops
"     https://caml.inria.fr/pub/docs/manual-ocaml/extn.html#s:index-operators
" = is both an operator name and a keyword, we let the user choose how
" to display it (has to be declared before regular infix operators):
syn match    ocamlEqual        "="
" Custom indexing operators:
syn region   ocamlIndexing matchgroup=ocamlIndexingOp
  \ start="\.[~?!:|&$%=>@^/*+-][~?!.:|&$%<=>@^*/+-]*\_s*("
  \ end=")\(\_s*<-\)\?"
  \ contains=ALLBUT,@ocamlContained,ocamlParenErr
syn region   ocamlIndexing matchgroup=ocamlIndexingOp
  \ start="\.[~?!:|&$%=>@^/*+-][~?!.:|&$%<=>@^*/+-]*\_s*\["
  \ end="]\(\_s*<-\)\?"
  \ contains=ALLBUT,@ocamlContained,ocamlBrackErr
syn region   ocamlIndexing matchgroup=ocamlIndexingOp
  \ start="\.[~?!:|&$%=>@^/*+-][~?!.:|&$%<=>@^*/+-]*\_s*{"
  \ end="}\(\_s*<-\)\?"
  \ contains=ALLBUT,@ocamlContained,ocamlBraceErr
" Extension operators (has to be declared before regular infix operators):
syn match    ocamlExtensionOp          "#[#~?!.:|&$%<=>@^*/+-]\+"
" Infix and prefix operators:
syn match    ocamlPrefixOp              "![~?!.:|&$%<=>@^*/+-]*"
syn match    ocamlPrefixOp           "[~?][~?!.:|&$%<=>@^*/+-]\+"
syn match    ocamlInfixOp   "[&$%<>@^*/+-][~?!.:|&$%<=>@^*/+-]*"
syn match    ocamlInfixOp            "[|=][~?!.:|&$%<=>@^*/+-]\+"
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

" Script shebang (has to be declared after operators)
syn match    ocamlShebang       "\%1l^#!.*$"

syn match    ocamlNumber        "-\=\<\d\(_\|\d\)*[l|L|n]\?\>"
syn match    ocamlNumber        "-\=\<0[x|X]\(\x\|_\)\+[l|L|n]\?\>"
syn match    ocamlNumber        "-\=\<0[o|O]\(\o\|_\)\+[l|L|n]\?\>"
syn match    ocamlNumber        "-\=\<0[b|B]\([01]\|_\)\+[l|L|n]\?\>"
syn match    ocamlFloat         "-\=\<\d\(_\|\d\)*\.\?\(_\|\d\)*\([eE][-+]\=\d\(_\|\d\)*\)\=\>"

" Labels
syn match    ocamlLabel        "[~?]\(\l\|_\)\(\w\|'\)*:\?"
syn region   ocamlLabel transparent matchgroup=ocamlLabel start="[~?](\(\l\|_\)\(\w\|'\)*"lc=2 end=")"me=e-1 contains=ALLBUT,@ocamlContained,ocamlParenErr

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"" Type contexts

" How we recognize type contexts is explained in `type-linter-notes.md`
" and a test suite is found in `type-linter-test.ml`.
"
" ocamlTypeExpr is the cluster of things that can make up a type expression
" (in a loose sense, e.g. the “as” keyword and universal quantification are
" included). Regions containing a type expression use it like this:
"
"     contains=@ocamlTypeExpr,...
"
" ocamlTypeContained is the cluster of things that can be found in a type
" expression or a type definition. It is not expected to be used in any region,
" it exists solely for throwing things in it that should not pollute the main
" linter.
"
" Both clusters are filled in incrementally. Every match group that is not to be
" found at the main level must be declared as “contained” and added to either
" ocamlTypeExpr or ocamlTypeContained.
"
" In these clusters we don’t put generic things that can also be found elswhere,
" i.e. ocamlComment and ocamlPpx, because everything that is in these clusters
" is also put in ocamlContained and thus ignored by the main linter.

"syn cluster ocamlTypeExpr contains=
syn cluster ocamlTypeContained contains=@ocamlTypeExpr
syn cluster ocamlContained add=@ocamlTypeContained

" We’ll use a “catch-all” highlighting group to show as error anything that is
" not matched more specifically; we don’t want spaces to be reported as errors
" (different background color), so we just catch them here:
syn cluster ocamlTypeExpr add=ocamlTypeBlank
syn match    ocamlTypeBlank    contained  "\_s\+"
hi link ocamlTypeBlank NONE

" NOTE: Carefully avoid catching "(*" here.
syn cluster ocamlTypeExpr add=ocamlTypeParen
syn region ocamlTypeParen contained transparent
\ matchgroup=ocamlEncl start="(\*\@!"
\ matchgroup=ocamlEncl end=")"
\ contains=@ocamlTypeExpr,ocamlComment,ocamlPpx

syn cluster ocamlTypeExpr add=ocamlTypeKeyChar,ocamlTypeAs
syn match    ocamlTypeKeyChar  contained  "->"
syn match    ocamlTypeKeyChar  contained  "\*"
syn match    ocamlTypeKeyChar  contained  "#"
syn match    ocamlTypeKeyChar  contained  ","
syn match    ocamlTypeKeyChar  contained  "\."
syn keyword  ocamlTypeAs       contained  as
hi link ocamlTypeAs ocamlKeyword

syn cluster ocamlTypeExpr add=ocamlTypeVariance
syn match ocamlTypeVariance contained "[-+!]\ze *\('\|\<_\>\)"
syn match ocamlTypeVariance contained "[-+] *!\+\ze *\('\|\<_\>\)"
syn match ocamlTypeVariance contained "! *[-+]\+\ze *\('\|\<_\>\)"

syn cluster ocamlTypeContained add=ocamlTypeEq
syn match    ocamlTypeEq       contained  "[+:]\?="
hi link ocamlTypeEq ocamlKeyChar

syn cluster ocamlTypeExpr add=ocamlTypeVar,ocamlTypeConstr,ocamlTypeAnyVar,ocamlTypeBuiltin
syn match    ocamlTypeVar      contained   "'\(\l\|_\)\(\w\|'\)*\>"
syn match    ocamlTypeConstr   contained  "\<\(\l\|_\)\(\w\|'\)*\>"
" NOTE: for correct precedence, the rule for the wildcard (ocamlTypeAnyVar)
" must come after the rule for type constructors (ocamlTypeConstr).
syn match    ocamlTypeAnyVar   contained  "\<_\>"
" NOTE: For correct precedence, these builtin names must occur after the rule
" for type constructors (ocamlTypeConstr) but before the rule for non-optional
" labeled arguments (ocamlTypeLabel). For the latter to take precedence over
" these builtin names, we use “syn match” here instead of “syn keyword”.
syn match    ocamlTypeBuiltin  contained  "\<array\>"
syn match    ocamlTypeBuiltin  contained  "\<bool\>"
syn match    ocamlTypeBuiltin  contained  "\<bytes\>"
syn match    ocamlTypeBuiltin  contained  "\<char\>"
syn match    ocamlTypeBuiltin  contained  "\<exn\>"
syn match    ocamlTypeBuiltin  contained  "\<float\>"
syn match    ocamlTypeBuiltin  contained  "\<format\>"
syn match    ocamlTypeBuiltin  contained  "\<format4\>"
syn match    ocamlTypeBuiltin  contained  "\<format6\>"
syn match    ocamlTypeBuiltin  contained  "\<in_channel\>"
syn match    ocamlTypeBuiltin  contained  "\<int\>"
syn match    ocamlTypeBuiltin  contained  "\<int32\>"
syn match    ocamlTypeBuiltin  contained  "\<int64\>"
syn match    ocamlTypeBuiltin  contained  "\<lazy_t\>"
syn match    ocamlTypeBuiltin  contained  "\<list\>"
syn match    ocamlTypeBuiltin  contained  "\<nativeint\>"
syn match    ocamlTypeBuiltin  contained  "\<option\>"
syn match    ocamlTypeBuiltin  contained  "\<out_channel\>"
syn match    ocamlTypeBuiltin  contained  "\<ref\>"
syn match    ocamlTypeBuiltin  contained  "\<result\>"
syn match    ocamlTypeBuiltin  contained  "\<scanner\>"
syn match    ocamlTypeBuiltin  contained  "\<string\>"
syn match    ocamlTypeBuiltin  contained  "\<unit\>"

syn cluster ocamlTypeExpr add=ocamlTypeLabel
syn match    ocamlTypeLabel    contained  "?\?\(\l\|_\)\(\w\|'\)*\_s*:[>=]\@!"
hi link ocamlTypeLabel ocamlLabel

" Object type
syn cluster ocamlTypeExpr add=ocamlTypeObject
syn region ocamlTypeObject contained
\ matchgroup=ocamlEncl start="<"
\ matchgroup=ocamlEncl end=">"
\ contains=ocamlTypeObjectDots,ocamlLCIdentifier,ocamlTypeObjectAnnot,ocamlTypeBlank,ocamlComment,ocamlPpx
hi link ocamlTypeObject ocamlTypeCatchAll
syn cluster ocamlTypeContained add=ocamlTypeObjectDots
syn match ocamlTypeObjectDots contained "\.\."
hi link ocamlTypeObjectDots ocamlKeyChar
syn cluster ocamlTypeContained add=ocamlTypeObjectAnnot
syn region ocamlTypeObjectAnnot contained
\ matchgroup=ocamlKeyChar start=":"
\ matchgroup=ocamlKeyChar end=";\|>\@="
\ contains=@ocamlTypeExpr,ocamlComment,ocamlPpx
hi link ocamlTypeObjectAnnot ocamlTypeCatchAll

" Record type definition
syn cluster ocamlTypeContained add=ocamlTypeRecordDecl
syn region ocamlTypeRecordDecl contained
\ matchgroup=ocamlEncl start="{"
\ matchgroup=ocamlEncl end="}"
\ contains=ocamlTypeMutable,ocamlLCIdentifier,ocamlTypeRecordAnnot,ocamlTypeBlank,ocamlComment,ocamlPpx
hi link ocamlTypeRecordDecl ocamlTypeCatchAll
syn cluster ocamlTypeContained add=ocamlTypeMutable
syn keyword ocamlTypeMutable contained mutable
hi link ocamlTypeMutable ocamlKeyword
syn cluster ocamlTypeContained add=ocamlTypeRecordAnnot
syn region ocamlTypeRecordAnnot contained
\ matchgroup=ocamlKeyChar start=":"
\ matchgroup=ocamlKeyChar end=";\|}\@="
\ contains=@ocamlTypeExpr,ocamlComment,ocamlPpx
hi link ocamlTypeRecordAnnot ocamlTypeCatchAll

" Polymorphic variant types
" NOTE: Carefully avoid catching "[@" here.
syn cluster ocamlTypeExpr add=ocamlTypeVariant
syn region ocamlTypeVariant contained
\ matchgroup=ocamlEncl start="\[>" start="\[<" start="\[@\@!"
\ matchgroup=ocamlEncl end="\]"
\ contains=ocamlTypeVariantKeyChar,ocamlTypeVariantConstr,ocamlTypeVariantAnnot,ocamlTypeBlank,ocamlComment,ocamlPpx
hi link ocamlTypeVariant ocamlTypeCatchAll
syn cluster ocamlTypeContained add=ocamlTypeVariantKeyChar
syn match ocamlTypeVariantKeyChar contained "|"
syn match ocamlTypeVariantKeyChar contained ">"
hi link ocamlTypeVariantKeyChar ocamlKeyChar
syn cluster ocamlTypeContained add=ocamlTypeVariantConstr
syn match ocamlTypeVariantConstr contained "`\w\(\w\|'\)*\>"
hi link ocamlTypeVariantConstr ocamlConstructor
syn cluster ocamlTypeContained add=ocamlTypeVariantAnnot
syn region ocamlTypeVariantAnnot contained
\ matchgroup=ocamlKeyword start="\<of\>"
\ matchgroup=ocamlKeyChar end="|\|>\|\]\@="
\ contains=@ocamlTypeExpr,ocamlTypeAmp,ocamlComment,ocamlPpx
hi link ocamlTypeVariantAnnot ocamlTypeCatchAll
syn cluster ocamlTypeContained add=ocamlTypeAmp
syn match ocamlTypeAmp contained "&"
hi link ocamlTypeAmp ocamlTypeKeyChar

" Sum type definition
syn cluster ocamlTypeContained add=ocamlTypeSumDecl
syn region ocamlTypeSumDecl contained
\ matchgroup=ocamlTypeSumBar    start="|"
\ matchgroup=ocamlTypeSumConstr start="\<\u\(\w\|'\)*\>"
\ matchgroup=ocamlTypeSumConstr start="\<false\>" start="\<true\>"
\ matchgroup=ocamlTypeSumConstr start="(\_s*)" start="\[\_s*]" start="(\_s*::\_s*)"
\ matchgroup=NONE end="\(\<type\>\|\<exception\>\|\<val\>\|\<module\>\|\<class\>\|\<method\>\|\<constraint\>\|\<inherit\>\|\<object\>\|\<struct\>\|\<open\>\|\<include\>\|\<let\>\|\<external\>\|\<in\>\|\<end\>\|)\|]\|}\|;\|;;\|=\)\@="
\ matchgroup=NONE end="\(\<and\>\)\@="
\ contains=ocamlTypeSumBar,ocamlTypeSumConstr,ocamlTypeSumAnnot,ocamlTypeBlank,ocamlComment,ocamlPpx
hi link ocamlTypeSumDecl ocamlTypeCatchAll
syn cluster ocamlTypeContained add=ocamlTypeSumBar
syn match ocamlTypeSumBar contained "|"
hi link ocamlTypeSumBar ocamlKeyChar
syn cluster ocamlTypeContained add=ocamlTypeSumConstr
syn match ocamlTypeSumConstr contained "\<\u\(\w\|'\)*\>"
syn match ocamlTypeSumConstr contained "\<false\>"
syn match ocamlTypeSumConstr contained "\<true\>"
syn match ocamlTypeSumConstr contained "(\_s*)"
syn match ocamlTypeSumConstr contained "\[\_s*]"
syn match ocamlTypeSumConstr contained "(\_s*::\_s*)"
hi link ocamlTypeSumConstr ocamlConstructor
syn cluster ocamlTypeContained add=ocamlTypeSumAnnot
syn region ocamlTypeSumAnnot contained
\ matchgroup=ocamlKeyword start="\<of\>"
\ matchgroup=ocamlKeyChar start=":"
\ matchgroup=NONE end="|\@="
\ matchgroup=NONE end="\(\<type\>\|\<exception\>\|\<val\>\|\<module\>\|\<class\>\|\<method\>\|\<constraint\>\|\<inherit\>\|\<object\>\|\<struct\>\|\<open\>\|\<include\>\|\<let\>\|\<external\>\|\<in\>\|\<end\>\|)\|]\|}\|;\|;;\)\@="
\ matchgroup=NONE end="\(\<and\>\)\@="
\ contains=@ocamlTypeExpr,ocamlTypeRecordDecl,ocamlComment,ocamlPpx
hi link ocamlTypeSumAnnot ocamlTypeCatchAll

" Type context opened by “type” (type definition), “constraint” (type
" constraint) and “exception” (exception definition)
syn region ocamlTypeDef
\ matchgroup=ocamlKeyword start="\<type\>\(\_s\+\<nonrec\>\)\?\|\<constraint\>\|\<exception\>"
\ matchgroup=NONE end="\(\<type\>\|\<exception\>\|\<val\>\|\<module\>\|\<class\>\|\<method\>\|\<constraint\>\|\<inherit\>\|\<object\>\|\<struct\>\|\<open\>\|\<include\>\|\<let\>\|\<external\>\|\<in\>\|\<end\>\|)\|]\|}\|;\|;;\)\@="
\ contains=@ocamlTypeExpr,ocamlTypeEq,ocamlTypePrivate,ocamlTypeDefDots,ocamlTypeRecordDecl,ocamlTypeSumDecl,ocamlTypeDefAnd,ocamlComment,ocamlPpx
hi link ocamlTypeDef ocamlTypeCatchAll
syn cluster ocamlTypeContained add=ocamlTypePrivate
syn keyword ocamlTypePrivate contained private
hi link ocamlTypePrivate ocamlKeyword
syn cluster ocamlTypeContained add=ocamlTypeDefAnd
syn keyword ocamlTypeDefAnd contained and
hi link ocamlTypeDefAnd ocamlKeyword
syn cluster ocamlTypeContained add=ocamlTypeDefDots
syn match ocamlTypeDefDots contained "\.\."
hi link ocamlTypeDefDots ocamlKeyChar

" When "exception" is preceded by "with", "|" or "(", that’s not an exception
" definition but an exception pattern; we simply highlight the keyword without
" starting a type context.
" NOTE: These rules must occur after that for "exception".
syn match ocamlKeyword "\<with\_s\+exception\>"lc=4
syn match ocamlKeyword "|\_s*exception\>"lc=1
syn match ocamlKeyword "(\_s*exception\>"lc=1

" Type context opened by “:” (countless kinds of type annotations) and “:>”
" (type coercions)
syn region ocamlTypeAnnot matchgroup=ocamlKeyChar start=":\(>\|\_s*type\>\|[>:=]\@!\)"
\ matchgroup=NONE end="\(\<type\>\|\<exception\>\|\<val\>\|\<module\>\|\<class\>\|\<method\>\|\<constraint\>\|\<inherit\>\|\<object\>\|\<struct\>\|\<open\>\|\<include\>\|\<let\>\|\<external\>\|\<in\>\|\<end\>\|)\|]\|}\|;\|;;\)\@="
\ matchgroup=NONE end="\(;\|}\)\@="
\ matchgroup=NONE end="\(=\|:>\)\@="
\ contains=@ocamlTypeExpr,ocamlComment,ocamlPpx
hi link ocamlTypeAnnot ocamlTypeCatchAll

" Type annotation that gives the return type of a `fun` keyword
" (the type context is ended by `->`)
syn cluster ocamlTypeContained add=ocamlFunTypeAnnot
syn region ocamlFunTypeAnnot contained containedin=ocamlFun
\ matchgroup=ocamlKeyChar start=":"
\ matchgroup=NONE end="\(->\)\@="
\ contains=@ocamlTypeExpr,ocamlComment,ocamlPpx
hi link ocamlFunTypeAnnot ocamlTypeCatchAll

" Module paths (including functors) in types.
" NOTE: This rule must occur after the rule for ocamlTypeSumDecl as it must take
" precedence over it (otherwise the module name would be mistakenly highlighted
" as a constructor).
" NOTE: Carefully avoid catching "(*" here.
syn cluster ocamlTypeExpr add=ocamlTypeModPath
syn match ocamlTypeModPath contained "\<\u\(\w\|'\)*\_s*\."
syn region ocamlTypeModPath contained transparent
\ matchgroup=ocamlModPath start="\<\u\(\w\|'\)*\_s*(\*\@!"
\ matchgroup=ocamlModPath end=")\_s*\."
\ contains=ocamlTypeDotlessModPath,ocamlTypeBlank,ocamlComment,ocamlPpx
hi link ocamlTypeModPath ocamlModPath
syn cluster ocamlTypeContained add=ocamlTypeDotlessModPath
syn match ocamlTypeDotlessModPath contained "\<\u\(\w\|'\)*\_s*\.\?"
syn region ocamlTypeDotlessModPath contained transparent
\ matchgroup=ocamlModPath start="\<\u\(\w\|'\)*\_s*(\*\@!"
\ matchgroup=ocamlModPath end=")\_s*\.\?"
\ contains=ocamlTypeDotlessModPath,ocamlTypeBlank,ocamlComment,ocamlPpx
hi link ocamlTypeDotlessModPath ocamlTypeModPath

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

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

hi def link ocamlBraceErr	   Error
hi def link ocamlBrackErr	   Error
hi def link ocamlParenErr	   Error
hi def link ocamlArrErr	   Error

hi def link ocamlCountErr	   Error
hi def link ocamlDoErr	   Error
hi def link ocamlDoneErr	   Error
hi def link ocamlEndErr	   Error
hi def link ocamlThenErr	   Error
hi def link ocamlKwErr	   Error

hi def link ocamlCharErr	   Error

hi def link ocamlErr	   Error

hi def link ocamlComment	   Comment
hi def link ocamlShebang    ocamlComment

hi def link ocamlModPath	   Include
hi def link ocamlObject	   Include
hi def link ocamlModule	   Include
hi def link ocamlModParam1    Include
hi def link ocamlGenMod       Include
hi def link ocamlFullMod	   Include
hi def link ocamlFuncWith	   Include
hi def link ocamlModParam     Include
hi def link ocamlModTypeRestr Include
hi def link ocamlWith	   Include
hi def link ocamlMTDef	   Include
hi def link ocamlSigEncl	   ocamlModule
hi def link ocamlStructEncl	   ocamlModule

hi def link ocamlScript	   Include

hi def link ocamlConstructor  Constant
hi def link ocamlEmptyConstructor  ocamlConstructor

hi def link ocamlVal          Keyword
hi def link ocamlModTypePre   Keyword
hi def link ocamlModPreRHS    Keyword
hi def link ocamlFunctor	   Keyword
hi def link ocamlModTypeOf  Keyword
hi def link ocamlKeyword	   Keyword
hi def link ocamlMethod	   Include
hi def link ocamlArrow	   Keyword
hi def link ocamlKeyChar	   Keyword
hi def link ocamlAnyVar	   Keyword
hi def link ocamlTopStop	   Keyword

hi def link ocamlRefAssign    ocamlKeyChar
hi def link ocamlEqual        ocamlKeyChar
hi def link ocamlCons         ocamlInfixOp

hi def link ocamlPrefixOp       ocamlOperator
hi def link ocamlInfixOp        ocamlOperator
hi def link ocamlExtensionOp    ocamlOperator
hi def link ocamlIndexingOp     ocamlOperator

if exists("ocaml_highlight_operators")
    hi def link ocamlInfixOpKeyword ocamlOperator
    hi def link ocamlOperator       Operator
else
    hi def link ocamlInfixOpKeyword Keyword
endif

hi def link ocamlBoolean	   Boolean
hi def link ocamlCharacter    Character
hi def link ocamlNumber	   Number
hi def link ocamlFloat	   Float
hi def link ocamlString	   String
hi def link ocamlQuotedStringDelim Identifier

hi def link ocamlLabel	   Identifier

" Type linting groups that the user can customize:
" - ocamlTypeCatchAll: anything in a type context that is not caught by more
"   specific rules (in principle, this should only match syntax errors)
" - ocamlTypeConstr: type constructors
" - ocamlTypeBuiltin: builtin type constructors (like int or list)
" - ocamlTypeVar: type variables ('a)
" - ocamlTypeAnyVar: wildcard (_)
" - ocamlTypeVariance: variance and injectivity indications (+'a, !'a)
" - ocamlTypeKeyChar: symbols such as -> and *
" Default values below mimick the behavior before the type linter was
" implemented, but now we can do better. :-)
hi def link ocamlTypeCatchAll Error
hi def link ocamlTypeConstr   NONE
hi def link ocamlTypeBuiltin  Type
hi def link ocamlTypeVar      NONE
hi def link ocamlTypeAnyVar   NONE
hi def link ocamlTypeVariance ocamlKeyChar
hi def link ocamlTypeKeyChar  ocamlKeyChar

hi def link ocamlTodo	   Todo

hi def link ocamlEncl	   Keyword

hi def link ocamlPpxEncl       ocamlEncl

let b:current_syntax = "ocaml"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim: ts=8
