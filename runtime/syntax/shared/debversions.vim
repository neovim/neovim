" Vim syntax file
" Language:     Debian version information
" Maintainer:   Debian Vim Maintainers
" Last Change:  2024 May 25
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/shared/debversions.vim

let s:cpo = &cpo
set cpo-=C

let g:debSharedSupportedVersions = [
      \ 'oldstable', 'stable', 'testing', 'unstable', 'experimental', 'sid', 'rc-buggy',
      \ 'bullseye', 'bookworm', 'trixie', 'forky',
      \
      \ 'focal', 'jammy', 'mantic', 'noble', 'oracular',
      \ 'devel'
      \ ]
let g:debSharedUnsupportedVersions = [
      \ 'buzz', 'rex', 'bo', 'hamm', 'slink', 'potato',
      \ 'woody', 'sarge', 'etch', 'lenny', 'squeeze', 'wheezy',
      \ 'jessie', 'stretch', 'buster',
      \
      \ 'warty', 'hoary', 'breezy', 'dapper', 'edgy', 'feisty',
      \ 'gutsy', 'hardy', 'intrepid', 'jaunty', 'karmic', 'lucid',
      \ 'maverick', 'natty', 'oneiric', 'precise', 'quantal', 'raring', 'saucy',
      \ 'trusty', 'utopic', 'vivid', 'wily', 'xenial', 'yakkety', 'zesty',
      \ 'artful', 'bionic', 'cosmic', 'disco', 'eoan', 'hirsute',
      \ 'impish', 'kinetic', 'lunar', 'groovy'
      \ ]

let &cpo=s:cpo
