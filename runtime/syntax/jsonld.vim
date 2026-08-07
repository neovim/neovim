" Vim syntax file
" Language:	JSON-LD
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2026 Aug 06
" Reference:	https://www.w3.org/TR/json-ld11/

if !exists('main_syntax')
  if exists('b:current_syntax')
    finish
  endif
  let main_syntax = 'jsonld'
endif

runtime! syntax/json.vim
unlet! b:current_syntax

" Match reserved keywords only when they occupy a complete JSON string.  The
" negative lookbehind excludes an escaped quote inside a longer string.
syn match jsonldKeyword /\C\%(\\"\)\@<!"\@<=@\%(base\|container\|context\|direction\|graph\|id\)\ze"/ contained containedin=jsonKeyword,jsonString
syn match jsonldKeyword /\C\%(\\"\)\@<!"\@<=@\%(import\|included\|index\|json\|language\|list\)\ze"/ contained containedin=jsonKeyword,jsonString
syn match jsonldKeyword /\C\%(\\"\)\@<!"\@<=@\%(nest\|none\|prefix\|propagate\|protected\|reverse\)\ze"/ contained containedin=jsonKeyword,jsonString
syn match jsonldKeyword /\C\%(\\"\)\@<!"\@<=@\%(set\|type\|value\|version\|vocab\)\ze"/ contained containedin=jsonKeyword,jsonString

hi def link jsonldKeyword SpecialChar

let b:current_syntax = 'jsonld'
if main_syntax ==# 'jsonld'
  unlet main_syntax
endif

" vim: ts=8
