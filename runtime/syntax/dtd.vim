" Vim syntax file
" Language:	DTD (Document Type Definition for XML)
" Maintainer:	Johannes Zellner <johannes@zellner.org>
"		Author and previous maintainer:
"		Daniel Amyot <damyot@site.uottawa.ca>
" Last Change:	Tue, 27 Apr 2004 14:54:59 CEST
" Filenames:	*.dtd
"
" REFERENCES:
"   http://www.w3.org/TR/html40/
"   http://www.w3.org/TR/NOTE-html-970421
"
" TODO:
"   - improve synchronizing.

if exists("b:current_syntax")
    finish
endif
let s:dtd_cpo_save = &cpo
set cpo&vim

if !exists("dtd_ignore_case")
    " I prefer having the case takes into consideration.
    syn case match
else
    syn case ignore
endif


" the following line makes the opening <! and
" closing > highlighted using 'dtdFunction'.
"
" PROVIDES: @dtdTagHook
"
syn region dtdTag matchgroup=dtdFunction
    \ start=+<!+ end=+>+ matchgroup=NONE
    \ contains=dtdTag,dtdTagName,dtdError,dtdComment,dtdString,dtdAttrType,dtdAttrDef,dtdEnum,dtdParamEntityInst,dtdParamEntityDecl,dtdCard,@dtdTagHook

if !exists("dtd_no_tag_errors")
    " mark everything as an error which starts with a <!
    " and is not overridden later. If this is annoying,
    " it can be switched off by setting the variable
    " dtd_no_tag_errors.
    syn region dtdError contained start=+<!+lc=2 end=+>+
endif

" if this is a html like comment hightlight also
" the opening <! and the closing > as Comment.
syn region dtdComment		start=+<![ \t]*--+ end=+-->+ contains=dtdTodo,@Spell


" proper DTD comment
syn region dtdComment contained start=+--+ end=+--+ contains=dtdTodo,@Spell


" Start tags (keywords). This is contained in dtdFunction.
" Note that everything not contained here will be marked
" as error.
syn match dtdTagName contained +<!\(ATTLIST\|DOCTYPE\|ELEMENT\|ENTITY\|NOTATION\|SHORTREF\|USEMAP\|\[\)+lc=2,hs=s+2


" wildcards and operators
syn match  dtdCard contained "|"
syn match  dtdCard contained ","
" evenutally overridden by dtdEntity
syn match  dtdCard contained "&"
syn match  dtdCard contained "?"
syn match  dtdCard contained "\*"
syn match  dtdCard contained "+"

" ...and finally, special cases.
syn match  dtdCard      "ANY"
syn match  dtdCard      "EMPTY"

if !exists("dtd_no_param_entities")

    " highlight parameter entity declarations
    " and instances. Note that the closing `;'
    " is optional.

    " instances
    syn region dtdParamEntityInst oneline matchgroup=dtdParamEntityPunct
	\ start="%[-_a-zA-Z0-9.]\+"he=s+1,rs=s+1
	\ skip=+[-_a-zA-Z0-9.]+
	\ end=";\|\>"
	\ matchgroup=NONE contains=dtdParamEntityPunct
    syn match  dtdParamEntityPunct contained "\."

    " declarations
    " syn region dtdParamEntityDecl oneline matchgroup=dtdParamEntityDPunct start=+<!ENTITY % +lc=8 skip=+[-_a-zA-Z0-9.]+ matchgroup=NONE end="\>" contains=dtdParamEntityDPunct
    syn match dtdParamEntityDecl +<!ENTITY % [-_a-zA-Z0-9.]*+lc=8 contains=dtdParamEntityDPunct
    syn match  dtdParamEntityDPunct contained "%\|\."

endif

" &entities; compare with xml
syn match   dtdEntity		      "&[^; \t]*;" contains=dtdEntityPunct
syn match   dtdEntityPunct  contained "[&.;]"

" Strings are between quotes
syn region dtdString    start=+"+ skip=+\\\\\|\\"+  end=+"+ contains=dtdAttrDef,dtdAttrType,dtdEnum,dtdParamEntityInst,dtdEntity,dtdCard
syn region dtdString    start=+'+ skip=+\\\\\|\\'+  end=+'+ contains=dtdAttrDef,dtdAttrType,dtdEnum,dtdParamEntityInst,dtdEntity,dtdCard

" Enumeration of elements or data between parenthesis
"
" PROVIDES: @dtdEnumHook
"
syn region dtdEnum matchgroup=dtdType start="(" end=")" matchgroup=NONE contains=dtdEnum,dtdParamEntityInst,dtdCard,@dtdEnumHook

"Attribute types
syn keyword dtdAttrType NMTOKEN  ENTITIES  NMTOKENS  ID  CDATA
syn keyword dtdAttrType IDREF  IDREFS
" ENTITY has to treated special for not overriding <!ENTITY
syn match   dtdAttrType +[^!]\<ENTITY+

"Attribute Definitions
syn match  dtdAttrDef   "#REQUIRED"
syn match  dtdAttrDef   "#IMPLIED"
syn match  dtdAttrDef   "#FIXED"

syn case match
" define some common keywords to mark TODO
" and important sections inside comments.
syn keyword dtdTodo contained TODO FIXME XXX

syn sync lines=250

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dtd_syn_inits")
    if version < 508
	let did_dtd_syn_inits = 1
	command -nargs=+ HiLink hi link <args>
    else
	command -nargs=+ HiLink hi def link <args>
    endif

    " The default highlighting.
    HiLink dtdFunction		Function
    HiLink dtdTag		Normal
    HiLink dtdType		Type
    HiLink dtdAttrType		dtdType
    HiLink dtdAttrDef		dtdType
    HiLink dtdConstant		Constant
    HiLink dtdString		dtdConstant
    HiLink dtdEnum		dtdConstant
    HiLink dtdCard		dtdFunction

    HiLink dtdEntity		Statement
    HiLink dtdEntityPunct	dtdType
    HiLink dtdParamEntityInst	dtdConstant
    HiLink dtdParamEntityPunct	dtdType
    HiLink dtdParamEntityDecl	dtdType
    HiLink dtdParamEntityDPunct dtdComment

    HiLink dtdComment		Comment
    HiLink dtdTagName		Statement
    HiLink dtdError		Error
    HiLink dtdTodo		Todo

    delcommand HiLink
endif

let &cpo = s:dtd_cpo_save
unlet s:dtd_cpo_save

let b:current_syntax = "dtd"

" vim: ts=8
