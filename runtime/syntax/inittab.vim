" Vim syntax file
" Language: SysV-compatible init process control file `inittab'
" Maintainer: Donovan Keohane <donovan.keohane@gmail.com>
" Previous Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2019-11-19

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
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
syn match inittabShCommand "\S\+" contained
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
syn region inittabProcess start="\S" end="$" transparent oneline contained contains=@inittabSh,inittabComment

" Define the default highlighting

hi def link inittabComment Comment
hi def link inittabFixme Todo
hi def link inittabActionName Type
hi def link inittabError Error
hi def link inittabId Identifier
hi def link inittabRunLevels Special

hi def link inittabColonProcess inittabColon
hi def link inittabColonAction inittabColon
hi def link inittabColonRunLevels inittabColon
hi def link inittabColon PreProc

hi def link inittabShString String
hi def link inittabShOption Special
hi def link inittabShCommand Statement


let b:current_syntax = "inittab"
