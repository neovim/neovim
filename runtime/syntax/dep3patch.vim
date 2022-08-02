" Vim syntax file
" Language:    Debian DEP3 Patch headers
" Maintainer:  Gabriel Filion <gabster@lelutin.ca>
" Last Change: 2022 Apr 06
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/master/syntax/dep3patch.vim
"
" Specification of the DEP3 patch header format is available at:
"   https://dep-team.pages.debian.net/deps/dep3/

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

runtime! syntax/diff.vim
unlet! b:current_syntax

let s:cpo_save = &cpo
set cpo&vim

syn region dep3patchHeaders start="\%^" end="^\%(---\)\@=" contains=dep3patchKey,dep3patchMultiField

syn case ignore

syn region dep3patchMultiField matchgroup=dep3patchKey start="^\%(Description\|Subject\)\ze: *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contained contains=@Spell
syn region dep3patchMultiField matchgroup=dep3patchKey start="^Origin\ze: *" end="$" contained contains=dep3patchHTTPUrl,dep3patchCommitID,dep3patchOriginCategory oneline keepend
syn region dep3patchMultiField matchgroup=dep3patchKey start="^Bug\%(-[[:graph:]]\+\)\?\ze: *" end="$" contained contains=dep3patchHTTPUrl oneline keepend
syn region dep3patchMultiField matchgroup=dep3patchKey start="^Forwarded\ze: *" end="$" contained contains=dep3patchHTTPUrl,dep3patchForwardedShort oneline keepend
syn region dep3patchMultiField matchgroup=dep3patchKey start="^\%(Author\|From\)\ze: *" end="$" contained contains=dep3patchEmail oneline keepend
syn region dep3patchMultiField matchgroup=dep3patchKey start="^\%(Reviewed-by\|Acked-by\)\ze: *" end="$" contained contains=dep3patchEmail oneline keepend
syn region dep3patchMultiField matchgroup=dep3patchKey start="^Last-Update\ze: *" end="$" contained contains=dep3patchISODate oneline keepend
syn region dep3patchMultiField matchgroup=dep3patchKey start="^Applied-Upstream\ze: *" end="$" contained contains=dep3patchHTTPUrl,dep3patchCommitID oneline keepend

syn match dep3patchHTTPUrl contained "\vhttps?://[[:alnum:]][-[:alnum:]]*[[:alnum:]]?(\.[[:alnum:]][-[:alnum:]]*[[:alnum:]]?)*\.[[:alpha:]][-[:alnum:]]*[[:alpha:]]?(:\d+)?(/[^[:space:]]*)?$"
syn match dep3patchCommitID contained "commit:[[:alnum:]]\+"
syn match dep3patchOriginCategory contained "\%(upstream\|backport\|vendor\|other\), "
syn match dep3patchForwardedShort contained "\%(yes\|no\|not-needed\), "
syn match dep3patchEmail "[_=[:alnum:]\.+-]\+@[[:alnum:]\./\-]\+"
syn match dep3patchEmail "<.\{-}>"
syn match dep3patchISODate "[[:digit:]]\{4}-[[:digit:]]\{2}-[[:digit:]]\{2}"

" Associate our matches and regions with pretty colours
hi def link dep3patchKey            Keyword
hi def link dep3patchOriginCategory Keyword
hi def link dep3patchForwardedShort Keyword
hi def link dep3patchMultiField     Normal
hi def link dep3patchHTTPUrl        Identifier
hi def link dep3patchCommitID       Identifier
hi def link dep3patchEmail          Identifier
hi def link dep3patchISODate        Identifier

let b:current_syntax = 'dep3patch'

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2
