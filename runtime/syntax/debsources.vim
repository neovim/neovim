" Vim syntax file
" Language:     Debian sources.list
" Maintainer:   Debian Vim Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
" Former Maintainer: Matthijs Mohlmann <matthijs@cacholong.nl>
" Last Change: 2014 Jul 11
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

" Match uri's
syn match debsourcesUri            +\(http://\|ftp://\|[rs]sh://\|debtorrent://\|\(cdrom\|copy\|file\):\)[^' 	<>"]\++
syn match debsourcesDistrKeyword   +\([[:alnum:]_./]*\)\(squeeze\|wheezy\|jessie\|\(old\)\=stable\|testing\|unstable\|sid\|rc-buggy\|experimental\|devel\|lucid\|precise\|trusty\|utopic\)\([-[:alnum:]_./]*\)+

" Associate our matches and regions with pretty colours
hi def link debsourcesLine            Error
hi def link debsourcesKeyword         Statement
hi def link debsourcesDistrKeyword    Type
hi def link debsourcesComment         Comment
hi def link debsourcesUri             Constant

let b:current_syntax = "debsources"
