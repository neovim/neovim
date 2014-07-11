" Vim syntax file
" Language:     WSML
" Maintainer:   Thomas Haselwanter <thomas.haselwanter@deri.org>
" URL:		none
" Last Change:  2006 Apr 30

" Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" WSML
syn keyword wsmlHeader		wsmlVariant
syn keyword wsmlNamespace	namespace
syn keyword wsmlTopLevel	concept instance relationInstance ofType usesMediator usesService relation sharedVariables importsOntology
syn keyword wsmlOntology	hasValue memberOf ofType impliesType subConceptOf
syn keyword wsmlAxiom		axiom definedBy
syn keyword wsmlService		assumption effect postcondition precondition capability interface
syn keyword wsmlTopLevel	ooMediator wwMediator wgMediator ggMediator
syn keyword wsmlMediation	usesService source target
syn match wsmlDataTypes	        "\( _string\| _decimal\| _integer\| _float\| _double\| _iri\| _sqname\| _boolean\| _duration\| _dateTime\| _time\| _date\| _gyearmonth\| _gyear\| _gmonthday\| _gday\| _gmonth\| _hexbinary\| _base64binary\)\((\S*)\)\?" contains=wsmlString,wsmlNumber,wsmlCharacter
syn keyword wsmlTopLevel	goal webService ontology
syn keyword wsmlKeywordsInsideLEs	true false memberOf hasValue subConceptOf ofType impliesType and or implies impliedBy equivalent neg naf forall exists
syn keyword wsmlNFP		nfp endnfp nonFunctionalProperties endNonFunctionalProperties
syn region wsmlNFPregion	start="nfp\|nonFunctionalProperties" end="endnfp\|endNonFunctionalProperties" contains=ALL
syn region wsmlNamespace	start="namespace" end="}" contains=wsmlIdentifier
syn match wsmlOperator		"!=\|:=:\|=<\|>=\|=\|+\|\*\|/\|<->\|->\|<-\|:-\|!-\|-\|<\|>"
syn match wsmlBrace		"(\|)\|\[\|\]\|{\|}"
syn match wsmlIdentifier	+_"\S*"+
syn match wsmlIdentifier	"_#\d*"
syn match wsmlSqName		"[0-9A-Za-z]\+#[0-9A-Za-z]\+"
syn match wsmlVariable		"?[0-9A-Za-z]\+"

" ASM-specific code
syn keyword wsmlBehavioral	choreography orchestration transitionRules
syn keyword wsmlChoreographyPri	stateSignature in out shared static controlled 
syn keyword wsmlChoreographySec with do withGrounding forall endForall choose if then endIf
syn match wsmlChoreographyTer   "\(\s\|\_^\)\(add\|delete\|update\)\s*(.*)" contains=wsmlKeywordsInsideLEs,wsmlIdentifier,wsmlSqName,wsmlString,wsmlNumber,wsmlDataTypes,wsmlVariable

" Comments
syn keyword wsmlTodo		 contained TODO
syn keyword wsmlFixMe		 contained FIXME
if exists("wsml_comment_strings")
  syn region  wsmlCommentString    contained start=+"+ end=+"+ end=+$+ end=+\*/+me=s-1,he=s-1 contains=wsmlSpecial,wsmlCommentStar,wsmlSpecialChar,@Spell
  syn region  wsmlComment2String   contained start=+"+  end=+$\|"+  contains=wsmlSpecial,wsmlSpecialChar,@Spell
  syn match   wsmlCommentCharacter contained "'\\[^']\{1,6\}'" contains=wsmlSpecialChar
  syn match   wsmlCommentCharacter contained "'\\''" contains=wsmlSpecialChar
  syn match   wsmlCommentCharacter contained "'[^\\]'"
  syn cluster wsmlCommentSpecial add=wsmlCommentString,wsmlCommentCharacter,wsmlNumber
  syn cluster wsmlCommentSpecial2 add=wsmlComment2String,wsmlCommentCharacter,wsmlNumber
endif

syn region  wsmlComment		 start="/\*"  end="\*/" contains=@wsmlCommentSpecial,wsmlTodo,wsmlFixMe,@Spell
syn match   wsmlCommentStar      contained "^\s*\*[^/]"me=e-1
syn match   wsmlCommentStar      contained "^\s*\*$"
syn match   wsmlLineComment      "//.*" contains=@wsmlCommentSpecial2,wsmlTodo,@Spell

syn cluster wsmlTop add=wsmlComment,wsmlLineComment

"match the special comment /**/
syn match   wsmlComment		 "/\*\*/"

" Strings
syn region  wsmlString		start=+"+ end=+"+ contains=wsmlSpecialChar,wsmlSpecialError,@Spell
syn match   wsmlCharacter	 "'[^']*'" contains=javaSpecialChar,javaSpecialCharError
syn match   wsmlCharacter	 "'\\''" contains=javaSpecialChar
syn match   wsmlCharacter	 "'[^\\]'"
syn match   wsmlNumber		 "\<\(0[0-7]*\|0[xX]\x\+\|\d\+\)[lL]\=\>"
syn match   wsmlNumber		 "\(\<\d\+\.\d*\|\.\d\+\)\([eE][-+]\=\d\+\)\=[fFdD]\="
syn match   wsmlNumber		 "\<\d\+[eE][-+]\=\d\+[fFdD]\=\>"
syn match   wsmlNumber		 "\<\d\+\([eE][-+]\=\d\+\)\=[fFdD]\>"

" unicode characters
syn match   wsmlSpecial "\\u\d\{4\}"

syn cluster wsmlTop add=wsmlString,wsmlCharacter,wsmlNumber,wsmlSpecial,wsmlStringError

" Define the default highlighting.
" " For version 5.7 and earlier: only when not done already
" " For version 5.8 and later: only when an item doesn't have highlighting yet
 if version >= 508 || !exists("did_wsml_syn_inits")
   if version < 508
       let did_wsml_syn_inits = 1
       command -nargs=+ HiLink hi link <args>
   else
       command -nargs=+ HiLink hi def link <args>
   endif              
   HiLink wsmlHeader			TypeDef
   HiLink wsmlNamespace			TypeDef
   HiLink wsmlOntology			Statement
   HiLink wsmlAxiom			TypeDef
   HiLink wsmlService			TypeDef
   HiLink wsmlNFP			TypeDef
   HiLink wsmlTopLevel			TypeDef
   HiLink wsmlMediation			TypeDef 
   HiLink wsmlBehavioral		TypeDef
   HiLink wsmlChoreographyPri		TypeDef
   HiLink wsmlChoreographySec		Operator
   HiLink wsmlChoreographyTer		Special
   HiLink wsmlString			String
   HiLink wsmlIdentifier		Normal 
   HiLink wsmlSqName                     Normal
   HiLink wsmlVariable			Define
   HiLink wsmlKeywordsInsideLEs		Operator
   HiLink wsmlOperator			Operator
   HiLink wsmlBrace			Operator
   HiLink wsmlCharacter			Character
   HiLink wsmlNumber			Number
   HiLink wsmlDataTypes			Special
   HiLink wsmlComment			Comment
   HiLink wsmlDocComment		Comment
   HiLink wsmlLineComment		Comment
   HiLink wsmlTodo			Todo
   HiLink wsmlFixMe			Error
   HiLink wsmlCommentTitle		SpecialComment
   HiLink wsmlCommentStar		wsmlComment
 endif

delcommand HiLink

let b:current_syntax = "wsml"
let b:spell_options="contained"

