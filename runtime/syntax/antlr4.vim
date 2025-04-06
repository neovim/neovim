" Vim syntax file
" Language:	ANTLR4, ANother Tool for Language Recognition v4 <www.antlr.org>
" Maintainer:	Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change:	2024 July 09

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Keywords. See https://github.com/antlr/antlr4/blob/4.13.1/doc/lexicon.md
syn keyword antlr4Include import
" https://github.com/antlr/antlr4/blob/4.13.1/doc/options.md
" https://github.com/antlr/antlr4/blob/4.13.1/doc/grammars.md
syn keyword antlr4Structure fragment lexer parser grammar options channels tokens mode
syn keyword antlr4Statement returns locals
syn keyword antlr4Exceptions throws catch finally

" Comments.
syn keyword antlr4Todo contained TODO FIXME XXX NOTE
syn region antlr4Comment start="//"  end="$"   contains=antlr4Todo,@Spell
syn region antlr4Comment start="/\*" end="\*/" contains=antlr4Todo,@Spell

hi def link antlr4Include Include
hi def link antlr4Structure Structure
hi def link antlr4Statement Statement
hi def link antlr4Exceptions Structure
hi def link antlr4Comment Comment

let b:current_syntax = "antlr4"
