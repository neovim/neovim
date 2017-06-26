" Vim syntax file
" Language: crontab
" Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Original Maintainer: John Hoelzel johnh51@users.sourceforge.net
" License: This file can be redistribued and/or modified under the same terms
"   as Vim itself.
" Filenames: /tmp/crontab.* used by "crontab -e"
" Last Change: 2015-01-20
"
" crontab line format:
" Minutes   Hours   Days   Months   Days_of_Week   Commands # comments

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syntax match crontabNick "^\s*@\(reboot\|yearly\|annually\|monthly\|weekly\|daily\|midnight\|hourly\)\>" nextgroup=crontabCmd skipwhite

syntax match crontabVar "^\s*\k\w*\s*="me=e-1

syntax case ignore

syntax match crontabMin "^\s*[-0-9/,.*]\+" nextgroup=crontabHr skipwhite
syntax match crontabHr "\s[-0-9/,.*]\+" nextgroup=crontabDay skipwhite contained
syntax match crontabDay "\s[-0-9/,.*]\+" nextgroup=crontabMnth skipwhite contained

syntax match crontabMnth "\s[-a-z0-9/,.*]\+" nextgroup=crontabDow skipwhite contained
syntax keyword crontabMnth12 contained jan feb mar apr may jun jul aug sep oct nov dec

syntax match crontabDow "\s[-a-z0-9/,.*]\+" nextgroup=crontabCmd skipwhite contained
syntax keyword crontabDow7 contained sun mon tue wed thu fri sat

syntax region crontabCmd start="\S" end="$" skipwhite contained keepend contains=crontabPercent
syntax match crontabCmnt "^\s*#.*" contains=@Spell
syntax match crontabPercent "[^\\]%.*"lc=1 contained

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link crontabMin		Number
hi def link crontabHr		PreProc
hi def link crontabDay		Type

hi def link crontabMnth		Number
hi def link crontabMnth12		Number
hi def link crontabMnthS		Number
hi def link crontabMnthN		Number

hi def link crontabDow		PreProc
hi def link crontabDow7		PreProc
hi def link crontabDowS		PreProc
hi def link crontabDowN		PreProc

hi def link crontabNick		Special
hi def link crontabVar		Identifier
hi def link crontabPercent		Special

" comment out next line for to suppress unix commands coloring.
hi def link crontabCmd		Statement

hi def link crontabCmnt		Comment


let b:current_syntax = "crontab"

" vim: ts=8
