" Vim syntax file
" Language:	wdl
" Maintainer:	Matt Dunford (zenmatic@gmail.com)
" URL:		https://github.com/zenmatic/vim-syntax-wdl
" Last Change:	2022 Nov 24

" https://github.com/openwdl/wdl

" quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syn case match

syn keyword wdlStatement alias task input command runtime input output workflow call scatter import as meta parameter_meta in version
syn keyword wdlConditional if then else
syn keyword wdlType struct Array String File Int Float Boolean Map Pair Object

syn keyword wdlFunctions stdout stderr read_lines read_tsv read_map read_object read_objects read_json read_int read_string read_float read_boolean write_lines write_tsv write_map write_object write_objects write_json size sub range transpose zip cross length flatten prefix select_first defined basename floor ceil round

syn region wdlCommandSection start="<<<" end=">>>"

syn region      wdlString            start=+"+ skip=+\\\\\|\\"+ end=+"+
syn region      wdlString            start=+'+ skip=+\\\\\|\\'+ end=+'+

" Comments; their contents
syn keyword     wdlTodo              contained TODO FIXME XXX BUG
syn cluster     wdlCommentGroup      contains=wdlTodo
syn region      wdlComment           start="#" end="$" contains=@wdlCommentGroup

hi def link wdlStatement      Statement
hi def link wdlConditional    Conditional
hi def link wdlType           Type
hi def link wdlFunctions      Function
hi def link wdlString         String
hi def link wdlCommandSection String
hi def link wdlComment        Comment
hi def link wdlTodo           Todo

let b:current_syntax = 'wdl'
