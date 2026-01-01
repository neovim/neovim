" Vim Compiler File
" Compiler:	ant
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Mi, 13 Apr 2005 22:50:07 CEST
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
    finish
endif
let current_compiler = "ant"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=ant

" first  line:
"     ant with jikes +E, which assumes  the following
"     two property lines in your 'build.xml':
"
"         <property name = "build.compiler"       value = "jikes"/>
"         <property name = "build.compiler.emacs" value = "true"/>
"
" second line:
"     ant with javac
"
" note that this will work also for tasks like [wtkbuild]
"
CompilerSet errorformat=\ %#[%.%#]\ %#%f:%l:%v:%*\\d:%*\\d:\ %t%[%^:]%#:%m,
    \%A\ %#[%.%#]\ %f:%l:\ %m,%-Z\ %#[%.%#]\ %p^,%C\ %#[%.%#]\ %#%m

" ,%-C%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
