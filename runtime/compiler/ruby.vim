" Vim compiler file
" Language:		Ruby
" Function:		Syntax check and/or error reporting
" Maintainer:		Tim Pope <vimNOSPAM@tpope.org>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>
" Last Change:		2019 Jan 06
"			2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "ruby"

let s:cpo_save = &cpo
set cpo-=C

" default settings runs script normally
" add '-c' switch to run syntax check only:
"
"   CompilerSet makeprg=ruby\ -c
"
" or add '-c' at :make command line:
"
"   :make -c %<CR>
"
CompilerSet makeprg=ruby

CompilerSet errorformat=
    \%+E%f:%l:\ parse\ error,
    \%W%f:%l:\ warning:\ %m,
    \%E%f:%l:in\ %*[^:]:\ %m,
    \%E%f:%l:\ %m,
    \%-C%\t%\\d%#:%#\ %#from\ %f:%l:in\ %.%#,
    \%-Z%\t%\\d%#:%#\ %#from\ %f:%l,
    \%-Z%p^,
    \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8:
