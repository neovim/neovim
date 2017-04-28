" Vim syntax file
" Language:	SGML (SGML Declaration <!SGML ...>)
" Last Change: jueves, 28 de diciembre de 2000, 13:51:44 CLST
" Maintainer: "Daniel A. Molina W." <sickd@linux-chile.org>
" You can modify and maintain this file, in other case send comments
" the maintainer email address.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

syn case ignore

syn region	sgmldeclDeclBlock	transparent start=+<!SGML+ end=+>+
syn region	sgmldeclTagBlock	transparent start=+<+ end=+>+
					\ contains=ALLBUT,
					\ @sgmlTagError,@sgmlErrInTag
syn region	sgmldeclComment		contained start=+--+ end=+--+

syn keyword	sgmldeclDeclKeys	SGML CHARSET CAPACITY SCOPE SYNTAX
					\ FEATURES

syn keyword	sgmldeclTypes		BASESET DESCSET DOCUMENT NAMING DELIM
					\ NAMES QUANTITY SHUNCHAR DOCTYPE
					\ ELEMENT ENTITY ATTLIST NOTATION
					\ TYPE

syn keyword	sgmldeclStatem		CONTROLS FUNCTION NAMECASE MINIMIZE
					\ LINK OTHER APPINFO REF ENTITIES

syn keyword sgmldeclVariables	TOTALCAP GRPCAP ENTCAP DATATAG OMITTAG RANK
					\ SIMPLE IMPLICIT EXPLICIT CONCUR SUBDOC FORMAL ATTCAP
					\ ATTCHCAP AVGRPCAP ELEMCAP ENTCHCAP IDCAP IDREFCAP
					\ SHORTTAG

syn match	sgmldeclNConst		contained +[0-9]\++

syn region	sgmldeclString		contained start=+"+ end=+"+

syn keyword	sgmldeclBool		YES NO

syn keyword	sgmldeclSpecial		SHORTREF SGMLREF UNUSED NONE GENERAL
					\ SEEALSO ANY

syn sync lines=250


" Define the default highlighting.
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink	sgmldeclDeclKeys	Keyword
HiLink	sgmldeclTypes		Type
HiLink	sgmldeclConst		Constant
HiLink	sgmldeclNConst		Constant
HiLink	sgmldeclString		String
HiLink	sgmldeclDeclBlock	Normal
HiLink	sgmldeclBool		Boolean
HiLink	sgmldeclSpecial		Special
HiLink	sgmldeclComment		Comment
HiLink	sgmldeclStatem		Statement
HiLink	sgmldeclVariables	Type

delcommand HiLink

let b:current_syntax = "sgmldecl"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:set tw=78 ts=4:
