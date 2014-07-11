" Vim syntax file
" This is a GENERATED FILE. Please always refer to source file at the URI below.
" Language: SysV-compatible init process control file `inittab'
" Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2002-09-13
" URL: http://physics.muni.cz/~yeti/download/syntax/inittab.vim

" Setup
if version >= 600
  if exists("b:current_syntax")
    finish
  endif
else
  syntax clear
endif

syn case match

" Base constructs
syn match inittabError "[^:]\+:"me=e-1 contained
syn match inittabError "[^:]\+$" contained
syn match inittabComment "^[#:].*$" contains=inittabFixme
syn match inittabComment "#.*$" contained contains=inittabFixme
syn keyword inittabFixme FIXME TODO XXX NOT

" Shell
syn region inittabShString start=+"+ end=+"+ skip=+\\\\\|\\\"+ contained
syn region inittabShString start=+'+ end=+'+ contained
syn match inittabShOption "\s[-+][[:alnum:]]\+"ms=s+1 contained
syn match inittabShOption "\s--[:alnum:][-[:alnum:]]*"ms=s+1 contained
syn match inittabShCommand "/\S\+" contained
syn cluster inittabSh add=inittabShOption,inittabShString,inittabShCommand

" Keywords
syn keyword inittabActionName respawn wait once boot bootwait off ondemand sysinit powerwait powerfail powerokwait powerfailnow ctrlaltdel kbrequest initdefault contained

" Line parser
syn match inittabId "^[[:alnum:]~]\{1,4}" nextgroup=inittabColonRunLevels,inittabError
syn match inittabColonRunLevels ":" contained nextgroup=inittabRunLevels,inittabColonAction,inittabError
syn match inittabRunLevels "[0-6A-Ca-cSs]\+" contained nextgroup=inittabColonAction,inittabError
syn match inittabColonAction ":" contained nextgroup=inittabAction,inittabError
syn match inittabAction "\w\+" contained nextgroup=inittabColonProcess,inittabError contains=inittabActionName
syn match inittabColonProcess ":" contained nextgroup=inittabProcessPlus,inittabProcess,inittabError
syn match inittabProcessPlus "+" contained nextgroup=inittabProcess,inittabError
syn region inittabProcess start="/" end="$" transparent oneline contained contains=@inittabSh,inittabComment

" Define the default highlighting
if version >= 508 || !exists("did_inittab_syntax_inits")
  if version < 508
    let did_inittab_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink inittabComment Comment
  HiLink inittabFixme Todo
  HiLink inittabActionName Type
  HiLink inittabError Error
  HiLink inittabId Identifier
  HiLink inittabRunLevels Special

  HiLink inittabColonProcess inittabColon
  HiLink inittabColonAction inittabColon
  HiLink inittabColonRunLevels inittabColon
  HiLink inittabColon PreProc

  HiLink inittabShString String
  HiLink inittabShOption Special
  HiLink inittabShCommand Statement

  delcommand HiLink
endif

let b:current_syntax = "inittab"
