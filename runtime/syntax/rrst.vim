" reStructured Text with R statements
" Language: reST with R code chunks
" Maintainer: Alex Zvoleff, azvoleff@mail.sdsu.edu
" Homepage: https://github.com/jalvesaq/R-Vim-runtime
" Last Change: Tue Jun 28, 2016  08:53AM
"
" CONFIGURATION:
"   To highlight chunk headers as R code, put in your vimrc:
"   let rrst_syn_hl_chunk = 1

if exists("b:current_syntax")
  finish
endif

" load all of the rst info
runtime syntax/rst.vim
unlet b:current_syntax

" load all of the r syntax highlighting rules into @R
syntax include @R syntax/r.vim

" highlight R chunks
if exists("g:rrst_syn_hl_chunk")
  " highlight R code inside chunk header
  syntax match rrstChunkDelim "^\.\. {r" contained
  syntax match rrstChunkDelim "}$" contained
else
  syntax match rrstChunkDelim "^\.\. {r .*}$" contained
endif
syntax match rrstChunkDelim "^\.\. \.\.$" contained
syntax region rrstChunk start="^\.\. {r.*}$" end="^\.\. \.\.$" contains=@R,rrstChunkDelim keepend transparent fold

" also highlight in-line R code
syntax match rrstInlineDelim "`" contained
syntax match rrstInlineDelim ":r:" contained
syntax region rrstInline start=":r: *`" skip=/\\\\\|\\`/ end="`" contains=@R,rrstInlineDelim keepend

hi def link rrstChunkDelim Special
hi def link rrstInlineDelim Special

let b:current_syntax = "rrst"

" vim: ts=8 sw=2
