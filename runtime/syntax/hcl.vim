" Vim syntax file
" Language:    HCL
" Maintainer:  Gregory Anders
" Upstream:    https://github.com/hashivim/vim-terraform
" Last Change: 2024-09-03
" License:     ISC
"
" Copyright (c) 2014-2016 Mark Cornick <mark@markcornick.com>
"
" Permission to use, copy, modify, and/or distribute this software for any purpose
" with or without fee is hereby granted, provided that the above copyright notice
" and this permission notice appear in all copies.
"
" THE SOFTWARE IS PROVIDED 'AS IS' AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
" REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
" FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
" INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
" OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
" TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
" THIS SOFTWARE.

if exists('b:current_syntax')
  finish
endif

syn iskeyword a-z,A-Z,48-57,_,-

syn case match

" A block is introduced by a type, some number of labels - which are either
" strings or identifiers - and an opening curly brace.  Match the type.
syn match hclBlockType /^\s*\zs\K\k*\ze\s\+\(\("\K\k*"\|\K\k*\)\s\+\)*{/

" An attribute name is an identifier followed by an equals sign.
syn match hclAttributeAssignment /\(\K\k*\.\)*\K\k*\s\+=\s/ contains=hclAttributeName
syn match hclAttributeName /\<\K\k*\>/ contained

syn keyword hclValueBool true false

syn keyword hclTodo         contained TODO FIXME XXX BUG
syn region  hclComment      start="/\*" end="\*/" contains=hclTodo,@Spell
syn region  hclComment      start="#" end="$" contains=hclTodo,@Spell
syn region  hclComment      start="//" end="$" contains=hclTodo,@Spell

""" misc.
syn match hclValueDec      "\<[0-9]\+\([kKmMgG]b\?\)\?\>"
syn match hclValueHexaDec  "\<0x[0-9a-f]\+\([kKmMgG]b\?\)\?\>"
syn match hclBraces        "[\[\]]"

""" skip \" and \\ in strings.
syn region hclValueString   start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=hclStringInterp
syn region hclStringInterp  matchgroup=hclBraces start=/\(^\|[^$]\)\$\zs{/ end=/}/ contained contains=ALLBUT,hclAttributeName
syn region hclHereDocText   start=/<<-\?\z([a-z0-9A-Z]\+\)/ end=/^\s*\z1/ contains=hclStringInterp

"" Functions.
syn match hclFunction "[a-z0-9]\+(\@="

""" HCL2
syn keyword hclRepeat         for in
syn keyword hclConditional    if
syn keyword hclValueNull      null

" enable block folding
syn region hclBlockBody matchgroup=hclBraces start="{" end="}" fold transparent

hi def link hclComment           Comment
hi def link hclTodo              Todo
hi def link hclBraces            Delimiter
hi def link hclAttributeName     Identifier
hi def link hclBlockType         Type
hi def link hclValueBool         Boolean
hi def link hclValueDec          Number
hi def link hclValueHexaDec      Number
hi def link hclValueString       String
hi def link hclHereDocText       String
hi def link hclFunction          Function
hi def link hclRepeat            Repeat
hi def link hclConditional       Conditional
hi def link hclValueNull         Constant

let b:current_syntax = 'hcl'
