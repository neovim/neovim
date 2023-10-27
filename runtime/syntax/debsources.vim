" Vim syntax file
" Language:     Debian sources.list
" Maintainer:   Debian Vim Maintainers
" Former Maintainer: Matthijs Mohlmann <matthijs@cacholong.nl>
" Last Change: 2023 Oct 11
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/debsources.vim

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

" case sensitive
syn case match

" A bunch of useful keywords
syn match debsourcesType               /\(deb-src\|deb\)/
syn match debsourcesFreeComponent      /\(main\|universe\)/
syn match debsourcesNonFreeComponent   /\(contrib\|non-free-firmware\|non-free\|restricted\|multiverse\)/

" Match comments
syn match debsourcesComment        /#.*/  contains=@Spell

" Include Debian versioning information
runtime! syntax/shared/debversions.vim

exe 'syn match debsourcesDistrKeyword   +\([[:alnum:]_./]*\)\<\('. join(g:debSharedSupportedVersions, '\|'). '\)\>\([-[:alnum:]_./]*\)+'
exe 'syn match debsourcesUnsupportedDistrKeyword +\([[:alnum:]_./]*\)\<\('. join(g:debSharedUnsupportedVersions, '\|') .'\)\>\([-[:alnum:]_./]*\)+'

unlet g:debSharedSupportedVersions
unlet g:debSharedUnsupportedVersions

" Match uri's
syn match debsourcesUri            '\(https\?://\|ftp://\|[rs]sh://\|debtorrent://\|\(cdrom\|copy\|file\):\)[^' 	<>"]\+'
syn region debsourcesLine start="^" end="$" contains=debsourcesType,debsourcesFreeComponent,debsourcesNonFreeComponent,debsourcesComment,debsourcesUri,debsourcesDistrKeyword,debsourcesUnsupportedDistrKeyword oneline


" Associate our matches and regions with pretty colours
hi def link debsourcesType                    Statement
hi def link debsourcesFreeComponent           Statement
hi def link debsourcesNonFreeComponent        Statement
hi def link debsourcesComment                 Comment
hi def link debsourcesUri                     Constant
hi def link debsourcesDistrKeyword            Type
hi def link debsourcesUnsupportedDistrKeyword WarningMsg

let b:current_syntax = 'debsources'
