" Vim syntax file
" Language:     Debian deb822-format source list file
" Maintainer:   Debian Vim Maintainers
" Last Change: 2023 May 25
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/deb822sources.vim

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

" case insensitive
syn case ignore

" Comments are matched from the first character of a line to the end-of-line
syn region deb822sourcesComment start="^#" end="$"

" A bunch of useful keywords
syn match deb822sourcesType               /\(deb-src\|deb\)/
syn match deb822sourcesFreeComponent      /\(main\|universe\)/
syn match deb822sourcesNonFreeComponent   /\(contrib\|non-free-firmware\|non-free\|restricted\|multiverse\)/

" Include Debian versioning information
runtime! syntax/shared/debversions.vim

exe 'syn match deb822sourcesSupportedSuites contained + *\([[:alnum:]_./]*\)\<\('. join(g:debSharedSupportedVersions, '\|'). '\)\>\([-[:alnum:]_./]*\)+'
exe 'syn match deb822sourcesUnsupportedSuites contained + *\([[:alnum:]_./]*\)\<\('. join(g:debSharedUnsupportedVersions, '\|'). '\)\>\([-[:alnum:]_./]*\)+'

unlet g:debSharedSupportedVersions
unlet g:debSharedUnsupportedVersions

syn region deb822sourcesSuites start="\(^Suites: *\)\@<=" end="$" contains=deb822sourcesSupportedSuites,deb822sourcesUnsupportedSuites oneline

syn keyword deb822sourcesForce contained force
syn keyword deb822sourcesYesNo contained yes no

" Match uri's
syn match deb822sourcesUri            '\(https\?://\|ftp://\|[rs]sh://\|debtorrent://\|\(cdrom\|copy\|file\):\)[^' 	<>"]\+'

syn match deb822sourcesEntryField            "^\%(Types\|URIs\|Suites\|Components\): *"
syn match deb822sourcesOptionField           "^\%(Signed-By\|Check-Valid-Until\|Valid-Until-Min\|Valid-Until-Max\|Date-Max-Future\|InRelease-Path\): *"
syn match deb822sourcesMultiValueOptionField "^\%(Architectures\|Languages\|Targets\)\%(-Add\|-Remove\)\?: *"

syn region deb822sourcesStrictField matchgroup=deb822sourcesBooleanOptionField start="^\%(PDiffs\|Allow-Insecure\|Allow-Weak\|Allow-Downgrade-To-Insecure\|Trusted\|Check-Date\): *" end="$" contains=deb822sourcesYesNo oneline
syn region deb822sourcesStrictField matchgroup=deb822sourcesForceBooleanOptionField start="^\%(By-Hash\): *" end="$" contains=deb822sourcesForce,deb822sourcesYesNo oneline

hi def link deb822sourcesComment                 Comment
hi def link deb822sourcesEntryField              Keyword
hi def link deb822sourcesOptionField             Special
hi def link deb822sourcesMultiValueOptionField   Special
hi def link deb822sourcesBooleanOptionField      Special
hi def link deb822sourcesForceBooleanOptionField Special
hi def link deb822sourcesStrictField             Error
hi def link deb822sourcesType                    Identifier
hi def link deb822sourcesFreeComponent           Identifier
hi def link deb822sourcesNonFreeComponent        Identifier
hi def link deb822sourcesForce                   Identifier
hi def link deb822sourcesYesNo                   Identifier
hi def link deb822sourcesUri                     Constant
hi def link deb822sourcesSupportedSuites         Type
hi def link deb822sourcesUnsupportedSuites       WarningMsg

let b:current_syntax = 'deb822sources'
