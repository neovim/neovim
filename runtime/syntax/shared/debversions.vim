" Vim syntax file
" Language:     Debian version information
" Maintainer:   Debian Vim Maintainers
" Last Change:  2026 Oct 27
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/shared/debversions.vim

let s:cpo = &cpo
set cpo-=C

" Try to get up-to-date versions from distro-info
let s:supported_debian_versions = []
let s:unsupported_debian_versions = []
if executable('debian-distro-info')
  let s:supported_debian_versions = systemlist('debian-distro-info --supported')
  let s:unsupported_debian_versions = systemlist('debian-distro-info --unsupported')
endif

let s:supported_ubuntu_versions = []
let s:unsupported_ubuntu_versions = []
if executable('ubuntu-distro-info')
  let s:supported_ubuntu_versions = systemlist('ubuntu-distro-info --supported')
  let s:unsupported_ubuntu_versions = systemlist('ubuntu-distro-info --unsupported')
endif

" Version names that are upcoming or released and still within the standard support window
let g:debSharedSupportedVersions = s:supported_debian_versions + s:supported_ubuntu_versions
if empty(g:debSharedSupportedVersions)
  " Hard-coded fallback in case distro-info is not available
  let g:debSharedSupportedVersions = [
      \ 'trixie', 'forky', 'duke', 'sid', 'rc-buggy',
      \
      \ 'jammy', 'noble', 'resolute', 'stonking', 'tenacious',
      \ ]
endif
let g:debSharedSupportedVersions += [
      \ 'oldstable', 'stable', 'testing', 'unstable', 'experimental',
      \
      \ 'devel',
      \ ]

" Historic version names, no longer under standard support
let g:debSharedUnsupportedVersions = s:unsupported_debian_versions + s:unsupported_ubuntu_versions
if empty(g:debSharedUnsupportedVersions)
  " Hard-coded fallback in case distro-info is not available
  let g:debSharedUnsupportedVersions = [
      \ 'buzz', 'rex', 'bo', 'hamm', 'slink', 'potato',
      \ 'woody', 'sarge', 'etch', 'lenny', 'squeeze', 'wheezy',
      \ 'jessie', 'stretch', 'buster', 'bullseye', 'bookworm',
      \
      \ 'warty', 'hoary', 'breezy', 'dapper', 'edgy', 'feisty',
      \ 'gutsy', 'hardy', 'intrepid', 'jaunty', 'karmic', 'lucid',
      \ 'maverick', 'natty', 'oneiric', 'precise', 'quantal', 'raring', 'saucy',
      \ 'trusty', 'utopic', 'vivid', 'wily', 'xenial', 'yakkety', 'zesty',
      \ 'artful', 'bionic', 'cosmic', 'disco', 'eoan', 'focal', 'groovy',
      \ 'hirsute', 'impish', 'kinetic', 'lunar', 'mantic', 'oracular',
      \ 'plucky', 'questing',
      \ ]
endif

let &cpo=s:cpo
