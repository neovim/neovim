" Vim ftplugin file
" Language:		NSIS script
" Maintainer:		Ken Takata
" URL:			https://github.com/k-takata/vim-nsis
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		2021-10-18

if exists("b:did_ftplugin")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let b:did_ftplugin = 1

let b:undo_ftplugin = "setl com< cms< fo< def< inc<"

setlocal comments=s1:/*,mb:*,ex:*/,b:#,:; commentstring=;\ %s
setlocal formatoptions-=t formatoptions+=croql
setlocal define=^\\s*!define\\%(\\%(utc\\)\\=date\\|math\\)\\=
setlocal include=^\\s*!include\\%(/NONFATAL\\)\\=

if exists("loaded_matchit")
  let b:match_ignorecase = 1
  let b:match_words =
	\ '\${\%(If\|IfNot\|Unless\)}:\${\%(Else\|ElseIf\|ElseIfNot\|ElseUnless\)}:\${\%(EndIf\|EndUnless\)},' .
	\ '\${Select}:\${EndSelect},' .
	\ '\${Switch}:\${EndSwitch},' .
	\ '\${\%(Do\|DoWhile\|DoUntil\)}:\${\%(Loop\|LoopWhile\|LoopUntil\)},' .
	\ '\${\%(For\|ForEach\)}:\${Next},' .
	\ '\<Function\>:\<FunctionEnd\>,' .
	\ '\<Section\>:\<SectionEnd\>,' .
	\ '\<SectionGroup\>:\<SectionGroupEnd\>,' .
	\ '\<PageEx\>:\<PageExEnd\>,' .
	\ '\${MementoSection}:\${MementoSectionEnd},' .
	\ '!if\%(\%(macro\)\?n\?def\)\?\>:!else\>:!endif\>,' .
	\ '!macro\>:!macroend\>'
  let b:undo_ftplugin .= " | unlet! b:match_ignorecase b:match_words"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
