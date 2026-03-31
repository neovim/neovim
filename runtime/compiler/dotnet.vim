" Vim compiler file
" Compiler:            dotnet build (.NET CLI)
" Maintainer:          Nick Jensen <nickspoon@gmail.com>
" Last Change:         2022-12-06
"                      2024 Apr 03 by The Vim Project (removed :CompilerSet definition)
" License:             Vim (see :h license)
" Repository:          https://github.com/nickspoons/vim-cs

if exists("current_compiler")
  finish
endif
let current_compiler = "dotnet"

let s:cpo_save = &cpo
set cpo&vim

if get(g:, "dotnet_errors_only", v:false)
  CompilerSet makeprg=dotnet\ build\ -nologo
		     \\ -consoleloggerparameters:NoSummary
		     \\ -consoleloggerparameters:ErrorsOnly
else
  CompilerSet makeprg=dotnet\ build\ -nologo\ -consoleloggerparameters:NoSummary
endif

if get(g:, "dotnet_show_project_file", v:true)
  CompilerSet errorformat=%E%f(%l\\,%c):\ %trror\ %m,
			 \%W%f(%l\\,%c):\ %tarning\ %m,
			 \%-G%.%#
else
  CompilerSet errorformat=%E%f(%l\\,%c):\ %trror\ %m\ [%.%#],
			 \%W%f(%l\\,%c):\ %tarning\ %m\ [%.%#],
			 \%-G%.%#
endif

let &cpo = s:cpo_save
unlet s:cpo_save
