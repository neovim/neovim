" Vim syntax file
" Language: Nvidia PTX (Parallel Thread Execution)
" Maintainer: Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Latest Revision: 2024-12-05

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syntax iskeyword .,_,a-z,48-57

" https://docs.nvidia.com/cuda/parallel-thread-execution/#directives
syntax keyword ptxFunction .entry .func
syntax keyword ptxDirective .branchtargets .file .loc .secion .maxnctapersm .maxnreg .minnctapersm .noreturn .pragma .reqntid .target .version .weak
syntax keyword ptxOperator .address_size .alias .align .callprototype .calltargets
syntax keyword ptxStorageClass .common .const .extern .global .local .param .reg .sreg .shared .tex .visible
syntax keyword ptxType .explicitcluster .maxclusterrank .reqnctapercluster

" https://docs.nvidia.com/cuda/parallel-thread-execution/#fundamental-types
" signed integer
syntax keyword ptxType .s8 .s16 .s32 .s64
" unsigned integer
syntax keyword ptxType .u8 .u16 .u32 .u64
" floating-point
syntax keyword ptxType .f16 .f16x2 .f32 .f64
" bits (untyped)
syntax keyword ptxType .b8 .b16 .b32 .b64 .b128
" predicate
syntax keyword ptxType .pred

" https://docs.nvidia.com/cuda/parallel-thread-execution/#instruction-statements
syntax keyword ptxStatement ret

syntax region  ptxCommentL start="//" skip="\\$" end="$" keepend
syntax region ptxComment matchgroup=ptxCommentStart start="/\*" end="\*/" extend

hi def link ptxFunction Function
hi def link ptxDirective Keyword
hi def link ptxOperator Operator
hi def link ptxStorageClass StorageClass
hi def link ptxType Type
hi def link ptxStatement Statement

hi def link ptxCommentL ptxComment
hi def link ptxCommentStart ptxComment
hi def link ptxComment Comment

let &cpo = s:cpo_save
unlet s:cpo_save
