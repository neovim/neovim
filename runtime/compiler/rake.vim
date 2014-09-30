" Vim compiler file
" Language:		Rake
" Maintainer:		Tim Pope <vimNOSPAM@tpope.org>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>

if exists("current_compiler")
  finish
endif
let current_compiler = "rake"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=rake

CompilerSet errorformat=
      \%D(in\ %f),
      \%\\s%#from\ %f:%l:%m,
      \%\\s%#from\ %f:%l:,
      \%\\s%##\ %f:%l:%m,
      \%\\s%##\ %f:%l,
      \%\\s%#[%f:%l:\ %#%m,
      \%\\s%#%f:%l:\ %#%m,
      \%\\s%#%f:%l:,
      \%m\ [%f:%l]:

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8:
