" Vim syntax file
" Language:     Debian sources.list
" Maintainer:   Debian Vim Maintainers
" Former Maintainer: Matthijs Mohlmann <matthijs@cacholong.nl>
" Last Change: 2023 Feb 06
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

let s:cpo = &cpo
set cpo-=C
let s:supported = [
      \ 'oldstable', 'stable', 'testing', 'unstable', 'experimental', 'sid', 'rc-buggy',
      \ 'buster', 'bullseye', 'bookworm', 'trixie', 'forky',
      \
      \ 'trusty', 'xenial', 'bionic', 'focal', 'jammy', 'kinetic', 'lunar',
      \ 'devel'
      \ ]
let s:unsupported = [
      \ 'buzz', 'rex', 'bo', 'hamm', 'slink', 'potato',
      \ 'woody', 'sarge', 'etch', 'lenny', 'squeeze', 'wheezy',
      \ 'jessie', 'stretch',
      \
      \ 'warty', 'hoary', 'breezy', 'dapper', 'edgy', 'feisty',
      \ 'gutsy', 'hardy', 'intrepid', 'jaunty', 'karmic', 'lucid',
      \ 'maverick', 'natty', 'oneiric', 'precise', 'quantal', 'raring', 'saucy',
      \ 'utopic', 'vivid', 'wily', 'yakkety', 'zesty', 'artful', 'cosmic',
      \ 'disco', 'eoan', 'hirsute', 'impish', 'groovy'
      \ ]
let &cpo=s:cpo

" Match uri's
syn match debsourcesUri            '\(https\?://\|ftp://\|[rs]sh://\|debtorrent://\|\(cdrom\|copy\|file\):\)[^' 	<>"]\+'
exe 'syn match debsourcesDistrKeyword   +\([[:alnum:]_./]*\)\<\('. join(s:supported, '\|'). '\)\>\([-[:alnum:]_./]*\)+'
exe 'syn match debsourcesUnsupportedDistrKeyword +\([[:alnum:]_./]*\)\<\('. join(s:unsupported, '\|') .'\)\>\([-[:alnum:]_./]*\)+'

" Associate our matches and regions with pretty colours
hi def link debsourcesLine                    Error
hi def link debsourcesType                    Statement
hi def link debsourcesFreeComponent           Statement
hi def link debsourcesNonFreeComponent        Statement
hi def link debsourcesDistrKeyword            Type
hi def link debsourcesUnsupportedDistrKeyword WarningMsg
hi def link debsourcesComment                 Comment
hi def link debsourcesUri                     Constant

let b:current_syntax = 'debsources'
