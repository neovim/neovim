" Vim syntax file
" Language:     Debian version information
" Maintainer:   Debian Vim Maintainers
" Last Change:  2025 Apr 24
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/shared/debversions.vim

let s:cpo = &cpo
set cpo-=C

let g:debSharedSupportedVersions = [
      \ 'oldstable', 'stable', 'testing', 'unstable', 'experimental', 'sid', 'rc-buggy',
      \ 'bullseye', 'bookworm', 'trixie', 'forky', 'duke',
      \
      \ 'focal', 'jammy', 'noble', 'oracular', 'plucky', 'questing',
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
      \ 'artful', 'bionic', 'cosmic', 'disco', 'eoan', 'groovy',
      \ 'hirsute', 'impish', 'kinetic', 'lunar', 'mantic',
      \ ]

let &cpo=s:cpo
