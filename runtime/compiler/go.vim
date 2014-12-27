" Vim compiler file
" Compiler:	Go
" Maintainer:	David Barnett (https://github.com/google/vim-ft-go)
" Last Change:	2014 Aug 16

if exists('current_compiler')
  finish
endif
let current_compiler = 'go'

if exists(':CompilerSet') != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:save_cpo = &cpo
set cpo-=C

CompilerSet makeprg=go\ build
CompilerSet errorformat=
    \%-G#\ %.%#,
    \%A%f:%l:%c:\ %m,
    \%A%f:%l:\ %m,
    \%C%*\\s%m,
    \%-G%.%#

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: sw=2 sts=2 et
