" Language   : Tar Listing Syntax
" Maintainer : Bram Moolenaar
" Last change: Sep 08, 2004

if exists("b:current_syntax")
 finish
endif

syn match tarComment '^".*' contains=tarFilename
syn match tarFilename 'tarfile \zs.*' contained
syn match tarDirectory '.*/$'

hi def link tarComment	Comment
hi def link tarFilename	Constant
hi def link tarDirectory Type

" vim: ts=8
