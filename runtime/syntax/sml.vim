" Vim syntax file
" Language:     SML
" Filenames:    *.sml *.sig
" Maintainers:  Markus Mottl            <markus.mottl@gmail.com>
"               Fabrizio Zeno Cornelli  <zeno@filibusta.crema.unimi.it>
" URL:          http://www.ocaml.info/vim/syntax/sml.vim
" Last Change:  2006 Oct 23 - Fixed character highlighting bug (MM)
"               2002 Jun 02 - Fixed small typo  (MM)
"               2001 Nov 20 - Fixed small highlighting bug with modules (MM)

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" SML is case sensitive.
syn case match

" lowercase identifier - the standard way to match
syn match    smlLCIdentifier /\<\(\l\|_\)\(\w\|'\)*\>/

syn match    smlKeyChar    "|"

" Errors
syn match    smlBraceErr   "}"
syn match    smlBrackErr   "\]"
syn match    smlParenErr   ")"
syn match    smlCommentErr "\*)"
syn match    smlThenErr    "\<then\>"

" Error-highlighting of "end" without synchronization:
" as keyword or as error (default)
if exists("sml_noend_error")
  syn match    smlKeyword    "\<end\>"
else
  syn match    smlEndErr     "\<end\>"
endif

" Some convenient clusters
syn cluster  smlAllErrs contains=smlBraceErr,smlBrackErr,smlParenErr,smlCommentErr,smlEndErr,smlThenErr

syn cluster  smlAENoParen contains=smlBraceErr,smlBrackErr,smlCommentErr,smlEndErr,smlThenErr

syn cluster  smlContained contains=smlTodo,smlPreDef,smlModParam,smlModParam1,smlPreMPRestr,smlMPRestr,smlMPRestr1,smlMPRestr2,smlMPRestr3,smlModRHS,smlFuncWith,smlFuncStruct,smlModTypeRestr,smlModTRWith,smlWith,smlWithRest,smlModType,smlFullMod


" Enclosing delimiters
syn region   smlEncl transparent matchgroup=smlKeyword start="(" matchgroup=smlKeyword end=")" contains=ALLBUT,@smlContained,smlParenErr
syn region   smlEncl transparent matchgroup=smlKeyword start="{" matchgroup=smlKeyword end="}"  contains=ALLBUT,@smlContained,smlBraceErr
syn region   smlEncl transparent matchgroup=smlKeyword start="\[" matchgroup=smlKeyword end="\]" contains=ALLBUT,@smlContained,smlBrackErr
syn region   smlEncl transparent matchgroup=smlKeyword start="#\[" matchgroup=smlKeyword end="\]" contains=ALLBUT,@smlContained,smlBrackErr


" Comments
syn region   smlComment start="(\*" end="\*)" contains=smlComment,smlTodo
syn keyword  smlTodo contained TODO FIXME XXX


" let
syn region   smlEnd matchgroup=smlKeyword start="\<let\>" matchgroup=smlKeyword end="\<end\>" contains=ALLBUT,@smlContained,smlEndErr

" local
syn region   smlEnd matchgroup=smlKeyword start="\<local\>" matchgroup=smlKeyword end="\<end\>" contains=ALLBUT,@smlContained,smlEndErr

" abstype
syn region   smlNone matchgroup=smlKeyword start="\<abstype\>" matchgroup=smlKeyword end="\<end\>" contains=ALLBUT,@smlContained,smlEndErr

" begin
syn region   smlEnd matchgroup=smlKeyword start="\<begin\>" matchgroup=smlKeyword end="\<end\>" contains=ALLBUT,@smlContained,smlEndErr

" if
syn region   smlNone matchgroup=smlKeyword start="\<if\>" matchgroup=smlKeyword end="\<then\>" contains=ALLBUT,@smlContained,smlThenErr


"" Modules

" "struct"
syn region   smlStruct matchgroup=smlModule start="\<struct\>" matchgroup=smlModule end="\<end\>" contains=ALLBUT,@smlContained,smlEndErr

" "sig"
syn region   smlSig matchgroup=smlModule start="\<sig\>" matchgroup=smlModule end="\<end\>" contains=ALLBUT,@smlContained,smlEndErr,smlModule
syn region   smlModSpec matchgroup=smlKeyword start="\<structure\>" matchgroup=smlModule end="\<\u\(\w\|'\)*\>" contained contains=@smlAllErrs,smlComment skipwhite skipempty nextgroup=smlModTRWith,smlMPRestr

" "open"
syn region   smlNone matchgroup=smlKeyword start="\<open\>" matchgroup=smlModule end="\<\u\(\w\|'\)*\(\.\u\(\w\|'\)*\)*\>" contains=@smlAllErrs,smlComment

" "structure" - somewhat complicated stuff ;-)
syn region   smlModule matchgroup=smlKeyword start="\<\(structure\|functor\)\>" matchgroup=smlModule end="\<\u\(\w\|'\)*\>" contains=@smlAllErrs,smlComment skipwhite skipempty nextgroup=smlPreDef
syn region   smlPreDef start="."me=e-1 matchgroup=smlKeyword end="\l\|="me=e-1 contained contains=@smlAllErrs,smlComment,smlModParam,smlModTypeRestr,smlModTRWith nextgroup=smlModPreRHS
syn region   smlModParam start="([^*]" end=")" contained contains=@smlAENoParen,smlModParam1
syn match    smlModParam1 "\<\u\(\w\|'\)*\>" contained skipwhite skipempty nextgroup=smlPreMPRestr

syn region   smlPreMPRestr start="."me=e-1 end=")"me=e-1 contained contains=@smlAllErrs,smlComment,smlMPRestr,smlModTypeRestr

syn region   smlMPRestr start=":" end="."me=e-1 contained contains=@smlComment skipwhite skipempty nextgroup=smlMPRestr1,smlMPRestr2,smlMPRestr3
syn region   smlMPRestr1 matchgroup=smlModule start="\ssig\s\=" matchgroup=smlModule end="\<end\>" contained contains=ALLBUT,@smlContained,smlEndErr,smlModule
syn region   smlMPRestr2 start="\sfunctor\(\s\|(\)\="me=e-1 matchgroup=smlKeyword end="->" contained contains=@smlAllErrs,smlComment,smlModParam skipwhite skipempty nextgroup=smlFuncWith
syn match    smlMPRestr3 "\w\(\w\|'\)*\(\.\w\(\w\|'\)*\)*" contained
syn match    smlModPreRHS "=" contained skipwhite skipempty nextgroup=smlModParam,smlFullMod
syn region   smlModRHS start="." end=".\w\|([^*]"me=e-2 contained contains=smlComment skipwhite skipempty nextgroup=smlModParam,smlFullMod
syn match    smlFullMod "\<\u\(\w\|'\)*\(\.\u\(\w\|'\)*\)*" contained skipwhite skipempty nextgroup=smlFuncWith

syn region   smlFuncWith start="([^*]"me=e-1 end=")" contained contains=smlComment,smlWith,smlFuncStruct
syn region   smlFuncStruct matchgroup=smlModule start="[^a-zA-Z]struct\>"hs=s+1 matchgroup=smlModule end="\<end\>" contains=ALLBUT,@smlContained,smlEndErr

syn match    smlModTypeRestr "\<\w\(\w\|'\)*\(\.\w\(\w\|'\)*\)*\>" contained
syn region   smlModTRWith start=":\s*("hs=s+1 end=")" contained contains=@smlAENoParen,smlWith
syn match    smlWith "\<\(\u\(\w\|'\)*\.\)*\w\(\w\|'\)*\>" contained skipwhite skipempty nextgroup=smlWithRest
syn region   smlWithRest start="[^)]" end=")"me=e-1 contained contains=ALLBUT,@smlContained

" "signature"
syn region   smlKeyword start="\<signature\>" matchgroup=smlModule end="\<\w\(\w\|'\)*\>" contains=smlComment skipwhite skipempty nextgroup=smlMTDef
syn match    smlMTDef "=\s*\w\(\w\|'\)*\>"hs=s+1,me=s

syn keyword  smlKeyword  and andalso case
syn keyword  smlKeyword  datatype else eqtype
syn keyword  smlKeyword  exception fn fun handle
syn keyword  smlKeyword  in infix infixl infixr
syn keyword  smlKeyword  match nonfix of orelse
syn keyword  smlKeyword  raise handle type
syn keyword  smlKeyword  val where while with withtype

syn keyword  smlType     bool char exn int list option
syn keyword  smlType     real string unit

syn keyword  smlOperator div mod not or quot rem

syn keyword  smlBoolean      true false
syn match    smlConstructor  "(\s*)"
syn match    smlConstructor  "\[\s*\]"
syn match    smlConstructor  "#\[\s*\]"
syn match    smlConstructor  "\u\(\w\|'\)*\>"

" Module prefix
syn match    smlModPath      "\u\(\w\|'\)*\."he=e-1

syn match    smlCharacter    +#"\\""\|#"."\|#"\\\d\d\d"+
syn match    smlCharErr      +#"\\\d\d"\|#"\\\d"+
syn region   smlString       start=+"+ skip=+\\\\\|\\"+ end=+"+

syn match    smlFunDef       "=>"
syn match    smlRefAssign    ":="
syn match    smlTopStop      ";;"
syn match    smlOperator     "\^"
syn match    smlOperator     "::"
syn match    smlAnyVar       "\<_\>"
syn match    smlKeyChar      "!"
syn match    smlKeyChar      ";"
syn match    smlKeyChar      "\*"
syn match    smlKeyChar      "="

syn match    smlNumber	      "\<-\=\d\+\>"
syn match    smlNumber	      "\<-\=0[x|X]\x\+\>"
syn match    smlReal	      "\<-\=\d\+\.\d*\([eE][-+]\=\d\+\)\=[fl]\=\>"

" Synchronization
syn sync minlines=20
syn sync maxlines=500

syn sync match smlEndSync     grouphere  smlEnd     "\<begin\>"
syn sync match smlEndSync     groupthere smlEnd     "\<end\>"
syn sync match smlStructSync  grouphere  smlStruct  "\<struct\>"
syn sync match smlStructSync  groupthere smlStruct  "\<end\>"
syn sync match smlSigSync     grouphere  smlSig     "\<sig\>"
syn sync match smlSigSync     groupthere smlSig     "\<end\>"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_sml_syntax_inits")
  if version < 508
    let did_sml_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink smlBraceErr	 Error
  HiLink smlBrackErr	 Error
  HiLink smlParenErr	 Error

  HiLink smlCommentErr	 Error

  HiLink smlEndErr	 Error
  HiLink smlThenErr	 Error

  HiLink smlCharErr	 Error

  HiLink smlComment	 Comment

  HiLink smlModPath	 Include
  HiLink smlModule	 Include
  HiLink smlModParam1	 Include
  HiLink smlModType	 Include
  HiLink smlMPRestr3	 Include
  HiLink smlFullMod	 Include
  HiLink smlModTypeRestr Include
  HiLink smlWith	 Include
  HiLink smlMTDef	 Include

  HiLink smlConstructor  Constant

  HiLink smlModPreRHS	 Keyword
  HiLink smlMPRestr2	 Keyword
  HiLink smlKeyword	 Keyword
  HiLink smlFunDef	 Keyword
  HiLink smlRefAssign	 Keyword
  HiLink smlKeyChar	 Keyword
  HiLink smlAnyVar	 Keyword
  HiLink smlTopStop	 Keyword
  HiLink smlOperator	 Keyword

  HiLink smlBoolean	 Boolean
  HiLink smlCharacter	 Character
  HiLink smlNumber	 Number
  HiLink smlReal	 Float
  HiLink smlString	 String
  HiLink smlType	 Type
  HiLink smlTodo	 Todo
  HiLink smlEncl	 Keyword

  delcommand HiLink
endif

let b:current_syntax = "sml"

" vim: ts=8
