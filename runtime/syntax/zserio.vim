" Vim syntax file
" Language:	Zserio
" Maintainer:	Dominique Pellé <dominique.pelle@gmail.com>
" Last Change:	2023 Jun 18
"
" Zserio is a serialization schema language for modeling binary
" data types, bitstreams or file formats. Based on the zserio
" language it is possible to automatically generate encoders and
" decoders for a given schema in various target languages
" (e.g. Java, C++, Python).
"
" Zserio is an evolution of the DataScript language.
"
" For more information, see:
" - http://zserio.org/
" - https://github.com/ndsev/zserio

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:keepcpo= &cpo
set cpo&vim

syn case match

syn keyword zserioPackage      import package zserio_compatibility_version
syn keyword zserioType         bit bool string
syn keyword zserioType         int int8 int16 int32 int64
syn keyword zserioType         uint8 uint16 uint32 uint64
syn keyword zserioType         float16 float32 float64
syn keyword zserioType         varint varint16 varint32 varint64
syn keyword zserioType         varuint varsize varuint16 varuint32 varuint64
syn keyword zserioAlign        align
syn keyword zserioLabel        case default
syn keyword zserioConditional  if condition
syn keyword zserioBoolean      true false
syn keyword zserioCompound     struct union choice on enum bitmask subtype
syn keyword zserioKeyword      function return
syn keyword zserioOperator     lengthof valueof instanceof numbits isset
syn keyword zserioRpc          service pubsub topic publish subscribe
syn keyword zserioRule         rule_group rule
syn keyword zserioStorageClass const implicit packed instantiate
syn keyword zserioTodo         contained TODO FIXME XXX
syn keyword zserioSql          sql sql_table sql_database sql_virtual sql_without_rowid
syn keyword zserioSql          explicit using

" zserioCommentGroup allows adding matches for special things in comments.
syn cluster zserioCommentGroup  contains=zserioTodo

syn match   zserioOffset        display "^\s*[a-zA-Z_:\.][a-zA-Z0-9_:\.]*\s*:"

syn match   zserioNumber        display "\<\d\+\>"
syn match   zserioNumberHex     display "\<0[xX]\x\+\>"
syn match   zserioNumberBin     display "\<[01]\+[bB]\>" contains=zserioBinaryB
syn match   zserioBinaryB       display contained "[bB]\>"
syn match   zserioOctal         display "\<0\o\+\>" contains=zserioOctalZero
syn match   zserioOctalZero     display contained "\<0"

syn match   zserioOctalError    display "\<0\o*[89]\d*\>"

syn match   zserioCommentError      display "\*/"
syn match   zserioCommentStartError display "/\*"me=e-1 contained

syn region   zserioCommentL
  \ start="//" skip="\\$" end="$" keepend
  \ contains=@zserioCommentGroup,@Spell
syn region   zserioComment
  \ matchgroup=zserioCommentStart start="/\*" end="\*/"
  \ contains=@zserioCommentGroup,zserioCommentStartError,@Spell extend

syn region  zserioString
  \ start=+L\="+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell

syn sync ccomment zserioComment

" Define the default highlighting.
hi def link zserioType              Type
hi def link zserioEndian            StorageClass
hi def link zserioStorageClass      StorageClass
hi def link zserioAlign             Label
hi def link zserioLabel             Label
hi def link zserioOffset            Label
hi def link zserioSql               PreProc
hi def link zserioCompound          Structure
hi def link zserioConditional       Conditional
hi def link zserioBoolean           Boolean
hi def link zserioKeyword           Statement
hi def link zserioRpc               Keyword
hi def link zserioRule              Keyword
hi def link zserioString            String
hi def link zserioNumber            Number
hi def link zserioNumberBin         Number
hi def link zserioBinaryB           Special
hi def link zserioOctal             Number
hi def link zserioOctalZero         Special
hi def link zserioOctalError        Error
hi def link zserioNumberHex         Number
hi def link zserioTodo              Todo
hi def link zserioOperator          Operator
hi def link zserioPackage           Include
hi def link zserioCommentError      Error
hi def link zserioCommentStartError Error
hi def link zserioCommentStart      zserioComment
hi def link zserioCommentL          zserioComment
hi def link zserioComment           Comment

let b:current_syntax = "zserio"

let &cpo = s:keepcpo
unlet s:keepcpo
