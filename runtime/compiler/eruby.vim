" Vim compiler file
" Language:		eRuby
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>
" Last Change:		2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "eruby"

let s:cpo_save = &cpo
set cpo-=C

if exists("eruby_compiler") && eruby_compiler == "eruby"
  CompilerSet makeprg=eruby
else
  CompilerSet makeprg=erb
endif

CompilerSet errorformat=
    \eruby:\ %f:%l:%m,
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
