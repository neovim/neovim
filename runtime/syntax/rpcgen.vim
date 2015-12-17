" Vim syntax file
" Language:	rpcgen
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Jan 13, 2015
" Version:	10
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_RPCGEN

if exists("b:current_syntax")
  finish
endif

" Read the C syntax to start with
if version < 600
  source <sfile>:p:h/c.vim
else
  runtime! syntax/c.vim
endif

syn keyword rpcProgram	program				skipnl skipwhite nextgroup=rpcProgName
syn match   rpcProgName	contained	"\<\i\I*\>"	skipnl skipwhite nextgroup=rpcProgZone
syn region  rpcProgZone	contained	matchgroup=Delimiter start="{" matchgroup=Delimiter end="}\s*=\s*\(\d\+\|0x[23]\x\{7}\)\s*;"me=e-1 contains=rpcVersion,cComment,rpcProgNmbrErr
syn keyword rpcVersion	contained	version		skipnl skipwhite nextgroup=rpcVersName
syn match   rpcVersName	contained	"\<\i\I*\>"	skipnl skipwhite nextgroup=rpcVersZone
syn region  rpcVersZone	contained	matchgroup=Delimiter start="{" matchgroup=Delimiter end="}\s*=\s*\d\+\s*;"me=e-1 contains=cType,cStructure,cStorageClass,rpcDecl,rpcProcNmbr,cComment
syn keyword rpcDecl	contained	string
syn match   rpcProcNmbr	contained	"=\s*\d\+;"me=e-1
syn match   rpcProgNmbrErr contained	"=\s*0x[^23]\x*"ms=s+1
syn match   rpcPassThru			"^\s*%.*$"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_rpcgen_syntax_inits")
  if version < 508
    let did_rpcgen_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink rpcProgName	rpcName
  HiLink rpcProgram	rpcStatement
  HiLink rpcVersName	rpcName
  HiLink rpcVersion	rpcStatement

  HiLink rpcDecl	cType
  HiLink rpcPassThru	cComment

  HiLink rpcName	Special
  HiLink rpcProcNmbr	Delimiter
  HiLink rpcProgNmbrErr	Error
  HiLink rpcStatement	Statement

  delcommand HiLink
endif

let b:current_syntax = "rpcgen"

" vim: ts=8
