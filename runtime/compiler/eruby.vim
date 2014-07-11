" Vim compiler file
" Language:		eRuby
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>

if exists("current_compiler")
  finish
endif
let current_compiler = "eruby"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

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
    \%-C%\tfrom\ %f:%l:in\ %.%#,
    \%-Z%\tfrom\ %f:%l,
    \%-Z%p^,
    \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8:
