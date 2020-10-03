" Vim syntax file
" Language:     TypeScript
" Maintainer:   Bram Moolenaar, Herrington Darkholme
" Last Change:	2019 Nov 30
" Based On:     Herrington Darkholme's yats.vim
" Changes:      Go to https:github.com/HerringtonDarkholme/yats.vim for recent changes.
" Origin:       https://github.com/othree/yajs
" Credits:      Kao Wei-Ko(othree), Jose Elera Campana, Zhao Yi, Claudio Fleiner, Scott Shattuck
"               (This file is based on their hard work), gumnos (From the #vim
"               IRC Channel in Freenode)

" This is the same syntax that is in yats.vim, but:
" - flattened into one file
" - HiLink commands changed to "hi def link"
" - Setting 'cpo' to the Vim value

if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'typescript'
endif

let s:cpo_save = &cpo
set cpo&vim

" this region is NOT used in TypeScriptReact
" nextgroup doesn't contain objectLiteral, let outer region contains it
syntax region typescriptTypeCast matchgroup=typescriptTypeBrackets
  \ start=/< \@!/ end=/>/
  \ contains=@typescriptType
  \ nextgroup=@typescriptExpression
  \ contained skipwhite oneline


"""""""""""""""""""""""""""""""""""""""""""""""""""
" Source the part common with typescriptreact.vim
source <sfile>:h/typescriptcommon.vim


let b:current_syntax = "typescript"
if main_syntax == 'typescript'
  unlet main_syntax
endif

let &cpo = s:cpo_save
unlet s:cpo_save
