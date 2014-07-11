" Vim syntax file
" Language: crontab
" Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Original Maintainer: John Hoelzel johnh51@users.sourceforge.net
" License: This file can be redistribued and/or modified under the same terms
"   as Vim itself.
" Filenames: /tmp/crontab.* used by "crontab -e"
" Last Change: 2012-05-16
"
" crontab line format:
" Minutes   Hours   Days   Months   Days_of_Week   Commands # comments

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

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

syntax match crontabNick "^\s*@\(reboot\|yearly\|annually\|monthly\|weekly\|daily\|midnight\|hourly\)\>" nextgroup=crontabCmd skipwhite

syntax match crontabVar "^\s*\k\w*\s*="me=e-1

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_crontab_syn_inits")
  if version < 508
    let did_crontab_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink crontabMin		Number
  HiLink crontabHr		PreProc
  HiLink crontabDay		Type

  HiLink crontabMnth		Number
  HiLink crontabMnth12		Number
  HiLink crontabMnthS		Number
  HiLink crontabMnthN		Number

  HiLink crontabDow		PreProc
  HiLink crontabDow7		PreProc
  HiLink crontabDowS		PreProc
  HiLink crontabDowN		PreProc

  HiLink crontabNick		Special
  HiLink crontabVar		Identifier
  HiLink crontabPercent		Special

" comment out next line for to suppress unix commands coloring.
  HiLink crontabCmd		Statement

  HiLink crontabCmnt		Comment

  delcommand HiLink
endif

let b:current_syntax = "crontab"

" vim: ts=8
