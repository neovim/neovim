" Vim filetype plugin file
" Language:	meson
" License:	VIM License
" Maintainer:   Liam Beguin <liambeguin@gmail.com>
" Original Author:	Laurent Pinchart <laurent.pinchart@ideasonboard.com>
" Last Change:		2018 Nov 27

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1
let s:keepcpo= &cpo
set cpo&vim

setlocal commentstring=#\ %s
setlocal comments=:#
setlocal formatoptions+=croql formatoptions-=t

let b:undo_ftplugin = "setl com< cms< fo<"

if get(g:, "meson_recommended_style", 1)
  setlocal expandtab
  setlocal shiftwidth=2
  setlocal softtabstop=2
  let b:undo_ftplugin .= " | setl et< sts< sw<"
endif

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words = '\<if\>:\<elif\>:\<else\>:\<endif\>,' .
	\             '\<foreach\>:\<break\>:\<continue\>:\<endforeach\>'
  let b:undo_ftplugin .= " | unlet! b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Meson Build Files (meson.build)\tmeson.build\n" .
	\	       "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin .= " | unlet! b:browsefilter"
endif

let &cpo = s:keepcpo
unlet s:keepcpo
