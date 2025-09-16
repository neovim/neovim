" Vim syntax file
" Language:    Debian autopkgtest control files
" Maintainer:  Debian Vim Maintainers
" Last Change: 2025 Jul 05
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/autopkgtest.vim
"
" Specification of the autopkgtest format is available at:
"   https://www.debian.org/doc/debian-policy/autopkgtest.txt

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Must call this first, because it will clear other settings
syn sync clear
syn sync match autopkgtestSync grouphere NONE '^$'

" Should match case except for the keys of each field
syn case match

syn iskeyword @,48-57,-

" #-Comments
syn match autopkgtestComment "#.*" contains=@Spell

syn match autopkgtestTests contained "[a-z0-9][a-z0-9+.-]\+\%(,\=\s*[a-z0-9][a-z0-9+.-]\+\)*,\="
syn match autopkgtestArbitrary contained "[^#]*"
syn keyword autopkgtestRestrictions contained
      \ allow-stderr
      \ breaks-testbe
      \ build-neede
      \ flaky
      \ hint-testsuite-trigger
      \ isolation-container
      \ isolation-machine
      \ needs-internet
      \ needs-reboot
      \ needs-root
      \ needs-sudo
      \ rw-build-tree
      \ skip-foreign-architecture
      \ skip-not-installable
      \ skippable
      \ superficial
syn keyword autopkgtestDeprecatedRestrictions contained needs-recommends
syn match autopkgtestFeatures contained 'test-name=[^, ]*\%([, ]*[^, #]\)*,\='
syn match autopkgtestDepends contained '\%(@builddeps@\|@recommends@\|@\)'

runtime! syntax/shared/debarchitectures.vim

syn keyword autopkgtestArchitecture contained any
exe 'syn keyword autopkgtestArchitecture contained '. join(g:debArchitectureKernelAnyArch)
exe 'syn keyword autopkgtestArchitecture contained '. join(g:debArchitectureAnyKernelArch)
exe 'syn keyword autopkgtestArchitecture contained '. join(g:debArchitectureArchs)

syn case ignore

" Catch-all for the legal fields
syn region autopkgtestMultiField matchgroup=autopkgtestKey start="^Tests: *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=autopkgtestTests,autopkgtestComment
syn region autopkgtestMultiField matchgroup=autopkgtestKey start="^Restrictions: *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=autopkgtestRestrictions,autopkgtestDeprecatedRestrictions,autopkgtestComment
syn region autopkgtestMultiField matchgroup=autopkgtestKey start="^Features: *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=autopkgtestFeatures,autopkgtestComment
syn region autopkgtestMultiField matchgroup=autopkgtestKey start="^Depends: *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=autopkgtestDepends,autopkgtestComment
syn region autopkgtestMultiField matchgroup=autopkgtestKey start="^Classes: *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=autopkgtestComment
syn region autopkgtestMultiField matchgroup=autopkgtestKey start="^Architecture: *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=autopkgtestArchitecture,autopkgtestComment

" Fields for which we do strict syntax checking
syn region autopkgtestStrictField matchgroup=autopkgtestKey start="^Test-Command: *" end="$" end='#'me=s-1 contains=autopkgtestArbitrary,autopkgtestComment oneline
syn region autopkgtestStrictField matchgroup=autopkgtestKey start="^Tests-Directory: *" end="$" end='#'me=s-1 contains=autopkgtestArbitrary,autopkgtestComment oneline

syn match autopkgtestError '^\%(\%(Architecture\|Classes\|Depends\|Features\|Restrictions\|Test-Command\|Tests-Directory\|Tests\)\@![^ #]*:\)'

" Associate our matches and regions with pretty colours
hi def link autopkgtestKey           Keyword
hi def link autopkgtestRestrictions  Identifier
hi def link autopkgtestFeatures      Keyword
hi def link autopkgtestDepends       Identifier
hi def link autopkgtestArchitecture  Identifier
hi def link autopkgtestStrictField   Error
hi def link autopkgtestDeprecatedRestrictions Error
hi def link autopkgtestMultiField    Normal
hi def link autopkgtestArbitrary     Normal
hi def link autopkgtestTests         Normal
hi def link autopkgtestComment       Comment
hi def link autopkgtestError         Error

let b:current_syntax = 'autopkgtest'

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2
