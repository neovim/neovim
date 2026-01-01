" Vim compiler file
" Compiler:     Mono C# Compiler
" Maintainer:   Jarek Sobiecki <harijari@go2.pl>
" Contributors: Peter Collingbourne and Enno Nagel
" Last Change:  2024 Mar 29
"               2024 Apr 05 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "mcs"

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=mcs
CompilerSet errorformat=
         \%D%.%#Project\ \"%f/%[%^/\"]%#\"%.%#,
         \%X%.%#Done\ building\ project\ \"%f/%[%^/\"]%#\"%.%#,
         \%-G%\\s%.%#,
         \%E%f(%l):\ error\ CS%n:%m,
         \%W%f(%l):\ warning\ CS%n:%m,
         \%E%f(%l\\,%c):\ error\ CS%n:%m,
         \%W%f(%l\\,%c):\ warning\ CS%n:%m,
         \%E%>syntax\ error\\,%m,%Z%f(%l\\,%c):\ error\ CS%n:%m,
         \%D%*\\a[%*\\d]:\ Entering\ directory\ `%f',
         \%X%*\\a[%*\\d]:\ Leaving\ directory\ `%f',
         \%DMaking\ %*\\a\ in\ %f,
         \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
