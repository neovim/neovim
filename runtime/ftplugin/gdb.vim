" Vim filetype plugin file
" Language:	gdb
" Maintainer:	Michaël Peeters <NOSPAMm.vim@noekeon.org>
" Contributors: Riley Bruins
" Last Changed:	2017 Oct 26
"		2024 Apr 10: add Matchit support (by Vim Project)
"		2024 Apr 23: add space to commentstring (by Riley Bruins) ('commentstring')
"		2026 Feb 08: add browsefilter, comment formatting, and improve matchit support (by Vim Project)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t
setlocal formatoptions+=croql
setlocal include=^\\s*source

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal com< cms< fo< inc<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let s:line_start = '\%(^\s*\)\@<='
  let b:match_words =
	\ s:line_start .. '\%(commands\|define\|document\|if\|while\|' ..
	\     '\%(py\%[thon]\|gu\%[ile]\)\%(\s*$\)\@=\|' ..
	\     '\%(compi\%[le]\|exp\%[ression]\)\s\+\%(c\%[ode]\|p\%[rint]\)\)\>:' ..
	\   s:line_start .. '\%(else\|loop_continue\|loop_break\)\>:' ..
	\ s:line_start .. 'end\>'
  unlet s:line_start
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter =
	\ "GDB Init Files (.gdbinit gdbinit .gdbearlyinit gdbearlyinit)\t" ..
	\   ".gdbinit;gdbinit;.gdbearlyinit;gdbearlyinit\n" ..
	\ "GDB Command Files (*.gdb)\t*.gdb\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
