" Vim compiler file
" Compiler:               Microsoft Visual Studio C#
" Maintainer:             Yichao Zhou (broken.zhou@gmail.com)
" Previous Maintainer:    Joseph H. Yao (hyao@sina.com)
" Last Change:            Jul 22, 2019
"                         2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "cs"
let s:keepcpo= &cpo
set cpo&vim

CompilerSet errorformat&
CompilerSet errorformat+=%f(%l\\,%v):\ %t%*[^:]:\ %m,
            \%trror%*[^:]:\ %m,
            \%tarning%*[^:]:\ %m

CompilerSet makeprg=csc\ %:S

let &cpo = s:keepcpo
unlet s:keepcpo
