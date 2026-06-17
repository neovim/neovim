" Vim compiler file
" Compiler: bean-check
" Maintainer: Nathan Grigg
" Latest Revision: 2017-03-20

if exists('g:current_compiler')
    finish
endif
let g:current_compiler = 'bean_check'

let s:cpo_save = &cpoptions
set cpoptions-=C

CompilerSet makeprg=bean-check\ %
" File:line: message
" Skip blank lines and indented lines.
CompilerSet errorformat=%-G
CompilerSet errorformat+=%f:%l:\ %m
CompilerSet errorformat+=%-G\ %.%#

let &cpoptions = s:cpo_save
unlet s:cpo_save
