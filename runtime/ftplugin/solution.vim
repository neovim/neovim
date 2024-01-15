" Vim filetype plugin file
" Language:	Microsoft Visual Studio Solution
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Jan 14

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:#
setlocal commentstring=#\ %s

let b:undo_ftplugin = "setl com< cms<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words =
	\ '\<Project\>:\<EndProject\>,' ..
	\ '\<ProjectSection\>:\<EndProjectSection\>,' ..
	\ '\<Global\>:\<EndGlobal\>,' ..
	\ '\<GlobalSection\>:\<EndGlobalSection\>'
  let b:undo_ftplugin ..= " | unlet! b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Microsoft Visual Studio Solution Files(*.sln)\t*.sln\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
