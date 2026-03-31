" Vim syntax file
" Language:    Debian copyright file
" Maintainer:  Debian Vim Maintainers
" Last Change: 2024 Jul 28
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/debcopyright.vim

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match

syn match debcopyrightUrl       "\vhttps?://[[:alnum:]][-[:alnum:]]*[[:alnum:]]?(\.[[:alnum:]][-[:alnum:]]*[[:alnum:]]?)*\.[[:alpha:]][-[:alnum:]]*[[:alpha:]]?(:\d+)?(/[^[:space:]]*)?$"
syn match debcopyrightKey       "^\%(Format\|Upstream-Name\|Upstream-Contact\|Disclaimer\|Source\|Comment\|Files\|Copyright\|License\|Files-\%(Excluded\|Included\)\%(-[-a-zA-Z0-9]\+\)\=\): *"
syn match debcopyrightEmail     "[_=[:alnum:]\.+-]\+@[[:alnum:]\./\-]\+"
syn match debcopyrightEmail     "<.\{-}>"
syn match debcopyrightComment   "^#.*$" contains=@Spell

hi def link debcopyrightUrl     Identifier
hi def link debcopyrightKey     Keyword
hi def link debcopyrightEmail   Identifier
hi def link debcopyrightComment Comment

let b:current_syntax = 'debcopyright'

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2
