" Vim syntax file
" Language:	DataScript
" Maintainer:	Dominique Pelle <dominique.pelle@gmail.com>
" Last Change:	2015 Jul 30
"
" DataScript is a formal language for modelling binary datatypes,
" bitstreams or file formats. For more information, see:
"
" http://dstools.sourceforge.net/DataScriptLanguageOverview.html

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

syn keyword dsPackage      import package
syn keyword dsType         bit bool string
syn keyword dsType         int int8 int16 int32 int64
syn keyword dsType         uint8 uint16 uint32 uint64
syn keyword dsType         varint16 varint32 varint64
syn keyword dsType         varuint16 varuint32 varuint64
syn keyword dsType         leint16 leint32 leint64
syn keyword dsType         leuint16 leuint32 leuint64
syn keyword dsEndian       little big
syn keyword dsAlign        align
syn keyword dsLabel        case default
syn keyword dsConditional  if condition
syn keyword dsBoolean      true false
syn keyword dsCompound     union choice on enum bitmask subtype explicit
syn keyword dsKeyword      function return
syn keyword dsOperator     sizeof bitsizeof lengthof is sum forall in
syn keyword dsStorageClass const
syn keyword dsTodo         contained TODO FIXME XXX
syn keyword dsSql          sql sql_table sql_database sql_pragma sql_index
syn keyword dsSql          sql_integer sql_metadata sql_key sql_virtual
syn keyword dsSql          using reference_key foreign_key to

" dsCommentGroup allows adding matches for special things in comments.
syn cluster dsCommentGroup  contains=dsTodo

syn match   dsOffset        display "^\s*[a-zA-Z_:\.][a-zA-Z0-9_:\.]*\s*:"

syn match   dsNumber        display "\<\d\+\>"
syn match   dsNumberHex     display "\<0[xX]\x\+\>"
syn match   dsNumberBin     display "\<[01]\+[bB]\>" contains=dsBinaryB
syn match   dsBinaryB       display contained "[bB]\>"
syn match   dsOctal         display "\<0\o\+\>" contains=dsOctalZero
syn match   dsOctalZero     display contained "\<0"

syn match   dsOctalError    display "\<0\o*[89]\d*\>"

syn match   dsCommentError      display "\*/"
syn match   dsCommentStartError display "/\*"me=e-1 contained

syn region   dsCommentL
  \ start="//" skip="\\$" end="$" keepend
  \ contains=@dsCommentGroup,@Spell
syn region   dsComment
  \ matchgroup=dsCommentStart start="/\*" end="\*/"
  \ contains=@dsCommentGroup,dsCommentStartError,@Spell extend

syn region  dsString
  \ start=+L\="+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell

syn sync ccomment dsComment

" Define the default highlighting.
hi def link dsType              Type
hi def link dsEndian            StorageClass
hi def link dsStorageClass      StorageClass
hi def link dsAlign             Label
hi def link dsLabel             Label
hi def link dsOffset            Label
hi def link dsSql               PreProc
hi def link dsCompound          Structure
hi def link dsConditional       Conditional
hi def link dsBoolean           Boolean
hi def link dsKeyword           Statement
hi def link dsString            String
hi def link dsNumber            Number
hi def link dsNumberBin         Number
hi def link dsBinaryB           Special
hi def link dsOctal             Number
hi def link dsOctalZero         Special
hi def link dsOctalError        Error
hi def link dsNumberHex         Number
hi def link dsTodo              Todo
hi def link dsOperator          Operator
hi def link dsPackage           Include
hi def link dsCommentError      Error
hi def link dsCommentStartError Error
hi def link dsCommentStart      dsComment
hi def link dsCommentL          dsComment
hi def link cCommentL           dsComment
hi def link dsComment           Comment

let b:current_syntax = "datascript"

let &cpo = s:keepcpo
unlet s:keepcpo
