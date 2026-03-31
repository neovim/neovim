" Vim syntax file
" Language:    RELAX NG
" Maintainer:  Jaromir Hradilek <jhradilek@gmail.com>
" URL:         https://github.com/jhradilek/vim-rng
" Last Change: 25 March 2013
" Description: A syntax file for RELAX NG, a schema language for XML

if exists('b:current_syntax')
  finish
endif

do Syntax xml
syn spell toplevel
syn cluster xmlTagHook add=rngTagName
syn case match

syn keyword rngTagName anyName attribute choice data define div contained
syn keyword rngTagName element empty except externalRef grammar contained
syn keyword rngTagName group include interleave list mixed name contained
syn keyword rngTagName notAllowed nsName oneOrMore optional param contained
syn keyword rngTagName parentRef ref start text value zeroOrMore contained

hi def link rngTagName Statement

let b:current_syntax = 'rng'
