" Vim syntax file
" Language:     Glimmer
" Maintainer:   Devin Weaver
" Last Change:  2026 Feb 20
" Origin:       https://github.com/joukevandermaas/vim-ember-hbs
" Credits:      Jouke van der Maas
" License:      Same as Vim

" Vim detects GJS/GTS files as {java,type}script.glimmer
" Vim will read the javascript/typescript syntax files first and set
" b:current_syntax accordingly then it will read the glimmer syntax file.
" This is why we use b:current_syntax to make sure we are in the correct state
" to continue.

if exists('b:current_syntax') && b:current_syntax !~# '\v%(type|java)script'
  finish
endif

let base_syntax = b:current_syntax
unlet! b:current_syntax

let s:cpo_save = &cpo
set cpo&vim

syntax include @hbs syntax/handlebars.vim

if base_syntax == "javascript"
  syntax region glimmerTemplateBlock
    \ start="<template>" end="</template>"
    \ contains=@hbs
    \ keepend fold

  let b:current_syntax = "javascript.glimmer"
else
  " syntax/typescript.vim adds typescriptTypeCast which is in conflict with
  " <template> typescriptreact doesn't define it but we want to not include
  " the JSX syntax.
  syntax clear typescriptTypeCast

  syntax region glimmerTemplateBlock
    \ start="<template>" end="</template>"
    \ contains=@hbs
    \ containedin=typescriptClassBlock,typescriptFuncCallArg
    \ keepend fold

  let b:current_syntax = "typescript.glimmer"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
unlet! base_syntax
