" Vim syntax file
" Language:     Debian sources.list
" Maintainer:   Debian Vim Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
" Former Maintainer: Matthijs Mohlmann <matthijs@cacholong.nl>
" Last Change: 2015 May 25
" URL: http://anonscm.debian.org/hg/pkg-vim/vim/raw-file/unstable/runtime/syntax/debsources.vim

" Standard syntax initialization
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" case sensitive
syn case match

" A bunch of useful keywords
syn match debsourcesKeyword        /\(deb-src\|deb\|main\|contrib\|non-free\|restricted\|universe\|multiverse\)/

" Match comments
syn match debsourcesComment        /#.*/  contains=@Spell

let s:cpo = &cpo
set cpo-=C
let s:supported = [
      \ 'oldstable', 'stable', 'testing', 'unstable', 'experimental',
      \ 'squeeze', 'wheezy', 'jessie', 'stretch', 'sid', 'rc-buggy',
      \
      \ 'precise', 'trusty', 'utopic', 'vivid', 'wily', 'devel'
      \ ]
let s:unsupported = [
      \ 'buzz', 'rex', 'bo', 'hamm', 'slink', 'potato',
      \ 'woody', 'sarge', 'etch', 'lenny',
      \
      \ 'warty', 'hoary', 'breezy', 'dapper', 'edgy', 'feisty',
      \ 'gutsy', 'hardy', 'intrepid', 'jaunty', 'karmic', 'lucid',
      \ 'maverick', 'natty', 'oneiric', 'quantal', 'raring', 'saucy'
      \ ]
let &cpo=s:cpo

" Match uri's
syn match debsourcesUri            +\(http://\|ftp://\|[rs]sh://\|debtorrent://\|\(cdrom\|copy\|file\):\)[^' 	<>"]\++
exe 'syn match debsourcesDistrKeyword   +\([[:alnum:]_./]*\)\('. join(s:supported, '\|'). '\)\([-[:alnum:]_./]*\)+'
exe 'syn match debsourcesUnsupportedDistrKeyword +\([[:alnum:]_./]*\)\('. join(s:unsupported, '\|') .'\)\([-[:alnum:]_./]*\)+'

" Associate our matches and regions with pretty colours
hi def link debsourcesLine                    Error
hi def link debsourcesKeyword                 Statement
hi def link debsourcesDistrKeyword            Type
hi def link debsourcesUnsupportedDistrKeyword WarningMsg
hi def link debsourcesComment                 Comment
hi def link debsourcesUri                     Constant

let b:current_syntax = "debsources"
