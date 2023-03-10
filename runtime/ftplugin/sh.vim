" Vim filetype plugin file
" Language:		sh
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp
" Last Change:		2022 Sep 07

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl com< cms< fo<"

" Shell:  thanks to Johannes Zellner
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let s:sol = '\%(;\s*\|^\s*\)\@<='  " start of line
  let b:match_words =
	\  s:sol .. 'if\>:' .. s:sol.'elif\>:' .. s:sol.'else\>:' .. s:sol .. 'fi\>,' ..
	\  s:sol .. '\%(for\|while\)\>:' .. s:sol .. 'done\>,' ..
	\  s:sol .. 'case\>:' .. s:sol .. 'esac\>'
  unlet s:sol
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words"
endif

" Change the :browse e filter to primarily show shell-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let  b:browsefilter = "Bourne Shell Scripts (*.sh)\t*.sh\n" ..
		\	  "Korn Shell Scripts (*.ksh)\t*.ksh\n" ..
		\	  "Bash Shell Scripts (*.bash)\t*.bash\n" ..
		\	  "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim: nowrap sw=2 sts=2 ts=8 noet:
