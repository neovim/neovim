" Vim syntax file
" Language:     Debian version information
" Maintainer:   Debian Vim Maintainers
" Last Change:  2025 Aug 26
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/shared/debversions.vim

let s:cpo = &cpo
set cpo-=C

" Version names that are upcoming or released and still within the standard support window
let g:debSharedSupportedVersions = [
      \ 'oldstable', 'stable', 'testing', 'unstable', 'experimental', 'sid', 'rc-buggy',
      \ 'bookworm', 'trixie', 'forky', 'duke',
      \
      \ 'jammy', 'noble', 'plucky', 'questing',
      \ 'devel'
      \ ]
" Historic version names, no longer under standard support
let g:debSharedUnsupportedVersions = [
      \ 'buzz', 'rex', 'bo', 'hamm', 'slink', 'potato',
      \ 'woody', 'sarge', 'etch', 'lenny', 'squeeze', 'wheezy',
      \ 'jessie', 'stretch', 'buster', 'bullseye',
      \
      \ 'warty', 'hoary', 'breezy', 'dapper', 'edgy', 'feisty',
      \ 'gutsy', 'hardy', 'intrepid', 'jaunty', 'karmic', 'lucid',
      \ 'maverick', 'natty', 'oneiric', 'precise', 'quantal', 'raring', 'saucy',
      \ 'trusty', 'utopic', 'vivid', 'wily', 'xenial', 'yakkety', 'zesty',
      \ 'artful', 'bionic', 'cosmic', 'disco', 'eoan', 'focal', 'groovy',
      \ 'hirsute', 'impish', 'kinetic', 'lunar', 'mantic', 'oracular',
      \ ]

let &cpo=s:cpo
