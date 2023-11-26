" Vim syntax file
" Language:     trustees
" Maintainer:   Nima Talebi <nima@it.net.au>
" Last Change:  2022 Jun 14

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syntax case match
syntax sync minlines=0 maxlines=0

" Errors & Comments
syntax match tfsError /.*/
highlight link tfsError Error
syntax keyword tfsSpecialComment TODO XXX FIXME contained
highlight link tfsSpecialComment Todo
syntax match tfsComment ~\s*#.*~ contains=tfsSpecialComment
highlight link tfsComment Comment 

" Operators & Delimiters
highlight link tfsSpecialChar Operator
syntax match tfsSpecialChar ~[*!+]~ contained
highlight link tfsDelimiter Delimiter
syntax match tfsDelimiter ~:~ contained

" Trustees Rules - Part 1 of 3 - The Device
syntax region tfsRuleDevice matchgroup=tfsDeviceContainer start=~\[/~ end=~\]~ nextgroup=tfsRulePath oneline
highlight link tfsRuleDevice Label
highlight link tfsDeviceContainer PreProc

" Trustees Rules - Part 2 of 3 - The Path
syntax match tfsRulePath ~/[-_a-zA-Z0-9/]*~ nextgroup=tfsRuleACL contained contains=tfsDelimiter 
highlight link tfsRulePath String

" Trustees Rules - Part 3 of 3 - The ACLs
syntax match tfsRuleACL ~\(:\(\*\|[+]\{0,1\}[a-zA-Z0-9/]\+\):[RWEBXODCU!]\+\)\+$~ contained contains=tfsDelimiter,tfsRuleWho,tfsRuleWhat
syntax match tfsRuleWho ~\(\*\|[+]\{0,1\}[a-zA-Z0-9/]\+\)~ contained contains=tfsSpecialChar
highlight link tfsRuleWho Identifier
syntax match tfsRuleWhat ~[RWEBXODCU!]\+~ contained contains=tfsSpecialChar
highlight link tfsRuleWhat Structure

let b:current_syntax = 'trustees'
